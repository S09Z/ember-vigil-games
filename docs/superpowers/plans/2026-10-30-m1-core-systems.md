# M1 Core Systems Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** สร้าง Player + EnemySystem + SpatialGrid ให้ Ghoul 400 ตัวเดินไล่ผู้เล่นและเบียดกันเองได้บน build เว็บที่ avg FPS ≥120 / 1% low ≥90 บน MacBook M3

**Architecture:** `run.gd` เป็นเจ้าของลำดับการอัปเดตทั้งหมดและเรียก `tick*()` ของแต่ละระบบเอง (ระบบลูกไม่มี `_physics_process`) ศัตรูเก็บเป็น struct-of-arrays บน slot ที่คงที่ หาเพื่อนบ้านด้วย hash grid ที่เป็น linked list บน `PackedInt32Array` และวาดด้วย `MultiMeshInstance2D` ชิ้นเดียว ตัวเลข gameplay ทุกตัวมาจาก `.tres`

**Tech Stack:** Godot 4.7.2.stable, GDScript, Compatibility renderer, GUT 9.7.1

**Spec:** `docs/superpowers/specs/2026-10-30-m1-core-systems-design.md`

**คำสั่งที่ใช้ซ้ำทุก task** (ตั้ง `alias godot="/Applications/Godot.app/Contents/MacOS/Godot"` ก่อน):

```bash
# รันเทสต์ทั้งหมด
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

# ให้ Godot รู้จักสคริปต์/ทรัพยากรที่เพิ่มใหม่ (ต้องรันหลังเพิ่มไฟล์ที่มี class_name)
godot --headless --path . --import
```

**กฎระหว่างทำ**
- หนึ่ง task = หนึ่ง commit ข้อความอังกฤษแบบ imperative
- ห้ามข้ามขั้น "รันเทสต์แล้วต้องเห็นมันพัง" เพราะเทสต์ที่ผ่านตั้งแต่ยังไม่มีโค้ดคือเทสต์ที่ไม่ได้ทดสอบอะไร
- ห้ามแก้อะไรใน `addons/gut`
- ถ้าติดเกิน 2 รอบในขั้นเดียว ให้หยุดแล้วรายงาน ห้ามเดา

---

### Task 0: เตรียม branch

- [x] **Step 1: แยก branch**

```bash
git checkout -b m1-core-systems
git status --short
```
Expected: ว่าง (ยกเว้น `.mcp.json` ที่ยังไม่ตัดสินใจ)

---

### Task 1: `Pool` — free-list ของ slot

**Files:**
- Create: `core/pool.gd`
- Test: `tests/test_pool.gd`

- [x] **Step 1: เขียนเทสต์ที่ต้องพัง**

`tests/test_pool.gd`:

```gdscript
extends GutTest

func test_acquire_hands_out_slots_in_order() -> void:
	var p: Pool = Pool.new(3)
	assert_eq(p.acquire(), 0)
	assert_eq(p.acquire(), 1)
	assert_eq(p.acquire(), 2)

func test_acquire_returns_minus_one_when_full() -> void:
	var p: Pool = Pool.new(1)
	assert_eq(p.acquire(), 0)
	assert_eq(p.acquire(), -1)

func test_released_slot_is_reused() -> void:
	var p: Pool = Pool.new(2)
	var a: int = p.acquire()
	p.acquire()
	p.release(a)
	assert_eq(p.acquire(), a)

func test_active_count_tracks_acquire_and_release() -> void:
	var p: Pool = Pool.new(4)
	assert_eq(p.active_count(), 0)
	p.acquire()
	p.acquire()
	assert_eq(p.active_count(), 2)
	p.release(0)
	assert_eq(p.active_count(), 1)

func test_double_release_does_not_corrupt_the_free_list() -> void:
	var p: Pool = Pool.new(2)
	var a: int = p.acquire()
	p.release(a)
	p.release(a)
	assert_push_error("repeated release", "a caller bug must be reported, not swallowed")
	assert_eq(p.active_count(), 0)
	assert_eq(p.acquire(), a)
	assert_eq(p.acquire(), 1)
	assert_eq(p.acquire(), -1, "a double release must not hand out a third slot")

func test_reset_frees_everything() -> void:
	var p: Pool = Pool.new(2)
	p.acquire()
	p.acquire()
	p.reset()
	assert_eq(p.active_count(), 0)
	assert_eq(p.acquire(), 0)
```

- [x] **Step 2: รันแล้วต้องพัง**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: FAIL — parse error ว่าไม่รู้จัก identifier `Pool`
(`assert_push_error()` จำเป็น เพราะ GUT 9 ถือว่า `push_error` ที่ไม่ได้ประกาศไว้คือเทสต์ตก
มันยืนยันว่า error ถูกรายงานจริงด้วย จึงแข็งกว่าการปล่อยผ่าน)

- [x] **Step 3: เขียน `core/pool.gd`**

```gdscript
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
```

- [x] **Step 4: import แล้วรันเทสต์ ต้องผ่าน**

```bash
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```
Expected: PASS ทั้งหมด (6 เทสต์ใหม่ + 7 เทสต์ของ M0) และ **Scripts ต้องเป็น 2**
GUT ข้ามไฟล์เทสต์ที่ parse ไม่ผ่านโดยรายงานเป็น warning ไม่ใช่ failure จึงยังขึ้น "All tests passed!" ได้
ต้องดูบรรทัด Scripts ทุกครั้ง ไม่ใช่ดูแค่ว่าผ่านหรือไม่ผ่าน

- [x] **Step 5: commit**

```bash
git add core/pool.gd tests/test_pool.gd
git commit -m "Add fixed-capacity slot pool"
```

---

### Task 2: `Rng` — RNG ที่ seed ได้

**Files:**
- Create: `core/rng.gd`
- Test: `tests/test_rng.gd`

- [x] **Step 1: เขียนเทสต์ที่ต้องพัง**

`tests/test_rng.gd`:

```gdscript
extends GutTest

func test_same_seed_gives_the_same_sequence() -> void:
	var a: Rng = Rng.new(1234)
	var b: Rng = Rng.new(1234)
	for i in 10:
		assert_eq(a.randf(), b.randf())

func test_different_seeds_diverge() -> void:
	var a: Rng = Rng.new(1)
	var b: Rng = Rng.new(2)
	var same: int = 0
	for i in 10:
		if a.randf() == b.randf():
			same += 1
	assert_lt(same, 10, "two different seeds must not produce an identical run")

func test_set_seed_restarts_the_sequence() -> void:
	var r: Rng = Rng.new(99)
	var first: float = r.randf()
	r.randf()
	r.set_seed(99)
	assert_eq(r.randf(), first)

func test_point_in_ring_respects_both_radii() -> void:
	var r: Rng = Rng.new(5)
	var center: Vector2 = Vector2(100.0, -50.0)
	for i in 200:
		var d: float = r.point_in_ring(center, 380.0, 420.0).distance_to(center)
		assert_between(d, 380.0, 420.0)

func test_point_in_ring_covers_every_direction() -> void:
	var r: Rng = Rng.new(8)
	var quadrants: Dictionary = {}
	for i in 200:
		var offset: Vector2 = r.point_in_ring(Vector2.ZERO, 380.0, 420.0)
		quadrants[Vector2(signf(offset.x), signf(offset.y))] = true
	assert_eq(quadrants.size(), 4, "enemies must be able to spawn on every side of the player")

func test_randi_range_is_inclusive_and_bounded() -> void:
	var r: Rng = Rng.new(11)
	for i in 100:
		assert_between(r.randi_range(3, 5), 3, 5)

func test_randf_range_stays_in_bounds() -> void:
	var r: Rng = Rng.new(13)
	for i in 100:
		assert_between(r.randf_range(-2.5, 7.5), -2.5, 7.5)
```

- [x] **Step 2: รันแล้วต้องพัง**

Run: คำสั่งเทสต์
Expected: FAIL — ไม่รู้จัก `Rng`

- [x] **Step 3: เขียน `core/rng.gd`**

```gdscript
class_name Rng
extends RefCounted

## Seedable random source.
##
## Every system that randomises anything takes one of these instead of calling
## the global RNG, so a run can be replayed exactly while debugging or while
## measuring performance.

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init(seed_value: int = 0) -> void:
	set_seed(seed_value)

func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value

func randf() -> float:
	return _rng.randf()

func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)

func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)

## Uniform in angle and in radius — the ring is thin enough that weighting by
## area would not be visible, and design.md specifies a flat 380-420 band.
func point_in_ring(center: Vector2, radius_min: float, radius_max: float) -> Vector2:
	var angle: float = _rng.randf_range(0.0, TAU)
	var radius: float = _rng.randf_range(radius_min, radius_max)
	return center + Vector2(cos(angle), sin(angle)) * radius
```

- [x] **Step 4: รันเทสต์ ต้องผ่าน**

```bash
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```
Expected: PASS ทั้งหมด

- [x] **Step 5: commit**

```bash
git add core/rng.gd tests/test_rng.gd
git commit -m "Add seedable RNG wrapper"
```

---

### Task 3: `SpatialGrid` — hash grid หาเพื่อนบ้าน

**Files:**
- Create: `core/spatial_grid.gd`
- Test: `tests/test_spatial_grid.gd`

- [x] **Step 1: เขียนเทสต์ที่ต้องพัง**

`tests/test_spatial_grid.gd`:

```gdscript
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
```

- [x] **Step 2: รันแล้วต้องพัง**

Expected: FAIL — ไม่รู้จัก `SpatialGrid`

- [x] **Step 3: เขียน `core/spatial_grid.gd`**

```gdscript
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
## the exact distance check in query_radius() is what keeps them out — so the
## grid stays correct for a world of any size.
##
## Constraint: the query radius must stay below half the wrap window
## (cell_size * GRID / 2), which is 512 px at the defaults.

const EMPTY: int = -1

var _cell_size: float = 16.0
var _inv_cell_size: float = 1.0 / 16.0
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
```

