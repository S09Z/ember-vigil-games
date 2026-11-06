extends GutTest

const SCREEN_SCENE: PackedScene = preload("res://ui/results_screen.tscn")

var _screen: ResultsScreen


func before_each() -> void:
	_screen = SCREEN_SCENE.instantiate() as ResultsScreen
	add_child_autofree(_screen)


func _make_summary() -> RunSummary:
	var s: RunSummary = RunSummary.new()
	s.survived_seconds = 125.7
	s.kills = 29
	s.level = 3
	s.damage_by_weapon = {&"greatsword": 1250.4}
	s.embers_from_kills = 2
	s.embers_from_time = 8
	s.embers_bonus = 5
	s.embers_total = 15
	return s


func _make_two_weapons() -> RunSummary:
	var s: RunSummary = _make_summary()
	s.damage_by_weapon = {&"b": 96.2, &"a": 1250.4}
	return s


func test_lines_report_time_kills_level() -> void:
	var lines: PackedStringArray = ResultsScreen.summary_lines(_make_summary(), {&"greatsword": "Greatsword"})
	assert_eq(lines[0], "Survived 02:05"); assert_eq(lines[1], "Kills 29"); assert_eq(lines[2], "Level 3")


func test_weapons_are_listed_by_damage_descending_with_thousands_separators() -> void:
	var lines: PackedStringArray = ResultsScreen.summary_lines(_make_two_weapons(), {&"a": "Greatsword", &"b": "Shield Bash"})
	assert_true(lines.has("Greatsword  1,250")); assert_true(lines.has("Shield Bash  96"))
	assert_lt(lines.find("Greatsword  1,250"), lines.find("Shield Bash  96"))


func test_a_weapon_without_a_name_shows_its_id() -> void:
	var lines: PackedStringArray = ResultsScreen.summary_lines(_make_summary(), {})
	assert_true(lines.has("greatsword  1,250"))


func test_embers_sources_are_listed_one_per_line() -> void:
	var lines: PackedStringArray = ResultsScreen.summary_lines(_make_summary(), {})
	assert_true(lines.has("Embers from kills +2")); assert_true(lines.has("Embers from time +8"))
	assert_true(lines.has("Embers from Ember Purse +5")); assert_true(lines.has("Embers total 15"))


func test_the_purse_line_is_hidden_when_zero() -> void:
	var s: RunSummary = _make_summary(); s.embers_bonus = 0; s.embers_total = 10
	for l in ResultsScreen.summary_lines(s, {}): assert_false(l.contains("Purse"))


func test_a_run_with_no_damage_or_kills_still_renders() -> void:
	var lines: PackedStringArray = ResultsScreen.summary_lines(RunSummary.new(), {})
	assert_true(lines.has("Kills 0")); assert_true(lines.has("Embers total 0"))


func test_equal_damage_is_ordered_by_id() -> void:
	var s: RunSummary = RunSummary.new()
	s.damage_by_weapon = {&"b": 10.0, &"a": 10.0}
	var lines: PackedStringArray = ResultsScreen.summary_lines(s, {})
	assert_lt(lines.find("a  10"), lines.find("b  10"))


func test_show_summary_shows_the_screen_and_fills_the_body() -> void:
	assert_false(_screen.visible)
	_screen.show_summary(_make_summary(), {})
	assert_true(_screen.visible)
	assert_true(_screen.get_node("Dim/Body").text.contains("Kills 29"))


func test_the_back_button_signal() -> void:
	watch_signals(_screen); _screen._on_back_pressed()
	assert_signal_emitted(_screen, "back_pressed")
