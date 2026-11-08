class_name ManualTimeSource
extends TimeSource
## Fully controllable clock for automated tests and debug tooling.

var current_time: float = 0.0


func _init(start_time: float = 0.0) -> void:
	current_time = start_time


func get_unix_time() -> float:
	return current_time


func advance(seconds: float) -> void:
	current_time += seconds
