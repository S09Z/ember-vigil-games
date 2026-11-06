extends GutTest

var _state: RunState


func before_each() -> void:
	_state = RunState.new()
	_state.setup(RunTuning.new())


func test_from_state_copies_the_numbers() -> void:
	for i in 29: _state.add_kill()
	_state.tick(125.0); _state.add_xp(24); _state.add_embers_bonus(5)
	_state.record_damage(&"greatsword", 1250.4)
	var s: RunSummary = RunSummary.from_state(_state)
	assert_eq(s.kills, 29); assert_almost_eq(s.survived_seconds, 125.0, 0.001); assert_eq(s.level, 3)
	assert_eq(s.embers_from_kills, 2); assert_eq(s.embers_from_time, 8); assert_eq(s.embers_bonus, 5)
	assert_eq(s.embers_total, 15); assert_almost_eq(s.damage_by_weapon[&"greatsword"], 1250.4, 0.01)


func test_the_summary_does_not_change_when_the_state_does() -> void:
	var s: RunSummary = RunSummary.from_state(_state)
	_state.add_kill()
	_state.record_damage(&"a", 5.0)
	assert_eq(s.kills, 0)
	assert_true(s.damage_by_weapon.is_empty())
