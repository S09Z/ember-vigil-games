extends GutTest

var _sys: EnemySystem
var _tuning: RunTuning
var _ghoul: EnemyDef

func before_each() -> void:
	_ghoul = EnemyDef.new()
	_ghoul.id = &"ghoul"
	_ghoul.hp = 10.0
	_ghoul.move_speed = 45.0
	_ghoul.contact_damage = 5.0
	_ghoul.xp = 1
	_ghoul.body_radius = 6.0
	_tuning = RunTuning.new()
	var defs: Array[EnemyDef] = [_ghoul]
	_sys = EnemySystem.new()
	autofree(_sys)
	_sys.setup(defs, _tuning, Rng.new(7), 8)

func test_a_fresh_system_is_empty() -> void:
	assert_eq(_sys.alive_count(), 0)
	assert_eq(_sys.capacity(), 8)

func test_spawn_returns_a_slot_and_counts_it() -> void:
	assert_eq(_sys.spawn(0, Vector2.ZERO, 0.0), 0)
	assert_eq(_sys.alive_count(), 1)
	assert_true(_sys.is_alive(0))

func test_spawn_stores_the_position() -> void:
	var id: int = _sys.spawn(0, Vector2(12.0, -4.0), 0.0)
	assert_eq(_sys.position_of(id), Vector2(12.0, -4.0))

func test_kill_frees_the_slot_for_reuse() -> void:
	var id: int = _sys.spawn(0, Vector2.ZERO, 0.0)
	_sys.kill(id)
	assert_eq(_sys.alive_count(), 0)
	assert_false(_sys.is_alive(id))
	assert_eq(_sys.spawn(0, Vector2.ZERO, 0.0), id, "slots must be recycled")

func test_killing_twice_is_harmless() -> void:
	var id: int = _sys.spawn(0, Vector2.ZERO, 0.0)
	_sys.kill(id)
	_sys.kill(id)
	assert_eq(_sys.alive_count(), 0)

func test_kill_ignores_out_of_range_ids() -> void:
	_sys.kill(-1)
	_sys.kill(99)
	assert_eq(_sys.alive_count(), 0)

func test_kill_reports_position_and_xp() -> void:
	watch_signals(_sys)
	var id: int = _sys.spawn(0, Vector2(3.0, 3.0), 0.0)
	_sys.kill(id)
	assert_signal_emitted_with_parameters(_sys, "enemy_died", [Vector2(3.0, 3.0), 1])

func test_killing_one_enemy_does_not_move_another() -> void:
	var a: int = _sys.spawn(0, Vector2(1.0, 1.0), 0.0)
	var b: int = _sys.spawn(0, Vector2(2.0, 2.0), 0.0)
	var c: int = _sys.spawn(0, Vector2(3.0, 3.0), 0.0)
	_sys.kill(a)
	assert_eq(_sys.position_of(b), Vector2(2.0, 2.0), "slots are stable, nothing is compacted")
	assert_eq(_sys.position_of(c), Vector2(3.0, 3.0))

func test_spawn_returns_minus_one_when_full() -> void:
	for i in 8:
		assert_ne(_sys.spawn(0, Vector2.ZERO, 0.0), -1)
	assert_eq(_sys.spawn(0, Vector2.ZERO, 0.0), -1)
	assert_eq(_sys.alive_count(), 8)

func test_hp_at_spawn_scales_with_elapsed_time() -> void:
	assert_almost_eq(_sys.hp_of(_sys.spawn(0, Vector2.ZERO, 0.0)), 10.0, 0.01)
	assert_almost_eq(_sys.hp_of(_sys.spawn(0, Vector2.ZERO, 150.0)), 20.0, 0.01,
		"1 + 150/150 doubles it")
	assert_almost_eq(_sys.hp_of(_sys.spawn(0, Vector2.ZERO, 300.0)), 30.0, 0.01)

func test_system_has_no_child_nodes() -> void:
	for i in 8:
		_sys.spawn(0, Vector2.ZERO, 0.0)
	assert_eq(_sys.get_child_count(), 0, "no node per enemy")

func test_multimesh_has_one_instance_per_slot() -> void:
	assert_not_null(_sys.multimesh)
	assert_eq(_sys.multimesh.instance_count, 8)
	assert_eq(_sys.multimesh.transform_format, MultiMesh.TRANSFORM_2D)

# The headless renderer does not store MultiMesh data, so these test the
# transform that sync_multimesh() writes rather than reading it back.
func test_drawn_transform_follows_the_enemy() -> void:
	var id: int = _sys.spawn(0, Vector2(20.0, 5.0), 0.0)
	assert_eq(_sys.transform_of(id).origin, Vector2(20.0, 5.0))

