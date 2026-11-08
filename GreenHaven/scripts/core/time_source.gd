class_name TimeSource
extends RefCounted
## Abstract source of "wall clock" time in Unix seconds.
##
## Production/business logic never calls Time.get_unix_time_from_system()
## directly: it asks TimeManager, which asks a TimeSource. This keeps the
## growth/production math testable and allows a different source later
## (e.g. a trusted server time) without touching gameplay code.


## Returns the current Unix time in seconds (may be fractional).
func get_unix_time() -> float:
	push_error("TimeSource.get_unix_time() is abstract and must be overridden.")
	return 0.0
