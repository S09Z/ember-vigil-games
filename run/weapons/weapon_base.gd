class_name WeaponBase
extends RefCounted

## Cooldown handling shared by every weapon. Subclasses override _fire().
## The cooldown is read from the weapon's current level at the moment it fires;
## leftover time is not carried over.

const EDGE_TOLERANCE: float = 0.0001

var def: WeaponDef = null
var level: int = 1

var _cooldown_left: float = 0.0


func setup(weapon_def: WeaponDef) -> void:
	def = weapon_def
	level = 1
	_cooldown_left = 0.0


func tick(delta: float, ctx: WeaponContext) -> void:
	_cooldown_left -= delta
	if _cooldown_left > 0.0:
		return
	var lv: WeaponLevelDef = current()
	if lv == null:
		return
	_fire(ctx, lv)
	_cooldown_left = lv.cooldown


## Virtual: apply the weapon's effect for one shot.
func _fire(_ctx: WeaponContext, _lv: WeaponLevelDef) -> void:
	pass


func current() -> WeaponLevelDef:
	return def.level_data(level)


## True when `point` is within `range` of `origin` and within half of
## `arc_degrees` of `facing`. The exact edge counts as inside; a point on the
## origin is inside; a zero `facing` is never inside.
static func in_cone(origin: Vector2, facing: Vector2, arc_degrees: float, range: float, point: Vector2) -> bool:
	if facing.length_squared() == 0.0:
		return false
	var offset: Vector2 = point - origin
	if offset.length_squared() > range * range:
		return false
	if offset.length_squared() == 0.0:
		return true
	return absf(facing.angle_to(offset)) <= deg_to_rad(arc_degrees) * 0.5 + EDGE_TOLERANCE
