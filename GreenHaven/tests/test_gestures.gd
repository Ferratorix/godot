extends GHTestCase
## TouchGestureHandler: synthetic touch/mouse events -> gesture signals.

var g: TouchGestureHandler
var events: Array = []


func before_each() -> void:
	g = TouchGestureHandler.new()
	events = []
	g.tapped.connect(func(p: Vector2) -> void: events.append(["tap", p]))
	g.long_pressed.connect(func(p: Vector2) -> void: events.append(["long", p]))
	g.panned.connect(func(d: Vector2) -> void: events.append(["pan", d]))
	g.pan_released.connect(func(v: Vector2) -> void: events.append(["fling", v]))
	g.pinched.connect(func(c: Vector2, f: float) -> void: events.append(["pinch", f]))
	g.wheel_zoomed.connect(func(c: Vector2, f: float) -> void: events.append(["wheel", f]))
	g.object_drag_moved.connect(func(p: Vector2) -> void: events.append(["drag", p]))
	g.object_drag_ended.connect(func(p: Vector2) -> void: events.append(["drop", p]))
	g.object_drag_cancelled.connect(func() -> void: events.append(["cancel"]))


func after_each() -> void:
	g.free()


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	g.handle_event(e)


func _drag(index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	g.handle_event(e)


func _kinds() -> Array:
	return events.map(func(entry: Array) -> String: return entry[0])


func test_tap() -> void:
	_touch(0, Vector2(100, 100), true)
	_drag(0, Vector2(102, 101))  # Tiny jitter is still a tap.
	_touch(0, Vector2(102, 101), false)
	check_eq(_kinds(), ["tap"])


func test_drag_becomes_pan_not_tap() -> void:
	_touch(0, Vector2(100, 100), true)
	_drag(0, Vector2(120, 100))
	_drag(0, Vector2(130, 105))
	_touch(0, Vector2(130, 105), false)
	check(not _kinds().has("tap"), "no tap after pan")
	check_eq(_kinds().count("pan"), 2)
	check_eq(events[1][1], Vector2(10, 5))
	check_eq(_kinds().back(), "fling")


func test_long_press_without_drag_is_not_tap() -> void:
	_touch(0, Vector2(50, 50), true)
	g.update(0.3)
	check(events.is_empty(), "not yet")
	g.update(0.3)
	check_eq(_kinds(), ["long"])
	_touch(0, Vector2(50, 50), false)
	check_eq(_kinds(), ["long"], "release after long press is not a tap")


func test_long_press_object_drag() -> void:
	_touch(0, Vector2(50, 50), true)
	g.update(0.5)
	g.begin_object_drag()
	check(g.is_dragging_object())
	_drag(0, Vector2(80, 60))
	_touch(0, Vector2(80, 60), false)
	check_eq(_kinds(), ["long", "drag", "drop"])
	check_eq(events[2][1], Vector2(80, 60))
	check(not g.is_dragging_object())


func test_second_finger_cancels_object_drag_and_pinches() -> void:
	_touch(0, Vector2(100, 100), true)
	g.update(0.5)
	g.begin_object_drag()
	_touch(1, Vector2(200, 100), true)
	check(_kinds().has("cancel"))
	_drag(1, Vector2(300, 100))  # Fingers move apart: zoom in.
	var pinch: Array = events.filter(func(e: Array) -> bool: return e[0] == "pinch")
	check_eq(pinch.size(), 1)
	check_near(pinch[0][1], 2.0, 0.001, "distance 100 -> 200")


func test_pinch_then_one_finger_continues_as_pan() -> void:
	_touch(0, Vector2(100, 100), true)
	_touch(1, Vector2(200, 100), true)
	_drag(0, Vector2(150, 100))  # Fingers move together: zoom out.
	var pinch: Array = events.filter(func(e: Array) -> bool: return e[0] == "pinch")
	check(pinch.size() == 1 and pinch[0][1] < 1.0)
	_touch(1, Vector2(200, 100), false)
	events.clear()
	_drag(0, Vector2(160, 100))
	check_eq(_kinds(), ["pan"])
	check_eq(events[0][1], Vector2(10, 0), "no jump after pinch")
	_touch(0, Vector2(160, 100), false)
	check(not _kinds().has("tap"))


func test_emulated_mouse_is_ignored() -> void:
	var e := InputEventMouseButton.new()
	e.device = InputEvent.DEVICE_ID_EMULATION
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	check(not g.handle_event(e))
	check(events.is_empty())


func test_mouse_click_and_wheel() -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(10, 10)
	g.handle_event(down)
	var up := down.duplicate()
	up.pressed = false
	g.handle_event(up)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	g.handle_event(wheel)
	check_eq(_kinds(), ["tap", "wheel"])
	check(events[1][1] > 1.0)
