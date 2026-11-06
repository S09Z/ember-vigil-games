class_name CountingWeapon
extends WeaponBase

## Test helper: counts how many times the weapon fired.

var fired: int = 0


func _fire(_ctx: WeaponContext, _lv: WeaponLevelDef) -> void:
	fired += 1
