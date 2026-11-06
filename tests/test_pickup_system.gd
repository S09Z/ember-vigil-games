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
