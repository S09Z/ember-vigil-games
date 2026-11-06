class_name CampScreen
extends CanvasLayer
## Minimal camp: game title, Embers balance and a button to begin the night.
## Emits signals only; the shop and class choice arrive in M3/M4.

signal start_pressed()

var _embers: int = 0

@onready var _embers_label: Label = $Background/EmbersLabel
@onready var _start_button: Button = $Background/StartButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_start_button.grab_focus.call_deferred()
	_refresh()


static func embers_text(total: int) -> String:
	var digits: String = str(maxi(total, 0))
	var out: String = ""
	var count: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = digits[i] + out
		count += 1
	return "Embers " + out


func set_embers(total: int) -> void:
	_embers = total
	if is_node_ready():
		_refresh()


func embers_label_text() -> String:
	if not is_node_ready():
		return embers_text(_embers)
	return _embers_label.text


func _refresh() -> void:
	_embers_label.text = embers_text(_embers)


func _on_start_pressed() -> void:
	start_pressed.emit()
