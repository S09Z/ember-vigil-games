class_name ClassDef
extends Resource

## Everything that distinguishes one playable class. Values come from the table
## in docs/design.md section 4.

@export var id: StringName = &""
@export var display_name: String = ""
@export var max_hp: float = 100.0
@export var move_speed: float = 100.0
@export var armor: int = 0
@export var pickup_radius: float = 40.0
@export var body_radius: float = 7.0
@export var start_weapon: WeaponDef
@export var class_weapons: Array[WeaponDef] = []
@export var steel_lifesteal: float = 0.0
