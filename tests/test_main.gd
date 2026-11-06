extends GutTest

const MAIN_SCENE: PackedScene = preload("res://main.tscn")

var _main: Node = null


func before_each() -> void:
	_main = MAIN_SCENE.instantiate()
	add_child_autofree(_main)


func _start_run() -> Run:
	_main.current_screen().start_pressed.emit()
	return _main.current_screen() as Run


func _die_once_with_embers(_n: int) -> void:
	var run: Run = _start_run()
	run.run_state().tick(60.0)  # 4 embers from time
	(run.get_node("Player") as Player).take_damage(100000.0)


func _go_back() -> void:
	_main.current_screen().back_pressed.emit()


func _go_back_noop() -> void:
	_main.show_screen(_main.Screen.CAMP)


func test_main_starts_on_the_camp_screen() -> void:
	assert_true(_main.current_screen() is CampScreen)


func test_pressing_start_enters_a_fresh_run() -> void:
	var run: Run = _start_run()
	assert_true(run is Run)
	assert_eq(run.state, Run.State.RUNNING)


func test_death_goes_to_results_and_banks_the_embers() -> void:
	_die_once_with_embers(4)
	assert_true(_main.current_screen() is ResultsScreen)
	assert_eq(_main.embers_total, 4)


func test_back_from_results_returns_to_camp_showing_the_total() -> void:
	_die_once_with_embers(4)
	_go_back()
	assert_true(_main.current_screen() is CampScreen)
	assert_eq((_main.current_screen() as CampScreen).embers_label_text(), "Embers 4")


func test_embers_add_up_over_several_runs() -> void:
	_die_once_with_embers(4)
	_go_back()
	_die_once_with_embers(4)
	assert_eq(_main.embers_total, 8)


func test_the_old_screen_is_freed_on_every_switch() -> void:
	var camp: Node = _main.current_screen()
	camp.start_pressed.emit()
	assert_true(camp.is_queued_for_deletion())
	var run: Node = _main.current_screen()
	(run.get_node("Player") as Player).take_damage(100000.0)
	assert_true(run.is_queued_for_deletion())
	var results: Node = _main.current_screen()
	results.back_pressed.emit()
	assert_true(results.is_queued_for_deletion())


func test_a_second_and_third_run_start_clean() -> void:
	for round in 3:
		var run: Run = _start_run()
		assert_eq(run.elapsed, 0.0)
		assert_eq(run.run_state().level, 1)
		assert_eq(run.run_state().kills, 0)
		assert_eq(run.run_state().weapon_count(), 1)
		assert_eq((run.get_node("EnemySystem") as EnemySystem).alive_count(), 0)
		assert_almost_eq(run.stats().damage_multiplier(), 1.0, 0.0001)
		(run.get_node("Player") as Player).take_damage(100000.0)
		_go_back()


func test_embers_are_not_changed_by_showing_camp_again() -> void:
	_die_once_with_embers(4)
	_go_back()
	_go_back_noop()
	assert_eq(_main.embers_total, 4)
