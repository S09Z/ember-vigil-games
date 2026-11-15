class_name WeaponDef
extends Resource

## A weapon and its per-level numbers. class_id == &"" means a shared weapon.

@export var id: StringName = &""
@export var display_name: String = ""
@export var tag: StringName = &"steel"
@export var class_id: StringName = &""
@export var levels: Array[WeaponLevelDef] = []


## Level is 1-based. Out-of-range returns null.
func level_data(level: int) -> WeaponLevelDef:
	if level < 1 or level > levels.size():
		push_error("WeaponDef %s: level %d out of range 1..%d" % [id, level, levels.size()])
		return null
	return levels[level - 1]


func max_level() -> int:
	return levels.size()
