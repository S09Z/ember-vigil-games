extends GutTest

const MAIN_SCENE: PackedScene = preload("res://main.tscn")

func test_main_starts_on_the_run_screen() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	assert_true(main.current_screen() is Run)

func test_showing_a_screen_again_replaces_the_old_one() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	var first: Node = main.current_screen()
	main.show_screen(main.Screen.RUN)
	assert_ne(main.current_screen(), first)
	assert_true(first.is_queued_for_deletion())
