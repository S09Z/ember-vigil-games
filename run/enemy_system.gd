class_name EnemySystem
extends MultiMeshInstance2D

## Every enemy in the game, as a struct of arrays.
##
## There is no node, Area2D or physics body per enemy; neighbour lookups go
## through SpatialGrid instead. All of them are drawn by this one
## MultiMeshInstance2D.
##
## Slots are stable: a dead enemy returns its slot to the pool, but live enemies
## never move slot. That keeps an enemy id usable across frames, which Rune
## Orbit, Hawk and piercing shots all need in M3.
##
## Nothing here hands a Packed*Array out to a caller. GDScript arrays are
## copy-on-write, so a second reference would make every write in here copy the
## whole buffer. Callers use the per-id getters below.

signal enemy_died(pos: Vector2, xp: int)

## Scale 0 hides an instance. Used for slots that are free.
const DEAD_TRANSFORM: Transform2D = Transform2D(0.0, Vector2.ZERO, 0.0, Vector2.ZERO)

var _capacity: int = 0
var _pos: PackedVector2Array = PackedVector2Array()
var _vel: PackedVector2Array = PackedVector2Array()
## Separation push in px/s, rebuilt every frame by tick_separation()
var _push: PackedVector2Array = PackedVector2Array()
var _hp: PackedFloat32Array = PackedFloat32Array()
var _type: PackedByteArray = PackedByteArray()
var _alive: PackedByteArray = PackedByteArray()

## EnemyDef values are copied into flat arrays once, so the per-frame loops
## never touch a Resource property.
var _type_hp: PackedFloat32Array = PackedFloat32Array()
var _type_speed: PackedFloat32Array = PackedFloat32Array()
var _type_damage: PackedFloat32Array = PackedFloat32Array()
var _type_radius: PackedFloat32Array = PackedFloat32Array()
var _type_xp: PackedInt32Array = PackedInt32Array()

var _pool: Pool = null
var _tuning: RunTuning = null
var _rng: Rng = null
var _grid: SpatialGrid = null
var _max_radius: float = 0.0

## Scratch buffer for neighbour queries, allocated once in setup()
var _query: PackedInt32Array = PackedInt32Array()

## Stage timings in microseconds, read by the debug overlay
var usec_grid: int = 0
var usec_separation: int = 0
var usec_contact: int = 0
var usec_movement: int = 0
var usec_multimesh: int = 0
var _alive_count: int = 0


func setup(defs: Array[EnemyDef], tuning: RunTuning, rng: Rng, capacity: int) -> void:
	_tuning = tuning
	_rng = rng
	_capacity = capacity

	_pos.resize(capacity)
	_vel.resize(capacity)
	_push.resize(capacity)
	_push.fill(Vector2.ZERO)
	_hp.resize(capacity)
	_type.resize(capacity)
	_alive.resize(capacity)
	_alive.fill(0)
	_query.resize(capacity)

	var kinds: int = defs.size()
	_type_hp.resize(kinds)
	_type_speed.resize(kinds)
	_type_damage.resize(kinds)
	_type_radius.resize(kinds)
	_type_xp.resize(kinds)
	_max_radius = 0.0
	for i in kinds:
		var def: EnemyDef = defs[i]
		_type_hp[i] = def.hp
		_type_speed[i] = def.move_speed
		_type_damage[i] = def.contact_damage
		_type_radius[i] = def.body_radius
		_type_xp[i] = def.xp
		_max_radius = maxf(_max_radius, def.body_radius)

	_pool = Pool.new(capacity)
	_grid = SpatialGrid.new(capacity, tuning.grid_cell_size)
	_alive_count = 0
	_build_multimesh()


## Returns the slot used, or -1 when the system is full. Hp is the type's base
## hp scaled by `1 + elapsed / hp_scale_divisor`.
func spawn(type_index: int, pos: Vector2, elapsed: float) -> int:
	var id: int = _pool.acquire()
	if id == -1:
		return -1
	_pos[id] = pos
	_vel[id] = Vector2.ZERO
	_push[id] = Vector2.ZERO
	_hp[id] = _type_hp[type_index] * (1.0 + elapsed / _tuning.hp_scale_divisor)
	_type[id] = type_index
	_alive[id] = 1
	_alive_count += 1
	return id


func kill(id: int) -> void:
	if id < 0 or id >= _capacity or _alive[id] == 0:
		return
	_alive[id] = 0
	_alive_count -= 1
	_pool.release(id)
	multimesh.set_instance_transform_2d(id, DEAD_TRANSFORM)
	enemy_died.emit(_pos[id], _type_xp[_type[id]])


## Rebuilds the neighbour grid from the current positions. Everything that
## queries neighbours this frame must run after this and before anything moves.
func tick_grid() -> void:
	var started: int = Time.get_ticks_usec()
	_grid.clear()
	for i in _capacity:
		if _alive[i] == 1:
			_grid.insert(i, _pos[i])
	usec_grid = Time.get_ticks_usec() - started


