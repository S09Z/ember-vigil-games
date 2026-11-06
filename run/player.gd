class_name Player
extends CharacterBody2D

## The only physics body in the game. Enemies are plain data in EnemySystem and
## their contacts are resolved there, so this node only has to move.
##
## run.gd drives it: there is no _physics_process here, so the update order of
## the whole run stays visible in one place and tests can step it by hand.
## Damage, armor and invulnerability are added in M1-7.

var max_hp: float = 100.0
var hp: float = 100.0
var armor: int = 0
var move_speed: float = 100.0
var pickup_radius: float = 40.0
var body_radius: float = 7.0

## Direction of the last non-zero input. Melee weapons in M2 swing along it.
var last_move_dir: Vector2 = Vector2.RIGHT


static func input_to_direction(raw: Vector2) -> Vector2:
	if raw.length_squared() <= 0.0:
		return Vector2.ZERO
	return raw.normalized()


func setup(def: ClassDef) -> void:
	max_hp = def.max_hp
	hp = def.max_hp
	armor = def.armor
	move_speed = def.move_speed
	pickup_radius = def.pickup_radius
	body_radius = def.body_radius


func tick(_delta: float) -> void:
	apply_input(Input.get_vector("move_left", "move_right", "move_up", "move_down"))
	move_and_slide()


## Turns a raw input vector into velocity and remembers the facing. Split out
## from tick() so tests can drive it without real input or a SceneTree.
func apply_input(raw: Vector2) -> void:
	var dir: Vector2 = input_to_direction(raw)
	if dir != Vector2.ZERO:
		last_move_dir = dir
	velocity = dir * move_speed