- [x] **Step 4: รันเทสต์ ต้องผ่าน**

```bash
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```
Expected: PASS ทั้งหมด

- [x] **Step 5: commit**

```bash
git add core/spatial_grid.gd tests/test_spatial_grid.gd
git commit -m "Add allocation-free spatial grid for neighbour queries"
```

---

### Task 4: Resource schema + ตัวเลขจาก design.md

> **สถานะ:** ทำครบแล้ว แบ่งเป็น M1-18 (`RunTuning` + design.md, `tests/test_run_tuning.gd`), M1-5 (`ClassDef` + knight, `tests/test_class_def.gd`) และ M1-8 (`EnemyDef` + ghoul, `tests/test_enemy_def.gd`) `.tres` เขียนด้วยมือพร้อมค่าครบ เพราะ `ResourceSaver` ไม่เก็บค่า default และเทสต์รวม `tests/test_data_defs.gd` ในแผนถูกแยกเป็นสามไฟล์ตามงาน

**Files:**
- Create: `data/class_def.gd`, `data/enemy_def.gd`, `data/run_tuning.gd`
- Create: `data/classes/knight.tres`, `data/enemies/ghoul.tres`, `data/tuning/run_tuning.tres`
- Modify: `docs/design.md` (เพิ่มรัศมีตัวและค่า tuning ที่ยังไม่มีในตาราง)
- Test: `tests/test_data_defs.gd`
- Delete: `.gitkeep` ของโฟลเดอร์ที่มีไฟล์จริงแล้ว

- [x] **Step 1: เขียนเทสต์ที่ต้องพัง**

`tests/test_data_defs.gd`:

```gdscript
extends GutTest

## ตัวเลขทุกตัวในนี้ต้องตรงกับตารางใน docs/design.md
## ถ้าแก้เกมแล้วเทสต์นี้ตก แปลว่าต้องไปแก้ design.md ให้ตรงด้วย ไม่ใช่แก้เทสต์

func test_knight_matches_the_design_table() -> void:
	var def: ClassDef = load("res://data/classes/knight.tres")
	assert_not_null(def)
	assert_eq(def.id, &"knight")
	assert_eq(def.max_hp, 140.0)
	assert_eq(def.move_speed, 95.0)
	assert_eq(def.armor, 2)
	assert_eq(def.pickup_radius, 40.0)
	assert_eq(def.body_radius, 7.0)

func test_ghoul_matches_the_design_table() -> void:
	var def: EnemyDef = load("res://data/enemies/ghoul.tres")
	assert_not_null(def)
	assert_eq(def.id, &"ghoul")
	assert_eq(def.hp, 10.0)
	assert_eq(def.move_speed, 45.0)
	assert_eq(def.contact_damage, 5.0)
	assert_eq(def.xp, 1)
	assert_eq(def.body_radius, 6.0)

func test_run_tuning_matches_the_design_numbers() -> void:
	var tuning: RunTuning = load("res://data/tuning/run_tuning.tres")
	assert_not_null(tuning)
	assert_eq(tuning.enemy_cap, 400)
	assert_eq(tuning.spawn_ring_min, 380.0)
	assert_eq(tuning.spawn_ring_max, 420.0)
	assert_eq(tuning.recycle_distance, 600.0)
	assert_eq(tuning.spawn_rate_base, 1.0)
	assert_eq(tuning.spawn_rate_time_divisor, 20.0)
	assert_eq(tuning.spawn_rate_cap, 12.0)
	assert_eq(tuning.hp_scale_divisor, 150.0)
	assert_eq(tuning.player_iframe_duration, 0.5)
	assert_eq(tuning.separation_strength, 60.0)
	assert_eq(tuning.grid_cell_size, 16.0)
```

- [x] **Step 2: รันแล้วต้องพัง**

Expected: FAIL — ไม่รู้จัก `ClassDef` / โหลด `.tres` ไม่ได้

- [x] **Step 3: เขียน schema สามไฟล์**

`data/class_def.gd`:

```gdscript
class_name ClassDef
extends Resource

## Everything that distinguishes one playable class. Values come from the table
## in docs/design.md section 4.

@export var id: StringName = &""
@export var display_name: String = ""
@export var max_hp: float = 100.0
@export var move_speed: float = 100.0
@export var armor: int = 0
@export var pickup_radius: float = 40.0
@export var body_radius: float = 7.0
```

`data/enemy_def.gd`:

```gdscript
class_name EnemyDef
extends Resource

## One enemy kind. Values come from the table in docs/design.md section 8.

@export var id: StringName = &""
@export var display_name: String = ""
@export var hp: float = 10.0
@export var move_speed: float = 45.0
@export var contact_damage: float = 5.0
@export var xp: int = 1
@export var body_radius: float = 6.0
```

`data/run_tuning.gd`:

```gdscript
class_name RunTuning
extends Resource

## Numbers that describe a run as a whole rather than one class or one enemy.
## See docs/design.md sections 8 and 4.

@export var enemy_cap: int = 400
@export var spawn_ring_min: float = 380.0
@export var spawn_ring_max: float = 420.0
@export var recycle_distance: float = 600.0

## Spawn rate per second is min(cap, base + elapsed / time_divisor)
@export var spawn_rate_base: float = 1.0
@export var spawn_rate_time_divisor: float = 20.0
@export var spawn_rate_cap: float = 12.0

## Enemy hp at spawn is def.hp * (1 + elapsed / hp_scale_divisor)
@export var hp_scale_divisor: float = 150.0

@export var player_iframe_duration: float = 0.5

## Push applied to fully overlapping enemies, in px/s
@export var separation_strength: float = 60.0

## Neighbour-lookup cell size; retune during the performance pass
@export var grid_cell_size: float = 16.0
```

- [x] **Step 4: import ให้ Godot รู้จัก class ใหม่**

```bash
godot --headless --path . --import
```
Expected: ไม่มี error

- [x] **Step 5: สร้างไฟล์ `.tres` ด้วยสคริปต์ใช้ครั้งเดียว**

เขียน `tools_make_data.gd` ที่รากโปรเจกต์ (ไฟล์นี้จะถูกลบใน step ถัดไป — เขียน `.tres` ด้วยมือเสี่ยงผิดฟอร์แมต):

```gdscript
extends SceneTree

func _init() -> void:
	var knight: ClassDef = ClassDef.new()
	knight.id = &"knight"
	knight.display_name = "Knight"
	knight.max_hp = 140.0
	knight.move_speed = 95.0
	knight.armor = 2
	knight.pickup_radius = 40.0
	knight.body_radius = 7.0
	_save(knight, "res://data/classes/knight.tres")

	var ghoul: EnemyDef = EnemyDef.new()
	ghoul.id = &"ghoul"
	ghoul.display_name = "Ghoul"
	ghoul.hp = 10.0
	ghoul.move_speed = 45.0
	ghoul.contact_damage = 5.0
	ghoul.xp = 1
	ghoul.body_radius = 6.0
	_save(ghoul, "res://data/enemies/ghoul.tres")

	# defaults in run_tuning.gd already match design.md
	_save(RunTuning.new(), "res://data/tuning/run_tuning.tres")
	quit()

func _save(res: Resource, path: String) -> void:
	var err: int = ResourceSaver.save(res, path)
	print("%s -> %d" % [path, err])
```

```bash
mkdir -p data/tuning
godot --headless --path . -s tools_make_data.gd
```
Expected: สามบรรทัดลงท้ายด้วย `-> 0` (0 = OK)
ถ้าได้ค่าอื่น ให้หยุดและรายงาน ห้ามไปเขียน `.tres` ด้วยมือแทน

- [x] **Step 6: ลบสคริปต์ชั่วคราวและ `.gitkeep` ที่ไม่ต้องใช้แล้ว**

```bash
rm tools_make_data.gd
rm -f data/classes/.gitkeep data/enemies/.gitkeep
godot --headless --path . --import
```

- [x] **Step 7: รันเทสต์ ต้องผ่าน**

Expected: PASS ทั้งหมด ถ้าค่าใดไม่ตรง ให้แก้ `.tres` ไม่ใช่แก้เทสต์

- [x] **Step 8: เพิ่มตัวเลขที่ยังไม่มีลง `docs/design.md`**

ในหัวข้อ 4 (ตารางอาชีพ) เพิ่มแถวหลัง "รัศมีเก็บของ (px)":

```
| รัศมีตัว (px) | 7 | 6 | 6 |
```

ในหัวข้อ 8 ต่อจากตารางศัตรู เพิ่มบรรทัด (รัศมีของตัวอื่นกำหนดตอนสร้างใน M3 อย่าเดาไว้ล่วงหน้า):

```
**รัศมีตัว (px):** Ghoul 6 — ตัวอื่นกำหนดเมื่อสร้างใน M3
```

ต่อท้ายย่อหน้า "การปล่อยศัตรู" เพิ่ม:

```
**ค่าปรับจูนเชิงเทคนิค:** แรงผลักระหว่างศัตรูที่ซ้อนกันสนิท 60 px/s ลดเชิงเส้นจนถึงระยะที่ไม่ซ้อนกัน
ขนาดเซลล์ของ grid ที่ใช้หาเพื่อนบ้าน 16 px (ปรับได้ตอนรอบวัดประสิทธิภาพ)
```

- [x] **Step 9: commit**

```bash
git add data/ tests/test_data_defs.gd docs/design.md
git commit -m "Add class, enemy and run tuning resources with design numbers"
```

---

### Task 5: `Player` — เดิน, HP, armor, อมตะ

