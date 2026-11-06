class_name Run
extends Node2D

## Owns the update order of one run. Every system is ticked from here instead of
## having its own _physics_process, so the order is visible in one place and the
## debug overlay can attribute time to each stage.

const START_SEED: int = 20261030

const KNIGHT: ClassDef = preload("res://data/classes/knight.tres")
const GHOUL: EnemyDef = preload("res://data/enemies/ghoul.tres")
const TUNING: RunTuning = preload("res://data/tuning/run_tuning.tres")

var elapsed: float = 0.0

var _rng: Rng = null
var _spawner: SpawnDirector = null

@onready var _enemies: EnemySystem = $EnemySystem
@onready var _player: Player = $Player
@onready var _overlay: DebugOverlay = $DebugOverlay


func _ready() -> void:
	_rng = Rng.new(START_SEED)
	var defs: Array[EnemyDef] = [GHOUL]
	# M2 will pass the class the player picked at Camp instead of hardcoding it
	_player.setup(KNIGHT, TUNING)
	_enemies.setup(defs, TUNING, _rng, TUNING.enemy_cap)
	_spawner = SpawnDirector.new()
	_spawner.setup(_enemies, TUNING, _rng)
	_overlay.bind_extra_lines(_overlay_lines)
	_player.died.connect(_on_player_died)


func _physics_process(delta: float) -> void:
	step(delta)


## One frame of the run. Separate from _physics_process so tests can drive it by
## hand. The order matters: the grid must be rebuilt before anything queries it,
## and nothing may move between the rebuild and the last query.
func step(delta: float) -> void:
	elapsed += delta
	_player.tick(delta)
	_spawner.tick(delta, elapsed, _player.global_position)
	_enemies.tick_grid()
	_enemies.tick_separation()
	_enemies.tick_contact(_player)
	_enemies.tick_movement(delta, _player.global_position)
	_enemies.sync_multimesh()


func _overlay_lines() -> String:
	return "enemies %d / %d\ngrid %.2f  sep %.2f  hit %.2f  move %.2f  draw %.2f ms" % [
		_enemies.alive_count(),
		_enemies.capacity(),
		_enemies.usec_grid / 1000.0,
		_enemies.usec_separation / 1000.0,
		_enemies.usec_contact / 1000.0,
		_enemies.usec_movement / 1000.0,
		_enemies.usec_multimesh / 1000.0,
	]


func _on_player_died() -> void:
	# M2 hands over to the results screen; for now the run simply stops.
	set_physics_process(false)
	print("player died at %.1f s" % elapsed)
