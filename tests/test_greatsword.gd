extends GutTest

var _weapon: Greatsword
var _enemies: EnemySystem
var _state: RunState
var _stats: StatBlock
var _player: Player
var _ctx: WeaponContext

func before_each() -> void:
	var edef: EnemyDef = EnemyDef.new()
	edef.id = &"dummy"
	edef.hp = 1000.0
	edef.move_speed = 0.0
	edef.contact_damage = 0.0
	edef.xp = 1
	edef.body_radius = 6.0
	var defs: Array[EnemyDef] = [edef]
	_enemies = EnemySystem.new()
	autofree(_enemies)
	_enemies.setup(defs, RunTuning.new(), Rng.new(3), 16)

	_state = RunState.new()
	_state.setup(RunTuning.new())
	_stats = StatBlock.new()
	var cdef: ClassDef = ClassDef.new()
	cdef.max_hp = 100.0
	cdef.move_speed = 90.0
	cdef.body_radius = 7.0
	cdef.pickup_radius = 40.0
	_player = Player.new()
	autofree(_player)
	_player.setup(cdef, RunTuning.new())
	_player.global_position = Vector2.ZERO
	_ctx = WeaponContext.new()
	_ctx.setup(_player, _enemies, null, _state, _stats, 0.0)

	_weapon = Greatsword.new()
	_weapon.setup(load("res://data/weapons/greatsword.tres"))

func _spawn(pos: Vector2) -> int:
	return _enemies.spawn(0, pos, 0.0)

func _swing() -> void:
	_enemies.tick_grid()
	_weapon.tick(0.0, _ctx)

func _advance(t: float) -> void:
	var steps: int = int(round(t * 60.0))
	for i in steps:
		_enemies.tick_movement(1.0 / 60.0, _player.global_position)

func test_the_data_file_matches_the_design_table() -> void:
	var d: WeaponDef = load("res://data/weapons/greatsword.tres")
	assert_eq(d.id, &"greatsword"); assert_eq(d.tag, &"steel")
	var lv: WeaponLevelDef = d.level_data(1)
	assert_eq(lv.damage, 20.0); assert_eq(lv.cooldown, 1.1); assert_eq(lv.arc_degrees, 140.0)
	assert_eq(lv.range, 48.0); assert_eq(lv.knockback, 20.0)

func test_hits_an_enemy_in_front() -> void:
	var id: int = _spawn(Vector2(30.0, 0.0))
	_swing()
	assert_almost_eq(_enemies.hp_of(id), 980.0, 0.01)

func test_misses_an_enemy_behind() -> void:
	var id: int = _spawn(Vector2(-30.0, 0.0))
	_swing()
	assert_eq(_enemies.hp_of(id), 1000.0)

func test_misses_an_enemy_out_of_range() -> void:
	var id: int = _spawn(Vector2(60.0, 0.0))
	_swing()
	assert_eq(_enemies.hp_of(id), 1000.0)

func test_pushes_the_enemy_away_from_the_player() -> void:
	var id: int = _spawn(Vector2(30.0, 0.0))
	_swing()
	_advance(0.5)
	assert_almost_eq(_enemies.position_of(id).x, 50.0, 0.5)

func test_swings_with_no_enemies_without_error() -> void:
	_swing()
	assert_eq(_enemies.alive_count(), 0)

func test_follows_the_last_move_direction() -> void:
	_player.apply_input(Vector2.UP)
	var up: int = _spawn(Vector2(0.0, -30.0))
	var right: int = _spawn(Vector2(30.0, 0.0))
	_swing()
	assert_lt(_enemies.hp_of(up), 1000.0); assert_eq(_enemies.hp_of(right), 1000.0)

func test_damage_is_recorded_for_the_results_screen() -> void:
	_spawn(Vector2(30.0, 0.0)); _swing()
	assert_eq(_state.damage_of(&"greatsword"), 20.0)

func test_a_real_loadout_creates_a_greatsword() -> void:
	var loadout: WeaponLoadout = WeaponLoadout.new()
	assert_true(loadout.factories.has(&"greatsword"))
