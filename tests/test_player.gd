extends GutTest

var _player: Player
var _def: ClassDef

func before_each() -> void:
	_def = ClassDef.new()
	_def.max_hp = 140.0
	_def.move_speed = 95.0
	_def.armor = 2
	_def.pickup_radius = 40.0
	_def.body_radius = 7.0
	_player = Player.new()
	autofree(_player)
	_player.setup(_def)

func test_setup_copies_the_class_stats() -> void:
	assert_eq(_player.max_hp, 140.0)
	assert_eq(_player.hp, 140.0)
	assert_eq(_player.armor, 2)
	assert_eq(_player.move_speed, 95.0)
	assert_eq(_player.pickup_radius, 40.0)
	assert_eq(_player.body_radius, 7.0)

func test_diagonal_input_is_normalised() -> void:
	assert_almost_eq(Player.input_to_direction(Vector2(1.0, 1.0)).length(), 1.0, 0.001)

func test_zero_input_gives_zero_direction() -> void:
	assert_eq(Player.input_to_direction(Vector2.ZERO), Vector2.ZERO)

func test_velocity_is_direction_times_speed() -> void:
	_player.apply_input(Vector2(-1.0, 0.0))
	assert_eq(_player.velocity, Vector2(-95.0, 0.0))

func test_diagonal_is_not_faster_than_straight() -> void:
	_player.apply_input(Vector2(1.0, 1.0))
	assert_almost_eq(_player.velocity.length(), 95.0, 0.01)

func test_no_input_stops_the_player() -> void:
	_player.apply_input(Vector2.RIGHT)
	_player.apply_input(Vector2.ZERO)
	assert_eq(_player.velocity, Vector2.ZERO)

func test_last_move_dir_starts_valid() -> void:
	assert_almost_eq(_player.last_move_dir.length(), 1.0, 0.001,
		"melee weapons in M2 aim along this, so it must never be zero")

func test_last_move_dir_follows_the_latest_input() -> void:
	_player.apply_input(Vector2.UP)
	assert_eq(_player.last_move_dir, Vector2.UP)

func test_last_move_dir_is_kept_when_the_player_stops() -> void:
	_player.apply_input(Vector2.LEFT)
	_player.apply_input(Vector2.ZERO)
	assert_eq(_player.last_move_dir, Vector2.LEFT)
