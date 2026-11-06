class_name Greatsword
extends WeaponBase

## Knight's weapon: a wide swing in front of the player that damages and pushes
## back every enemy inside the arc. Fires even when nothing is in range.

const ARC_COLOR: Color = Color(0.85, 0.9, 1.0, 0.7)
const ARC_LIFETIME: float = 0.12


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
