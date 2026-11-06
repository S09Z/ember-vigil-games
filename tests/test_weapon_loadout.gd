extends GutTest

var _state: RunState
var _loadout: WeaponLoadout
var _catalog: Dictionary

func _def(id: StringName) -> WeaponDef:
	var d: WeaponDef = WeaponDef.new()
	d.id = id
	var a: WeaponLevelDef = WeaponLevelDef.new()
	a.cooldown = 1.0
	var b: WeaponLevelDef = WeaponLevelDef.new()
	b.cooldown = 0.5
	var rows: Array[WeaponLevelDef] = [a, b]
	d.levels = rows
	_catalog[id] = d
	return d

func _counting_def(id: StringName) -> WeaponDef:
	return _def(id)

func before_each() -> void:
	_catalog = {}
	_state = RunState.new()
	_state.setup(RunTuning.new())
	_loadout = WeaponLoadout.new()

func test_sync_creates_a_weapon_for_each_one_in_the_build() -> void:
	_state.add_weapon(_def(&"a"))
	_loadout.sync(_state, _catalog)
	assert_eq(_loadout.weapon_count(), 1)

func test_sync_follows_upgrades_without_recreating_the_weapon() -> void:
	_state.add_weapon(_def(&"a"))
	_loadout.sync(_state, _catalog)
	var first: WeaponBase = _loadout.get_weapon(&"a")
	_state.upgrade_weapon(&"a")
	_loadout.sync(_state, _catalog)
	assert_same(_loadout.get_weapon(&"a"), first)
	assert_eq(first.level, 2)

func test_an_upgrade_does_not_reset_the_cooldown() -> void:
	_loadout.factories[&"counting"] = CountingWeapon
	_state.add_weapon(_counting_def(&"counting"))
	_loadout.sync(_state, _catalog)
	_loadout.tick(0.016, null)
	var w: CountingWeapon = _loadout.get_weapon(&"counting") as CountingWeapon
	_state.upgrade_weapon(&"counting")
	_loadout.sync(_state, _catalog)
	_loadout.tick(0.016, null)
	assert_eq(w.fired, 1, "the upgrade must not make it fire again at once")

func test_tick_runs_every_weapon() -> void:
	_loadout.factories[&"c1"] = CountingWeapon
	_loadout.factories[&"c2"] = CountingWeapon
	_state.add_weapon(_counting_def(&"c1"))
	_state.add_weapon(_counting_def(&"c2"))
	_loadout.sync(_state, _catalog)
	_loadout.tick(0.016, null)
	assert_eq((_loadout.get_weapon(&"c1") as CountingWeapon).fired, 1)
	assert_eq((_loadout.get_weapon(&"c2") as CountingWeapon).fired, 1)

func test_unknown_ids_get_a_harmless_default_weapon() -> void:
	_state.add_weapon(_def(&"mystery"))
	_loadout.sync(_state, _catalog)
	_loadout.tick(0.1, null)
	assert_eq(_loadout.weapon_count(), 1)

func test_get_weapon_returns_null_for_a_missing_id() -> void:
	assert_null(_loadout.get_weapon(&"nope"))
