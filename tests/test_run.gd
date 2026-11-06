extends GutTest

const RUN_SCENE: PackedScene = preload("res://run/run.tscn")

var _run: Run

func before_each() -> void:
	_run = RUN_SCENE.instantiate()
	add_child_autofree(_run)

func test_the_run_scene_wires_every_system() -> void:
	assert_not_null(_run.get_node("EnemySystem"))
	assert_not_null(_run.get_node("Player"))
	assert_not_null(_run.get_node("Player/Camera2D"), "the camera follows the player")
	assert_not_null(_run.get_node("DebugOverlay"))

func test_the_player_is_set_up_from_the_knight() -> void:
	var player: Player = _run.get_node("Player")
	assert_eq(player.max_hp, 140.0)

func test_stepping_advances_the_clock() -> void:
	_run.step(0.5)
	assert_almost_eq(_run.elapsed, 0.5, 0.0001)

func test_enemies_appear_over_time_and_stay_under_the_cap() -> void:
	for i in 600:
		_run.step(1.0 / 60.0)
	var enemies: EnemySystem = _run.get_node("EnemySystem")
	assert_gt(enemies.alive_count(), 0)
	assert_lte(enemies.alive_count(), Run.TUNING.enemy_cap)

func test_live_enemies_have_a_visible_size_after_a_step() -> void:
	for i in 120:
		_run.step(1.0 / 60.0)
	var enemies: EnemySystem = _run.get_node("EnemySystem")
	var checked: int = 0
	for i in enemies.capacity():
		if enemies.is_alive(i):
			assert_gt(enemies.transform_of(i).x.length(), 0.0)
			checked += 1
	assert_gt(checked, 0)

func test_the_overlay_text_reports_enemy_count_and_stage_times() -> void:
	for i in 120:
		_run.step(1.0 / 60.0)
	var text: String = _run._overlay_lines()
	assert_string_contains(text, "enemies")
	assert_string_contains(text, "/ 400")
	assert_string_contains(text, "move")

func test_the_run_stops_ticking_when_the_player_dies() -> void:
	var player: Player = _run.get_node("Player")
	assert_true(_run.is_physics_processing())
	player.take_damage(100000.0)
	assert_false(_run.is_physics_processing())

func test_the_same_seed_gives_the_same_run() -> void:
	var other: Run = RUN_SCENE.instantiate()
	add_child_autofree(other)
	for i in 300:
		_run.step(1.0 / 60.0)
		other.step(1.0 / 60.0)
	var a: EnemySystem = _run.get_node("EnemySystem")
	var b: EnemySystem = other.get_node("EnemySystem")
	assert_eq(a.alive_count(), b.alive_count())
	for i in a.capacity():
		if a.is_alive(i):
			assert_eq(a.position_of(i), b.position_of(i))

func test_the_burst_fills_the_enemy_cap_at_once() -> void:
	var enemies: EnemySystem = _run.get_node("EnemySystem")
	assert_eq(enemies.alive_count(), 0)
	var spawned: int = _run.spawn_burst_to_cap()
	assert_eq(spawned, Run.TUNING.enemy_cap)
	assert_eq(enemies.alive_count(), Run.TUNING.enemy_cap)

func test_a_second_burst_adds_nothing_at_the_cap() -> void:
	_run.spawn_burst_to_cap()
	assert_eq(_run.spawn_burst_to_cap(), 0)

func test_the_burst_tops_up_a_partly_filled_run() -> void:
	for i in 300:
		_run.step(1.0 / 60.0)
	var enemies: EnemySystem = _run.get_node("EnemySystem")
	var before: int = enemies.alive_count()
	_run.spawn_burst_to_cap()
	assert_eq(enemies.alive_count(), Run.TUNING.enemy_cap)
	assert_gt(Run.TUNING.enemy_cap, before)

func test_the_run_uses_a_fixed_seed_so_bursts_repeat() -> void:
	var other: Run = RUN_SCENE.instantiate()
	add_child_autofree(other)
	_run.spawn_burst_to_cap()
	other.spawn_burst_to_cap()
	var a: EnemySystem = _run.get_node("EnemySystem")
	var b: EnemySystem = other.get_node("EnemySystem")
	for i in 20:
		assert_eq(a.position_of(i), b.position_of(i))

# --- M2-29: weapons, pickups, level-up and run states -----------------------

const HEARTH_BREAD: CardDef = preload("res://data/cards/hearth_bread.tres")
const EMBER_PURSE: CardDef = preload("res://data/cards/ember_purse.tres")

func _player() -> Player:
	return _run.get_node("Player") as Player

func _player_pos() -> Vector2:
	return _player().global_position

## Spawns a ghoul right next to the player and kills it through EnemySystem, so
## enemy_died fires exactly as it would from a weapon hit.
func _kill_one_enemy_next_to_the_player() -> void:
	var enemies: EnemySystem = _run.get_node("EnemySystem")
	var id: int = enemies.spawn(0, _player_pos() + Vector2(10.0, 0.0), 0.0)
	enemies.kill(id)

