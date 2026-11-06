extends GutTest

var _sys: EnemySystem
var _spawner: SpawnDirector
var _tuning: RunTuning

func before_each() -> void:
	var ghoul: EnemyDef = EnemyDef.new()
	ghoul.id = &"ghoul"
	ghoul.hp = 10.0
	ghoul.move_speed = 45.0
	ghoul.contact_damage = 5.0
	ghoul.xp = 1
	ghoul.body_radius = 6.0
	var defs: Array[EnemyDef] = [ghoul]
	_tuning = RunTuning.new()
	_tuning.enemy_cap = 5
	_sys = EnemySystem.new()
	autofree(_sys)
	_sys.setup(defs, _tuning, Rng.new(3), _tuning.enemy_cap)
	_spawner = SpawnDirector.new()
	_spawner.setup(_sys, _tuning, Rng.new(3))

func test_rate_curve_matches_design() -> void:
	assert_almost_eq(_spawner.rate_at(0.0), 1.0, 0.001)
	assert_almost_eq(_spawner.rate_at(20.0), 2.0, 0.001)
	assert_almost_eq(_spawner.rate_at(220.0), 12.0, 0.001)

func test_rate_is_capped() -> void:
	assert_almost_eq(_spawner.rate_at(10000.0), 12.0, 0.001)

func test_fractional_spawns_accumulate_instead_of_being_lost() -> void:
	_spawner.tick(0.5, 0.0, Vector2.ZERO)
	assert_eq(_sys.alive_count(), 0, "half a second at 1/s is not a whole enemy yet")
	_spawner.tick(0.5, 0.0, Vector2.ZERO)
	assert_eq(_sys.alive_count(), 1)

func test_a_long_frame_can_spawn_several() -> void:
	_spawner.tick(3.0, 0.0, Vector2.ZERO)
	assert_eq(_sys.alive_count(), 3)

func test_the_cap_is_respected() -> void:
	_spawner.tick(100.0, 0.0, Vector2.ZERO)
	assert_eq(_sys.alive_count(), 5)

func test_backlog_is_dropped_at_the_cap() -> void:
	_spawner.tick(100.0, 0.0, Vector2.ZERO)
	_sys.kill(0)
	_spawner.tick(0.1, 0.0, Vector2.ZERO)
	assert_eq(_sys.alive_count(), 4, "a freed slot must not trigger a burst of saved-up spawns")

func test_burst_stops_at_the_cap() -> void:
	assert_eq(_spawner.spawn_burst(99, 0.0, Vector2.ZERO), 5)
	assert_eq(_sys.alive_count(), 5)

func test_spawns_land_in_the_ring_around_the_player() -> void:
	var player_pos: Vector2 = Vector2(100.0, -200.0)
	_spawner.spawn_burst(5, 0.0, player_pos)
	for i in 5:
		var d: float = _sys.position_of(i).distance_to(player_pos)
		assert_between(d, _tuning.spawn_ring_min, _tuning.spawn_ring_max)

func test_spawned_enemies_carry_the_time_scaled_hp() -> void:
	_spawner.spawn_burst(1, 150.0, Vector2.ZERO)
	assert_almost_eq(_sys.hp_of(0), 20.0, 0.01)

func test_the_cap_comes_from_the_tuning() -> void:
	_tuning.enemy_cap = 2
	assert_eq(_spawner.spawn_burst(99, 0.0, Vector2.ZERO), 2)

func test_the_same_seed_gives_the_same_spawn_points() -> void:
	var other_sys: EnemySystem = EnemySystem.new()
	autofree(other_sys)
	var ghoul: EnemyDef = EnemyDef.new()
	var defs: Array[EnemyDef] = [ghoul]
	other_sys.setup(defs, _tuning, Rng.new(3), 5)
	var other: SpawnDirector = SpawnDirector.new()
	other.setup(other_sys, _tuning, Rng.new(3))
	_spawner.spawn_burst(3, 0.0, Vector2.ZERO)
	other.spawn_burst(3, 0.0, Vector2.ZERO)
	for i in 3:
		assert_eq(_sys.position_of(i), other_sys.position_of(i))
