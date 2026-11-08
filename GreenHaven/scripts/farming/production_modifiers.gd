class_name ProductionModifiers
extends RefCounted
## Effective production parameters at a moment in time. Snapshotted into a
## PlantInstance when a cycle starts, so later purchases never change a
## running cycle retroactively.

## Growth can be at most 40% faster than base (design doc / ECONOMY.md).
const MIN_TIME_MULTIPLIER: float = 0.6
const MAX_YIELD_BONUS: float = 0.5

var time_multiplier: float = 1.0
var yield_bonus: float = 0.0


func _init(time_mult: float = 1.0, bonus: float = 0.0) -> void:
	time_multiplier = clampf(time_mult, MIN_TIME_MULTIPLIER, 1.0)
	yield_bonus = clampf(bonus, 0.0, MAX_YIELD_BONUS)


## Growth duration (seconds, >= 1) for a crop under these modifiers.
func apply_to_duration(base_seconds: float) -> float:
	return maxf(1.0, base_seconds * time_multiplier)


func apply_to_yield(base_amount: int) -> float:
	return base_amount * (1.0 + yield_bonus)
