class_name LevelUpDeck
extends RefCounted

## Pure logic for drawing level-up cards. Reads the run state, never changes it.

const HELD_WEIGHT: float = 2.0
const NEW_WEIGHT: float = 1.0


## Allocates; called once per level-up, never per frame.
static func draw(
	state: RunState, class_def: ClassDef, fallbacks: Array[CardDef], rng: Rng, count: int = 3
) -> Array[LevelUpCard]:
	var pool: Array[WeaponDef] = []
	var weights: PackedFloat32Array = PackedFloat32Array()
	for def in class_def.class_weapons:
		var held: int = state.weapon_level(def.id)
		if held > 0:
			if held < def.max_level():
				pool.append(def)
				weights.append(HELD_WEIGHT)
		elif state.has_weapon_room():
			pool.append(def)
			weights.append(NEW_WEIGHT)

	var cards: Array[LevelUpCard] = []
	while cards.size() < count and not pool.is_empty():
		var i: int = rng.weighted_pick(weights)
		if i < 0:
			break
		var card: LevelUpCard = LevelUpCard.new()
		card.kind = LevelUpCard.Kind.WEAPON
		card.weapon = pool[i]
		card.new_level = state.weapon_level(pool[i].id) + 1
		cards.append(card)
		pool.remove_at(i)
		weights.remove_at(i)

	var f: int = 0
	while cards.size() < count and not fallbacks.is_empty():
		var card: LevelUpCard = LevelUpCard.new()
		card.kind = LevelUpCard.Kind.FALLBACK
		card.fallback = fallbacks[f % fallbacks.size()]
		cards.append(card)
		f += 1
	return cards
