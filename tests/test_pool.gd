extends GutTest

func test_acquire_hands_out_slots_in_order() -> void:
	var p: Pool = Pool.new(3)
	assert_eq(p.acquire(), 0)
	assert_eq(p.acquire(), 1)
	assert_eq(p.acquire(), 2)

func test_acquire_returns_minus_one_when_full() -> void:
	var p: Pool = Pool.new(1)
	assert_eq(p.acquire(), 0)
	assert_eq(p.acquire(), -1)

func test_released_slot_is_reused() -> void:
	var p: Pool = Pool.new(2)
	var a: int = p.acquire()
	p.acquire()
	p.release(a)
	assert_eq(p.acquire(), a)

func test_active_count_tracks_acquire_and_release() -> void:
	var p: Pool = Pool.new(4)
	assert_eq(p.active_count(), 0)
	p.acquire()
	p.acquire()
	assert_eq(p.active_count(), 2)
	p.release(0)
	assert_eq(p.active_count(), 1)

func test_double_release_does_not_corrupt_the_free_list() -> void:
	var p: Pool = Pool.new(2)
	var a: int = p.acquire()
	p.release(a)
	p.release(a)
	assert_push_error("repeated release", "a caller bug must be reported, not swallowed")
	assert_eq(p.active_count(), 0)
	assert_eq(p.acquire(), a)
	assert_eq(p.acquire(), 1)
	assert_eq(p.acquire(), -1, "a double release must not hand out a third slot")

func test_reset_frees_everything() -> void:
	var p: Pool = Pool.new(2)
	p.acquire()
	p.acquire()
	p.reset()
	assert_eq(p.active_count(), 0)
	assert_eq(p.acquire(), 0)