## Takes every gem slot with gems far from the player, so none is collected.
func _fill_the_gem_pool() -> void:
	var pickups: PickupSystem = _run.get_node("PickupSystem")
	while pickups.spawn(_player_pos() + Vector2(5000.0, 5000.0), 1):
		pass

func _weapon_def(id: StringName) -> WeaponDef:
	for def in Run.KNIGHT.class_weapons:
		if def.id == id:
			return def
	return null

func _new_weapon_card(id: StringName) -> LevelUpCard:
	var card: LevelUpCard = LevelUpCard.new()
	card.kind = LevelUpCard.Kind.WEAPON
	card.weapon = _weapon_def(id)
	card.new_level = 1
	return card

func _upgrade_card(id: StringName, new_level: int) -> LevelUpCard:
	var card: LevelUpCard = _new_weapon_card(id)
	card.new_level = new_level
	return card

func _fallback_card(card_name: String) -> LevelUpCard:
	var card: LevelUpCard = LevelUpCard.new()
	card.kind = LevelUpCard.Kind.FALLBACK
	card.fallback = HEARTH_BREAD if card_name == "hearth_bread" else EMBER_PURSE
	return card

func test_the_run_scene_has_the_m2_nodes() -> void:
	assert_not_null(_run.get_node("PickupSystem"))
	assert_not_null(_run.get_node("FxLayer"))
	assert_not_null(_run.get_node("HUD"))
	assert_not_null(_run.get_node("LevelUpPanel"))
	assert_not_null(_run.get_node("PauseScreen"))

func test_gems_draw_below_the_enemies_and_effects_above_them() -> void:
	var gems: int = _run.get_node("PickupSystem").get_index()
	var enemies: int = _run.get_node("EnemySystem").get_index()
	var player: int = _run.get_node("Player").get_index()
	var fx: int = _run.get_node("FxLayer").get_index()
	assert_gt(gems, _run.get_node("Background").get_index())
	assert_lt(gems, enemies)
	assert_lt(gems, player)
	assert_gt(fx, enemies)
	assert_gt(fx, player)

func test_a_run_starts_running_with_the_knights_starting_weapon() -> void:
	assert_eq(_run.state, Run.State.RUNNING)
	assert_eq(_run.run_state().weapon_level(&"greatsword"), 1)
	assert_not_null(_run.loadout_weapon(&"greatsword"))

func test_the_greatsword_swings_and_hurts_nearby_enemies() -> void:
	var enemies: EnemySystem = _run.get_node("EnemySystem")
	var id: int = enemies.spawn(0, _player_pos() + Vector2(30.0, 0.0), 0.0)
	var hp: float = enemies.hp_of(id)
	_run.step(1.0 / 60.0)
	assert_lt(enemies.hp_of(id), hp)
	assert_gt(_run.run_state().damage_of(&"greatsword"), 0.0)

func test_the_swing_is_drawn_on_the_fx_layer() -> void:
	_run.step(1.0 / 60.0)
	assert_gt((_run.get_node("FxLayer") as FxLayer).active_count(), 0)

func test_a_kill_drops_a_gem_that_is_collected_into_xp() -> void:
	_kill_one_enemy_next_to_the_player()
	assert_eq(_run.run_state().kills, 1)
	assert_eq((_run.get_node("PickupSystem") as PickupSystem).active_count(), 1, "the kill drops a gem")
	for i in 120: _run.step(1.0 / 60.0)
	assert_gt(_run.run_state().kills, 0)
	assert_true(_run.run_state().xp > 0 or _run.run_state().level > 1)

func test_enough_xp_opens_the_level_up_and_freezes_the_run() -> void:
	_run.run_state().add_xp(10)
	assert_eq(_run.state, Run.State.LEVEL_UP)
	assert_true((_run.get_node("LevelUpPanel") as LevelUpPanel).is_open())
	var t: float = _run.elapsed
	_run.step(1.0)
	assert_eq(_run.elapsed, t, "nothing advances while choosing a card")

func test_picking_a_card_resumes_the_run() -> void:
	_run.run_state().add_xp(10)
	_run.pick_card(0)
	assert_eq(_run.state, Run.State.RUNNING)
	assert_eq(_run.run_state().pending_levelups(), 0)

func test_a_big_gem_shows_every_level_in_turn() -> void:
	_run.run_state().add_xp(10 + 14 + 19)        # three levels at once
	var shown: int = 0
	while _run.state == Run.State.LEVEL_UP and shown < 10:
		_run.pick_card(0); shown += 1
	assert_eq(shown, 3)
	assert_eq(_run.state, Run.State.RUNNING)

func test_picking_through_the_panel_reopens_it_for_the_next_queued_level() -> void:
	var panel: LevelUpPanel = _run.get_node("LevelUpPanel")
	_run.run_state().add_xp(10 + 14)             # two levels at once
	panel._pick(0)
	assert_eq(_run.state, Run.State.LEVEL_UP)
	assert_true(panel.is_open(), "the second level's hand stays on screen")
	panel._pick(0)
	assert_eq(_run.state, Run.State.RUNNING)
	assert_false(panel.is_open())

