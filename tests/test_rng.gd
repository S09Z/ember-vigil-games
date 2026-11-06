extends GutTest

func test_same_seed_gives_the_same_sequence() -> void:
	var a: Rng = Rng.new(1234)
	var b: Rng = Rng.new(1234)
	for i in 10:
		assert_eq(a.randf(), b.randf())

func test_different_seeds_diverge() -> void:
	var a: Rng = Rng.new(1)
	var b: Rng = Rng.new(2)
	var same: int = 0
	for i in 10:
		if a.randf() == b.randf():
			same += 1
	assert_lt(same, 10, "two different seeds must not produce an identical run")

func test_set_seed_restarts_the_sequence() -> void:
	var r: Rng = Rng.new(99)
	var first: float = r.randf()
	r.randf()
	r.set_seed(99)
	assert_eq(r.randf(), first)

func test_point_in_ring_respects_both_radii() -> void:
	var r: Rng = Rng.new(5)
	var center: Vector2 = Vector2(100.0, -50.0)
	for i in 200:
		var d: float = r.point_in_ring(center, 380.0, 420.0).distance_to(center)
		assert_between(d, 380.0, 420.0)

func test_point_in_ring_covers_every_direction() -> void:
	var r: Rng = Rng.new(8)
	var quadrants: Dictionary = {}
	for i in 200:
		var offset: Vector2 = r.point_in_ring(Vector2.ZERO, 380.0, 420.0)
		quadrants[Vector2(signf(offset.x), signf(offset.y))] = true
	assert_eq(quadrants.size(), 4, "enemies must be able to spawn on every side of the player")

func test_randi_range_is_inclusive_and_bounded() -> void:
	var r: Rng = Rng.new(11)
	for i in 100:
		assert_between(r.randi_range(3, 5), 3, 5)

func test_randf_range_stays_in_bounds() -> void:
	var r: Rng = Rng.new(13)
	for i in 100:
		assert_between(r.randf_range(-2.5, 7.5), -2.5, 7.5)

func test_weighted_pick_never_chooses_a_zero_weight() -> void:
	var r: Rng = Rng.new(1)
	for i in 200:
		assert_ne(r.weighted_pick(PackedFloat32Array([0.0, 1.0, 0.0])), 0)
		assert_ne(r.weighted_pick(PackedFloat32Array([0.0, 1.0, 0.0])), 2)

func test_weighted_pick_follows_the_weights() -> void:
	var r: Rng = Rng.new(1)
	var counts: Array[int] = [0, 0]
	for i in 3000:
		counts[r.weighted_pick(PackedFloat32Array([1.0, 2.0]))] += 1
	assert_between(float(counts[1]) / float(counts[0]), 1.7, 2.3)

func test_weighted_pick_degenerate_inputs_return_minus_one() -> void:
	var r: Rng = Rng.new(1)
	assert_eq(r.weighted_pick(PackedFloat32Array()), -1)
	assert_eq(r.weighted_pick(PackedFloat32Array([0.0, 0.0])), -1)
