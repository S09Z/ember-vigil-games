extends GutTest

const CAMP_SCENE: PackedScene = preload("res://ui/camp_screen.tscn")

var _camp: CampScreen


func before_each() -> void:
	_camp = CAMP_SCENE.instantiate() as CampScreen
	add_child_autofree(_camp)


func test_embers_text() -> void:
	assert_eq(CampScreen.embers_text(0), "Embers 0")
	assert_eq(CampScreen.embers_text(1234), "Embers 1,234")


func test_set_embers_updates_the_label() -> void:
	_camp.set_embers(15)
	assert_eq(_camp.embers_label_text(), "Embers 15")


func test_pressing_start_emits_once_per_press() -> void:
	watch_signals(_camp)
	_camp._on_start_pressed()
	_camp._on_start_pressed()
	assert_signal_emit_count(_camp, "start_pressed", 2)


func test_negative_embers_are_clamped_to_zero() -> void:
	assert_eq(CampScreen.embers_text(-5), "Embers 0")