func test_a_pick_outside_the_level_up_does_nothing() -> void:
	_run.pick_card(0)
	assert_eq(_run.state, Run.State.RUNNING)
	assert_eq(_run.run_state().weapon_count(), 1)

func test_an_out_of_range_pick_keeps_the_hand_open() -> void:
	_run.run_state().add_xp(10)
	_run.pick_card(7)
	_run.pick_card(-1)
	assert_eq(_run.state, Run.State.LEVEL_UP)
	assert_eq(_run.run_state().weapon_count(), 1)

func test_a_new_weapon_card_adds_it_to_the_build_and_the_loadout() -> void:
	_run.apply_card_for_test(_new_weapon_card(&"shield_bash"))
	assert_eq(_run.run_state().weapon_level(&"shield_bash"), 1)
	assert_not_null(_run.loadout_weapon(&"shield_bash"))

func test_an_upgrade_card_raises_the_level_of_the_live_weapon() -> void:
	_run.apply_card_for_test(_upgrade_card(&"greatsword", 2))
	assert_eq(_run.run_state().weapon_level(&"greatsword"), 2)
	assert_eq(_run.loadout_weapon(&"greatsword").level, 2)

func test_hearth_bread_heals_and_ember_purse_adds_embers() -> void:
	var player: Player = _run.get_node("Player"); player.take_damage(52.0)
	var before: float = player.hp
	_run.apply_card_for_test(_fallback_card("hearth_bread"))
	assert_almost_eq(player.hp, minf(before + 30.0, 140.0), 0.01)
	_run.apply_card_for_test(_fallback_card("ember_purse"))
	assert_eq(_run.run_state().embers_bonus(), 5)

func test_a_full_xp_pool_still_grants_xp() -> void:
	_fill_the_gem_pool(); _kill_one_enemy_next_to_the_player()
	assert_gt(_run.run_state().xp, 0)             # granted directly, not lost

func test_pause_toggles_between_running_and_paused() -> void:
	var screen: PauseScreen = _run.get_node("PauseScreen")
	_run.toggle_pause(); assert_eq(_run.state, Run.State.PAUSED)
	assert_true(screen.is_open())
	var t: float = _run.elapsed; _run.step(1.0); assert_eq(_run.elapsed, t)
	_run.toggle_pause(); assert_eq(_run.state, Run.State.RUNNING)
	assert_false(screen.is_open())

func test_pause_does_nothing_while_choosing_a_card() -> void:
	_run.run_state().add_xp(10); _run.toggle_pause()
	assert_eq(_run.state, Run.State.LEVEL_UP)
	assert_false((_run.get_node("PauseScreen") as PauseScreen).is_open())

func test_pause_does_nothing_after_death() -> void:
	(_run.get_node("Player") as Player).take_damage(100000.0)
	_run.toggle_pause()
	assert_eq(_run.state, Run.State.ENDED)

func test_death_ends_the_run_once_with_a_summary() -> void:
	watch_signals(_run)
	_kill_one_enemy_next_to_the_player()
	var player: Player = _run.get_node("Player")
	player.take_damage(100000.0)
	assert_eq(_run.state, Run.State.ENDED)
	assert_signal_emit_count(_run, "run_ended", 1)
	var params: Array = get_signal_parameters(_run, "run_ended")
	var summary: RunSummary = params[0]
	assert_eq(summary.kills, 1)

func test_dying_while_choosing_a_card_closes_the_hand() -> void:
	_run.run_state().add_xp(10)
	_player().take_damage(100000.0)
	assert_eq(_run.state, Run.State.ENDED)
	assert_false((_run.get_node("LevelUpPanel") as LevelUpPanel).is_open())
	_run.pick_card(0)
	assert_eq(_run.state, Run.State.ENDED)

func test_xp_gained_on_the_frame_of_death_does_not_open_a_level_up() -> void:
	(_run.get_node("Player") as Player).take_damage(100000.0)
	_run.run_state().add_xp(10)
	assert_eq(_run.state, Run.State.ENDED, "a dead run never shows a card")
	assert_false((_run.get_node("LevelUpPanel") as LevelUpPanel).is_open())

func test_the_buff_and_the_clock_do_not_run_while_paused() -> void:
	_run.stats().apply_damage_buff(15.0, 3.0)
	_run.toggle_pause(); _run.step(5.0); _run.toggle_pause()
	assert_almost_eq(_run.stats().buff_time_left(), 3.0, 0.001)

func test_the_run_clock_follows_the_run_state() -> void:
	_run.step(0.25)
	assert_almost_eq(_run.run_state().elapsed, 0.25, 0.0001)
	assert_almost_eq(_run.elapsed, _run.run_state().elapsed, 0.0001)

func test_the_hud_shows_kills_and_the_starting_weapon() -> void:
	var hud: HUD = _run.get_node("HUD")
	assert_eq(hud.weapon_slot_text(0), "Greatsword 1")
	_kill_one_enemy_next_to_the_player()
	assert_eq(hud.kills_text(), "1")
