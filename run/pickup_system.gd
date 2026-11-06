class_name PickupSystem
extends MultiMeshInstance2D

## Every XP gem on the ground, as a struct of arrays.
##
## No node per gem: positions live in flat arrays and one MultiMesh draws them
## all. Slots come from a fixed-capacity pool, so spawning never allocates.
##
## Nothing here hands a Packed*Array out to a caller; use the per-id getters.

## Scale 0 hides an instance. Used for slots that are free.
const DEAD_TRANSFORM: Transform2D = Transform2D(0.0, Vector2.ZERO, 0.0, Vector2.ZERO)

## Pale cyan so gems read differently from the red enemies
const GEM_COLOR: Color = Color(0.55, 0.9, 0.85, 1.0)

## Emitted once per gem the player touches.
signal xp_collected(amount: int)

var _capacity: int = 0
var _radius: float = 0.0
var _pull_speed: float = 0.0
var _pos: PackedVector2Array = PackedVector2Array()
var _xp: PackedInt32Array = PackedInt32Array()
var _active: PackedByteArray = PackedByteArray()
var _pool: Pool = null
var _active_count: int = 0


func setup(tuning: RunTuning) -> void:
	_capacity = tuning.gem_capacity
	_radius = tuning.gem_radius
	_pull_speed = tuning.gem_pull_speed
	_pos.resize(_capacity)
	_xp.resize(_capacity)
	_active.resize(_capacity)
	_active.fill(0)
	_pool = Pool.new(_capacity)
	_active_count = 0
	modulate = GEM_COLOR
	_build_multimesh()


## Returns false, changing nothing, when every slot is taken.
func spawn(pos: Vector2, xp: int) -> bool:
	var id: int = _pool.acquire()
	if id == -1:
		return false
	_pos[id] = pos
	_xp[id] = xp
	_active[id] = 1
	_active_count += 1
	return true


## Places a gem, or returns the XP for the caller to grant directly when the
## pool is full (so XP is never lost). Returns 0 when the gem was placed.
func spawn_or_grant(pos: Vector2, xp: int) -> int:
	if spawn(pos, xp):
		return 0
	return xp


## Pulls gems inside pickup_radius toward the player and collects those that
## touch. Allocation-free: reads the SoA arrays by index.
func tick(delta: float, player_pos: Vector2, pickup_radius: float, player_radius: float) -> void:
	var touch: float = player_radius + _radius
	var touch_sq: float = touch * touch
	var pickup_sq: float = pickup_radius * pickup_radius
	var step: float = _pull_speed * delta
	for i in _capacity:
		if _active[i] == 0:
			continue
		var offset: Vector2 = player_pos - _pos[i]
		var dist_sq: float = offset.length_squared()
		if dist_sq > pickup_sq:
			continue
		if dist_sq > touch_sq:
			var dist: float = sqrt(dist_sq)
			if step >= dist:
				_pos[i] = player_pos
				dist_sq = 0.0
			else:
				_pos[i] += offset * (step / dist)
				dist_sq = (dist - step) * (dist - step)
		if dist_sq <= touch_sq:
			_collect(i)


func _collect(id: int) -> void:
	var xp: int = _xp[id]
	_active[id] = 0
	_active_count -= 1
	_pool.release(id)
	multimesh.set_instance_transform_2d(id, DEAD_TRANSFORM)
	xp_collected.emit(xp)


func clear() -> void:
	for i in _capacity:
		if _active[i] == 1:
			_active[i] = 0
			_pool.release(i)
			multimesh.set_instance_transform_2d(i, DEAD_TRANSFORM)
	_active_count = 0


func active_count() -> int:
	return _active_count


func position_of(id: int) -> Vector2:
	return _pos[id]


func is_active(id: int) -> bool:
	return id >= 0 and id < _capacity and _active[id] == 1


## The transform drawn for a slot: sized by gem radius and placed at the gem,
## or hidden if the slot is free.
func transform_of(id: int) -> Transform2D:
	if _active[id] == 0:
		return DEAD_TRANSFORM
	return Transform2D(0.0, Vector2(_radius, _radius), 0.0, _pos[id])


## Writes every live gem into the MultiMesh. Allocation-free.
func sync_multimesh() -> void:
	var mm: MultiMesh = multimesh
	for i in _capacity:
		if _active[i] == 1:
			mm.set_instance_transform_2d(i, transform_of(i))


func _build_multimesh() -> void:
	# Unit quad of diameter 2, scaled per instance by the gem radius
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.mesh = quad
	mm.instance_count = _capacity
	multimesh = mm
	for i in _capacity:
		mm.set_instance_transform_2d(i, DEAD_TRANSFORM)
