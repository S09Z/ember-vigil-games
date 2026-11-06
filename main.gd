extends Node2D

## Switches between the screens of the game: Camp -> Run -> Results -> Camp.
## Each switch frees the old screen and builds a new one, so nothing from a
## previous run can leak into the next.

enum Screen { CAMP, RUN, RESULTS }

const CAMP_SCENE: PackedScene = preload("res://ui/camp_screen.tscn")
const RUN_SCENE: PackedScene = preload("res://run/run.tscn")
const RESULTS_SCENE: PackedScene = preload("res://ui/results_screen.tscn")

## Embers banked across runs. Memory only; M4 persists it.
var embers_total: int = 0

var _current: Node = null


func _ready() -> void:
	show_screen(Screen.CAMP)


func show_screen(screen: Screen) -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	match screen:
		Screen.CAMP:
			var camp: CampScreen = CAMP_SCENE.instantiate()
			camp.set_embers(embers_total)
			camp.start_pressed.connect(_on_start_pressed, CONNECT_ONE_SHOT)
			_current = camp
		Screen.RUN:
			var run: Run = RUN_SCENE.instantiate()
			run.run_ended.connect(_on_run_ended, CONNECT_ONE_SHOT)
			_current = run
		Screen.RESULTS:
			var results: ResultsScreen = RESULTS_SCENE.instantiate()
			results.back_pressed.connect(_on_back_pressed, CONNECT_ONE_SHOT)
			_current = results
	add_child(_current)


func current_screen() -> Node:
	return _current


func _on_start_pressed() -> void:
	show_screen(Screen.RUN)


func _on_run_ended(summary: RunSummary) -> void:
	embers_total += summary.embers_total
	show_screen(Screen.RESULTS)
	var name_of: Dictionary = {}
	for def in Run.KNIGHT.class_weapons:
		name_of[def.id] = def.display_name
	(_current as ResultsScreen).show_summary(summary, name_of)  # after add_child: @onready labels


func _on_back_pressed() -> void:
	show_screen(Screen.CAMP)
