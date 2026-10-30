extends Node2D

## M0 placeholder screen.
##
## Its only job is to prove, from inside a browser, that the web build renders,
## the main loop runs and the project really uses the Compatibility renderer.
## Replaced by the Camp / Run / Results state switch in M2.

const REFRESH_INTERVAL: float = 0.25

@onready var _info_label: Label = $UI/InfoLabel

var _time_since_refresh: float = 0.0


func _ready() -> void:
	_refresh_info()


func _process(delta: float) -> void:
	_time_since_refresh += delta
	if _time_since_refresh < REFRESH_INTERVAL:
		return
	_time_since_refresh = 0.0
	_refresh_info()


func _refresh_info() -> void:
	var version: String = str(Engine.get_version_info().get("string", "unknown"))
	var renderer: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	_info_label.text = "FPS %d\nGodot %s\n%s" % [
		Engine.get_frames_per_second(),
		version,
		renderer,
	]
