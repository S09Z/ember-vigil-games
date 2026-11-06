class_name ResultsScreen
extends CanvasLayer

## End-of-run results. Pure display: builds lines from a RunSummary and emits back_pressed.

signal back_pressed()

@onready var _body: Label = $Dim/Body
@onready var _button: Button = $Dim/BackButton


func _ready() -> void:
	_button.pressed.connect(_on_back_pressed)


func show_summary(summary: RunSummary, name_of: Dictionary) -> void:
	_body.text = "\n".join(summary_lines(summary, name_of))
	visible = true
	_button.grab_focus()


func _on_back_pressed() -> void:
	back_pressed.emit()


static func summary_lines(summary: RunSummary, name_of: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var secs: int = floori(summary.survived_seconds)
	lines.append("Survived %02d:%02d" % [secs / 60, secs % 60])
	lines.append("Kills %d" % summary.kills)
	lines.append("Level %d" % summary.level)
	var ids: Array = summary.damage_by_weapon.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var da: float = summary.damage_by_weapon[a]
		var db: float = summary.damage_by_weapon[b]
		if da != db:
			return da > db
		return str(a) < str(b))
	for id in ids:
		lines.append("%s  %s" % [str(name_of.get(id, id)), _thousands(roundi(summary.damage_by_weapon[id]))])
	lines.append("Embers from kills +%d" % summary.embers_from_kills)
	lines.append("Embers from time +%d" % summary.embers_from_time)
	if summary.embers_bonus > 0:
		lines.append("Embers from Ember Purse +%d" % summary.embers_bonus)
	lines.append("Embers total %d" % summary.embers_total)
	return lines


static func _thousands(n: int) -> String:
	var digits: String = str(absi(n))
	var out: String = ""
	var count: int = 0
	for i in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = digits[i] + out
		count += 1
	return ("-" if n < 0 else "") + out
