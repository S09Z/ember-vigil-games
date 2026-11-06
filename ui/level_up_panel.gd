class_name LevelUpPanel
extends CanvasLayer

## Level-up screen: shows up to 3 cards, picked with keys 1/2/3 or a click.
## Only emits card_picked; it never edits any game system.

signal card_picked(index: int)

const MAX_CARDS: int = 3

var _open: bool = false
var _count: int = 0

@onready var _title: Label = $Dim/Title
@onready var _buttons: Array[Button] = [
	$Dim/Cards/Card1 as Button,
	$Dim/Cards/Card2 as Button,
	$Dim/Cards/Card3 as Button,
]


func _ready() -> void:
	visible = false
	for i in MAX_CARDS:
		_buttons[i].pressed.connect(_pick.bind(i))


static func card_title(card: LevelUpCard) -> String:
	if card.kind == LevelUpCard.Kind.FALLBACK:
		return card.fallback.display_name
	if card.is_upgrade():
		return "%s LV%d" % [card.weapon.display_name, card.new_level]
	return card.weapon.display_name


static func key_to_index(keycode: Key, count: int) -> int:
	var index: int = -1
	match keycode:
		KEY_1:
			index = 0
		KEY_2:
			index = 1
		KEY_3:
			index = 2
	if index >= count:
		return -1
	return index


static func card_subtitle(card: LevelUpCard) -> String:
	if card.kind == LevelUpCard.Kind.FALLBACK:
		return card.fallback.description
	if card.is_upgrade():
		return "LV%d -> LV%d  %s" % [card.new_level - 1, card.new_level, card.weapon.tag]
	return "NEW  %s" % card.weapon.tag


func show_cards(cards: Array[LevelUpCard], old_level: int, new_level: int) -> void:
	_title.text = "Level %d -> %d" % [old_level, new_level]
	_count = mini(cards.size(), MAX_CARDS)
	for i in MAX_CARDS:
		var button: Button = _buttons[i]
		button.visible = i < _count
		if i < _count:
			button.text = "[%d] %s\n%s" % [i + 1, card_title(cards[i]), card_subtitle(cards[i])]
	_open = true
	visible = true


func hide_panel() -> void:
	_open = false
	visible = false


func is_open() -> bool:
	return _open


func _pick(index: int) -> void:
	if not _open or index < 0 or index >= _count:
		return
	card_picked.emit(index)
	hide_panel()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var index: int = key_to_index(key.keycode, _count)
	if index >= 0:
		_pick(index)
		get_viewport().set_input_as_handled()
