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


## Uniform in angle and in radius. The ring is thin enough that weighting by
## area would not be visible, and design.md specifies a flat 380-420 band.
func point_in_ring(center: Vector2, radius_min: float, radius_max: float) -> Vector2:
	var angle: float = _rng.randf_range(0.0, TAU)
	var radius: float = _rng.randf_range(radius_min, radius_max)
	return center + Vector2(cos(angle), sin(angle)) * radius


## Index chosen with probability proportional to its weight. Zero (or negative)
## weights are never chosen. Returns -1 for an empty array or a total of 0.
func weighted_pick(weights: PackedFloat32Array) -> int:
	var total: float = 0.0
	for w in weights:
		if w > 0.0:
			total += w
	if total <= 0.0:
		return -1
	var roll: float = _rng.randf() * total
	var last_positive: int = -1
	for i in weights.size():
		if weights[i] <= 0.0:
			continue
		last_positive = i
		roll -= weights[i]
		if roll < 0.0:
			return i
	return last_positive
