class_name SystemTimeSource
extends TimeSource
## Local device clock. Works offline; can be changed by the user, which is
## why TimeManager sanitises the values it returns.


func get_unix_time() -> float:
	return Time.get_unix_time_from_system()
