extends GutTest

var _weapon: ShieldBash
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

	_weapon = ShieldBash.new()
	_weapon.setup(load("res://data/weapons/shield_bash.tres"))

func _spawn(pos: Vector2) -> int:
	return _enemies.spawn(0, pos, 0.0)

func _bash() -> void:
	_enemies.tick_grid()
	_weapon.tick(0.0, _ctx)

func _set_level(n: int) -> void:
	_weapon.level = n

func _advance(t: float) -> void:
	var steps: int = int(round(t * 60.0))
	for i in steps:
		_enemies.tick_movement(1.0 / 60.0, _player.global_position)

func test_the_level_table_matches_the_design() -> void:
	var d: WeaponDef = load("res://data/weapons/shield_bash.tres")
	assert_eq(d.max_level(), 5); assert_eq(d.tag, &"steel")
	assert_eq(d.level_data(1).damage, 8.0); assert_eq(d.level_data(1).cooldown, 3.0)
	assert_eq(d.level_data(1).stun_seconds, 0.5); assert_eq(d.level_data(1).knockback, 60.0)
	assert_eq(d.level_data(3).stun_seconds, 1.0)
	assert_eq(d.level_data(5).damage, 24.0); assert_eq(d.level_data(5).cooldown, 2.0)
	for n in range(1, 6):
		assert_eq(d.level_data(n).arc_degrees, 90.0); assert_eq(d.level_data(n).range, 40.0)

func test_hits_stuns_and_pushes_an_enemy_in_the_cone() -> void:
	var id: int = _spawn(Vector2(30.0, 0.0)); _bash()
	assert_almost_eq(_enemies.hp_of(id), 992.0, 0.01)
	assert_true(_enemies.is_stunned(id))

func test_misses_outside_the_ninety_degree_cone() -> void:
	var id: int = _spawn(Vector2.from_angle(deg_to_rad(50.0)) * 30.0)   # half angle is 45
	_bash()
	assert_eq(_enemies.hp_of(id), 1000.0); assert_false(_enemies.is_stunned(id))

func test_misses_beyond_range_forty() -> void:
	var id: int = _spawn(Vector2(41.0, 0.0)); _bash()
	assert_eq(_enemies.hp_of(id), 1000.0)

func test_pushes_sixty_pixels() -> void:
	var id: int = _spawn(Vector2(30.0, 0.0)); _bash(); _advance(0.5)
	assert_almost_eq(_enemies.position_of(id).x, 90.0, 0.5)

func test_level_three_stuns_for_a_full_second() -> void:
	_set_level(3); var id: int = _spawn(Vector2(30.0, 0.0)); _bash()
	_advance(0.9); assert_true(_enemies.is_stunned(id))
	_advance(0.2); assert_false(_enemies.is_stunned(id))

func test_it_heals_through_oathguard_because_it_is_steel() -> void:
	_ctx.steel_lifesteal = 0.03   # the Knight's Oathguard value
	_player.take_damage(32.0); _spawn(Vector2(30.0, 0.0)); _bash()
	assert_almost_eq(_player.hp, 68.0 + 8.0 * 0.03, 0.01)

func test_bashing_with_no_enemies_is_harmless() -> void:
	_bash(); assert_eq(_enemies.alive_count(), 0)

func test_a_real_loadout_creates_a_shield_bash() -> void:
	var loadout: WeaponLoadout = WeaponLoadout.new()
	assert_true(loadout.factories.has(&"shield_bash"))
