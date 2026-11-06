extends GutTest

const RUN_SCENE: PackedScene = preload("res://run/run.tscn")

var _run: Run

func before_each() -> void:
	_run = RUN_SCENE.instantiate()
	add_child_autofree(_run)

func test_the_run_scene_wires_every_system() -> void:
	assert_not_null(_run.get_node("EnemySystem"))
	assert_not_null(_run.get_node("Player"))
	assert_not_null(_run.get_node("Player/Camera2D"), "the camera follows the player")
	assert_not_null(_run.get_node("DebugOverlay"))

func test_the_player_is_set_up_from_the_knight() -> void:
	var player: Player = _run.get_node("Player")
	assert_eq(player.max_hp, 140.0)

func test_stepping_advances_the_clock() -> void:
	_run.step(0.5)
	assert_almost_eq(_run.elapsed, 0.5, 0.0001)

func test_enemies_appear_over_time_and_stay_under_the_cap() -> void:
	for i in 600:
		_run.step(1.0 / 60.0)
	var enemies: EnemySystem = _run.get_node("EnemySystem")
	assert_gt(enemies.alive_count(), 0)
	assert_lte(enemies.alive_count(), Run.TUNING.enemy_cap)

func test_live_enemies_have_a_visible_size_after_a_step() -> void:
	for i in 120:
		_run.step(1.0 / 60.0)
	var enemies: EnemySystem = _run.get_node("EnemySystem")
	var checked: int = 0
	for i in enemies.capacity():
		if enemies.is_alive(i):
			assert_gt(enemies.transform_of(i).x.length(), 0.0)
			checked += 1
	assert_gt(checked, 0)

func test_the_overlay_text_reports_enemy_count_and_stage_times() -> void:
	for i in 120:
		_run.step(1.0 / 60.0)
	var text: String = _run._overlay_lines()
	assert_string_contains(text, "enemies")
	assert_string_contains(text, "/ 400")
	assert_string_contains(text, "move")

func test_the_run_stops_ticking_when_the_player_dies() -> void:
	var player: Player = _run.get_node("Player")
	assert_true(_run.is_physics_processing())
	player.take_damage(100000.0)
	assert_false(_run.is_physics_processing())

func test_the_same_seed_gives_the_same_run() -> void:
	var other: Run = RUN_SCENE.instantiate()
	add_child_autofree(other)
	for i in 300:
		_run.step(1.0 / 60.0)
		other.step(1.0 / 60.0)
	var a: EnemySystem = _run.get_node("EnemySystem")
	var b: EnemySystem = other.get_node("EnemySystem")
	assert_eq(a.alive_count(), b.alive_count())
	for i in a.capacity():
		if a.is_alive(i):
			assert_eq(a.position_of(i), b.position_of(i))
