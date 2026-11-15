extends Node2D

## Switches between the screens of the game. M1 only has RUN; Camp and Results
## arrive in M2, which is why this is a switcher and not a direct load.

enum Screen { RUN }

const RUN_SCENE: PackedScene = preload("res://run/run.tscn")

var _current: Node = null


func _ready() -> void:
	show_screen(Screen.RUN)


func show_screen(screen: Screen) -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	match screen:
		Screen.RUN:
			_current = RUN_SCENE.instantiate()
	add_child(_current)


func current_screen() -> Node:
	return _current