> **สถานะ:** ทำครบแล้ว แบ่งเป็น M1-6 (เดิน + `last_move_dir`) และ M1-7 (HP/armor/อมตะ/signal) ไม่ใส่ Camera2D ในฉากเพราะเป็นของ M1-19 และตั้ง `motion_mode = FLOATING`

**Files:**
- Create: `run/player.gd`, `run/player.tscn`
- Test: `tests/test_player.gd`

- [x] **Step 1: เขียนเทสต์ที่ต้องพัง**

`tests/test_player.gd`:

```gdscript
extends GutTest

var _player: Player
var _tuning: RunTuning
var _def: ClassDef

func before_each() -> void:
	_tuning = RunTuning.new()
	_def = ClassDef.new()
	_def.max_hp = 140.0
	_def.move_speed = 95.0
	_def.armor = 2
	_def.pickup_radius = 40.0
	_def.body_radius = 7.0
	_player = Player.new()
	autofree(_player)
	_player.setup(_def, _tuning)

func test_setup_copies_the_class_stats() -> void:
	assert_eq(_player.max_hp, 140.0)
	assert_eq(_player.hp, 140.0)
	assert_eq(_player.armor, 2)
	assert_eq(_player.move_speed, 95.0)
	assert_eq(_player.body_radius, 7.0)

func test_diagonal_input_is_normalised() -> void:
	assert_almost_eq(Player.input_to_direction(Vector2(1.0, 1.0)).length(), 1.0, 0.001)

func test_zero_input_gives_zero_direction() -> void:
	assert_eq(Player.input_to_direction(Vector2.ZERO), Vector2.ZERO)

func test_damage_is_reduced_by_armor() -> void:
	_player.take_damage(5.0)
	assert_almost_eq(_player.hp, 137.0, 0.01, "max(1, 5 - 2) = 3")

func test_damage_has_a_floor_of_one() -> void:
	_player.take_damage(1.0)
	assert_almost_eq(_player.hp, 139.0, 0.01, "max(1, 1 - 2) = 1")

func test_invulnerability_blocks_a_second_hit() -> void:
	_player.take_damage(5.0)
	_player.take_damage(5.0)
	assert_almost_eq(_player.hp, 137.0, 0.01)

func test_invulnerability_expires_after_the_tuned_window() -> void:
	_player.take_damage(5.0)
	_player.tick_timers(_tuning.player_iframe_duration)
	_player.take_damage(5.0)
	assert_almost_eq(_player.hp, 134.0, 0.01)

func test_health_changed_fires_on_damage() -> void:
	watch_signals(_player)
	_player.take_damage(5.0)
	assert_signal_emitted(_player, "health_changed")

func test_died_fires_exactly_once() -> void:
	watch_signals(_player)
	_player.take_damage(1000.0)
	_player.tick_timers(10.0)
	_player.take_damage(1000.0)
	assert_signal_emit_count(_player, "died", 1)
	assert_eq(_player.hp, 0.0, "hp must clamp at zero, not go negative")

func test_last_move_dir_starts_valid() -> void:
	assert_almost_eq(_player.last_move_dir.length(), 1.0, 0.001,
		"melee weapons in M2 aim along this, so it must never be zero")
```

- [x] **Step 2: รันแล้วต้องพัง**

Expected: FAIL — ไม่รู้จัก `Player`

- [x] **Step 3: เขียน `run/player.gd`**

```gdscript
class_name Player
extends CharacterBody2D

## The only physics body in the game. Enemies are plain data in EnemySystem and
## their contacts are resolved there, so this node only has to move and take
## damage.
##
## run.gd drives it: there is no _physics_process here, so the update order of
## the whole run stays visible in one place and tests can step it by hand.

signal health_changed(hp: float, max_hp: float)
signal died()

var max_hp: float = 100.0
var hp: float = 100.0
var armor: int = 0
var move_speed: float = 100.0
var pickup_radius: float = 40.0
var body_radius: float = 7.0

## Direction of the last non-zero input. Melee weapons in M2 swing along it.
var last_move_dir: Vector2 = Vector2.RIGHT

var _iframe_duration: float = 0.5
var _iframe_timer: float = 0.0
var _dead: bool = false

static func input_to_direction(raw: Vector2) -> Vector2:
	if raw.length_squared() <= 0.0:
		return Vector2.ZERO
	return raw.normalized()

func setup(def: ClassDef, tuning: RunTuning) -> void:
	max_hp = def.max_hp
	hp = def.max_hp
	armor = def.armor
	move_speed = def.move_speed
	pickup_radius = def.pickup_radius
	body_radius = def.body_radius
	_iframe_duration = tuning.player_iframe_duration
	_iframe_timer = 0.0
	_dead = false
	health_changed.emit(hp, max_hp)

func tick(delta: float) -> void:
	tick_timers(delta)
	tick_movement()

## Split out from tick() so tests can advance time without a SceneTree.
func tick_timers(delta: float) -> void:
	if _iframe_timer > 0.0:
		_iframe_timer -= delta

func tick_movement() -> void:
	var dir: Vector2 = input_to_direction(
		Input.get_vector("move_left", "move_right", "move_up", "move_down"))
	if dir != Vector2.ZERO:
		last_move_dir = dir
	velocity = dir * move_speed
	move_and_slide()

func take_damage(amount: float) -> void:
	if _dead or _iframe_timer > 0.0:
		return
	hp -= maxf(1.0, amount - float(armor))
	_iframe_timer = _iframe_duration
	if hp <= 0.0:
		hp = 0.0
		_dead = true
		health_changed.emit(hp, max_hp)
		died.emit()
		return
	health_changed.emit(hp, max_hp)

func is_invulnerable() -> bool:
	return _iframe_timer > 0.0

func is_dead() -> bool:
	return _dead
```

- [x] **Step 4: รันเทสต์ ต้องผ่าน**

```bash
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```
Expected: PASS ทั้งหมด

- [x] **Step 5: เขียน `run/player.tscn`**

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://run/player.gd" id="1_player"]

[sub_resource type="CircleShape2D" id="CircleShape2D_body"]
radius = 7.0

[node name="Player" type="CharacterBody2D"]
script = ExtResource("1_player")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_body")

[node name="Body" type="Polygon2D" parent="."]
color = Color(0.953, 0.882, 0.741, 1)
polygon = PackedVector2Array(-7, -7, 7, -7, 7, 7, -7, 7)

[node name="Camera2D" type="Camera2D" parent="."]
```

- [x] **Step 6: ตรวจว่าฉากโหลดได้**

```bash
godot --headless --path . --import
```
Expected: ไม่มี error และไม่มีคำว่า `player.tscn` ในบรรทัด error ใด

- [x] **Step 7: commit**

```bash
git add run/player.gd run/player.tscn tests/test_player.gd
git commit -m "Add player with movement, armor and invulnerability window"
```

---

### Task 6: `EnemySystem` — โครงข้อมูลและการวาด

> **สถานะ:** ทำครบแล้ว แบ่งเป็น M1-9 (โครง SoA, `spawn`/`kill`, hp scaling) และ M1-10 (MultiMesh) ต่างจากโค้ดตัวอย่าง: `setup(defs, tuning, capacity)` ยังไม่รับ `Rng` และยังไม่มี grid/scratch buffer/ตัวจับเวลา (เพิ่มตอน M1-11/12/17) และเพิ่ม `transform_of(id)` เพราะ renderer แบบ headless ไม่เก็บข้อมูล MultiMesh ทำให้อ่านกลับด้วย `get_instance_transform_2d` ในเทสต์ไม่ได้ ตรวจการวาดจริงแยกด้วยการรันแบบมี renderer แล้ว

**Files:**
- Create: `run/enemy_system.gd`
- Test: `tests/test_enemy_system.gd`
- Delete: `data/.gitkeep` ถ้ายังเหลือ

- [x] **Step 1: เขียนเทสต์ที่ต้องพัง**

`tests/test_enemy_system.gd`:

```gdscript
extends GutTest

var _sys: EnemySystem
var _tuning: RunTuning
var _ghoul: EnemyDef

func before_each() -> void:
	_ghoul = EnemyDef.new()
	_ghoul.id = &"ghoul"
	_ghoul.hp = 10.0
	_ghoul.move_speed = 45.0
	_ghoul.contact_damage = 5.0
	_ghoul.xp = 1
	_ghoul.body_radius = 6.0
	_tuning = RunTuning.new()
	var defs: Array[EnemyDef] = [_ghoul]
	_sys = EnemySystem.new()
	autofree(_sys)
	_sys.setup(defs, _tuning, Rng.new(7), 8)

func test_a_fresh_system_is_empty() -> void:
	assert_eq(_sys.alive_count(), 0)

func test_spawn_returns_a_slot_and_counts_it() -> void:
	assert_eq(_sys.spawn(0, Vector2.ZERO, 0.0), 0)
	assert_eq(_sys.alive_count(), 1)

func test_spawn_stores_the_position() -> void:
	var id: int = _sys.spawn(0, Vector2(12.0, -4.0), 0.0)
	assert_eq(_sys.position_of(id), Vector2(12.0, -4.0))

func test_kill_frees_the_slot_for_reuse() -> void:
	var id: int = _sys.spawn(0, Vector2.ZERO, 0.0)
	_sys.kill(id)
	assert_eq(_sys.alive_count(), 0)
	assert_eq(_sys.spawn(0, Vector2.ZERO, 0.0), id, "slots must be recycled")

func test_killing_twice_is_harmless() -> void:
	var id: int = _sys.spawn(0, Vector2.ZERO, 0.0)
	_sys.kill(id)
	_sys.kill(id)
	assert_eq(_sys.alive_count(), 0)

func test_kill_reports_position_and_xp() -> void:
	watch_signals(_sys)
	var id: int = _sys.spawn(0, Vector2(3.0, 3.0), 0.0)
	_sys.kill(id)
	assert_signal_emitted_with_parameters(_sys, "enemy_died", [Vector2(3.0, 3.0), 1])

