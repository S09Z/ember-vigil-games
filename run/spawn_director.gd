class_name SpawnDirector
extends RefCounted

## Releases enemies over time: min(cap, base + elapsed / divisor) per second,
## in a ring just outside the view. Every number comes from RunTuning.
##
## M1 only has Ghouls; the per-enemy start times in design.md section 8 arrive
## with the spawn table in M3.
##
## Driven by run.gd through tick(); it has no process callback of its own.

const GHOUL: int = 0

var _enemies: EnemySystem = null
var _tuning: RunTuning = null
var _rng: Rng = null
var _accumulator: float = 0.0


func setup(enemies: EnemySystem, tuning: RunTuning, rng: Rng) -> void:
	_enemies = enemies
	_tuning = tuning
	_rng = rng
	_accumulator = 0.0


func rate_at(elapsed: float) -> float:
	return minf(_tuning.spawn_rate_cap,
		_tuning.spawn_rate_base + elapsed / _tuning.spawn_rate_time_divisor)


func tick(delta: float, elapsed: float, player_pos: Vector2) -> void:
	_accumulator += rate_at(elapsed) * delta
	while _accumulator >= 1.0:
		_accumulator -= 1.0
		if not _spawn_one(elapsed, player_pos):
			# at the cap: drop the backlog so it cannot burst later
			_accumulator = 0.0
			return


## Spawns up to `count` enemies right now and returns how many fit under the cap.
func spawn_burst(count: int, elapsed: float, player_pos: Vector2) -> int:
	var spawned: int = 0
	for i in count:
		if not _spawn_one(elapsed, player_pos):
			break
		spawned += 1
	return spawned


func _spawn_one(elapsed: float, player_pos: Vector2) -> bool:
	if _enemies.alive_count() >= _tuning.enemy_cap:
		return false
	var pos: Vector2 = _rng.point_in_ring(player_pos,
		_tuning.spawn_ring_min, _tuning.spawn_ring_max)
	return _enemies.spawn(GHOUL, pos, elapsed) != -1
