class_name Run
extends Node2D

## Owns the update order of one run. Every system is ticked from here instead of
## having its own _physics_process, so the order is visible in one place and the
## debug overlay can attribute time to each stage.
##
## The scene tree is never paused: the run freezes by not stepping unless the
## state is RUNNING, so time, buffs and cooldowns only advance while playing.

signal run_ended(summary: RunSummary)

enum State { RUNNING, LEVEL_UP, PAUSED, ENDED }

const START_SEED: int = 20261030
const HAND_SIZE: int = 3

const KNIGHT: ClassDef = preload("res://data/classes/knight.tres")
const GHOUL: EnemyDef = preload("res://data/enemies/ghoul.tres")
const TUNING: RunTuning = preload("res://data/tuning/run_tuning.tres")
const HEARTH_BREAD: CardDef = preload("res://data/cards/hearth_bread.tres")
const EMBER_PURSE: CardDef = preload("res://data/cards/ember_purse.tres")

var state: State = State.RUNNING
## Mirrors RunState.elapsed after every step, kept for the overlay and M1 tests.
var elapsed: float = 0.0

var _rng: Rng = null
var _spawner: SpawnDirector = null
var _run_state: RunState = null
var _stats: StatBlock = null
var _loadout: WeaponLoadout = null
var _ctx: WeaponContext = null
var _catalog: Dictionary = {}  # StringName weapon id -> WeaponDef
var _name_of: Dictionary = {}  # StringName weapon id -> display name
var _fallbacks: Array[CardDef] = [HEARTH_BREAD, EMBER_PURSE]
var _hand: Array[LevelUpCard] = []
var _shown_embers: int = -1

@onready var _enemies: EnemySystem = $EnemySystem
@onready var _pickups: PickupSystem = $PickupSystem
@onready var _player: Player = $Player
@onready var _fx: FxLayer = $FxLayer
@onready var _hud: HUD = $HUD
@onready var _panel: LevelUpPanel = $LevelUpPanel
@onready var _pause_screen: PauseScreen = $PauseScreen
@onready var _overlay: DebugOverlay = $DebugOverlay


func _ready() -> void:
	_rng = Rng.new(START_SEED)
	var defs: Array[EnemyDef] = [GHOUL]
	# M2-3 will pass the class the player picked at Camp instead of hardcoding it
	_player.setup(KNIGHT, TUNING)
	_enemies.setup(defs, TUNING, _rng, TUNING.enemy_cap)
	_pickups.setup(TUNING)
	_spawner = SpawnDirector.new()
	_spawner.setup(_enemies, TUNING, _rng)

	for def in KNIGHT.class_weapons:
		_catalog[def.id] = def
		_name_of[def.id] = def.display_name
	_run_state = RunState.new()
	_run_state.setup(TUNING)
	_stats = StatBlock.new()
	_loadout = WeaponLoadout.new()
	_ctx = WeaponContext.new()
	_ctx.setup(_player, _enemies, _fx, _run_state, _stats, KNIGHT.steel_lifesteal)

	_run_state.build_changed.connect(_on_build_changed)
	_run_state.level_up_queued.connect(_on_level_up_queued)
	_enemies.enemy_died.connect(_on_enemy_died)
	_pickups.xp_collected.connect(_on_xp_collected)
	_panel.card_picked.connect(pick_card)
	_player.died.connect(_on_player_died)

	_hud.bind(_run_state, _player, _name_of)
	_run_state.add_weapon(KNIGHT.start_weapon)
	_update_embers()
	_overlay.bind_extra_lines(_overlay_lines)


func _physics_process(delta: float) -> void:
	step(delta)


## Debug key (F4): fills the enemy cap immediately so the worst case can be
## measured without waiting for the spawn curve. Ships in the web build on
## purpose, because the M1 gate is measured there. Returns how many were added.
func spawn_burst_to_cap() -> int:
	var free: int = _enemies.capacity() - _enemies.alive_count()
	return _spawner.spawn_burst(free, elapsed, _player.global_position)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_spawn_burst"):
		spawn_burst_to_cap()
	elif event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()


