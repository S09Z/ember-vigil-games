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
