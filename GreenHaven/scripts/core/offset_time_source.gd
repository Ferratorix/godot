class_name OffsetTimeSource
extends TimeSource
## Another time source shifted by [member offset] seconds (Developer Lab time skip).

var base: TimeSource
var offset: float = 0.0


func _init(base_source: TimeSource = null) -> void:
	base = base_source if base_source else SystemTimeSource.new()


func get_unix_time() -> float:
	return base.get_unix_time() + offset
