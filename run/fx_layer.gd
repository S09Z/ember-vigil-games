class_name FxLayer
extends Node2D

## Short-lived weapon visuals (melee arcs, expanding rings) drawn by one node.
##
## There is no node per effect: all of them live in fixed-size arrays allocated
## once, and _draw() walks them. When every slot is busy a new effect replaces
## the oldest one instead of being dropped.

const CAPACITY: int = 32
const KIND_ARC: int = 0
const KIND_RING: int = 1
const ARC_POINTS: int = 20
const RING_POINTS: int = 32
const LINE_WIDTH: float = 3.0
## Used when an arc is added with a zero facing vector
const DEFAULT_FACING: Vector2 = Vector2.RIGHT

var _active: PackedByteArray = PackedByteArray()
var _kind: PackedByteArray = PackedByteArray()
var _origin: PackedVector2Array = PackedVector2Array()
## Arc: facing angle in radians. Unused for rings.
var _angle: PackedFloat32Array = PackedFloat32Array()
## Arc: full opening in radians. Unused for rings.
var _span: PackedFloat32Array = PackedFloat32Array()
## Arc: reach in px. Ring: radius in px.
var _size: PackedFloat32Array = PackedFloat32Array()
var _color: PackedColorArray = PackedColorArray()
var _age: PackedFloat32Array = PackedFloat32Array()
var _life: PackedFloat32Array = PackedFloat32Array()
## Birth order, so the oldest effect can be found when the layer is full
var _seq: PackedInt32Array = PackedInt32Array()
var _next_seq: int = 0
var _active_count: int = 0

func _init() -> void:
	_active.resize(CAPACITY)
	_kind.resize(CAPACITY)
	_origin.resize(CAPACITY)
	_angle.resize(CAPACITY)
	_span.resize(CAPACITY)
	_size.resize(CAPACITY)
	_color.resize(CAPACITY)
	_age.resize(CAPACITY)
	_life.resize(CAPACITY)
	_seq.resize(CAPACITY)

func add_arc(origin: Vector2, facing: Vector2, arc_degrees: float, range: float, color: Color, lifetime: float) -> void:
	var dir: Vector2 = facing if facing.length_squared() > 0.0001 else DEFAULT_FACING
	var slot: int = _take_slot()
	_kind[slot] = KIND_ARC
	_angle[slot] = dir.angle()
	_span[slot] = deg_to_rad(arc_degrees)
	_fill(slot, origin, range, color, lifetime)

func add_ring(origin: Vector2, radius: float, color: Color, lifetime: float) -> void:
	var slot: int = _take_slot()
	_kind[slot] = KIND_RING
	_fill(slot, origin, radius, color, lifetime)

## Ages every effect, frees the expired ones and requests a redraw while any remain.
func tick(delta: float) -> void:
	for i in CAPACITY:
		if _active[i] == 0:
			continue
		_age[i] += delta
		if _age[i] >= _life[i]:
			_active[i] = 0
			_active_count -= 1
	if _active_count > 0:
		queue_redraw()

func active_count() -> int:
	return _active_count

## State check used by tests: is an active effect centred on this origin?
func has_effect_at(origin: Vector2) -> bool:
	for i in CAPACITY:
		if _active[i] != 0 and _origin[i] == origin:
			return true
	return false

func clear() -> void:
	for i in CAPACITY:
		_active[i] = 0
	_active_count = 0
	queue_redraw()

func _draw() -> void:
	for i in CAPACITY:
		if _active[i] == 0:
			continue
		var t: float = clampf(_age[i] / _life[i], 0.0, 1.0)
		var col: Color = _color[i]
		col.a *= 1.0 - t
		if _kind[i] == KIND_ARC:
			var half: float = _span[i] * 0.5
			draw_arc(_origin[i], _size[i], _angle[i] - half, _angle[i] + half, ARC_POINTS, col, LINE_WIDTH)
		else:
			draw_arc(_origin[i], _size[i] * (0.5 + 0.5 * t), 0.0, TAU, RING_POINTS, col, LINE_WIDTH)

func _fill(slot: int, origin: Vector2, size: float, color: Color, lifetime: float) -> void:
	_origin[slot] = origin
	_size[slot] = size
	_color[slot] = color
	_age[slot] = 0.0
	_life[slot] = maxf(lifetime, 0.001)
	_seq[slot] = _next_seq
	_next_seq += 1
	_active[slot] = 1

## A free slot, or the slot of the oldest effect when none is free.
func _take_slot() -> int:
	var oldest: int = 0
	for i in CAPACITY:
		if _active[i] == 0:
			_active_count += 1
			return i
		if _seq[i] < _seq[oldest]:
			oldest = i
	return oldest
