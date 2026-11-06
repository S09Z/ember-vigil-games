extends GutTest


func test_hearth_bread_heals_thirty() -> void:
	var c: CardDef = load("res://data/cards/hearth_bread.tres")
	assert_eq(c.id, &"hearth_bread")
	assert_eq(c.heal_amount, 30.0)
	assert_eq(c.embers_bonus, 0)


func test_ember_purse_gives_five_embers() -> void:
	var c: CardDef = load("res://data/cards/ember_purse.tres")
	assert_eq(c.id, &"ember_purse")
	assert_eq(c.embers_bonus, 5)
	assert_eq(c.heal_amount, 0.0)


func test_every_fallback_has_a_display_name() -> void:
	for p in ["hearth_bread", "ember_purse"]:
		assert_ne((load("res://data/cards/%s.tres" % p) as CardDef).display_name, "")
