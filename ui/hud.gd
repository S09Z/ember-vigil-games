class_name HUD
extends CanvasLayer

## In-run HUD. Read-only: it listens to RunState / Player signals and never changes them.

@onready var _xp_bar: ProgressBar = $XpBar
@onready var _hp: Label = $Hp
@onready var _clock: Label = $Clock
@onready var _kills: Label = $Right/Kills
@onready var _embers: Label = $Right/Embers
@onready var _weapon_labels: Array[Label] = [
	$Slots/Weapons/W0, $Slots/Weapons/W1, $Slots/Weapons/W2, $Slots/Weapons/W3
]
@onready var _passive_labels: Array[Label] = [
	$Slots/Passives/P0, $Slots/Passives/P1, $Slots/Passives/P2, $Slots/Passives/P3
]

var _state: RunState = null
var _name_of: Dictionary = {}
var _shown_second: int = -1


static func format_time(seconds: float) -> String:
	var total: int = maxi(0, floori(seconds))
	return "%02d:%02d" % [total / 60, total % 60]


static func format_hp(hp: float, max_hp: float) -> String:
	var shown: int = 0
	if hp > 0.0:
		shown = maxi(1, ceili(hp))
	return "HP %d / %d" % [shown, ceili(max_hp)]


## name_of maps weapon id -> display name; ids missing from it are shown as-is.
func bind(state: RunState, player: Player, name_of: Dictionary = {}) -> void:
	_state = state
	_name_of = name_of
	state.xp_changed.connect(_on_xp_changed)
	state.kills_changed.connect(_on_kills_changed)
	state.build_changed.connect(_refresh_slots)
	player.health_changed.connect(_on_health_changed)
	_on_xp_changed(state.xp, state.xp_needed(state.level), state.level)
	_on_kills_changed(state.kills)
	_on_health_changed(player.hp, player.max_hp)
	_refresh_slots()


## Only touches the label when the displayed second changes.
func set_clock(seconds: float) -> void:
	var second: int = maxi(0, floori(seconds))
	if second == _shown_second:
		return
	_shown_second = second
	_clock.text = format_time(seconds)


func set_embers(total: int) -> void:
	_embers.text = "Embers %d" % total


func hp_text() -> String:
	return _hp.text


func kills_text() -> String:
	return _kills.text


func clock_text() -> String:
	return _clock.text


func embers_text() -> String:
	return _embers.text


func weapon_slot_text(index: int) -> String:
	return _weapon_labels[index].text


func xp_fraction() -> float:
	return float(_xp_bar.value / _xp_bar.max_value)


func _on_xp_changed(xp: int, needed: int, _level: int) -> void:
	_xp_bar.max_value = maxf(1.0, float(needed))
	_xp_bar.value = float(xp)


func _on_kills_changed(kills: int) -> void:
	_kills.text = str(kills)


func _on_health_changed(hp: float, max_hp: float) -> void:
	_hp.text = format_hp(hp, max_hp)


func _refresh_slots() -> void:
	var ids: Array[StringName] = _state.weapon_ids()
	for i in _weapon_labels.size():
		if i < ids.size():
			var id: StringName = ids[i]
			_weapon_labels[i].text = "%s %d" % [_name_of.get(id, String(id)), _state.weapon_level(id)]
		else:
			_weapon_labels[i].text = ""
	for label in _passive_labels:
		label.text = ""  # passives arrive after M2
