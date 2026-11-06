extends GutTest

var _p: PickupSystem

func before_each() -> void:
	var tuning: RunTuning = RunTuning.new()
	tuning.gem_capacity = 4
	_p = PickupSystem.new()
	autofree(_p)
	_p.setup(tuning)

func test_spawn_returns_true_and_counts_the_gem() -> void:
	assert_true(_p.spawn(Vector2(5.0, 5.0), 1))
	assert_eq(_p.active_count(), 1)

func test_spawn_stores_position() -> void:
	_p.spawn(Vector2(5.0, 5.0), 1)
	assert_eq(_p.position_of(0), Vector2(5.0, 5.0))

func test_spawn_returns_false_when_full_and_changes_nothing() -> void:
	for i in 4:
		assert_true(_p.spawn(Vector2.ZERO, 1))
	assert_false(_p.spawn(Vector2.ZERO, 1))
	assert_eq(_p.active_count(), 4)

func test_the_multimesh_has_one_instance_per_slot() -> void:
	assert_eq(_p.multimesh.instance_count, 4)
	assert_eq(_p.multimesh.transform_format, MultiMesh.TRANSFORM_2D)

func test_a_gem_is_drawn_at_its_position_with_the_gem_radius() -> void:
	_p.spawn(Vector2(20.0, 5.0), 1)
	assert_eq(_p.transform_of(0).origin, Vector2(20.0, 5.0))
	assert_almost_eq(_p.transform_of(0).x.length(), 3.0, 0.001)

func test_empty_slots_are_hidden() -> void:
	assert_eq(_p.transform_of(2), PickupSystem.DEAD_TRANSFORM)

func test_the_system_has_no_child_nodes() -> void:
	for i in 4:
		_p.spawn(Vector2.ZERO, 1)
	assert_eq(_p.get_child_count(), 0)

func test_clear_empties_the_system() -> void:
	_p.spawn(Vector2.ZERO, 1)
	_p.clear()
	assert_eq(_p.active_count(), 0)

func test_a_gem_outside_the_pickup_radius_stays_put() -> void:
	_p.spawn(Vector2(100.0, 0.0), 1)
	_p.tick(0.5, Vector2.ZERO, 40.0, 7.0)
	assert_eq(_p.position_of(0), Vector2(100.0, 0.0))

func test_a_gem_inside_the_radius_is_pulled_at_the_tuned_speed() -> void:
	_p.spawn(Vector2(30.0, 0.0), 1)
	_p.tick(0.1, Vector2.ZERO, 40.0, 7.0)
	assert_almost_eq(_p.position_of(0).x, 30.0 - 18.0, 0.01)

func test_touching_the_player_collects_the_gem_once() -> void:
	watch_signals(_p)
	_p.spawn(Vector2(9.0, 0.0), 3)
	_p.tick(0.016, Vector2.ZERO, 40.0, 7.0)
	assert_signal_emitted_with_parameters(_p, "xp_collected", [3])
	assert_eq(_p.active_count(), 0)
	_p.tick(0.016, Vector2.ZERO, 40.0, 7.0)
	assert_signal_emit_count(_p, "xp_collected", 1)

func test_a_gem_is_never_pulled_past_the_player() -> void:
	watch_signals(_p)
	_p.spawn(Vector2(11.0, 0.0), 1)
	_p.tick(1.0, Vector2.ZERO, 40.0, 7.0)
	assert_eq(_p.active_count(), 0, "it arrived and was collected, not overshot")
	assert_signal_emit_count(_p, "xp_collected", 1)

func test_a_gem_exactly_on_the_player_is_collected_without_nan() -> void:
	watch_signals(_p)
	_p.spawn(Vector2.ZERO, 2)
	_p.tick(0.016, Vector2.ZERO, 40.0, 7.0)
	assert_signal_emitted_with_parameters(_p, "xp_collected", [2])

func test_a_collected_slot_is_reused() -> void:
	_p.spawn(Vector2(9.0, 0.0), 1)
	_p.tick(0.016, Vector2.ZERO, 40.0, 7.0)
	_p.spawn(Vector2(50.0, 0.0), 1)
	assert_eq(_p.position_of(0), Vector2(50.0, 0.0))

func test_a_collected_slot_is_hidden() -> void:
	_p.spawn(Vector2(9.0, 0.0), 1)
	_p.tick(0.016, Vector2.ZERO, 40.0, 7.0)
	assert_eq(_p.transform_of(0), PickupSystem.DEAD_TRANSFORM)

func test_a_larger_pickup_radius_pulls_from_further_away() -> void:
	_p.spawn(Vector2(60.0, 0.0), 1)
	_p.tick(0.1, Vector2.ZERO, 40.0, 7.0)
	assert_eq(_p.position_of(0).x, 60.0)
	_p.tick(0.1, Vector2.ZERO, 70.0, 7.0)
	assert_lt(_p.position_of(0).x, 60.0)

func test_spawn_or_grant_places_a_gem_when_there_is_room() -> void:
	assert_eq(_p.spawn_or_grant(Vector2.ZERO, 5), 0)
	assert_eq(_p.active_count(), 1)

func test_spawn_or_grant_returns_the_xp_when_full() -> void:
	for i in 4:
		_p.spawn(Vector2.ZERO, 1)
	assert_eq(_p.spawn_or_grant(Vector2.ZERO, 5), 5)
	assert_eq(_p.active_count(), 4)

func test_many_gems_collected_in_one_tick_all_report() -> void:
	watch_signals(_p)
	for i in 4:
		_p.spawn(Vector2(5.0, 0.0), 2)
	_p.tick(0.016, Vector2.ZERO, 40.0, 7.0)
	assert_signal_emit_count(_p, "xp_collected", 4)
