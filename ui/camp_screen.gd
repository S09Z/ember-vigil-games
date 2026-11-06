class_name CampScreen
extends CanvasLayer
## Minimal camp: game title, Embers balance and a button to begin the night.
## Emits signals only; the shop and class choice arrive in M3/M4.

signal start_pressed()

@onready var _embers_label: Label = $Background/EmbersLabel
@onready var _start_button: Button = $Background/StartButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	set_embers(0)


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
	_embers_label.text = embers_text(total)


func embers_label_text() -> String:
	return _embers_label.text


func _on_start_pressed() -> void:
	start_pressed.emit()