## One frame of the run. Separate from _physics_process so tests can drive it by
## hand. Does nothing unless RUNNING. The order matters: the grid must be rebuilt
## before anything queries it (weapons included), and nothing may move between
## the rebuild and the last query.
func step(delta: float) -> void:
	if state != State.RUNNING:
		return
	_player.tick(delta)
	_stats.tick(delta)
	_run_state.tick(delta)
	elapsed = _run_state.elapsed
	_spawner.tick(delta, elapsed, _player.global_position)
	_enemies.tick_grid()
	_loadout.tick(delta, _ctx)
	_enemies.tick_separation()
	_enemies.tick_contact(_player)
	_enemies.tick_movement(delta, _player.global_position)
	_pickups.tick(delta, _player.global_position, _player.pickup_radius, _player.body_radius)
	_enemies.sync_multimesh()
	_pickups.sync_multimesh()
	_fx.tick(delta)
	_hud.set_clock(elapsed)
	_update_embers()


## RUNNING <-> PAUSED only; ignored while choosing a card or after death.
func toggle_pause() -> void:
	if state == State.RUNNING:
		state = State.PAUSED
		_pause_screen.show_build(PauseScreen.build_lines(_run_state, _name_of))
	elif state == State.PAUSED:
		state = State.RUNNING
		_pause_screen.hide_screen()


## Applies a card from the hand on screen (LevelUpPanel.card_picked), then shows
## the next queued level or resumes. Ignored outside LEVEL_UP or out of range.
func pick_card(index: int) -> void:
	if state != State.LEVEL_UP or index < 0 or index >= _hand.size():
		return
	var card: LevelUpCard = _hand[index]
	_hand.clear()
	_apply_card(card)
	if state != State.LEVEL_UP:
		return  # the card itself can't end the run today, but never resume a dead run
	if _run_state.pending_levelups() > 0:
		_present_next_level()
	else:
		_panel.hide_panel()
		state = State.RUNNING


func run_state() -> RunState:
	return _run_state


func stats() -> StatBlock:
	return _stats


func loadout_weapon(id: StringName) -> WeaponBase:
	return _loadout.get_weapon(id)


## Applies a card exactly as pick_card would, without a hand or the panel.
func apply_card_for_test(card: LevelUpCard) -> void:
	_apply_card(card)


func _apply_card(card: LevelUpCard) -> void:
	if card.kind == LevelUpCard.Kind.FALLBACK:
		_player.heal(card.fallback.heal_amount)
		_run_state.add_embers_bonus(card.fallback.embers_bonus)
		_update_embers()
		return
	var id: StringName = card.weapon.id
	if _run_state.weapon_level(id) == 0:
		_run_state.add_weapon(card.weapon)
	else:
		_run_state.upgrade_weapon(id)


## Pops the oldest queued level, draws a hand for it and shows it. Allocates;
## runs once per level-up, never per frame.
func _present_next_level() -> void:
	var new_level: int = _run_state.pop_levelup()
	if new_level < 0:
		return
	state = State.LEVEL_UP
	_hand = LevelUpDeck.draw(_run_state, KNIGHT, _fallbacks, _rng, HAND_SIZE)
	_panel.show_cards(_hand, new_level - 1, new_level)


## Only touches the HUD label when the total changes (it formats a String).
func _update_embers() -> void:
	var total: int = _run_state.embers_total()
	if total == _shown_embers:
		return
	_shown_embers = total
	_hud.set_embers(total)


func _overlay_lines() -> String:
	return "enemies %d / %d\ngrid %.2f  sep %.2f  hit %.2f  move %.2f  draw %.2f ms" % [
		_enemies.alive_count(),
		_enemies.capacity(),
		_enemies.usec_grid / 1000.0,
		_enemies.usec_separation / 1000.0,
		_enemies.usec_contact / 1000.0,
		_enemies.usec_movement / 1000.0,
		_enemies.usec_multimesh / 1000.0,
	]


func _on_build_changed() -> void:
	_loadout.sync(_run_state, _catalog)


func _on_enemy_died(pos: Vector2, xp: int) -> void:
	_run_state.add_kill()
	_run_state.add_xp(_pickups.spawn_or_grant(pos, xp))


func _on_xp_collected(amount: int) -> void:
	_run_state.add_xp(amount)


## Every level-up is queued in RunState; only the first one opens the panel.
## The rest wait for pick_card. A dead or paused run never opens a card.
func _on_level_up_queued(_new_level: int) -> void:
	if state == State.RUNNING:
		_present_next_level()


func _on_player_died() -> void:
	if state == State.ENDED:
		return
	state = State.ENDED
	_hand.clear()
	_panel.hide_panel()
	_pause_screen.hide_screen()
	set_physics_process(false)
	run_ended.emit(RunSummary.from_state(_run_state))
