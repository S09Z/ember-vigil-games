extends GutTest

## Every number here must match docs/design.md. If this test fails after a
## gameplay change, update design.md to match instead of editing the test.

func test_run_tuning_matches_the_design_numbers() -> void:
	var tuning: RunTuning = load("res://data/tuning/run_tuning.tres")
	assert_not_null(tuning)
	assert_eq(tuning.enemy_cap, 400)
	assert_eq(tuning.spawn_ring_min, 380.0)
	assert_eq(tuning.spawn_ring_max, 420.0)
	assert_eq(tuning.recycle_distance, 600.0)
	assert_eq(tuning.spawn_rate_base, 1.0)
	assert_eq(tuning.spawn_rate_time_divisor, 20.0)
	assert_eq(tuning.spawn_rate_cap, 12.0)
	assert_eq(tuning.hp_scale_divisor, 150.0)
	assert_eq(tuning.player_iframe_duration, 0.5)
	assert_eq(tuning.separation_strength, 60.0)
	assert_eq(tuning.grid_cell_size, 16.0)

func test_spawn_ring_is_ordered_and_inside_recycle_distance() -> void:
	var tuning: RunTuning = load("res://data/tuning/run_tuning.tres")
	assert_lt(tuning.spawn_ring_min, tuning.spawn_ring_max)
	assert_lt(tuning.spawn_ring_max, tuning.recycle_distance,
		"enemies spawned on the ring must not be recycled immediately")
