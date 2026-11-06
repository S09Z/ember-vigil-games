extends GutTest

var _w: CountingWeapon
var _def: WeaponDef
var _enemies: EnemySystem
var _state: RunState
var _stats: StatBlock
var _player: Player
var _ctx: WeaponContext
var _enemy_id: int
var _steel_weapon: CountingWeapon
var _holy_weapon: CountingWeapon

func _level(cooldown: float) -> WeaponLevelDef:
	var lv: WeaponLevelDef = WeaponLevelDef.new()
	lv.cooldown = cooldown
	return lv

func before_each() -> void:
	_def = WeaponDef.new()
	_def.id = &"w"
	var rows: Array[WeaponLevelDef] = [_level(1.0), _level(0.5)]
	_def.levels = rows
	_w = CountingWeapon.new()
	_w.setup(_def)

	var edef: EnemyDef = EnemyDef.new()
	edef.id = &"dummy"
	edef.hp = 100.0
	edef.move_speed = 0.0
	edef.contact_damage = 0.0
	edef.xp = 1
	edef.body_radius = 6.0
	var defs: Array[EnemyDef] = [edef]
	_enemies = EnemySystem.new()
	autofree(_enemies)
	_enemies.setup(defs, RunTuning.new(), Rng.new(3), 8)
	_enemy_id = _enemies.spawn(0, Vector2(10.0, 0.0), 0.0)

	_state = RunState.new()
	_state.setup(RunTuning.new())
	_stats = StatBlock.new()
	var cdef: ClassDef = ClassDef.new()
	cdef.max_hp = 140.0
	cdef.armor = 2
	cdef.move_speed = 90.0
	cdef.body_radius = 7.0
	cdef.pickup_radius = 40.0
	_player = Player.new()
	autofree(_player)
	_player.setup(cdef, RunTuning.new())
	_ctx = WeaponContext.new()
	_ctx.setup(_player, _enemies, null, _state, _stats, 0.03)
	_steel_weapon = _tagged_weapon(&"steel")
	_holy_weapon = _tagged_weapon(&"holy")

func _tagged_weapon(tag: StringName) -> CountingWeapon:
	var d: WeaponDef = WeaponDef.new()
	d.id = tag
	d.tag = tag
	var rows: Array[WeaponLevelDef] = [_level(1.0)]
	d.levels = rows
	var weapon: CountingWeapon = CountingWeapon.new()
	weapon.setup(d)
	return weapon

func test_starts_at_level_one() -> void:
	assert_eq(_w.level, 1)

func test_fires_on_the_first_tick() -> void:
	_w.tick(0.016, null)
	assert_eq(_w.fired, 1)

func test_waits_for_the_cooldown_between_shots() -> void:
	_w.tick(0.016, null)
	_w.tick(0.9, null)
	assert_eq(_w.fired, 1)
	_w.tick(0.1, null)
	assert_eq(_w.fired, 2)

func test_a_long_frame_fires_once_not_many() -> void:
	_w.tick(0.016, null)
	_w.tick(5.0, null)
	assert_eq(_w.fired, 2)

func test_the_cooldown_comes_from_the_level_at_the_time_of_firing() -> void:
	_w.tick(0.016, null)
	_w.level = 2
	_w.tick(1.0, null)
	_w.tick(0.5, null)
	assert_eq(_w.fired, 3)

func test_in_cone_accepts_points_inside_and_rejects_outside() -> void:
	assert_true(WeaponBase.in_cone(Vector2.ZERO, Vector2.RIGHT, 140.0, 48.0, Vector2(30.0, 0.0)))
	assert_false(WeaponBase.in_cone(Vector2.ZERO, Vector2.RIGHT, 140.0, 48.0, Vector2(49.0, 0.0)), "too far")
	assert_false(WeaponBase.in_cone(Vector2.ZERO, Vector2.RIGHT, 140.0, 48.0, Vector2(-30.0, 0.0)), "behind")

func test_in_cone_boundary_angle() -> void:
	var inside: Vector2 = Vector2.from_angle(deg_to_rad(69.0)) * 30.0
	var outside: Vector2 = Vector2.from_angle(deg_to_rad(71.0)) * 30.0
	assert_true(WeaponBase.in_cone(Vector2.ZERO, Vector2.RIGHT, 140.0, 48.0, inside))
	assert_false(WeaponBase.in_cone(Vector2.ZERO, Vector2.RIGHT, 140.0, 48.0, outside))

func test_in_cone_counts_the_exact_edge_as_inside() -> void:
	assert_true(WeaponBase.in_cone(Vector2.ZERO, Vector2.RIGHT, 180.0, 56.0, Vector2(0.0, 30.0)))

func test_in_cone_degenerate_inputs() -> void:
	assert_true(WeaponBase.in_cone(Vector2.ZERO, Vector2.RIGHT, 140.0, 48.0, Vector2.ZERO), "on top of the origin")
	assert_false(WeaponBase.in_cone(Vector2.ZERO, Vector2.ZERO, 140.0, 48.0, Vector2(10.0, 0.0)), "no facing")

func test_deal_damage_applies_the_buff_and_records_the_final_amount() -> void:
	_stats.apply_damage_buff(25.0, 3.0)
	_ctx.deal_damage(_enemy_id, 8.0, _w)
	assert_almost_eq(_state.damage_of(&"w"), 10.0, 0.001)
	assert_almost_eq(_enemies.hp_of(_enemy_id), 90.0, 0.001)

func test_deal_damage_reports_a_kill() -> void:
	assert_true(_ctx.deal_damage(_enemy_id, 1000.0, _w))

func test_deal_damage_on_a_dead_enemy_records_nothing() -> void:
	_enemies.kill(_enemy_id)
	assert_false(_ctx.deal_damage(_enemy_id, 10.0, _w))
	assert_eq(_state.damage_of(&"w"), 0.0)

func test_context_exposes_position_and_facing() -> void:
	_player.global_position = Vector2(5.0, 6.0)
	_player.last_move_dir = Vector2.UP
	assert_eq(_ctx.player_pos(), Vector2(5.0, 6.0))
	assert_eq(_ctx.facing(), Vector2.UP)

func test_context_hits_buffer_matches_enemy_capacity() -> void:
	assert_eq(_ctx.hits.size(), 8)

func test_a_steel_weapon_heals_three_percent_of_damage() -> void:
	_player.take_damage(32.0)
	_ctx.deal_damage(_enemy_id, 100.0, _steel_weapon)
	assert_almost_eq(_player.hp, 113.0, 0.01)

func test_lifesteal_uses_the_buffed_damage() -> void:
	_player.take_damage(32.0)
	_stats.apply_damage_buff(25.0, 3.0)
	_ctx.deal_damage(_enemy_id, 100.0, _steel_weapon)
	assert_almost_eq(_player.hp, 110.0 + 3.75, 0.01)

func test_a_holy_weapon_does_not_heal() -> void:
	_player.take_damage(32.0)
	_ctx.deal_damage(_enemy_id, 100.0, _holy_weapon)
	assert_almost_eq(_player.hp, 110.0, 0.01)

func test_lifesteal_never_exceeds_max_hp() -> void:
	_ctx.deal_damage(_enemy_id, 100.0, _steel_weapon)
	assert_eq(_player.hp, _player.max_hp)

func test_a_blocked_hit_on_a_dead_enemy_does_not_heal() -> void:
	_player.take_damage(32.0)
	_enemies.kill(_enemy_id)
	_ctx.deal_damage(_enemy_id, 100.0, _steel_weapon)
	assert_almost_eq(_player.hp, 110.0, 0.01)
