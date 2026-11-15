extends GutTest

const CAPACITY: int = 16
const CELL: float = 16.0

var _grid: SpatialGrid
var _out: PackedInt32Array

func before_each() -> void:
	_grid = SpatialGrid.new(CAPACITY, CELL)
	_out = PackedInt32Array()
	_out.resize(CAPACITY)

func test_finds_points_inside_the_radius() -> void:
	_grid.insert(0, Vector2(0.0, 0.0))
	_grid.insert(1, Vector2(5.0, 0.0))
	assert_eq(_grid.query_radius(Vector2.ZERO, 10.0, _out), 2)

func test_excludes_points_outside_the_radius() -> void:
	_grid.insert(0, Vector2(0.0, 0.0))
	_grid.insert(1, Vector2(40.0, 0.0))
	assert_eq(_grid.query_radius(Vector2.ZERO, 10.0, _out), 1)
	assert_eq(_out[0], 0)

func test_finds_a_neighbour_across_a_cell_boundary() -> void:
	_grid.insert(0, Vector2(15.5, 0.0))
	_grid.insert(1, Vector2(16.5, 0.0))
	assert_eq(_grid.query_radius(Vector2(15.5, 0.0), 5.0, _out), 2,
		"points either side of a cell edge must still see each other")

func test_radius_larger_than_one_cell() -> void:
	_grid.insert(0, Vector2(35.0, 0.0))
	assert_eq(_grid.query_radius(Vector2.ZERO, 40.0, _out), 1)

func test_clear_empties_the_grid() -> void:
	_grid.insert(0, Vector2.ZERO)
	_grid.clear()
	assert_eq(_grid.query_radius(Vector2.ZERO, 100.0, _out), 0)

func test_wrapped_cells_do_not_leak_distant_points() -> void:
	# cell 16 x grid 64 repeats every 1024 px, so this point shares a bucket
	# with the origin; only the real distance check keeps it out
	_grid.insert(0, Vector2(1024.0, 0.0))
	assert_eq(_grid.query_radius(Vector2.ZERO, 10.0, _out), 0)

func test_negative_coordinates_work() -> void:
	_grid.insert(0, Vector2(-33.0, -17.0))
	assert_eq(_grid.query_radius(Vector2(-30.0, -15.0), 10.0, _out), 1)

func test_query_never_grows_the_output_buffer() -> void:
	for i in 8:
		_grid.insert(i, Vector2(float(i), 0.0))
	var before: int = _out.size()
	_grid.query_radius(Vector2.ZERO, 100.0, _out)
	assert_eq(_out.size(), before, "query_radius fills the caller's buffer, it never grows it")

func test_each_id_is_returned_once() -> void:
	for i in 8:
		_grid.insert(i, Vector2(float(i) * 3.0, 0.0))
	var n: int = _grid.query_radius(Vector2.ZERO, 100.0, _out)
	var seen: Dictionary = {}
	for i in n:
		seen[_out[i]] = true
	assert_eq(n, 8)
	assert_eq(seen.size(), 8, "no id may appear twice")

func test_reinsert_after_clear_reuses_ids() -> void:
	_grid.insert(0, Vector2(0.0, 0.0))
	_grid.clear()
	_grid.insert(0, Vector2(200.0, 0.0))
	assert_eq(_grid.query_radius(Vector2.ZERO, 10.0, _out), 0)
	assert_eq(_grid.query_radius(Vector2(200.0, 0.0), 10.0, _out), 1)
