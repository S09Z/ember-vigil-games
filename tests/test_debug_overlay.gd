extends GutTest

var _overlay: DebugOverlay

func before_each() -> void:
	_overlay = DebugOverlay.new()
	autofree(_overlay)
	_overlay.init_buffers()

func test_stats_are_unavailable_until_the_window_is_full() -> void:
	for i in 10:
		_overlay.record_frame(1.0 / 120.0)
	assert_false(_overlay.has_stats(), "a partly filled window must not be reported as a result")

func test_average_fps_over_a_full_window() -> void:
	for i in DebugOverlay.WINDOW:
		_overlay.record_frame(1.0 / 120.0)
	assert_true(_overlay.has_stats())
	assert_almost_eq(_overlay.average_fps(), 120.0, 0.5)

func test_one_percent_low_catches_the_worst_frames() -> void:
	# 594 good frames at 120 fps and 6 bad ones at 20 fps: the 1% low must
	# report the bad end, not the average
	for i in DebugOverlay.WINDOW - 6:
		_overlay.record_frame(1.0 / 120.0)
	for i in 6:
		_overlay.record_frame(1.0 / 20.0)
	assert_almost_eq(_overlay.one_percent_low_fps(), 20.0, 0.5)
	assert_gt(_overlay.average_fps(), 60.0, "a few bad frames must not sink the average")

func test_the_window_is_a_ring_buffer() -> void:
	for i in DebugOverlay.WINDOW:
		_overlay.record_frame(1.0 / 20.0)
	for i in DebugOverlay.WINDOW:
		_overlay.record_frame(1.0 / 120.0)
	assert_almost_eq(_overlay.average_fps(), 120.0, 0.5, "old frames must be overwritten")

func test_text_includes_lines_from_the_bound_source() -> void:
	_overlay.bind_extra_lines(func() -> String: return "enemies 12 / 400")
	assert_string_contains(_overlay.build_text(), "enemies 12 / 400")

func test_text_without_a_source_still_reports_fps() -> void:
	var text: String = _overlay.build_text()
	assert_string_contains(text, "FPS")
	assert_string_contains(text, "avg --", "no stats yet while the window is filling")
