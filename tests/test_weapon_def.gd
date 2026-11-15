extends GutTest

func _def_with_levels(n: int) -> WeaponDef:
	var d: WeaponDef = WeaponDef.new()
	for i in n:
		var lv: WeaponLevelDef = WeaponLevelDef.new()
		lv.damage = float(10 * (i + 1))
		d.levels.append(lv)
	return d


func test_max_level_is_the_number_of_rows() -> void:
	assert_eq(_def_with_levels(5).max_level(), 5)


func test_level_data_is_one_based() -> void:
	assert_eq(_def_with_levels(5).level_data(1).damage, 10.0)
	assert_eq(_def_with_levels(5).level_data(5).damage, 50.0)


func test_level_data_out_of_range_returns_null() -> void:
	var d: WeaponDef = _def_with_levels(5)
	assert_null(d.level_data(0))
	assert_push_error("out of range")
	assert_null(d.level_data(6))
	assert_push_error("out of range")
