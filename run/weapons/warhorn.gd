class_name Warhorn
extends WeaponBase

## Knight's holy weapon: a blast that pushes every enemy in a ring away from the
## player and buffs all player weapons' damage for a few seconds. Deals no damage
## itself. Re-casting refreshes the buff (StatBlock never stacks it). Level 5
## also heals the player.

const RING_COLOR: Color = Color(1.0, 0.85, 0.4, 0.6)
const RING_LIFETIME: float = 0.3


func _fire(ctx: WeaponContext, lv: WeaponLevelDef) -> void:
	var origin: Vector2 = ctx.player_pos()
	if ctx.fx != null:
		ctx.fx.add_ring(origin, lv.radius, RING_COLOR, RING_LIFETIME)
	var found: int = ctx.enemies.query_radius(origin, lv.radius, ctx.hits)
	for i in found:
		var id: int = ctx.hits[i]
		ctx.enemies.knockback(id, ctx.enemies.position_of(id) - origin, lv.knockback)
	ctx.stats.apply_damage_buff(lv.buff_percent, lv.buff_seconds)
	if lv.heal > 0.0:
		ctx.player.heal(lv.heal)
