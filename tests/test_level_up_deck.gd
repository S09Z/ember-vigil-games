extends GutTest

var _state: RunState
var _class: ClassDef
var _a: WeaponDef
var _b: WeaponDef
var _c: WeaponDef
var _fallbacks: Array[CardDef]


func _weapon(id: StringName) -> WeaponDef:
	var def: WeaponDef = WeaponDef.new()
	def.id = id
	for i in 5:
		def.levels.append(WeaponLevelDef.new())
	return def


func before_each() -> void:
	_state = RunState.new()
	_state.setup(RunTuning.new())
	_a = _weapon(&"a")
	_b = _weapon(&"b")
	_c = _weapon(&"c")
	_class = ClassDef.new()
	_class.class_weapons = [_a, _b, _c] as Array[WeaponDef]
	var f1: CardDef = CardDef.new()
	f1.id = &"f1"
	var f2: CardDef = CardDef.new()
	f2.id = &"f2"
	_fallbacks = [f1, f2] as Array[CardDef]


## First card of a one-card draw that is for the given weapon, searching seeds.
func _first_card_for(def: WeaponDef) -> LevelUpCard:
	for s in 200:
		for c in LevelUpDeck.draw(_state, _class, _fallbacks, Rng.new(s)):
			if c.weapon == def:
				return c
	return null


func test_draws_three_distinct_cards() -> void:
	var cards: Array[LevelUpCard] = LevelUpDeck.draw(_state, _class, _fallbacks, Rng.new(3))
	assert_eq(cards.size(), 3)
	assert_ne(cards[0].weapon, cards[1].weapon)
	assert_ne(cards[1].weapon, cards[2].weapon)
	assert_ne(cards[0].weapon, cards[2].weapon)


func test_held_weapons_are_twice_as_likely() -> void:
	_state.add_weapon(_a)
	var a_first: int = 0
	for s in 600:
		var cards: Array[LevelUpCard] = LevelUpDeck.draw(_state, _class, _fallbacks, Rng.new(s), 1)
		if cards[0].weapon == _a:
			a_first += 1
	assert_between(float(a_first) / 600.0, 0.43, 0.57)


func test_a_held_weapon_card_is_an_upgrade_to_the_next_level() -> void:
	_state.add_weapon(_a)
	_state.upgrade_weapon(&"a")
	var card: LevelUpCard = _first_card_for(_a)
	assert_true(card.is_upgrade())
	assert_eq(card.new_level, 3)


func test_a_new_weapon_card_starts_at_level_one() -> void:
	var card: LevelUpCard = _first_card_for(_b)
	assert_false(card.is_upgrade())
	assert_eq(card.new_level, 1)


func test_a_maxed_weapon_is_never_offered() -> void:
	_state.add_weapon(_a)
	for i in 4:
		_state.upgrade_weapon(&"a")
	for s in 100:
		for c in LevelUpDeck.draw(_state, _class, _fallbacks, Rng.new(s)):
			assert_ne(c.weapon, _a)


func test_no_new_weapon_is_offered_when_slots_are_full() -> void:
	for n in ["w1", "w2", "w3", "w4"]:
		_state.add_weapon(_weapon(StringName(n)))
	for s in 50:
		for c in LevelUpDeck.draw(_state, _class, _fallbacks, Rng.new(s)):
			assert_eq(c.kind, LevelUpCard.Kind.FALLBACK, "slots are full and none of the class weapons is held")


func test_only_the_classes_own_weapons_are_offered() -> void:
	var foreign: WeaponDef = _weapon(&"foreign")
	for s in 50:
		for c in LevelUpDeck.draw(_state, _class, _fallbacks, Rng.new(s)):
			assert_ne(c.weapon, foreign)


func test_fallbacks_fill_the_hand_when_real_choices_run_out() -> void:
	_class.class_weapons = [_a] as Array[WeaponDef]
	var cards: Array[LevelUpCard] = LevelUpDeck.draw(_state, _class, _fallbacks, Rng.new(1))
	assert_eq(cards.size(), 3)
	assert_eq(cards[0].kind, LevelUpCard.Kind.WEAPON)
	assert_eq(cards[1].kind, LevelUpCard.Kind.FALLBACK)
	assert_eq(cards[2].kind, LevelUpCard.Kind.FALLBACK)
	assert_eq(cards[1].fallback, _fallbacks[0])
	assert_eq(cards[2].fallback, _fallbacks[1])


func test_fallbacks_cycle_when_there_are_fewer_than_needed() -> void:
	_class.class_weapons = [] as Array[WeaponDef]
	var one: Array[CardDef] = [_fallbacks[0]] as Array[CardDef]
	var cards: Array[LevelUpCard] = LevelUpDeck.draw(_state, _class, one, Rng.new(1))
	assert_eq(cards.size(), 3)
	for c in cards:
		assert_eq(c.fallback, one[0])


func test_with_nothing_but_fallbacks_the_hand_is_all_fallback() -> void:
	_class.class_weapons = [] as Array[WeaponDef]
	var cards: Array[LevelUpCard] = LevelUpDeck.draw(_state, _class, _fallbacks, Rng.new(1))
	assert_eq(cards.size(), 3)
	for c in cards:
		assert_eq(c.kind, LevelUpCard.Kind.FALLBACK)


func test_the_same_seed_gives_the_same_hand() -> void:
	var one: Array[LevelUpCard] = LevelUpDeck.draw(_state, _class, _fallbacks, Rng.new(9))
	var two: Array[LevelUpCard] = LevelUpDeck.draw(_state, _class, _fallbacks, Rng.new(9))
	for i in 3:
		assert_eq(one[i].weapon, two[i].weapon)


func test_drawing_does_not_change_the_run_state() -> void:
	_state.add_weapon(_a)
	LevelUpDeck.draw(_state, _class, _fallbacks, Rng.new(4))
	assert_eq(_state.weapon_count(), 1)
	assert_eq(_state.weapon_level(&"a"), 1)
	assert_eq(_state.weapon_level(&"b"), 0)
