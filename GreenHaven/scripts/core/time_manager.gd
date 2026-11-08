extends Node
## Autoload "TimeManager": the single entry point for real-world time.
##
## Responsibilities:
## * Wraps a swappable TimeSource (system clock by default).
## * Sanitises time: rejects invalid timestamps and detects the device clock
##   being moved backwards (rollback). During a rollback the game keeps using
##   the last trusted time, so timers never run "in reverse" and the player
##   cannot farm by toggling the clock.
## * Provides clamped helpers (never negative remaining/elapsed time).
## * Emits a lightweight once-per-second tick for UI timers.
##
## IMPORTANT: growth/production is never simulated in a loop. Systems store
## start/finish timestamps and derive state on demand from now().

## Emitted once per real second while the game runs (UI countdown refresh).
signal second_tick(now_unix: float)
## Emitted when the source clock is earlier than the last trusted time.
signal clock_rollback_detected(rollback_seconds: float)

## Rollbacks smaller than this are treated as normal NTP jitter.
const ROLLBACK_TOLERANCE_SEC: float = 2.0
## 2020-01-01T00:00:00Z. Anything earlier is considered a broken clock.
const MIN_VALID_UNIX_TIME: float = 1577836800.0
## 2100-01-01T00:00:00Z. Anything later is considered a broken clock.
const MAX_VALID_UNIX_TIME: float = 4102444800.0

var _source: TimeSource = SystemTimeSource.new()
## Highest time the game has accepted as real. Persisted by SaveManager
## (Phase 6) via get_state()/apply_state().
var _last_trusted_time: float = 0.0
var _tick_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tick_timer = Timer.new()
	_tick_timer.wait_time = 1.0
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)
	_tick_timer.start()
	now()  # Initialise the trusted time.


## Replaces the time source (tests, debug, future server time).
## Resets the trusted time so the new source is accepted as-is.
func set_time_source(source: TimeSource) -> void:
	if source == null:
		push_error("TimeManager: time source cannot be null.")
		return
	_source = source
	_last_trusted_time = 0.0


func get_time_source() -> TimeSource:
	return _source


## Current sanitised Unix time in seconds. Never decreases during a session.
func now() -> float:
	var raw: float = _source.get_unix_time()
	if not is_valid_timestamp(raw):
		# Broken clock: keep the last trusted time instead of garbage.
		return _last_trusted_time
	if _last_trusted_time > 0.0 and raw < _last_trusted_time:
		var rollback: float = _last_trusted_time - raw
		if rollback > ROLLBACK_TOLERANCE_SEC:
			clock_rollback_detected.emit(rollback)
		return _last_trusted_time
	_last_trusted_time = raw
	return raw


## Seconds left until [param target_unix]; never negative.
func seconds_until(target_unix: float) -> float:
	return maxf(0.0, target_unix - now())


## Seconds passed since [param start_unix]; never negative.
func seconds_since(start_unix: float) -> float:
	return maxf(0.0, now() - start_unix)


## 0..1 progress of an interval; robust to bad/zero-length intervals.
func progress(start_unix: float, end_unix: float) -> float:
	var duration: float = end_unix - start_unix
	if duration <= 0.0:
		return 1.0
	return clampf((now() - start_unix) / duration, 0.0, 1.0)


func is_valid_timestamp(value: float) -> bool:
	return is_finite(value) and value >= MIN_VALID_UNIX_TIME and value <= MAX_VALID_UNIX_TIME


## Formats a duration for UI, e.g. "1:05:09" or "4:59".
static func format_duration(seconds: float) -> String:
	var total: int = int(ceil(maxf(0.0, seconds)))
	var h: int = total / 3600
	var m: int = (total % 3600) / 60
	var s: int = total % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%d:%02d" % [m, s]


## Serializable state for SaveManager (Phase 6).
func get_state() -> Dictionary:
	return {"last_trusted_time": _last_trusted_time}


func apply_state(state: Dictionary) -> void:
	var value: Variant = state.get("last_trusted_time", 0.0)
	if (value is float or value is int) and is_valid_timestamp(float(value)):
		_last_trusted_time = float(value)


func _on_tick() -> void:
	second_tick.emit(now())
