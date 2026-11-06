class_name RunTuning
extends Resource

## Numbers that describe a run as a whole rather than one class or one enemy.
## See docs/design.md sections 4 and 8.

@export var enemy_cap: int = 400
@export var spawn_ring_min: float = 380.0
@export var spawn_ring_max: float = 420.0
@export var recycle_distance: float = 600.0

## Spawn rate per second is min(cap, base + elapsed / time_divisor)
@export var spawn_rate_base: float = 1.0
@export var spawn_rate_time_divisor: float = 20.0
@export var spawn_rate_cap: float = 12.0

## Enemy hp at spawn is def.hp * (1 + elapsed / hp_scale_divisor)
@export var hp_scale_divisor: float = 150.0

@export var player_iframe_duration: float = 0.5

## Push applied to fully overlapping enemies, in px/s
@export var separation_strength: float = 60.0

## Neighbour-lookup cell size; retune during the performance pass
@export var grid_cell_size: float = 16.0

## XP needed for the next level is round(xp_base + level * xp_per_level)
@export var xp_base: float = 5.0
@export var xp_per_level: float = 4.5

## Embers = floor(kills / embers_kills_divisor) + floor(seconds / embers_seconds_divisor) + bonuses
@export var embers_kills_divisor: int = 10
@export var embers_seconds_divisor: int = 15

## A push of N px is delivered as a velocity that decays to zero over this many seconds
@export var knockback_duration: float = 0.2

## XP gems: pull speed in px/s once inside pickup range, pool size, and collect radius
@export var gem_pull_speed: float = 180.0
@export var gem_capacity: int = 512
@export var gem_radius: float = 3.0
