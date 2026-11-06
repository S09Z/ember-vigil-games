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
	_sys.setup(defs, _tuning, 8)

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
