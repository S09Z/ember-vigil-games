class_name Pool
extends RefCounted

## Fixed-capacity free list of slot indices for struct-of-arrays systems.
##
## Systems keep their data in parallel Packed*Array buffers of a fixed size and
## ask this pool which slot to write into. Capacity never changes at runtime so
## nothing reallocates mid-run.

var _free: PackedInt32Array = PackedInt32Array()
var _in_use: PackedByteArray = PackedByteArray()
var _free_count: int = 0
var _capacity: int = 0


func _init(capacity: int) -> void:
	_capacity = maxi(0, capacity)
	_free.resize(_capacity)
	_in_use.resize(_capacity)
	reset()


func reset() -> void:
	_free_count = _capacity
	for i in _capacity:
		# reversed so that acquire() hands out 0, 1, 2, ... on a fresh pool
		_free[i] = _capacity - 1 - i
		_in_use[i] = 0


func acquire() -> int:
	if _free_count == 0:
		return -1
	_free_count -= 1
	var id: int = _free[_free_count]
	_in_use[id] = 1
	return id


func release(id: int) -> void:
	if id < 0 or id >= _capacity or _in_use[id] == 0:
		push_error("Pool.release: invalid or repeated release of slot %d" % id)
		return
	_in_use[id] = 0
	_free[_free_count] = id
	_free_count += 1


func is_active(id: int) -> bool:
	return id >= 0 and id < _capacity and _in_use[id] == 1


func active_count() -> int:
	return _capacity - _free_count


func capacity() -> int:
	return _capacity
