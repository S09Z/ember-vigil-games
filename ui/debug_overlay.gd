class_name DebugOverlay
extends CanvasLayer

## F3 overlay. Reports the numbers the M1 gate is judged on: average and 1% low
## fps over a fixed window. Systems add their own lines (enemy count, ms per
## stage) by binding a Callable that returns text, so this file never depends on
## a game system and only ever reads from them.

const WINDOW: int = 600
const REFRESH_SECONDS: float = 0.25

var _frame_times: PackedFloat32Array = PackedFloat32Array()
var _sorted: PackedFloat32Array = PackedFloat32Array()
var _write_index: int = 0
var _filled: int = 0
var _refresh_timer: float = 0.0
var _extra_lines: Callable = Callable()

@onready var _label: Label = $Label


func _ready() -> void:
	init_buffers()
	visible = false


## Separate from _ready() so tests can use the statistics without a SceneTree.
func init_buffers() -> void:
	_frame_times.resize(WINDOW)
	_sorted.resize(WINDOW)
	_frame_times.fill(0.0)
	_write_index = 0
	_filled = 0


## `provider` is called a few times a second while visible and returns extra
## lines of text, e.g. "enemies 120 / 400". It must only read state.
func bind_extra_lines(provider: Callable) -> void:
	_extra_lines = provider


func record_frame(delta: float) -> void:
	_frame_times[_write_index] = delta
	_write_index = (_write_index + 1) % WINDOW
	_filled = mini(_filled + 1, WINDOW)


func has_stats() -> bool:
	return _filled >= WINDOW


func average_fps() -> float:
	if not has_stats():
		return 0.0
	var total: float = 0.0
	for i in WINDOW:
		total += _frame_times[i]
	if total <= 0.0:
		return 0.0
	return float(WINDOW) / total


## The 99th percentile frame time expressed as fps: the number that shows
## stutter that an average hides.
func one_percent_low_fps() -> float:
	if not has_stats():
		return 0.0
	for i in WINDOW:
		_sorted[i] = _frame_times[i]
	_sorted.sort()
	var worst: float = _sorted[int(float(WINDOW) * 0.99)]
	if worst <= 0.0:
		return 0.0
	return 1.0 / worst


func build_text() -> String:
	var stats: String = "avg --  1% low --"
	if has_stats():
		stats = "avg %.0f  1%% low %.0f" % [average_fps(), one_percent_low_fps()]
	var text: String = "FPS %d   %s" % [Engine.get_frames_per_second(), stats]
	if _extra_lines.is_valid():
		text += "\n" + String(_extra_lines.call())
	return text


func _process(delta: float) -> void:
	record_frame(delta)
	if not visible:
		return
	_refresh_timer -= delta
	if _refresh_timer > 0.0:
		return
	_refresh_timer = REFRESH_SECONDS
	_label.text = build_text()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		visible = not visible
