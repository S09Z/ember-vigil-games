class_name PauseScreen
extends CanvasLayer

## Pause screen: lists the current build, one line per entry.
## It reads nothing by itself and takes no input; Run toggles it from the pause action.

var _open: bool = false

@onready var _body: Label = $Dim/Body


func _ready() -> void:
	visible = _open


## One line per weapon in the order added, "Name  LVn"; "(empty)" when none.
## Pure: call on opening the screen, not per frame.
static func build_lines(state: RunState, name_of: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for id in state.weapon_ids():
		var shown: String = str(name_of.get(id, id))
		lines.append("%s  LV%d" % [shown, state.weapon_level(id)])
	if lines.is_empty():
		lines.append("(empty)")
	return lines


func show_build(lines: PackedStringArray) -> void:
	_body.text = "\n".join(lines)
	_open = true
	visible = true


func hide_screen() -> void:
	_open = false
	visible = false


func is_open() -> bool:
	return _open