func test_spawn_returns_minus_one_when_full() -> void:
	for i in 8:
		assert_ne(_sys.spawn(0, Vector2.ZERO, 0.0), -1)
	assert_eq(_sys.spawn(0, Vector2.ZERO, 0.0), -1)

func test_hp_at_spawn_scales_with_elapsed_time() -> void:
	assert_almost_eq(_sys.hp_of(_sys.spawn(0, Vector2.ZERO, 0.0)), 10.0, 0.01)
	assert_almost_eq(_sys.hp_of(_sys.spawn(0, Vector2.ZERO, 150.0)), 20.0, 0.01,
		"1 + 150/150 doubles it")
	assert_almost_eq(_sys.hp_of(_sys.spawn(0, Vector2.ZERO, 300.0)), 30.0, 0.01)

func test_multimesh_has_one_instance_per_slot() -> void:
	assert_not_null(_sys.multimesh)
	assert_eq(_sys.multimesh.instance_count, 8)
	assert_eq(_sys.multimesh.transform_format, MultiMesh.TRANSFORM_2D)

func test_drawn_transform_follows_the_enemy() -> void:
	var id: int = _sys.spawn(0, Vector2(20.0, 5.0), 0.0)
	_sys.sync_multimesh()
	assert_eq(_sys.multimesh.get_instance_transform_2d(id).origin, Vector2(20.0, 5.0))

func test_dead_slots_are_drawn_at_zero_scale() -> void:
	var id: int = _sys.spawn(0, Vector2(20.0, 5.0), 0.0)
	_sys.sync_multimesh()
	_sys.kill(id)
	var t: Transform2D = _sys.multimesh.get_instance_transform_2d(id)
	assert_almost_eq(t.get_scale().length(), 0.0, 0.001, "a dead slot must not be visible")
```

- [x] **Step 2: รันแล้วต้องพัง**

Expected: FAIL — ไม่รู้จัก `EnemySystem`

- [x] **Step 3: เขียน `run/enemy_system.gd`**

```gdscript
class_name EnemySystem
extends MultiMeshInstance2D

## Every enemy in the game, as a struct of arrays drawn by a single MultiMesh.
##
## There is no node, Area2D or physics body per enemy — neighbour lookups go
## through SpatialGrid instead. See docs/superpowers/specs/2026-10-30-m1-core-systems-design.md
##
## Slots are stable: a dead enemy returns its slot to the pool and its instance
## is drawn at zero scale, but live enemies never move slot. That keeps an
## enemy id usable across frames, which Rune Orbit, Hawk and piercing shots all
## need in M3.
##
## Nothing here hands a Packed*Array out to a caller. GDScript arrays are
## copy-on-write, so a second reference would make every write in here copy the
## whole buffer; query_radius() fills a buffer we own instead.

signal enemy_died(pos: Vector2, xp: int)

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
var _max_radius: float = 0.0

var _pool: Pool = null
var _grid: SpatialGrid = null
var _rng: Rng = null
var _tuning: RunTuning = null

## Reusable scratch buffers, allocated once in setup()
var _query: PackedInt32Array = PackedInt32Array()
var _push: PackedVector2Array = PackedVector2Array()

var _alive_count: int = 0

## Stage timings in microseconds, read by the debug overlay
var usec_grid: int = 0
var usec_separation: int = 0
var usec_contact: int = 0
var usec_movement: int = 0
var usec_multimesh: int = 0

func setup(defs: Array[EnemyDef], tuning: RunTuning, rng: Rng, capacity: int) -> void:
	_tuning = tuning
	_rng = rng
	_capacity = capacity

	_pos.resize(capacity)
	_vel.resize(capacity)
	_hp.resize(capacity)
	_type.resize(capacity)
	_alive.resize(capacity)
	_query.resize(capacity)
	_push.resize(capacity)
	_alive.fill(0)
	_push.fill(Vector2.ZERO)

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

func sync_multimesh() -> void:
	var started: int = Time.get_ticks_usec()
	var mm: MultiMesh = multimesh
	for i in _capacity:
		if _alive[i] == 1:
			var r: float = _type_radius[_type[i]]
			mm.set_instance_transform_2d(i, Transform2D(0.0, Vector2(r, r), 0.0, _pos[i]))
	usec_multimesh = Time.get_ticks_usec() - started

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
```

- [x] **Step 4: รันเทสต์ ต้องผ่าน**

```bash
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```
Expected: PASS ทั้งหมด
ถ้า `const DEAD_TRANSFORM` ใช้ constructor 4 ตัวไม่ได้ ให้เปลี่ยนเป็น `static var` แล้วรายงานไว้ในข้อความ commit

- [x] **Step 5: commit**

```bash
git add run/enemy_system.gd tests/test_enemy_system.gd
git rm -q --cached data/.gitkeep 2>/dev/null; rm -f data/.gitkeep
git commit -m "Add enemy system with struct-of-arrays storage and multimesh drawing"
```

---

### Task 7: ศัตรูเดินไล่ผู้เล่นและตัวที่หลงไกลถูกย้ายกลับ

> **สถานะ:** ทำแล้วใน M1-11 แต่ไม่ติ๊ก step เพราะต่างจากโค้ดตัวอย่าง: `tick_movement(delta, player_pos)` ไม่รับ `elapsed` (hp scaling อยู่ที่ `spawn()` แล้ว) ไม่มี `tick_grid()` และ `_push` (เป็นของ M1-12/M1-17 ที่ยังไม่มีโค้ดใช้) และ `setup()` รับ `Rng` เพิ่ม ส่วนเทสต์ปรับตามนี้และเพิ่ม 3 ข้อ (เดินทแยง, รีไซเคิลรอบตำแหน่งผู้เล่น, ซ้ำได้ด้วย seed เดิม)

**Files:**
- Modify: `run/enemy_system.gd` (เพิ่ม `tick_grid()` และ `tick_movement()`)
- Modify: `tests/test_enemy_system.gd`

- [ ] **Step 1: เพิ่มเทสต์ที่ต้องพัง**

ต่อท้าย `tests/test_enemy_system.gd`:

```gdscript
func test_enemy_walks_towards_the_player() -> void:
	var id: int = _sys.spawn(0, Vector2(100.0, 0.0), 0.0)
	_sys.tick_grid()
	_sys.tick_movement(0.1, Vector2.ZERO, 0.0)
	assert_almost_eq(_sys.position_of(id).x, 95.5, 0.01, "45 px/s for 0.1 s")
	assert_almost_eq(_sys.position_of(id).y, 0.0, 0.001)

func test_enemy_on_top_of_the_player_does_not_produce_nan() -> void:
	var id: int = _sys.spawn(0, Vector2.ZERO, 0.0)
	_sys.tick_grid()
	_sys.tick_movement(0.1, Vector2.ZERO, 0.0)
	assert_false(is_nan(_sys.position_of(id).x), "normalising a zero vector must not leak NaN")

func test_a_stray_enemy_is_recycled_into_the_spawn_ring() -> void:
	var id: int = _sys.spawn(0, Vector2(2000.0, 0.0), 0.0)
	_sys.tick_grid()
	_sys.tick_movement(0.1, Vector2.ZERO, 0.0)
	var d: float = _sys.position_of(id).length()
	assert_between(d, _tuning.spawn_ring_min, _tuning.spawn_ring_max)
	assert_eq(_sys.alive_count(), 1, "recycling moves an enemy, it does not kill it")

func test_an_enemy_just_inside_the_recycle_distance_keeps_walking() -> void:
	var id: int = _sys.spawn(0, Vector2(599.0, 0.0), 0.0)
	_sys.tick_grid()
	_sys.tick_movement(0.1, Vector2.ZERO, 0.0)
	assert_almost_eq(_sys.position_of(id).x, 594.5, 0.01)

func test_dead_slots_do_not_move() -> void:
	var id: int = _sys.spawn(0, Vector2(100.0, 0.0), 0.0)
	_sys.kill(id)
	_sys.tick_grid()
	_sys.tick_movement(0.1, Vector2.ZERO, 0.0)
	assert_eq(_sys.position_of(id), Vector2(100.0, 0.0))
```

- [ ] **Step 2: รันแล้วต้องพัง**

Expected: FAIL — ไม่มีเมธอด `tick_grid` / `tick_movement`

- [ ] **Step 3: เพิ่มสองเมธอดลง `run/enemy_system.gd`** (วางไว้ก่อน `sync_multimesh()`)

```gdscript
## Rebuilds the neighbour grid from the current positions. Everything that
## queries neighbours this frame must run after this and before anything moves.
func tick_grid() -> void:
	var started: int = Time.get_ticks_usec()
	_grid.clear()
	for i in _capacity:
		if _alive[i] == 1:
			_grid.insert(i, _pos[i])
	usec_grid = Time.get_ticks_usec() - started

func tick_movement(delta: float, player_pos: Vector2, elapsed: float) -> void:
	var started: int = Time.get_ticks_usec()
	var recycle_sq: float = _tuning.recycle_distance * _tuning.recycle_distance
	for i in _capacity:
		if _alive[i] == 0:
			continue
		var p: Vector2 = _pos[i]
		var to_player: Vector2 = player_pos - p
		if to_player.length_squared() > recycle_sq:
			# Rather than pay to kill and respawn, drop the stray back into the
			# ring; the player never sees where it came from.
			_pos[i] = _rng.point_in_ring(player_pos, _tuning.spawn_ring_min, _tuning.spawn_ring_max)
			_vel[i] = Vector2.ZERO
			continue
		var v: Vector2 = to_player.normalized() * _type_speed[_type[i]] + _push[i]
		_vel[i] = v
		_pos[i] = p + v * delta
	usec_movement = Time.get_ticks_usec() - started
