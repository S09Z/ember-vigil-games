class_name RunState
extends RefCounted

## Data for one run: clock, kills, level and the weapon build.
## Systems change it through its methods; UI only listens to its signals.

signal kills_changed(kills: int)
signal build_changed()

const WEAPON_SLOTS: int = 4
const PASSIVE_SLOTS: int = 4

var elapsed: float = 0.0
var kills: int = 0
var level: int = 1
var xp: int = 0

var _tuning: RunTuning = null
var _weapon_levels: Dictionary = {}  # StringName id -> int level
var _weapon_defs: Array[WeaponDef] = []  # in the order added


func setup(tuning: RunTuning) -> void:
	_tuning = tuning
	elapsed = 0.0
	kills = 0
	level = 1
	xp = 0
	_weapon_levels.clear()
	_weapon_defs.clear()


func tick(delta: float) -> void:
	elapsed += delta


func add_kill() -> void:
	kills += 1
	kills_changed.emit(kills)


func add_weapon(def: WeaponDef) -> bool:
	if not has_weapon_room() or _weapon_levels.has(def.id):
		return false
	_weapon_levels[def.id] = 1
	_weapon_defs.append(def)
	build_changed.emit()
	return true


func upgrade_weapon(id: StringName) -> bool:
	if not _weapon_levels.has(id):
		return false
	var def: WeaponDef = _find_weapon(id)
	var current: int = _weapon_levels[id]
	if current >= def.max_level():
		return false
	_weapon_levels[id] = current + 1
	build_changed.emit()
	return true


func weapon_level(id: StringName) -> int:
	return _weapon_levels.get(id, 0)


func weapon_count() -> int:
	return _weapon_defs.size()


func has_weapon_room() -> bool:
	return _weapon_defs.size() < WEAPON_SLOTS


## Allocates; call on build changes only, never per frame.
func weapon_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for def in _weapon_defs:
		ids.append(def.id)
	return ids


func _find_weapon(id: StringName) -> WeaponDef:
	for def in _weapon_defs:
		if def.id == id:
			return def
	return null
