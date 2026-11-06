extends GutTest

var _s: StatBlock

func before_each() -> void:
	_s = StatBlock.new()

func test_the_multiplier_is_one_without_a_buff() -> void:
	assert_eq(_s.damage_multiplier(), 1.0)

func test_a_buff_raises_the_multiplier() -> void:
	_s.apply_damage_buff(15.0, 3.0)
	assert_almost_eq(_s.damage_multiplier(), 1.15, 0.0001)

func test_the_buff_expires_after_its_duration() -> void:
	_s.apply_damage_buff(15.0, 3.0)
	_s.tick(2.9)
	assert_almost_eq(_s.damage_multiplier(), 1.15, 0.0001)
	_s.tick(0.1)
	assert_eq(_s.damage_multiplier(), 1.0)

func test_recasting_refreshes_and_does_not_stack() -> void:
	_s.apply_damage_buff(15.0, 3.0)
	_s.tick(2.0)
	_s.apply_damage_buff(15.0, 3.0)
	assert_almost_eq(_s.damage_multiplier(), 1.15, 0.0001, "not 1.30")
	assert_almost_eq(_s.buff_time_left(), 3.0, 0.0001)

func test_a_stronger_recast_replaces_the_weaker_one() -> void:
	_s.apply_damage_buff(15.0, 3.0)
	_s.apply_damage_buff(25.0, 3.0)
	assert_almost_eq(_s.damage_multiplier(), 1.25, 0.0001)

func test_reset_clears_the_buff() -> void:
	_s.apply_damage_buff(15.0, 3.0); _s.reset()
	assert_eq(_s.damage_multiplier(), 1.0)