```

- [ ] **Step 4: รันเทสต์ ต้องผ่าน**

Expected: PASS ทั้งหมด

- [ ] **Step 5: commit**

```bash
git add run/enemy_system.gd tests/test_enemy_system.gd
git commit -m "Make enemies chase the player and recycle strays into the ring"
```

---

### Task 8: separation — ศัตรูผลักกันเอง

> **สถานะ (M1-17):** ทำแล้ว ต่างจากโค้ดตัวอย่าง: `tick_separation()` ไม่รับ `delta` (แรงผลักเก็บเป็นความเร็วและ `tick_movement` เป็นคนคูณเวลา) ล้าง `_push` ตอน `spawn()` ด้วย และเทสต์ใช้ศัตรูความเร็ว 0 แทนผู้เล่นที่ `(0, 10000)` เพราะระยะนั้นเกิน `recycle_distance` ทำให้ศัตรูถูก recycle แทนที่จะถูกผลัก

**Files:**
- Modify: `run/enemy_system.gd` (เพิ่ม `tick_separation()`)
- Modify: `tests/test_enemy_system.gd`

- [x] **Step 1: เพิ่มเทสต์ที่ต้องพัง**

ต่อท้าย `tests/test_enemy_system.gd`:

```gdscript
func _distance(a: int, b: int) -> float:
	return _sys.position_of(a).distance_to(_sys.position_of(b))

func test_overlapping_enemies_are_pushed_apart() -> void:
	var a: int = _sys.spawn(0, Vector2(0.0, 0.0), 0.0)
	var b: int = _sys.spawn(0, Vector2(4.0, 0.0), 0.0)
	var before: float = _distance(a, b)
	_sys.tick_grid()
	_sys.tick_separation(0.1)
	# player far away on +Y so both chase in nearly the same direction and the
	# only thing that can change their distance is the separation push
	_sys.tick_movement(0.1, Vector2(0.0, 10000.0), 0.0)
	assert_gt(_distance(a, b), before)

func test_enemies_that_do_not_overlap_are_left_alone() -> void:
	var a: int = _sys.spawn(0, Vector2(0.0, 0.0), 0.0)
	var b: int = _sys.spawn(0, Vector2(50.0, 0.0), 0.0)
	var before: float = _distance(a, b)
	_sys.tick_grid()
	_sys.tick_separation(0.1)
	_sys.tick_movement(0.1, Vector2(0.0, 10000.0), 0.0)
	assert_almost_eq(_distance(a, b), before, 0.01)

func test_separation_is_symmetric() -> void:
	var a: int = _sys.spawn(0, Vector2(-2.0, 0.0), 0.0)
	var b: int = _sys.spawn(0, Vector2(2.0, 0.0), 0.0)
	_sys.tick_grid()
	_sys.tick_separation(0.1)
	_sys.tick_movement(0.1, Vector2(0.0, 10000.0), 0.0)
	assert_almost_eq(_sys.position_of(a).x, -_sys.position_of(b).x, 0.01,
		"an equal pair must be pushed by equal and opposite amounts")

func test_a_dead_neighbour_pushes_nobody() -> void:
	var a: int = _sys.spawn(0, Vector2.ZERO, 0.0)
	var b: int = _sys.spawn(0, Vector2(1.0, 0.0), 0.0)
	_sys.kill(b)
	_sys.tick_grid()
	_sys.tick_separation(0.1)
	_sys.tick_movement(0.1, Vector2(0.0, 10000.0), 0.0)
	assert_almost_eq(_sys.position_of(a).x, 0.0, 0.001)

func test_exactly_stacked_enemies_still_separate() -> void:
	var a: int = _sys.spawn(0, Vector2.ZERO, 0.0)
	var b: int = _sys.spawn(0, Vector2.ZERO, 0.0)
	_sys.tick_grid()
	_sys.tick_separation(0.1)
	_sys.tick_movement(0.1, Vector2(0.0, 10000.0), 0.0)
	assert_gt(_distance(a, b), 0.0, "two enemies on the exact same pixel must not stay welded")

func test_the_push_buffer_is_cleared_every_frame() -> void:
	var a: int = _sys.spawn(0, Vector2(0.0, 0.0), 0.0)
	var b: int = _sys.spawn(0, Vector2(4.0, 0.0), 0.0)
	_sys.tick_grid()
	_sys.tick_separation(0.1)
	_sys.tick_movement(0.1, Vector2(0.0, 10000.0), 0.0)
	var pushed_x: float = _sys.position_of(a).x
	assert_lt(pushed_x, 0.0, "the first frame must push a to the left")
	_sys.kill(b)
	_sys.tick_grid()
	_sys.tick_separation(0.1)
	_sys.tick_movement(0.1, Vector2(0.0, 10000.0), 0.0)
	assert_almost_eq(_sys.position_of(a).x, pushed_x, 0.001,
		"with the neighbour gone, a stale push must not move a again")
```

- [x] **Step 2: รันแล้วต้องพัง**

Expected: FAIL — ไม่มีเมธอด `tick_separation`

- [x] **Step 3: เพิ่ม `tick_separation()` ลง `run/enemy_system.gd`** (วางไว้หลัง `tick_grid()`)

```gdscript
## Soft collision between enemies. Each overlapping pair is visited once (j > i)
## and pushed both ways, which halves the work for the same result. The push
## becomes velocity rather than a position jump, so the behaviour does not
## change with frame rate.
func tick_separation(delta: float) -> void:
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
```

- [x] **Step 4: รันเทสต์ ต้องผ่าน**

Expected: PASS ทั้งหมด

- [x] **Step 5: commit**

```bash
git add run/enemy_system.gd tests/test_enemy_system.gd
git commit -m "Add soft separation between enemies"
```

---

### Task 9: contact — ศัตรูแตะผู้เล่นแล้วเกิดดาเมจ

> **สถานะ:** ทำแล้วใน M1-12 รวม `tick_grid()` ที่ย้ายมาจาก Task 7 ต่างจากโค้ดตัวอย่าง: คง `_alive[j]` เช็คไว้ใน `tick_contact()` เพราะกริดสร้างครั้งเดียวต่อเฟรม ตัวที่ตายหลังจากนั้นยังค้างอยู่ในกริด (มีเทสต์ครอบ) และเพิ่ม `usec_grid` / `usec_contact` ให้ overlay `tick_separation()` ที่แผนอ้างถึงทำแล้วใน M1-17

**Files:**
- Modify: `run/enemy_system.gd` (เพิ่ม `tick_contact()`)
- Modify: `tests/test_enemy_system.gd`

- [x] **Step 1: เพิ่มเทสต์ที่ต้องพัง**

ต่อท้าย `tests/test_enemy_system.gd`:

```gdscript
func _make_knight() -> Player:
	var def: ClassDef = ClassDef.new()
	def.max_hp = 140.0
	def.move_speed = 95.0
	def.armor = 2
	def.pickup_radius = 40.0
	def.body_radius = 7.0
	var player: Player = Player.new()
	autofree(player)
	player.setup(def, _tuning)
	return player

func test_a_touching_enemy_damages_the_player_once() -> void:
	var player: Player = _make_knight()
	_sys.spawn(0, Vector2(5.0, 0.0), 0.0)
	_sys.spawn(0, Vector2(-5.0, 0.0), 0.0)
	_sys.tick_grid()
	_sys.tick_contact(player)
	assert_almost_eq(player.hp, 137.0, 0.01, "max(1, 5 - 2) = 3, charged once not twice")

func test_a_distant_enemy_does_not_damage_the_player() -> void:
	var player: Player = _make_knight()
	_sys.spawn(0, Vector2(200.0, 0.0), 0.0)
	_sys.tick_grid()
	_sys.tick_contact(player)
	assert_eq(player.hp, 140.0)

func test_an_enemy_just_out_of_reach_does_not_damage_the_player() -> void:
	var player: Player = _make_knight()
	_sys.spawn(0, Vector2(13.5, 0.0), 0.0)
	_sys.tick_grid()
	_sys.tick_contact(player)
	assert_eq(player.hp, 140.0, "the body radii sum to 13, so 13.5 misses")

func test_contact_respects_invulnerability() -> void:
	var player: Player = _make_knight()
	_sys.spawn(0, Vector2(5.0, 0.0), 0.0)
	_sys.tick_grid()
	_sys.tick_contact(player)
	_sys.tick_contact(player)
	assert_almost_eq(player.hp, 137.0, 0.01)
	player.tick_timers(_tuning.player_iframe_duration)
	_sys.tick_contact(player)
	assert_almost_eq(player.hp, 134.0, 0.01)

func test_the_hardest_hitting_toucher_wins() -> void:
	var brute: EnemyDef = EnemyDef.new()
	brute.id = &"brute"
	brute.hp = 70.0
	brute.move_speed = 28.0
	brute.contact_damage = 12.0
	brute.xp = 5
	brute.body_radius = 11.0
	var defs: Array[EnemyDef] = [_ghoul, brute]
	var sys: EnemySystem = EnemySystem.new()
	autofree(sys)
	sys.setup(defs, _tuning, Rng.new(1), 8)
	var player: Player = _make_knight()
	sys.spawn(0, Vector2(5.0, 0.0), 0.0)
	sys.spawn(1, Vector2(-5.0, 0.0), 0.0)
	sys.tick_grid()
	sys.tick_contact(player)
	assert_almost_eq(player.hp, 130.0, 0.01,
		"max(1, 12 - 2) = 10 from the brute, independent of slot order")
