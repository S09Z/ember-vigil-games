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
