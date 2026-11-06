class_name WeaponLevelDef
extends Resource

## One row of a weapon's level table (docs/design.md section 5). Fields a
## weapon does not use stay 0.

@export var cooldown: float = 0.0
@export var damage: float = 0.0
@export var arc_degrees: float = 0.0
@export var range: float = 0.0
@export var radius: float = 0.0
@export var knockback: float = 0.0
@export var stun_seconds: float = 0.0
@export var both_sides: bool = false
@export var buff_percent: float = 0.0
@export var buff_seconds: float = 0.0
@export var heal: float = 0.0
