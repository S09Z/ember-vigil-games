class_name EnemyDef
extends Resource

## One enemy kind. Values come from the table in docs/design.md section 8.

@export var id: StringName = &""
@export var display_name: String = ""
@export var hp: float = 10.0
@export var move_speed: float = 45.0
@export var contact_damage: float = 5.0
@export var xp: int = 1
@export var body_radius: float = 6.0