func test_drawn_size_follows_the_body_radius() -> void:
	var id: int = _sys.spawn(0, Vector2.ZERO, 0.0)
	assert_almost_eq(_sys.transform_of(id).x.length(), 6.0, 0.001)
	assert_almost_eq(_sys.transform_of(id).y.length(), 6.0, 0.001)

func test_never_used_slots_are_hidden() -> void:
	assert_eq(_sys.transform_of(5), EnemySystem.DEAD_TRANSFORM)

func test_dead_slots_are_hidden() -> void:
	var id: int = _sys.spawn(0, Vector2(20.0, 5.0), 0.0)
	_sys.kill(id)
	assert_eq(_sys.transform_of(id), EnemySystem.DEAD_TRANSFORM)
	assert_almost_eq(EnemySystem.DEAD_TRANSFORM.get_scale().length(), 0.0, 0.001)

func test_a_reused_slot_is_drawn_at_its_new_position() -> void:
	var id: int = _sys.spawn(0, Vector2(20.0, 5.0), 0.0)
	_sys.kill(id)
	var again: int = _sys.spawn(0, Vector2(-7.0, 9.0), 0.0)
	assert_eq(again, id)
	assert_eq(_sys.transform_of(id).origin, Vector2(-7.0, 9.0))

func test_sync_multimesh_runs_with_live_and_dead_slots() -> void:
	var a: int = _sys.spawn(0, Vector2(1.0, 1.0), 0.0)
	_sys.spawn(0, Vector2(2.0, 2.0), 0.0)
	_sys.kill(a)
	_sys.sync_multimesh()
	assert_eq(_sys.alive_count(), 1)

func test_enemy_walks_towards_the_player() -> void:
	var id: int = _sys.spawn(0, Vector2(100.0, 0.0), 0.0)
	_sys.tick_movement(0.1, Vector2.ZERO)
	assert_almost_eq(_sys.position_of(id).x, 95.5, 0.01, "45 px/s for 0.1 s")
	assert_almost_eq(_sys.position_of(id).y, 0.0, 0.001)

func test_enemy_walks_straight_at_a_diagonal_target() -> void:
	var id: int = _sys.spawn(0, Vector2(30.0, 40.0), 0.0)
	_sys.tick_movement(1.0, Vector2.ZERO)
	assert_almost_eq(_sys.position_of(id).length(), 5.0, 0.01, "50 px away, moves 45")

func test_enemy_on_top_of_the_player_does_not_produce_nan() -> void:
	var id: int = _sys.spawn(0, Vector2.ZERO, 0.0)
	_sys.tick_movement(0.1, Vector2.ZERO)
	assert_false(is_nan(_sys.position_of(id).x), "normalising a zero vector must not leak NaN")
	assert_false(is_nan(_sys.position_of(id).y))

func test_a_stray_enemy_is_recycled_into_the_spawn_ring() -> void:
	var id: int = _sys.spawn(0, Vector2(2000.0, 0.0), 0.0)
	_sys.tick_movement(0.1, Vector2.ZERO)
	var d: float = _sys.position_of(id).length()
	assert_between(d, _tuning.spawn_ring_min, _tuning.spawn_ring_max)
	assert_eq(_sys.alive_count(), 1, "recycling moves an enemy, it does not kill it")
	assert_true(_sys.is_alive(id))

func test_recycling_is_centred_on_the_player() -> void:
	var player: Vector2 = Vector2(5000.0, -3000.0)
	var id: int = _sys.spawn(0, Vector2.ZERO, 0.0)
	_sys.tick_movement(0.1, player)
	var d: float = _sys.position_of(id).distance_to(player)
	assert_between(d, _tuning.spawn_ring_min, _tuning.spawn_ring_max)

func test_an_enemy_just_inside_the_recycle_distance_keeps_walking() -> void:
	var id: int = _sys.spawn(0, Vector2(599.0, 0.0), 0.0)
	_sys.tick_movement(0.1, Vector2.ZERO)
	assert_almost_eq(_sys.position_of(id).x, 594.5, 0.01)

func test_dead_slots_do_not_move() -> void:
	var id: int = _sys.spawn(0, Vector2(100.0, 0.0), 0.0)
	_sys.kill(id)
	_sys.tick_movement(0.1, Vector2.ZERO)
	assert_eq(_sys.position_of(id), Vector2(100.0, 0.0))

func test_recycling_is_repeatable_with_the_same_seed() -> void:
	var defs: Array[EnemyDef] = [_ghoul]
	var other: EnemySystem = EnemySystem.new()
	autofree(other)
	other.setup(defs, _tuning, Rng.new(7), 8)
	var a: int = _sys.spawn(0, Vector2(2000.0, 0.0), 0.0)
	var b: int = other.spawn(0, Vector2(2000.0, 0.0), 0.0)
	_sys.tick_movement(0.1, Vector2.ZERO)
	other.tick_movement(0.1, Vector2.ZERO)
	assert_eq(_sys.position_of(a), other.position_of(b))
