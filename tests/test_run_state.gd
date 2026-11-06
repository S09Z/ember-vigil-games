extends GutTest

var _s: RunState

func before_each() -> void:
	_s = RunState.new()
	_s.setup(RunTuning.new())

func _weapon(id: StringName, levels: int) -> WeaponDef:
	var d: WeaponDef = WeaponDef.new()
	d.id = id
	for i in levels:
		d.levels.append(WeaponLevelDef.new())
	return d

func test_a_fresh_state_starts_at_level_one() -> void:
	assert_eq(_s.level, 1)
	assert_eq(_s.kills, 0)
	assert_eq(_s.elapsed, 0.0)

func test_tick_advances_the_clock() -> void:
	_s.tick(0.5)
	_s.tick(0.25)
	assert_almost_eq(_s.elapsed, 0.75, 0.0001)

func test_add_kill_counts_and_signals() -> void:
	watch_signals(_s)
	_s.add_kill()
	_s.add_kill()
	assert_eq(_s.kills, 2)
	assert_signal_emit_count(_s, "kills_changed", 2)

func test_add_weapon_starts_at_level_one_and_signals() -> void:
	watch_signals(_s)
	assert_true(_s.add_weapon(_weapon(&"a", 5)))
	assert_eq(_s.weapon_level(&"a"), 1)
	assert_signal_emitted(_s, "build_changed")

func test_the_same_weapon_cannot_be_added_twice() -> void:
	_s.add_weapon(_weapon(&"a", 5))
	assert_false(_s.add_weapon(_weapon(&"a", 5)))
	assert_eq(_s.weapon_count(), 1)

func test_weapon_slots_cap_at_four() -> void:
	for n in ["a", "b", "c", "d"]:
		assert_true(_s.add_weapon(_weapon(StringName(n), 5)))
	assert_false(_s.has_weapon_room())
	assert_false(_s.add_weapon(_weapon(&"e", 5)))

func test_upgrade_stops_at_the_last_level() -> void:
	_s.add_weapon(_weapon(&"a", 3))
	assert_true(_s.upgrade_weapon(&"a"))
	assert_true(_s.upgrade_weapon(&"a"))
	assert_false(_s.upgrade_weapon(&"a"))
	assert_eq(_s.weapon_level(&"a"), 3)

func test_upgrading_a_weapon_you_do_not_have_fails() -> void:
	assert_false(_s.upgrade_weapon(&"nope"))
	assert_eq(_s.weapon_level(&"nope"), 0)

func test_setup_again_clears_everything() -> void:
	_s.add_weapon(_weapon(&"a", 5))
	_s.add_kill()
	_s.tick(5.0)
	_s.setup(RunTuning.new())
	assert_eq(_s.weapon_count(), 0)
	assert_eq(_s.kills, 0)
	assert_eq(_s.elapsed, 0.0)
