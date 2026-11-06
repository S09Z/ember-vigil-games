class_name LevelUpCard
extends RefCounted

## One option on the level-up panel: a weapon (new or upgrade) or a fallback card.

enum Kind { WEAPON, FALLBACK }

var kind: Kind = Kind.WEAPON
var weapon: WeaponDef = null
var new_level: int = 1  # level the weapon will be at after picking this card
var fallback: CardDef = null


func is_upgrade() -> bool:
	return kind == Kind.WEAPON and new_level > 1
