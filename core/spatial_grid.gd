class_name SpatialGrid
extends RefCounted

## Uniform grid for neighbour queries, with no per-frame allocation.
##
## Cells hold a singly linked list of item ids inside flat PackedInt32Arrays:
## `_cell_head[cell]` is the first id in that cell and `_next[id]` is the one
## after it. clear() only touches the cells that were actually used this frame.
##
## Cell coordinates wrap around a fixed GRID x GRID window instead of being
## hashed, so two neighbouring cells can never share a bucket (which would
## return the same id twice). Far-apart points can land in the same bucket, and
## the exact distance check in query_radius() is what keeps them out, so the
## grid stays correct for a world of any size.
##
## Constraint: the query radius must stay below half the wrap window
## (cell_size * GRID / 2), which is 512 px at the defaults.

const EMPTY: int = -1

var _cell_size: float = 16.0
var _inv_cell_size: float = 1.0 / 16.0
var _grid_size: int = 0
var _grid_mask: int = 0
var _grid_shift: int = 0
var _cell_head: PackedInt32Array = PackedInt32Array()
var _next: PackedInt32Array = PackedInt32Array()
var _pos: PackedVector2Array = PackedVector2Array()
var _touched: PackedInt32Array = PackedInt32Array()
var _touched_count: int = 0


func _init(capacity: int, cell_size: float, grid_size: int = 64) -> void:
	assert(grid_size > 0 and (grid_size & (grid_size - 1)) == 0, "grid_size must be a power of two")
	assert(cell_size > 0.0, "cell_size must be positive")
	_cell_size = cell_size
	_inv_cell_size = 1.0 / cell_size
	_grid_size = grid_size
	_grid_mask = grid_size - 1
	_grid_shift = 0
	while (1 << _grid_shift) < grid_size:
		_grid_shift += 1
	var cells: int = grid_size * grid_size
	_cell_head.resize(cells)
	_touched.resize(cells)
	_cell_head.fill(EMPTY)
	_next.resize(capacity)
	_pos.resize(capacity)
	_touched_count = 0


func clear() -> void:
	for i in _touched_count:
		_cell_head[_touched[i]] = EMPTY
	_touched_count = 0


func insert(id: int, pos: Vector2) -> void:
	var cell: int = _cell_index(
		int(floor(pos.x * _inv_cell_size)),
		int(floor(pos.y * _inv_cell_size)))
	_pos[id] = pos
	_next[id] = _cell_head[cell]
	if _cell_head[cell] == EMPTY:
		_touched[_touched_count] = cell
		_touched_count += 1
	_cell_head[cell] = id


## Fills `out` with the ids within `radius` of `center` and returns how many.
## `out` must already be at least as large as the grid capacity.
func query_radius(center: Vector2, radius: float, out: PackedInt32Array) -> int:
	var found: int = 0
	var limit: int = out.size()
	var radius_sq: float = radius * radius
	var span: int = int(ceil(radius * _inv_cell_size))
	assert(span * 2 + 1 <= _grid_size, "query radius exceeds half the wrap window")
	var cx: int = int(floor(center.x * _inv_cell_size))
	var cy: int = int(floor(center.y * _inv_cell_size))
	for oy in range(-span, span + 1):
		for ox in range(-span, span + 1):
			var id: int = _cell_head[_cell_index(cx + ox, cy + oy)]
			while id != EMPTY:
				if found < limit and center.distance_squared_to(_pos[id]) <= radius_sq:
					out[found] = id
					found += 1
				id = _next[id]
	return found


func cell_size() -> float:
	return _cell_size


func _cell_index(cx: int, cy: int) -> int:
	return ((cy & _grid_mask) << _grid_shift) | (cx & _grid_mask)
