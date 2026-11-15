extends GutTest

var _weapon: Warhorn
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

	_weapon = Warhorn.new()
	_weapon.setup(load("res://data/weapons/warhorn.tres"))

func _spawn(pos: Vector2) -> int:
	return _enemies.spawn(0, pos, 0.0)

func _blow() -> void:
	_enemies.tick_grid()
	_weapon.tick(0.0, _ctx)

func _set_level(n: int) -> void:
	_weapon.level = n

func _advance(t: float) -> void:
	var steps: int = int(round(t * 60.0))
	for i in steps:
		_enemies.tick_movement(1.0 / 60.0, _player.global_position)

func test_the_level_table_matches_the_design() -> void:
	var d: WeaponDef = load("res://data/weapons/warhorn.tres")
	assert_eq(d.max_level(), 5); assert_eq(d.tag, &"holy")
	assert_eq(d.level_data(1).radius, 70.0); assert_eq(d.level_data(1).buff_percent, 15.0)
	assert_eq(d.level_data(1).buff_seconds, 3.0); assert_eq(d.level_data(1).cooldown, 6.0)
	assert_eq(d.level_data(1).knockback, 30.0); assert_eq(d.level_data(1).damage, 0.0)
	assert_eq(d.level_data(4).buff_percent, 25.0); assert_eq(d.level_data(5).radius, 110.0)
	assert_eq(d.level_data(5).heal, 10.0); assert_eq(d.level_data(4).heal, 0.0)

func test_it_pushes_every_enemy_in_the_ring_and_does_no_damage() -> void:
	var a: int = _spawn(Vector2(60.0, 0.0)); var b: int = _spawn(Vector2(0.0, -60.0))
	_blow(); _advance(0.5)
	assert_gt(_enemies.position_of(a).x, 60.0 + 25.0); assert_lt(_enemies.position_of(b).y, -60.0 - 25.0)
	assert_eq(_enemies.hp_of(a), 1000.0); assert_eq(_state.damage_of(&"warhorn"), 0.0)

func test_it_ignores_enemies_outside_the_radius() -> void:
	var id: int = _spawn(Vector2(75.0, 0.0)); _blow(); _advance(0.5)
	assert_eq(_enemies.position_of(id), Vector2(75.0, 0.0), "radius is 70, so 75 is not pushed")

func test_it_buffs_the_players_damage_for_three_seconds() -> void:
	_blow()
	assert_almost_eq(_stats.damage_multiplier(), 1.15, 0.0001)
	_stats.tick(3.0)
	assert_eq(_stats.damage_multiplier(), 1.0)

func test_blowing_again_refreshes_the_buff_without_stacking() -> void:
	_blow(); _stats.tick(2.0); _weapon._cooldown_left = 0.0; _blow()
	assert_almost_eq(_stats.damage_multiplier(), 1.15, 0.0001)
	assert_almost_eq(_stats.buff_time_left(), 3.0, 0.0001)

func test_level_four_gives_a_stronger_buff() -> void:
	_set_level(4); _blow()
	assert_almost_eq(_stats.damage_multiplier(), 1.25, 0.0001)

func test_only_level_five_heals() -> void:
	_player.take_damage(52.0)                       # 140 - 50 = 90 in the brief; here 100 - 50 = 50
	var before: float = _player.hp
	_set_level(4); _blow()
	assert_almost_eq(_player.hp, before, 0.01)
	_set_level(5); _weapon._cooldown_left = 0.0; _blow()
	assert_almost_eq(_player.hp, before + 10.0, 0.01)

func test_it_works_with_no_enemies_nearby() -> void:
	_blow(); assert_almost_eq(_stats.damage_multiplier(), 1.15, 0.0001)

func test_the_buff_raises_greatsword_damage() -> void:
	var sword: Greatsword = Greatsword.new()
	sword.setup(load("res://data/weapons/greatsword.tres"))
	var id: int = _spawn(Vector2(30.0, 0.0))
	_blow()
	_enemies.tick_grid()
	sword.tick(0.0, _ctx)
	assert_almost_eq(_enemies.hp_of(id), 1000.0 - 20.0 * 1.15, 0.01)

func test_a_real_loadout_creates_a_warhorn() -> void:
	var loadout: WeaponLoadout = WeaponLoadout.new()
	assert_true(loadout.factories.has(&"warhorn"))
