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


func _set_level(n: int) -> void:
	_weapon.level = n

## Counts fired swings through the damage recorded against a single enemy that
## sits in front of the player (damage per swing is read from the current level).
func _swings() -> int:
	return int(round(_state.damage_of(&"greatsword") / _weapon.current().damage))

func test_level_table_matches_the_design() -> void:
	var d: WeaponDef = load("res://data/weapons/greatsword.tres")
	assert_eq(d.max_level(), 5)
	assert_eq(d.level_data(2).damage, 25.0)
	assert_eq(d.level_data(3).arc_degrees, 180.0); assert_eq(d.level_data(3).range, 56.0)
	assert_almost_eq(d.level_data(4).cooldown, 0.9, 0.0001)
	assert_true(d.level_data(5).both_sides); assert_false(d.level_data(4).both_sides)
	for n in range(2, 6):
		assert_eq(d.level_data(n).knockback, 20.0, "knockback never changes")

func test_level_two_hits_for_25() -> void:
	_set_level(2); var id: int = _spawn(Vector2(30.0, 0.0)); _swing()
	assert_almost_eq(_enemies.hp_of(id), 975.0, 0.01)

func test_level_three_reaches_further_and_wider() -> void:
	_set_level(3)
	var far: int = _spawn(Vector2(54.0, 0.0))
	var wide: int = _spawn(Vector2.from_angle(deg_to_rad(85.0)) * 30.0)   # outside 140 deg, inside 180
	_swing()
	assert_lt(_enemies.hp_of(far), 1000.0); assert_lt(_enemies.hp_of(wide), 1000.0)

func test_level_five_also_hits_behind() -> void:
	_set_level(5); var id: int = _spawn(Vector2(-30.0, 0.0)); _swing()
	assert_lt(_enemies.hp_of(id), 1000.0)

func test_level_four_does_not_hit_behind() -> void:
	_set_level(4); var id: int = _spawn(Vector2(-30.0, 0.0)); _swing()
	assert_eq(_enemies.hp_of(id), 1000.0)

func test_level_five_hits_an_enemy_beside_the_player_only_once() -> void:
	_set_level(5)
	var id: int = _spawn(Vector2(0.0, 30.0))         # on the 90 degree edge of both cones
	_swing()
	assert_almost_eq(_enemies.hp_of(id), 975.0, 0.01, "25, not 50")

func test_level_five_hits_front_and_back_enemies_once_each() -> void:
	_set_level(5)
	var front: int = _spawn(Vector2(30.0, 0.0))
	var back: int = _spawn(Vector2(-30.0, 0.0))
	_swing()
	assert_almost_eq(_enemies.hp_of(front), 975.0, 0.01)
	assert_almost_eq(_enemies.hp_of(back), 975.0, 0.01)

func test_level_four_swings_faster() -> void:
	_set_level(4)
	_spawn(Vector2(30.0, 0.0)); _enemies.tick_grid()
	_weapon.tick(0.0, _ctx)            # first swing
	_weapon.tick(0.89, _ctx); assert_eq(_swings(), 1)
	_weapon.tick(0.02, _ctx); assert_eq(_swings(), 2)
