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
var _alive_count: int = 0


func setup(defs: Array[EnemyDef], tuning: RunTuning, capacity: int) -> void:
	_tuning = tuning
	_capacity = capacity

	_pos.resize(capacity)
	_vel.resize(capacity)
	_hp.resize(capacity)
	_type.resize(capacity)
	_alive.resize(capacity)
	_alive.fill(0)

	var kinds: int = defs.size()
	_type_hp.resize(kinds)
	_type_speed.resize(kinds)
	_type_damage.resize(kinds)
	_type_radius.resize(kinds)
	_type_xp.resize(kinds)
	for i in kinds:
		var def: EnemyDef = defs[i]
		_type_hp[i] = def.hp
		_type_speed[i] = def.move_speed
		_type_damage[i] = def.contact_damage
		_type_radius[i] = def.body_radius
		_type_xp[i] = def.xp

	_pool = Pool.new(capacity)
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


## Writes every live enemy's position into the MultiMesh. Free slots were already
## hidden when they died, so only live slots are touched. Allocation-free: the
## transform is built on the stack and the loop reads flat arrays only.
func sync_multimesh() -> void:
	var mm: MultiMesh = multimesh
	for i in _capacity:
		if _alive[i] == 1:
			mm.set_instance_transform_2d(i, transform_of(i))


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
