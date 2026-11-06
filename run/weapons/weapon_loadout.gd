class_name WeaponLoadout
extends RefCounted

## Owns the live weapon objects for the current build. sync() follows RunState;
## tick() runs every weapon.

## weapon id -> GDScript (a WeaponBase subclass). Unknown ids get a plain WeaponBase.
var factories: Dictionary = {}  ## later tasks add shield_bash, warhorn

var _weapons: Array[WeaponBase] = []
var _by_id: Dictionary = {}


func _init() -> void:
	factories[&"greatsword"] = Greatsword


## Call on build_changed. Creates missing weapons and aligns levels; never
## recreates an existing weapon, so cooldowns survive upgrades.
func sync(state: RunState, catalog: Dictionary) -> void:
	for id in state.weapon_ids():
		var weapon: WeaponBase = _by_id.get(id, null)
		if weapon == null:
			weapon = _create(id, catalog[id])
			_by_id[id] = weapon
			_weapons.append(weapon)
		weapon.level = state.weapon_level(id)


func tick(delta: float, ctx: WeaponContext) -> void:
	for weapon in _weapons:
		weapon.tick(delta, ctx)


func weapon_count() -> int:
	return _weapons.size()


func get_weapon(id: StringName) -> WeaponBase:
	return _by_id.get(id, null)


func _create(id: StringName, def: WeaponDef) -> WeaponBase:
	var script: GDScript = factories.get(id, null)
	var weapon: WeaponBase = script.new() if script != null else WeaponBase.new()
	weapon.setup(def)
	return weapon