```

- [x] **Step 2: รันแล้วต้องพัง**

Expected: FAIL — ไม่มีเมธอด `tick_contact`

- [x] **Step 3: เพิ่ม `tick_contact()` ลง `run/enemy_system.gd`** (วางไว้หลัง `tick_separation()`)

```gdscript
## Charges the player for touching enemies. design.md gives the player a single
## 0.5 s invulnerability window rather than a per-enemy cooldown, so one hit is
## resolved per frame and the hardest hitter is the one that lands — picking the
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
			if _alive[j] == 0:
				continue
			var reach: float = player.body_radius + _type_radius[_type[j]]
			if center.distance_squared_to(_pos[j]) > reach * reach:
				continue
			worst = maxf(worst, _type_damage[_type[j]])
		if worst > 0.0:
			player.take_damage(worst)
	usec_contact = Time.get_ticks_usec() - started
```

- [x] **Step 4: รันเทสต์ ต้องผ่าน**

Expected: PASS ทั้งหมด

- [x] **Step 5: commit**

```bash
git add run/enemy_system.gd tests/test_enemy_system.gd
git commit -m "Damage the player from enemy contact through the grid"
```

---

### Task 10: `SpawnDirector` — ปล่อยศัตรูตามเวลา

> **สถานะ (M1-13):** ทำแล้ว ต่างจากโค้ดตัวอย่าง: `SpawnDirector` สืบทอด `RefCounted` แทน `Node` เพราะไม่มี process callback (run.gd เรียก `tick()` เอง) จึงไม่ต้อง `autofree` ในเทสต์ และเพิ่มเทสต์ 3 ข้อ (ทิ้ง backlog ตอนถึงเพดาน, เพดานอ่านจาก tuning, seed เดียวกันได้จุดเกิดเดียวกัน)

**Files:**
- Create: `run/spawn_director.gd`
- Test: `tests/test_spawn_director.gd`

- [x] **Step 1: เขียนเทสต์ที่ต้องพัง**

`tests/test_spawn_director.gd`:

```gdscript
extends GutTest

const GHOUL: int = 0

var _sys: EnemySystem
var _spawner: SpawnDirector
var _tuning: RunTuning

func before_each() -> void:
	var ghoul: EnemyDef = EnemyDef.new()
	ghoul.id = &"ghoul"
	ghoul.hp = 10.0
	ghoul.move_speed = 45.0
	ghoul.contact_damage = 5.0
	ghoul.xp = 1
	ghoul.body_radius = 6.0
	var defs: Array[EnemyDef] = [ghoul]
	_tuning = RunTuning.new()
	_tuning.enemy_cap = 5
	_sys = EnemySystem.new()
	autofree(_sys)
	_sys.setup(defs, _tuning, Rng.new(3), _tuning.enemy_cap)
	_spawner = SpawnDirector.new()
	autofree(_spawner)
	_spawner.setup(_sys, _tuning, Rng.new(3))

func test_rate_curve_matches_design() -> void:
	assert_almost_eq(_spawner.rate_at(0.0), 1.0, 0.001)
	assert_almost_eq(_spawner.rate_at(20.0), 2.0, 0.001)
	assert_almost_eq(_spawner.rate_at(220.0), 12.0, 0.001)

func test_rate_is_capped() -> void:
	assert_almost_eq(_spawner.rate_at(10000.0), 12.0, 0.001)

func test_fractional_spawns_accumulate_instead_of_being_lost() -> void:
	_spawner.tick(0.5, 0.0, Vector2.ZERO)
	assert_eq(_sys.alive_count(), 0, "half a second at 1/s is not a whole enemy yet")
	_spawner.tick(0.5, 0.0, Vector2.ZERO)
	assert_eq(_sys.alive_count(), 1)

func test_a_long_frame_can_spawn_several() -> void:
	_spawner.tick(3.0, 0.0, Vector2.ZERO)
	assert_eq(_sys.alive_count(), 3)

func test_the_cap_is_respected() -> void:
	_spawner.tick(100.0, 0.0, Vector2.ZERO)
	assert_eq(_sys.alive_count(), 5)

func test_burst_stops_at_the_cap() -> void:
	assert_eq(_spawner.spawn_burst(99, 0.0, Vector2.ZERO), 5)
	assert_eq(_sys.alive_count(), 5)

func test_spawns_land_in_the_ring_around_the_player() -> void:
	var player_pos: Vector2 = Vector2(100.0, -200.0)
	_spawner.spawn_burst(5, 0.0, player_pos)
	for i in 5:
		var d: float = _sys.position_of(i).distance_to(player_pos)
		assert_between(d, _tuning.spawn_ring_min, _tuning.spawn_ring_max)

func test_spawned_enemies_carry_the_time_scaled_hp() -> void:
	_spawner.spawn_burst(1, 150.0, Vector2.ZERO)
	assert_almost_eq(_sys.hp_of(0), 20.0, 0.01)
```

- [x] **Step 2: รันแล้วต้องพัง**

Expected: FAIL — ไม่รู้จัก `SpawnDirector`

- [x] **Step 3: เขียน `run/spawn_director.gd`**

```gdscript
class_name SpawnDirector
extends Node

## Releases enemies over time: min(cap, base + elapsed / divisor) per second,
## in a ring just outside the view. Every number comes from RunTuning.
##
## M1 only has Ghouls; the per-enemy start times in design.md section 8 arrive
## with the spawn table in M3.

const GHOUL: int = 0

var _enemies: EnemySystem = null
var _tuning: RunTuning = null
var _rng: Rng = null
var _accumulator: float = 0.0

func setup(enemies: EnemySystem, tuning: RunTuning, rng: Rng) -> void:
	_enemies = enemies
	_tuning = tuning
	_rng = rng
	_accumulator = 0.0

func rate_at(elapsed: float) -> float:
	return minf(_tuning.spawn_rate_cap,
		_tuning.spawn_rate_base + elapsed / _tuning.spawn_rate_time_divisor)

func tick(delta: float, elapsed: float, player_pos: Vector2) -> void:
	_accumulator += rate_at(elapsed) * delta
	while _accumulator >= 1.0:
		_accumulator -= 1.0
		if not _spawn_one(elapsed, player_pos):
			# at the cap: drop the backlog so it cannot burst later
			_accumulator = 0.0
			return

func spawn_burst(count: int, elapsed: float, player_pos: Vector2) -> int:
	var spawned: int = 0
	for i in count:
		if not _spawn_one(elapsed, player_pos):
			break
		spawned += 1
	return spawned

func _spawn_one(elapsed: float, player_pos: Vector2) -> bool:
	if _enemies.alive_count() >= _tuning.enemy_cap:
		return false
	var pos: Vector2 = _rng.point_in_ring(player_pos,
		_tuning.spawn_ring_min, _tuning.spawn_ring_max)
	return _enemies.spawn(GHOUL, pos, elapsed) != -1
