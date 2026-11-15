class_name WeaponContext
extends RefCounted

## What a weapon needs to act on the world, bundled once per run.

var player: Player = null
var enemies: EnemySystem = null
var fx: FxLayer = null  ## null in tests
var state: RunState = null
var stats: StatBlock = null
var steel_lifesteal: float = 0.0
## Scratch buffer for EnemySystem.query_radius; sized to the enemy capacity.
var hits: PackedInt32Array = PackedInt32Array()


func setup(p_player: Player, p_enemies: EnemySystem, p_fx: FxLayer, p_state: RunState, p_stats: StatBlock, lifesteal: float) -> void:
	player = p_player
	enemies = p_enemies
	fx = p_fx
	state = p_state
	stats = p_stats
	steel_lifesteal = lifesteal
	hits.resize(p_enemies.capacity())


func player_pos() -> Vector2:
	return player.global_position


func facing() -> Vector2:
	return player.last_move_dir


## Applies the damage buff, hits the enemy and records the full final amount.
## STEEL weapons also heal the player by steel_lifesteal of that amount.
## Returns true if the enemy died. A dead or bad id records nothing.
func deal_damage(id: int, amount: float, weapon: WeaponBase) -> bool:
	if not enemies.is_alive(id):
		return false
	var final_amount: float = amount * stats.damage_multiplier()
	var killed: bool = enemies.damage(id, final_amount)
	state.record_damage(weapon.def.id, final_amount)
	if weapon.def.tag == &"steel":
		player.heal(final_amount * steel_lifesteal)
	return killed
