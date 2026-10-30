extends GutTest

## Locks the project settings that the web build depends on.
## Switching to Forward+ or changing the base resolution silently breaks
## the browser demo, so these are asserted instead of remembered.


func test_renderer_is_gl_compatibility() -> void:
	var method: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	assert_eq(method, "gl_compatibility", "web export requires the Compatibility renderer")


func test_project_godot_pins_mobile_renderer_to_gl_compatibility() -> void:
	# ProjectSettings does not expose feature-tagged overrides (".mobile") at
	# runtime, so the raw config line is asserted instead. Mobile browsers pick
	# the .mobile renderer, which must not fall back to Forward+ / Mobile.
	var text: String = FileAccess.get_file_as_string("res://project.godot")
	assert_string_contains(text, 'rendering_method.mobile="gl_compatibility"')


func test_base_viewport_is_640x360() -> void:
	assert_eq(int(ProjectSettings.get_setting("display/window/size/viewport_width")), 640)
	assert_eq(int(ProjectSettings.get_setting("display/window/size/viewport_height")), 360)


func test_stretch_is_canvas_items_expand() -> void:
	assert_eq(str(ProjectSettings.get_setting("display/window/stretch/mode")), "canvas_items")
	assert_eq(str(ProjectSettings.get_setting("display/window/stretch/aspect")), "expand")


func test_canvas_texture_filter_is_nearest() -> void:
	# 0 = Nearest in the "Nearest,Linear,Linear Mipmap,Nearest Mipmap" enum.
	# Pixel art must not be filtered.
	var filter: int = int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"))
	assert_eq(filter, 0)


func test_movement_and_system_actions_exist() -> void:
	var required: Array[String] = [
		"move_up", "move_down", "move_left", "move_right", "pause", "toggle_debug",
	]
	for action: String in required:
		assert_true(InputMap.has_action(action), "missing input action: %s" % action)
