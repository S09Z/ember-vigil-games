extends GutTest

## Every number here must match docs/design.md section 4. If this fails after a
## gameplay change, update design.md to match instead of editing the test.

func test_knight_matches_the_design_table() -> void:
	var def: ClassDef = load("res://data/classes/knight.tres")
	assert_not_null(def)
	assert_eq(def.id, &"knight")
	assert_eq(def.display_name, "Knight")
	assert_eq(def.max_hp, 140.0)
	assert_eq(def.move_speed, 95.0)
	assert_eq(def.armor, 2)
	assert_eq(def.pickup_radius, 40.0)
	assert_eq(def.body_radius, 7.0)


func test_class_def_has_weapon_fields() -> void:
	var def: ClassDef = ClassDef.new()
	assert_null(def.start_weapon)
	assert_eq(def.class_weapons.size(), 0)
	assert_eq(def.steel_lifesteal, 0.0)
