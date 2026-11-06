class_name ShieldBash
extends WeaponBase

## Knight's weapon: a short, narrow shove in front of the player that damages,
## pushes back and stuns every enemy inside the cone. Fires on cooldown even
## when nothing is in range.

const ARC_COLOR: Color = Color(0.7, 0.85, 1.0, 0.8)
const ARC_LIFETIME: float = 0.15


func _fire(ctx: WeaponContext, lv: WeaponLevelDef) -> void:
	var origin: Vector2 = ctx.player_pos()
	var facing: Vector2 = ctx.facing()
	if ctx.fx != null:
		ctx.fx.add_arc(origin, facing, lv.arc_degrees, lv.range, ARC_COLOR, ARC_LIFETIME)
	var found: int = ctx.enemies.query_radius(origin, lv.range, ctx.hits)
	for i in found:
		var id: int = ctx.hits[i]
		var pos: Vector2 = ctx.enemies.position_of(id)
		if not WeaponBase.in_cone(origin, facing, lv.arc_degrees, lv.range, pos):
			continue
		var killed: bool = ctx.deal_damage(id, lv.damage, self)
		if not killed:
			ctx.enemies.knockback(id, pos - origin, lv.knockback)
			ctx.enemies.stun(id, lv.stun_seconds)
