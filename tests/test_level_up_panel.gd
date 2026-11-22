extends GutTest

const PANEL_SCENE: PackedScene = preload("res://ui/level_up_panel.tscn")

var _panel: LevelUpPanel


func before_each() -> void:
	_panel = PANEL_SCENE.instantiate() as LevelUpPanel
	add_child_autofree(_panel)


func _weapon(display_name: String) -> WeaponDef:
	var def: WeaponDef = WeaponDef.new()
	def.display_name = display_name
	def.tag = &"steel"
	return def


func _new_weapon_card(display_name: String) -> LevelUpCard:
	var card: LevelUpCard = LevelUpCard.new()
	card.kind = LevelUpCard.Kind.WEAPON
	card.weapon = _weapon(display_name)
	card.new_level = 1
	return card


func _upgrade_card(display_name: String, new_level: int) -> LevelUpCard:
	var card: LevelUpCard = _new_weapon_card(display_name)
	card.new_level = new_level
	return card


func _fallback_card(display_name: String) -> LevelUpCard:
	var card: LevelUpCard = LevelUpCard.new()
	card.kind = LevelUpCard.Kind.FALLBACK
	card.fallback = CardDef.new()
	card.fallback.display_name = display_name
	card.fallback.description = "Heal 30"
	return card


func _three_cards() -> Array[LevelUpCard]:
	var cards: Array[LevelUpCard] = []
	cards.append(_new_weapon_card("Greatsword"))
	cards.append(_upgrade_card("Warhorn", 3))
	cards.append(_fallback_card("Hearth Bread"))
	return cards


func _key_event(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func test_card_titles() -> void:
	assert_eq(LevelUpPanel.card_title(_new_weapon_card("Greatsword")), "Greatsword")
	assert_eq(LevelUpPanel.card_title(_upgrade_card("Greatsword", 3)), "Greatsword LV3")
	assert_eq(LevelUpPanel.card_title(_fallback_card("Hearth Bread")), "Hearth Bread")


func test_number_keys_map_to_card_indices() -> void:
	assert_eq(LevelUpPanel.key_to_index(KEY_1, 3), 0)
	assert_eq(LevelUpPanel.key_to_index(KEY_3, 3), 2)


func test_a_key_for_a_missing_card_is_ignored() -> void:
	assert_eq(LevelUpPanel.key_to_index(KEY_3, 2), -1)
	assert_eq(LevelUpPanel.key_to_index(KEY_A, 3), -1)


func test_the_panel_is_closed_until_cards_are_shown() -> void:
	assert_false(_panel.is_open())
	_panel.show_cards(_three_cards(), 1, 2)
	assert_true(_panel.is_open())


func test_picking_emits_the_index_and_closes() -> void:
	_panel.show_cards(_three_cards(), 1, 2)
	watch_signals(_panel)
	_panel._pick(1)
	assert_signal_emitted_with_parameters(_panel, "card_picked", [1])
	assert_false(_panel.is_open())


func test_keys_do_nothing_while_closed() -> void:
	watch_signals(_panel)
	_panel._unhandled_input(_key_event(KEY_1))
	assert_signal_not_emitted(_panel, "card_picked")


func test_pressing_one_while_open_picks_the_first_card() -> void:
	_panel.show_cards(_three_cards(), 1, 2)
	watch_signals(_panel)
	_panel._unhandled_input(_key_event(KEY_1))
	assert_signal_emitted_with_parameters(_panel, "card_picked", [0])


func test_a_second_pick_while_closed_is_ignored() -> void:
	_panel.show_cards(_three_cards(), 1, 2)
	_panel._pick(0)
	watch_signals(_panel)
	_panel._pick(0)
	assert_signal_not_emitted(_panel, "card_picked")


func test_showing_the_next_queued_hand_reopens_the_panel() -> void:
	_panel.show_cards(_three_cards(), 1, 2)
	_panel._pick(0)
	_panel.show_cards(_three_cards(), 2, 3)
	assert_true(_panel.is_open())


func test_card_subtitles() -> void:
	assert_eq(LevelUpPanel.card_subtitle(_new_weapon_card("Greatsword")), "NEW  steel")
	assert_eq(LevelUpPanel.card_subtitle(_upgrade_card("Greatsword", 3)), "LV2 -> LV3  steel")
	assert_eq(LevelUpPanel.card_subtitle(_fallback_card("Hearth Bread")), "Heal 30")
