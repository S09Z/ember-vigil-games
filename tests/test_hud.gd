extends GutTest

const HUD_SCENE: PackedScene = preload("res://ui/hud.tscn")

var _hud: HUD
var _state: RunState
var _player: Player


func before_each() -> void:
	var tuning: RunTuning = RunTuning.new()
	tuning.xp_base = 5.0
	tuning.xp_per_level = 5.0  # level 1 needs 10
	_state = RunState.new()
	_state.setup(tuning)
	var def: ClassDef = ClassDef.new()
	def.max_hp = 140.0
	def.armor = 2
	_player = Player.new()
	autofree(_player)
	_player.setup(def, tuning)
	_hud = HUD_SCENE.instantiate() as HUD
	add_child_autofree(_hud)


func _weapon(id: StringName) -> WeaponDef:
	var d: WeaponDef = WeaponDef.new()
	d.id = id
	for i in 3:
		d.levels.append(WeaponLevelDef.new())
	return d


func test_time_formatting() -> void:
	assert_eq(HUD.format_time(0.0), "00:00")
	assert_eq(HUD.format_time(125.9), "02:05")
	assert_eq(HUD.format_time(3599.0), "59:59")
	assert_eq(HUD.format_time(3600.0), "60:00")


func test_negative_time_is_clamped_to_zero() -> void:
	assert_eq(HUD.format_time(-3.0), "00:00")


func test_hp_formatting() -> void:
	assert_eq(HUD.format_hp(117.0, 140.0), "HP 117 / 140")
	assert_eq(HUD.format_hp(0.4, 140.0), "HP 1 / 140", "a living player never shows 0")
	assert_eq(HUD.format_hp(0.0, 140.0), "HP 0 / 140")
	assert_eq(HUD.format_hp(-5.0, 140.0), "HP 0 / 140")
	assert_eq(HUD.format_hp(116.2, 140.0), "HP 117 / 140")


func test_binding_shows_the_current_state() -> void:
	_hud.bind(_state, _player)
	assert_eq(_hud.hp_text(), "HP 140 / 140")
	assert_eq(_hud.kills_text(), "0")


func test_it_updates_from_signals() -> void:
	_hud.bind(_state, _player)
	_state.add_kill()
	_state.add_kill()
	_player.take_damage(25.0)
	assert_eq(_hud.kills_text(), "2")
	assert_eq(_hud.hp_text(), "HP 117 / 140")


func test_weapon_slots_follow_the_build() -> void:
	_hud.bind(_state, _player, {&"greatsword": "Greatsword"})
	_state.add_weapon(_weapon(&"greatsword"))
	assert_eq(_hud.weapon_slot_text(0), "Greatsword 1")
	assert_eq(_hud.weapon_slot_text(1), "")
	_state.upgrade_weapon(&"greatsword")
	assert_eq(_hud.weapon_slot_text(0), "Greatsword 2")


func test_weapon_slot_falls_back_to_the_id() -> void:
	_hud.bind(_state, _player)
	_state.add_weapon(_weapon(&"warhorn"))
	assert_eq(_hud.weapon_slot_text(0), "warhorn 1")


func test_xp_bar_reflects_progress() -> void:
	_hud.bind(_state, _player)
	_state.add_xp(5)
	assert_almost_eq(_hud.xp_fraction(), 0.5, 0.001)


func test_clock_and_embers_labels() -> void:
	_hud.set_clock(125.9)
	_hud.set_embers(12)
	assert_eq(_hud.clock_text(), "02:05")
	assert_eq(_hud.embers_text(), "Embers 12")