```

- [x] **Step 4: รันเทสต์ ต้องผ่าน**

Expected: PASS ทั้งหมด

- [x] **Step 5: commit**

```bash
git add run/spawn_director.gd tests/test_spawn_director.gd
git commit -m "Add spawn director with the design spawn rate curve"
```

---

### Task 11: ปุ่ม F4 สำหรับอัดศัตรูให้เต็มเพดาน

> **สถานะ (M1-14):** ทำแล้ว ต่างจากแผน: เพิ่ม `Run.spawn_burst_to_cap()` กับ `_unhandled_input` ใน `run/run.gd` (แผน Task 13 ยังไม่ได้ผูกปุ่ม) และเทสต์ 4 ข้อใน `tests/test_run.gd` seed ล็อกอยู่แล้วจาก M1-19 (`START_SEED` ใน `run.gd`) จึงไม่ต้องแก้ ตรวจแล้วบน renderer จริงว่ากด F4 ได้ 400 / 400

**Files:**
- Modify: `project.godot` (`[input]`)
- Modify: `tests/test_project_config.gd`

- [x] **Step 1: เพิ่มเทสต์ที่ต้องพัง**

ใน `tests/test_project_config.gd` แก้ list ใน `test_movement_and_system_actions_exist` ให้เป็น:

```gdscript
	var required: Array[String] = [
		"move_up", "move_down", "move_left", "move_right", "pause", "toggle_debug",
		"debug_spawn_burst",
```

(ส่วนที่เหลือของฟังก์ชันไม่ต้องแก้)

- [x] **Step 2: รันแล้วต้องพัง**

Expected: FAIL — ไม่มี action `debug_spawn_burst`

- [x] **Step 3: เพิ่ม action ลง `project.godot`**

ต่อท้ายบล็อก `toggle_debug={...}` ใน section `[input]` (ก่อนบรรทัดว่างที่คั่นกับ `[rendering]`) ใส่:

```
debug_spawn_burst={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194335,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

(4194335 = `KEY_F4` ตัวเดียวกับที่ `toggle_debug` ใช้ 4194334 = `KEY_F3`)

- [x] **Step 4: ยืนยันว่า keycode แมปเป็น F4 จริง**

```bash
cat > check_input.gd <<'EOF'
extends SceneTree

func _init() -> void:
	for action in ["toggle_debug", "debug_spawn_burst"]:
		for e in InputMap.action_get_events(action):
			print("%s -> %s" % [action, e.as_text()])
	quit()
EOF
godot --headless --path . -s check_input.gd
rm check_input.gd
```
Expected: `toggle_debug -> F3` และ `debug_spawn_burst -> F4`

- [x] **Step 5: รันเทสต์ ต้องผ่าน**

Expected: PASS ทั้งหมด

- [x] **Step 6: commit**

```bash
git add project.godot tests/test_project_config.gd
git commit -m "Add F4 debug action for filling the enemy cap"
```

---

### Task 12: `DebugOverlay` — F3, FPS avg และ 1% low, ms ต่อขั้น

> **สถานะ (M1-4):** ทำแล้ว แต่ต่างจากโค้ดตัวอย่าง: `EnemySystem` ยังไม่มี จึงไม่ `bind(enemies)` ตรง ๆ แต่ใช้ `bind_extra_lines(provider: Callable)` ให้ระบบส่งข้อความมาเอง (จำนวนศัตรู / ms ต่อขั้น) และเพิ่ม `build_text()` เป็น public สำหรับเทสต์ ตอนทำ M1-9 ให้ bind จาก `run.gd` ด้วย Callable ที่ประกอบข้อความจาก getter ของ EnemySystem. แก้ `1%%` ในสตริงที่ไม่ผ่าน `%` ด้วย

**Files:**
- Create: `ui/debug_overlay.gd`, `ui/debug_overlay.tscn`
- Test: `tests/test_debug_overlay.gd`

เทสต์ครอบแค่คณิตศาสตร์ของสถิติ ส่วนการแสดงผลดูด้วยตา

- [x] **Step 1: เขียนเทสต์ที่ต้องพัง**

`tests/test_debug_overlay.gd`:

```gdscript
extends GutTest

var _overlay: DebugOverlay

func before_each() -> void:
	_overlay = DebugOverlay.new()
	autofree(_overlay)
	_overlay.init_buffers()

func test_stats_are_unavailable_until_the_window_is_full() -> void:
	for i in 10:
		_overlay.record_frame(1.0 / 120.0)
	assert_false(_overlay.has_stats(), "a partly filled window must not be reported as a result")

func test_average_fps_over_a_full_window() -> void:
	for i in DebugOverlay.WINDOW:
		_overlay.record_frame(1.0 / 120.0)
	assert_true(_overlay.has_stats())
	assert_almost_eq(_overlay.average_fps(), 120.0, 0.5)

func test_one_percent_low_catches_the_worst_frames() -> void:
	# 594 good frames at 120 fps and 6 bad ones at 20 fps: the 1% low must
	# report the bad end, not the average
	for i in DebugOverlay.WINDOW - 6:
		_overlay.record_frame(1.0 / 120.0)
	for i in 6:
		_overlay.record_frame(1.0 / 20.0)
	assert_almost_eq(_overlay.one_percent_low_fps(), 20.0, 0.5)
	assert_gt(_overlay.average_fps(), 60.0, "a few bad frames must not sink the average")

func test_the_window_is_a_ring_buffer() -> void:
	for i in DebugOverlay.WINDOW:
		_overlay.record_frame(1.0 / 20.0)
	for i in DebugOverlay.WINDOW:
		_overlay.record_frame(1.0 / 120.0)
	assert_almost_eq(_overlay.average_fps(), 120.0, 0.5, "old frames must be overwritten")
```

- [x] **Step 2: รันแล้วต้องพัง**

Expected: FAIL — ไม่รู้จัก `DebugOverlay`

- [x] **Step 3: เขียน `ui/debug_overlay.gd`**

```gdscript
class_name DebugOverlay
extends CanvasLayer

## F3 overlay. Reports the numbers the M1 gate is judged on: average and 1% low
## fps over a fixed window, the live enemy count and the cost of each stage of
## the run loop.
##
## Reads the systems through getters and never writes to them.

const WINDOW: int = 600

var _frame_times: PackedFloat32Array = PackedFloat32Array()
var _sorted: PackedFloat32Array = PackedFloat32Array()
var _write_index: int = 0
var _filled: int = 0
var _refresh_timer: float = 0.0
var _enemies: EnemySystem = null

@onready var _label: Label = $Label

func _ready() -> void:
	init_buffers()
	visible = false

## Separate from _ready() so tests can use the statistics without a SceneTree.
func init_buffers() -> void:
	_frame_times.resize(WINDOW)
	_sorted.resize(WINDOW)
	_frame_times.fill(0.0)
	_write_index = 0
	_filled = 0

func bind(enemies: EnemySystem) -> void:
	_enemies = enemies

func record_frame(delta: float) -> void:
	_frame_times[_write_index] = delta
	_write_index = (_write_index + 1) % WINDOW
	_filled = mini(_filled + 1, WINDOW)

func has_stats() -> bool:
	return _filled >= WINDOW

func average_fps() -> float:
	if not has_stats():
		return 0.0
	var total: float = 0.0
	for i in WINDOW:
		total += _frame_times[i]
	if total <= 0.0:
		return 0.0
	return float(WINDOW) / total

## The 99th percentile frame time, expressed as fps — the number that shows
## stutter that an average hides.
func one_percent_low_fps() -> float:
	if not has_stats():
		return 0.0
	for i in WINDOW:
		_sorted[i] = _frame_times[i]
	_sorted.sort()
	var worst: float = _sorted[int(float(WINDOW) * 0.99)]
	if worst <= 0.0:
		return 0.0
	return 1.0 / worst

func _process(delta: float) -> void:
	record_frame(delta)
	if not visible:
		return
	_refresh_timer -= delta
	if _refresh_timer > 0.0:
		return
	_refresh_timer = 0.25
	_label.text = _build_text()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		visible = not visible

func _build_text() -> String:
	var stats: String = "avg --  1%% low --"
	if has_stats():
		stats = "avg %.0f  1%% low %.0f" % [average_fps(), one_percent_low_fps()]
	var lines: PackedStringArray = PackedStringArray()
	lines.append("FPS %d   %s" % [Engine.get_frames_per_second(), stats])
	if _enemies != null:
		lines.append("enemies %d / %d" % [_enemies.alive_count(), _enemies.capacity()])
		lines.append("grid %.2f  sep %.2f  hit %.2f  move %.2f  draw %.2f ms" % [
			_enemies.usec_grid / 1000.0,
			_enemies.usec_separation / 1000.0,
			_enemies.usec_contact / 1000.0,
			_enemies.usec_movement / 1000.0,
			_enemies.usec_multimesh / 1000.0,
		])
	return "\n".join(lines)
```

- [x] **Step 4: รันเทสต์ ต้องผ่าน**

```bash
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```
Expected: PASS ทั้งหมด

- [x] **Step 5: เขียน `ui/debug_overlay.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/debug_overlay.gd" id="1_overlay"]

[node name="DebugOverlay" type="CanvasLayer"]
layer = 10
script = ExtResource("1_overlay")

[node name="Label" type="Label" parent="."]
offset_left = 4.0
offset_top = 4.0
offset_right = 320.0
offset_bottom = 60.0
theme_override_colors/font_color = Color(0.6, 1, 0.6, 1)
theme_override_font_sizes/font_size = 8
text = "F3"
```

- [x] **Step 6: commit**

```bash
git add ui/debug_overlay.gd ui/debug_overlay.tscn tests/test_debug_overlay.gd
rm -f ui/.gitkeep core/.gitkeep
git add -A ui core
git commit -m "Add debug overlay with frame time window and stage timings"
```

---

### Task 13: ประกอบฉาก run และเปลี่ยน main.tscn เป็น state switcher

> **สถานะ (M1-19):** ทำแล้ว ต่างจากโค้ดตัวอย่าง: `Run` เป็น `class_name` และมี `step(delta)` ที่ `_physics_process` เรียก เพื่อให้เทสต์ขยับทีละเฟรมได้; `SpawnDirector` เป็น `RefCounted` จึงสร้างด้วย `SpawnDirector.new()` ในโค้ดไม่ใช่ node ใน scene; overlay ผูกด้วย `bind_extra_lines(Callable)` แทน `bind(enemies)`; `tick_separation()` ไม่มี `delta` และ `tick_movement()` ไม่มี `elapsed`; ไม่มี `debug_spawn_burst` (เป็นของ M1-14); `Camera2D` อยู่ใต้ `Player` ใน run.tscn; เพิ่ม `usec_movement` / `usec_multimesh` ใน EnemySystem ให้ overlay แสดงครบทุกขั้น; คง `run/weapons/.gitkeep` ไว้ (ลบเฉพาะ `run/.gitkeep`) เพราะโฟลเดอร์นี้อยู่ในโครงสร้างโปรเจกต์ของ CLAUDE.md; step 6 ตรวจด้วยสคริปต์บน renderer จริงแทนการเปิดดูด้วยตา

**Files:**
- Create: `run/run.gd`, `run/run.tscn`
- Modify: `main.gd`, `main.tscn`
- Delete: `run/.gitkeep`

- [x] **Step 1: เขียน `run/run.gd`**

```gdscript
extends Node2D

## Owns the update order of one run. Every system is ticked from here instead of
## having its own _physics_process, so the order is visible in one place and the
## debug overlay can attribute time to each stage.

const START_SEED: int = 20261030

const KNIGHT := preload("res://data/classes/knight.tres")
const GHOUL := preload("res://data/enemies/ghoul.tres")
const TUNING := preload("res://data/tuning/run_tuning.tres")

var elapsed: float = 0.0

var _rng: Rng = null

@onready var _enemies: EnemySystem = $EnemySystem
@onready var _player: Player = $Player
@onready var _spawner: SpawnDirector = $SpawnDirector
@onready var _overlay: DebugOverlay = $DebugOverlay

func _ready() -> void:
	_rng = Rng.new(START_SEED)
	var defs: Array[EnemyDef] = [GHOUL]
	# M2 will pass the class the player picked at Camp instead of hardcoding it
	_player.setup(KNIGHT, TUNING)
	_enemies.setup(defs, TUNING, _rng, TUNING.enemy_cap)
	_spawner.setup(_enemies, TUNING, _rng)
	_overlay.bind(_enemies)
	_player.died.connect(_on_player_died)

func _physics_process(delta: float) -> void:
	elapsed += delta
	_player.tick(delta)
	_spawner.tick(delta, elapsed, _player.global_position)
	# the grid must be rebuilt before anything queries it, and nothing may move
	# between the rebuild and the last query
	_enemies.tick_grid()
	_enemies.tick_separation(delta)
	_enemies.tick_contact(_player)
	_enemies.tick_movement(delta, _player.global_position, elapsed)
	_enemies.sync_multimesh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_spawn_burst"):
		_spawner.spawn_burst(TUNING.enemy_cap, elapsed, _player.global_position)

func _on_player_died() -> void:
	# M2 hands over to the results screen; for now the run simply stops.
	set_physics_process(false)
	print("player died at %.1f s" % elapsed)
```

ถ้า `preload` ของ `.tres` พังตอน parse (เกิดได้ถ้า `--import` ยังไม่เคยรันหลังเพิ่ม schema)
ให้รัน `godot --headless --path . --import` หนึ่งครั้งแล้วลองใหม่ ห้ามเปลี่ยนไป hardcode ตัวเลข

- [x] **Step 2: เขียน `run/run.tscn`**

```
[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://run/run.gd" id="1_run"]
[ext_resource type="Script" path="res://run/enemy_system.gd" id="2_enemies"]
[ext_resource type="PackedScene" path="res://run/player.tscn" id="3_player"]
[ext_resource type="Script" path="res://run/spawn_director.gd" id="4_spawner"]
[ext_resource type="PackedScene" path="res://ui/debug_overlay.tscn" id="5_overlay"]

[node name="Run" type="Node2D"]
script = ExtResource("1_run")

[node name="Background" type="Polygon2D" parent="."]
color = Color(0.078, 0.051, 0.078, 1)
polygon = PackedVector2Array(-4000, -4000, 4000, -4000, 4000, 4000, -4000, 4000)

[node name="EnemySystem" type="MultiMeshInstance2D" parent="."]
modulate = Color(0.722, 0.306, 0.325, 1)
script = ExtResource("2_enemies")

[node name="Player" parent="." instance=ExtResource("3_player")]

[node name="SpawnDirector" type="Node" parent="."]
script = ExtResource("4_spawner")

[node name="DebugOverlay" parent="." instance=ExtResource("5_overlay")]
```

- [x] **Step 3: เขียน `main.gd` ใหม่เป็น state switcher**

```gdscript
extends Node2D

## Switches between the screens of the game. M1 only has RUN; Camp and Results
## arrive in M2, which is why this is a switcher and not a direct load.

enum Screen { RUN }

const RUN_SCENE := preload("res://run/run.tscn")

var _current: Node = null

func _ready() -> void:
	show_screen(Screen.RUN)

func show_screen(screen: Screen) -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	match screen:
		Screen.RUN:
			_current = RUN_SCENE.instantiate()
	add_child(_current)
```

- [x] **Step 4: เขียน `main.tscn` ใหม่ (ทิ้ง label ของ M0)**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://main.gd" id="1_main"]

[node name="Main" type="Node2D"]
script = ExtResource("1_main")
```

- [x] **Step 5: import แล้วรันเทสต์**

```bash
rm -f run/.gitkeep run/weapons/.gitkeep
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```
Expected: ไม่มี error ตอน import และเทสต์ผ่านทั้งหมด (`test_main_scene_is_set_and_loadable` ต้องยังผ่าน)

- [x] **Step 6: เปิดบนเดสก์ท็อปดูด้วยตา**

```bash
godot --path . --quit-after 600
```
Expected: เห็นสี่เหลี่ยมผู้เล่นอยู่กลางจอ มีศัตรูสีแดงค่อย ๆ เพิ่ม เดินเข้าหาผู้เล่น และ console ขึ้น `OpenGL API ... Compatibility`
ถ้ามองไม่เห็นศัตรูเลย ให้เช็ค `modulate` ของ `EnemySystem` และว่า `sync_multimesh()` ถูกเรียก

- [x] **Step 7: commit**

```bash
git add main.gd main.tscn run/run.gd run/run.tscn
git add -A run
git commit -m "Wire the run scene and turn main into a screen switcher"
```

---

### Task 14: เพิ่มกฎ copy-on-write ลง CLAUDE.md

> **สถานะ (M1-20):** ทำแล้ว ต่างจากข้อความตัวอย่างเล็กน้อย: เพิ่มทางเลือก getter ต่อ id (เช่น `position_of(id)`) ซึ่งเป็นวิธีที่ `EnemySystem` ใช้จริง

**Files:**
- Modify: `CLAUDE.md`

- [x] **Step 1: เพิ่มข้อนี้ใต้หัวข้อ "Performance" ใน `CLAUDE.md`**

```
- **ห้ามส่ง `Packed*Array` ออกจากระบบ** ให้รับ buffer เข้ามาเติมแล้วคืนจำนวนที่เติม (เช่น `query_radius(pos, r, out) -> int`)
  เพราะ array ใน GDScript เป็น copy-on-write ถ้ามีคนถือ reference ที่สองไว้แล้วเจ้าของเขียนทับ จะเกิดการ copy ทั้งก้อนเงียบ ๆ ทุกเฟรม
```

- [x] **Step 2: commit**

```bash
git add CLAUDE.md
git commit -m "Document the copy-on-write rule for packed arrays"
```

---

### Task 15: วัดบนเดสก์ท็อป

> **สถานะ (M1-15):** วัดแล้ว ผลอยู่ในตาราง performance ของ roadmap วัดด้วยสคริปต์ชั่วคราวนอกโปรเจกต์บนเครื่อง Ryzen 7 7800X3D + RTX 5070 ไม่ใช่ M3

**Files:**
- Modify: `docs/roadmap.md` (ตาราง performance)

- [x] **Step 1: รันแล้วอัดศัตรูให้เต็ม**

```bash
godot --path . --resolution 1280x720
```
กด F3 เปิด overlay แล้วกด F4 เพื่ออัดศัตรูให้เต็ม 400 ตัว เดินวนอยู่กลางฝูงประมาณ 15 วินาทีให้หน้าต่าง 600 เฟรมเต็ม
แล้วจดค่า avg, 1% low และ ms ของแต่ละขั้น

- [x] **Step 2: ถ้า avg ต่ำกว่า 200 บนเดสก์ท็อป ให้หยุดและรายงาน**

เดสก์ท็อปควรมี headroom มากกว่าเว็บหลายเท่า ถ้าเดสก์ท็อปยังช้า อย่าเสียเวลา export เว็บ
ให้ดู ms ต่อขั้นก่อนว่าขั้นไหนกิน แล้วรายงานตัวเลขออกมา

- [x] **Step 3: บันทึกผลลงตาราง performance ใน `docs/roadmap.md`**

เพิ่มแถว: วันที่ / M1 / `M3 / desktop` / 400 / avg / ms ต่อขั้น / หมายเหตุ

- [x] **Step 4: commit**

```bash
git add docs/roadmap.md
git commit -m "Record desktop performance numbers for 400 enemies"
```

---

### Task 16: วัดบนเว็บ — ตัดสิน gate

> **สถานะ (M1-15):** วัดบนเว็บแล้วด้วย Chromium 152 ของแอป Claude (Claude in Chrome ไม่ได้เชื่อมต่อ) ผ่านเกณฑ์ตัวเลขแต่ไม่ใช่เครื่อง gate จริง Step 5 ไม่ได้ใช้เพราะไม่มีการตกเกณฑ์ ยังไม่ปิด gate: ให้ยืนยันซ้ำบน M3 + Chrome ก่อนตัดสินใจ M1-16 และ M2

**Files:**
- Modify: `docs/roadmap.md` (ตาราง performance)

- [x] **Step 1: export แล้วเช็คว่า thread support ยังปิดอยู่**

```bash
godot --headless --path . --export-release "Web" build/web/index.html
ls build/web/
```
Expected: มี `index.html`, `index.js`, `index.pck`, `index.wasm` และ **ไม่มี** `index.worker.js`

- [x] **Step 2: เสิร์ฟแล้วเปิดใน Chrome**

```bash
python3 -m http.server 8000 -d build/web
```
เปิด http://localhost:8000 → กด F3 → กด F4 → เดินวนกลางฝูง 15 วินาที

- [x] **Step 3: อ่านค่าและเทียบเกณฑ์**

| ตัวชี้วัด | เกณฑ์ |
|---|---|
| avg FPS | ≥ 120 |
| 1% low | ≥ 90 |
| ศัตรู | 400 / 400 |

ตรวจ console ของเบราว์เซอร์ด้วย: ต้องไม่มี error และต้องมีบรรทัด `single-threaded, no GDExtension support`

- [x] **Step 4: บันทึกผลลงตาราง performance ใน `docs/roadmap.md`**

เพิ่มแถว: วันที่ / M1 / `M3 / Chrome (web)` / 400 / avg + 1% low / ms ต่อขั้น / ผ่านหรือไม่ผ่าน

- [ ] **Step 5: ถ้าไม่ผ่าน**

ทำตามลำดับในหัวข้อ 8 ของ spec แล้ววัดใหม่ บันทึกทุกครั้งที่วัด **ห้ามข้ามไป M2**

- [x] **Step 6: commit**

```bash
git add docs/roadmap.md
git commit -m "Record web performance numbers and the M1 gate result"
```

---

### Task 17: ปิด M1

> **สถานะ:** gate ผ่านบน M3 (ผู้ใช้ยืนยัน ไม่มีตัวเลข) M1-16 ไม่ต้องทำ Step 4 ยังไม่ทำ: ตาม CLAUDE.md ผู้ใช้เป็นคน merge PR เข้า `main` เอง (#1 → … → #20)

- [x] **Step 1: รันทุกอย่างอีกครั้งให้ครบ**

```bash
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```
Expected: import ไม่มี error, เทสต์ผ่านทั้งหมด

- [x] **Step 2: ติ๊ก ✅ ให้ sub-task ของ M1 ใน `docs/roadmap.md`**

- [x] **Step 3: commit แล้วจบ branch**

```bash
git add docs/roadmap.md
git commit -m "Mark M1 sub-tasks complete"
```

- [ ] **Step 4: ใช้ skill `superpowers:finishing-a-development-branch`**

ตรวจเทสต์ → ถามผู้ใช้ว่าจะ merge, เปิด PR, เก็บ branch ไว้ หรือทิ้ง
