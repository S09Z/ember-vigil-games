extends GutTest

var _fx: FxLayer = null

func before_each() -> void:
	_fx = autofree(FxLayer.new())

func test_a_new_effect_is_active_then_expires() -> void:
	_fx.add_arc(Vector2.ZERO, Vector2.RIGHT, 140.0, 48.0, Color.WHITE, 0.2)
	assert_eq(_fx.active_count(), 1)
	_fx.tick(0.19); assert_eq(_fx.active_count(), 1)
	_fx.tick(0.02); assert_eq(_fx.active_count(), 0)

func test_arcs_and_rings_share_the_same_capacity() -> void:
	for i in 10: _fx.add_arc(Vector2.ZERO, Vector2.UP, 90.0, 40.0, Color.WHITE, 1.0)
	for i in 10: _fx.add_ring(Vector2.ZERO, 70.0, Color.WHITE, 1.0)
	assert_eq(_fx.active_count(), 20)

func test_a_full_layer_overwrites_the_oldest_instead_of_dropping_the_new_one() -> void:
	for i in FxLayer.CAPACITY:
		_fx.add_ring(Vector2(float(i), 0.0), 10.0, Color.WHITE, 10.0)
	_fx.add_ring(Vector2(999.0, 0.0), 10.0, Color.WHITE, 10.0)
	assert_eq(_fx.active_count(), FxLayer.CAPACITY, "never grows past capacity")
	assert_true(_fx.has_effect_at(Vector2(999.0, 0.0)), "the new one is kept")
	assert_false(_fx.has_effect_at(Vector2(0.0, 0.0)), "the oldest was replaced")
	_fx.add_ring(Vector2(998.0, 0.0), 10.0, Color.WHITE, 10.0)
	assert_false(_fx.has_effect_at(Vector2(1.0, 0.0)), "the next-oldest is replaced next")
	assert_true(_fx.has_effect_at(Vector2(2.0, 0.0)), "newer ones survive")
	assert_eq(_fx.active_count(), FxLayer.CAPACITY)

func test_clear_removes_everything() -> void:
	_fx.add_ring(Vector2.ZERO, 10.0, Color.WHITE, 1.0); _fx.clear()
	assert_eq(_fx.active_count(), 0)

func test_a_zero_facing_does_not_break_an_arc() -> void:
	_fx.add_arc(Vector2.ZERO, Vector2.ZERO, 90.0, 40.0, Color.WHITE, 0.1)
	_fx.tick(0.01)
	assert_eq(_fx.active_count(), 1)

func test_the_tick_that_expires_the_last_effect_still_requests_a_redraw() -> void:
	_fx.add_ring(Vector2.ZERO, 10.0, Color.WHITE, 0.1)
	_fx.tick(0.05)
	var before: int = _fx.redraw_requests()
	_fx.tick(0.1)
	assert_eq(_fx.active_count(), 0)
	assert_eq(_fx.redraw_requests(), before + 1, "redraw so the faded ghost is erased")
	_fx.tick(0.1)
	assert_eq(_fx.redraw_requests(), before + 1, "an idle layer does not redraw")
