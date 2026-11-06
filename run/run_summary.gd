class_name RunSummary
extends RefCounted

## Snapshot of a finished run, copied out of RunState so it can outlive it.

var survived_seconds: float = 0.0
var kills: int = 0
var level: int = 1
var damage_by_weapon: Dictionary = {}  # StringName id -> float
var embers_from_kills: int = 0
var embers_from_time: int = 0
var embers_bonus: int = 0
var embers_total: int = 0


static func from_state(state: RunState) -> RunSummary:
	var s: RunSummary = RunSummary.new()
	s.survived_seconds = state.elapsed
	s.kills = state.kills
	s.level = state.level
	s.damage_by_weapon = state.damage_by_weapon()
	s.embers_from_kills = state.embers_from_kills()
	s.embers_from_time = state.embers_from_time()
	s.embers_bonus = state.embers_bonus()
	s.embers_total = state.embers_total()
	return s