## Soft collision between enemies. Each overlapping pair is visited once (j > i)
## and pushed both ways, which halves the work for the same result. The push is
## stored as a velocity that tick_movement() adds, not a position jump, so the
## behaviour does not change with frame rate.
##
## Must run after tick_grid() and before tick_movement().
func tick_separation() -> void:
	var started: int = Time.get_ticks_usec()
	_push.fill(Vector2.ZERO)
	var strength: float = _tuning.separation_strength
	for i in _capacity:
		if _alive[i] == 0:
			continue
		var pi: Vector2 = _pos[i]
		var ri: float = _type_radius[_type[i]]
		# reach uses the largest radius in the game so no pair is ever missed
		var found: int = _grid.query_radius(pi, ri + _max_radius, _query)
		for k in found:
			var j: int = _query[k]
			if j <= i or _alive[j] == 0:
				continue
			var offset: Vector2 = _pos[j] - pi
			var dist: float = offset.length()
			var min_dist: float = ri + _type_radius[_type[j]]
			if dist >= min_dist:
				continue
			var dir: Vector2
			if dist > 0.001:
				dir = offset / dist
			else:
				# stacked on the same pixel: pick a stable per-slot direction so
				# the pile unwinds instead of staying welded together
				dir = Vector2(cos(float(i)), sin(float(i)))
			var force: float = (1.0 - dist / min_dist) * strength
			_push[i] -= dir * force
			_push[j] += dir * force
	usec_separation = Time.get_ticks_usec() - started


## Charges the player for touching enemies. design.md gives the player a single
## invulnerability window rather than a per-enemy cooldown, so one hit is
## resolved per frame and the hardest hitter is the one that lands; taking the
## maximum keeps the result independent of slot order.
##
## Must run while the grid still matches the current positions, i.e. after
## tick_grid() and before tick_movement().
func tick_contact(player: Player) -> void:
	var started: int = Time.get_ticks_usec()
	if not player.is_invulnerable() and not player.is_dead():
		var center: Vector2 = player.global_position
		var found: int = _grid.query_radius(center, player.body_radius + _max_radius, _query)
		var worst: float = 0.0
		for k in found:
			var j: int = _query[k]
			# the grid is built once per frame, so an enemy killed since then
			# is still in it
			if _alive[j] == 0:
				continue
			var reach: float = player.body_radius + _type_radius[_type[j]]
			if center.distance_squared_to(_pos[j]) > reach * reach:
				continue
			worst = maxf(worst, _type_damage[_type[j]])
		if worst > 0.0:
			player.take_damage(worst)
	usec_contact = Time.get_ticks_usec() - started


## Moves every live enemy straight at the player, plus whatever
## tick_separation() pushed it by. An enemy further away than
## `recycle_distance` is dropped back into the spawn ring around the player
## instead of being killed and respawned; the player never sees where it came
## from, and it keeps its slot, hp and type.
func tick_movement(delta: float, player_pos: Vector2) -> void:
	var started: int = Time.get_ticks_usec()
	var recycle_sq: float = _tuning.recycle_distance * _tuning.recycle_distance
	for i in _capacity:
		if _alive[i] == 0:
			continue
		var p: Vector2 = _pos[i]
		var to_player: Vector2 = player_pos - p
		if to_player.length_squared() > recycle_sq:
			_pos[i] = _rng.point_in_ring(player_pos, _tuning.spawn_ring_min, _tuning.spawn_ring_max)
			_vel[i] = Vector2.ZERO
			continue
		# normalized() of a zero vector is zero in Godot, so an enemy exactly on
		# the player just stands still instead of producing NaN.
		var v: Vector2 = to_player.normalized() * _type_speed[_type[i]] + _push[i]
		_vel[i] = v
		_pos[i] = p + v * delta
	usec_movement = Time.get_ticks_usec() - started


## Writes every live enemy's position into the MultiMesh. Free slots were already
## hidden when they died, so only live slots are touched. Allocation-free: the
## transform is built on the stack and the loop reads flat arrays only.
func sync_multimesh() -> void:
	var started: int = Time.get_ticks_usec()
	var mm: MultiMesh = multimesh
	for i in _capacity:
		if _alive[i] == 1:
			mm.set_instance_transform_2d(i, transform_of(i))
	usec_multimesh = Time.get_ticks_usec() - started


## The transform drawn for a slot: sized by body radius and placed at the
## enemy, or hidden if the slot is free. Kept separate from the MultiMesh write
## so it can be tested without a renderer.
func transform_of(id: int) -> Transform2D:
	if _alive[id] == 0:
		return DEAD_TRANSFORM
	var r: float = _type_radius[_type[id]]
	return Transform2D(0.0, Vector2(r, r), 0.0, _pos[id])


func alive_count() -> int:
	return _alive_count


func capacity() -> int:
	return _capacity


func position_of(id: int) -> Vector2:
	return _pos[id]


func hp_of(id: int) -> float:
	return _hp[id]


func is_alive(id: int) -> bool:
	return id >= 0 and id < _capacity and _alive[id] == 1


func _build_multimesh() -> void:
	# A unit quad of diameter 2, scaled per instance by the enemy's radius, so
	# one MultiMesh can draw every enemy size added later.
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.mesh = quad
	mm.instance_count = _capacity
	multimesh = mm
	for i in _capacity:
		mm.set_instance_transform_2d(i, DEAD_TRANSFORM)
