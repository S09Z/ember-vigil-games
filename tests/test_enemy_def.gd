extends GutTest

## Every number here must match docs/design.md section 8. If this fails after a
## gameplay change, update design.md to match instead of editing the test.

func test_ghoul_matches_the_design_table() -> void:
	var def: EnemyDef = load("res://data/enemies/ghoul.tres")
	assert_not_null(def)
	assert_eq(def.id, &"ghoul")
	assert_eq(def.display_name, "Ghoul")
	assert_eq(def.hp, 10.0)
	assert_eq(def.move_speed, 45.0)
	assert_eq(def.contact_damage, 5.0)
	assert_eq(def.xp, 1)
	assert_eq(def.body_radius, 6.0)
