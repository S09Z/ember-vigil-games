extends GutTest

const SCREEN_SCENE: PackedScene = preload("res://ui/pause_screen.tscn")

var _state: RunState
var _screen: PauseScreen


func before_each() -> void:
	_state = RunState.new()
	_screen = SCREEN_SCENE.instantiate() as PauseScreen
	add_child_autofree(_screen)


func _weapon(id: StringName) -> WeaponDef:
	var def: WeaponDef = WeaponDef.new()
	def.id = id
	def.tag = &"steel"
	for i in 3:
		def.levels.append(WeaponLevelDef.new())
	return def


func test_build_lines_list_each_weapon_with_its_level() -> void:
	_state.add_weapon(_weapon(&"greatsword")); _state.upgrade_weapon(&"greatsword")
	_state.add_weapon(_weapon(&"warhorn"))
	var lines: PackedStringArray = PauseScreen.build_lines(_state, {&"greatsword": "Greatsword", &"warhorn": "Warhorn"})
	assert_eq(lines, PackedStringArray(["Greatsword  LV2", "Warhorn  LV1"]))


func test_an_empty_build_says_so() -> void:
	assert_eq(PauseScreen.build_lines(_state, {}), PackedStringArray(["(empty)"]))


func test_an_unknown_id_falls_back_to_the_id() -> void:
	_state.add_weapon(_weapon(&"mystery"))
	assert_eq(PauseScreen.build_lines(_state, {})[0], "mystery  LV1")


func test_open_and_close() -> void:
	assert_false(_screen.is_open())
	_screen.show_build(PackedStringArray(["x"])); assert_true(_screen.is_open())
	_screen.hide_screen(); assert_false(_screen.is_open())
