class_name StatBlock
extends RefCounted

## Small run-time stat modifiers. For now only a temporary damage buff; M3-1
## expands this with passives, tags and meta upgrades.

const EXPIRY_EPSILON: float = 0.000001

var _damage_buff_percent: float = 0.0
var _buff_time_left: float = 0.0


## Sets the buff, replacing any existing one (no stacking). percent is in
## percent units: 15.0 means +15% damage.
func apply_damage_buff(percent: float, seconds: float) -> void:
	_damage_buff_percent = percent
	_buff_time_left = seconds


func tick(delta: float) -> void:
	if _buff_time_left <= 0.0:
		return
	_buff_time_left -= delta
	if _buff_time_left <= EXPIRY_EPSILON:
		_buff_time_left = 0.0
		_damage_buff_percent = 0.0


func damage_multiplier() -> float:
	if _buff_time_left > 0.0:
		return 1.0 + _damage_buff_percent / 100.0
	return 1.0


func buff_time_left() -> float:
	return _buff_time_left


func reset() -> void:
	_damage_buff_percent = 0.0
	_buff_time_left = 0.0
