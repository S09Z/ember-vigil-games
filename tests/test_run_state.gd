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

func test_xp_curve_matches_the_design() -> void:
	assert_eq(_s.xp_needed(1), 10)    # round(5 + 1 * 4.5) = round(9.5)
	assert_eq(_s.xp_needed(2), 14)
	assert_eq(_s.xp_needed(3), 19)    # round(18.5) rounds half away from zero
	assert_eq(_s.xp_needed(10), 50)

func test_enough_xp_levels_up_and_keeps_the_remainder() -> void:
	_s.add_xp(13)
	assert_eq(_s.level, 2)
	assert_eq(_s.xp, 3)

func test_one_big_gem_can_gain_several_levels() -> void:
	watch_signals(_s)
	_s.add_xp(10 + 14 + 19 + 5)       # lv1->2, 2->3, 3->4 then 5 left
	assert_eq(_s.level, 4)
	assert_eq(_s.xp, 5)
	assert_signal_emit_count(_s, "level_up_queued", 3)

func test_exact_threshold_levels_up_with_zero_left() -> void:
	_s.add_xp(10)
	assert_eq(_s.level, 2)
	assert_eq(_s.xp, 0)

func test_one_xp_short_does_not_level_up() -> void:
	_s.add_xp(9)
	assert_eq(_s.level, 1)

func test_zero_or_negative_xp_is_ignored() -> void:
	watch_signals(_s)
	_s.add_xp(0)
	_s.add_xp(-5)
	assert_eq(_s.xp, 0)
	assert_signal_not_emitted(_s, "xp_changed")

func test_xp_changed_reports_final_values() -> void:
	watch_signals(_s)
	_s.add_xp(13)
	assert_signal_emitted_with_parameters(_s, "xp_changed", [3, 14, 2])

func test_each_level_gained_is_queued_in_order() -> void:
	_s.add_xp(10 + 14 + 19)            # reaches level 4
	assert_eq(_s.pending_levelups(), 3)
	assert_eq(_s.pop_levelup(), 2)
	assert_eq(_s.pop_levelup(), 3)
	assert_eq(_s.pop_levelup(), 4)
	assert_eq(_s.pop_levelup(), -1)

func test_a_level_gained_while_one_is_pending_is_not_lost() -> void:
	_s.add_xp(10)
	_s.add_xp(14)                       # second level before the first was popped
	assert_eq(_s.pending_levelups(), 2)
	assert_eq(_s.pop_levelup(), 2)
	assert_eq(_s.pop_levelup(), 3)

func test_popping_an_empty_queue_is_safe() -> void:
	assert_eq(_s.pop_levelup(), -1)
	assert_eq(_s.pending_levelups(), 0)

func test_setup_clears_the_queue() -> void:
	_s.add_xp(100)
	_s.setup(RunTuning.new())
	assert_eq(_s.pending_levelups(), 0)

func test_setup_resets_level_and_xp() -> void:
	_s.add_xp(100)
	_s.setup(RunTuning.new())
	assert_eq(_s.level, 1)
	assert_eq(_s.xp, 0)

func test_damage_accumulates_per_weapon() -> void:
	_s.record_damage(&"a", 20.0); _s.record_damage(&"a", 5.0); _s.record_damage(&"b", 8.0)
	assert_eq(_s.damage_of(&"a"), 25.0); assert_eq(_s.damage_of(&"b"), 8.0)

func test_an_unused_weapon_has_zero_damage() -> void:
	assert_eq(_s.damage_of(&"never"), 0.0)

func test_non_positive_damage_is_ignored() -> void:
	_s.record_damage(&"a", 0.0); _s.record_damage(&"a", -3.0)
	assert_eq(_s.damage_by_weapon().size(), 0)

func test_setup_clears_recorded_damage() -> void:
	_s.record_damage(&"a", 9.0); _s.setup(RunTuning.new())
	assert_eq(_s.damage_of(&"a"), 0.0)
