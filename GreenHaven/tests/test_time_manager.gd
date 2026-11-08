extends GHTestCase
## TimeManager: sanitised real time, rollback protection, clamping.

const T0: float = 1800000000.0  # 2027-01-15

var clock: ManualTimeSource
var tm: Node


func before_each() -> void:
	tm = tree.root.get_node("TimeManager")
	clock = ManualTimeSource.new(T0)
	tm.set_time_source(clock)


func after_each() -> void:
	tm.set_time_source(SystemTimeSource.new())


func test_now_follows_source() -> void:
	check_eq(tm.now(), T0)
	clock.advance(90.0)
	check_eq(tm.now(), T0 + 90.0)


func test_clock_rollback_is_ignored_and_reported() -> void:
	var reported: Array = []
	var cb := func(sec: float) -> void: reported.append(sec)
	tm.clock_rollback_detected.connect(cb)
	tm.now()
	clock.current_time = T0 - 3600.0  # Player moved the clock 1 h back.
	check_eq(tm.now(), T0, "time must not go backwards")
	check_eq(reported.size(), 1, "rollback signal")
	check_near(reported[0], 3600.0)
	clock.current_time = T0 + 10.0
	check_eq(tm.now(), T0 + 10.0, "recovers once clock passes trusted time")
	tm.clock_rollback_detected.disconnect(cb)


func test_small_jitter_is_not_reported() -> void:
	var count := [0]
	var cb := func(_s: float) -> void: count[0] += 1
	tm.clock_rollback_detected.connect(cb)
	tm.now()
	clock.current_time = T0 - 1.0
	check_eq(tm.now(), T0)
	check_eq(count[0], 0)
	tm.clock_rollback_detected.disconnect(cb)


func test_invalid_timestamps_are_rejected() -> void:
	tm.now()
	for bad: float in [0.0, -5.0, 1.0e12, NAN, INF]:
		clock.current_time = bad
		check_eq(tm.now(), T0, "bad value %s" % bad)


func test_remaining_and_elapsed_never_negative() -> void:
	check_eq(tm.seconds_until(T0 - 100.0), 0.0)
	check_eq(tm.seconds_until(T0 + 100.0), 100.0)
	check_eq(tm.seconds_since(T0 + 100.0), 0.0)
	check_eq(tm.seconds_since(T0 - 100.0), 100.0)


func test_progress_is_clamped() -> void:
	check_eq(tm.progress(T0 - 50.0, T0 + 50.0), 0.5)
	check_eq(tm.progress(T0 + 10.0, T0 + 50.0), 0.0)
	check_eq(tm.progress(T0 - 90.0, T0 - 10.0), 1.0)
	check_eq(tm.progress(T0, T0), 1.0, "zero-length interval")


func test_simulated_app_restart_offline_time() -> void:
	# Session 1 records a finish time, the "app" is closed for 2 hours.
	var finish: float = tm.now() + 3600.0
	var saved: Dictionary = tm.get_state()
	clock.advance(7200.0)
	tm.set_time_source(clock)  # Fresh session.
	tm.apply_state(saved)
	check_eq(tm.seconds_until(finish), 0.0, "finished while closed")
	check_eq(tm.progress(finish - 3600.0, finish), 1.0)


func test_rollback_across_restart_uses_saved_trusted_time() -> void:
	tm.now()
	var saved: Dictionary = tm.get_state()
	clock.current_time = T0 - 86400.0  # Clock set a day back while closed.
	tm.set_time_source(clock)
	tm.apply_state(saved)
	check_eq(tm.now(), T0)


func test_apply_state_ignores_garbage() -> void:
	tm.apply_state({"last_trusted_time": "oops"})
	tm.apply_state({})
	check_eq(tm.now(), T0)


func test_format_duration() -> void:
	var tm_script: GDScript = tm.get_script()
	check_eq(tm_script.format_duration(0.0), "0:00")
	check_eq(tm_script.format_duration(59.2), "1:00")
	check_eq(tm_script.format_duration(3909.0), "1:05:09")
	check_eq(tm_script.format_duration(-5.0), "0:00")
