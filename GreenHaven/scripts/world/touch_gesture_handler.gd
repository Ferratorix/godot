class_name TouchGestureHandler
extends Node
## Turns raw touch / mouse input into high-level gestures.
##
## Knows nothing about the camera or the farm: it only emits signals with
## positions in viewport (canvas) coordinates. The scene controller decides
## what a tap or a drag means. Feed events with [method handle_event] and
## time with [method update] (both happen automatically when in the tree;
## tests call them directly).
##
## Gestures:
## * tap — short press without moving;
## * long press — hold still; the listener may call [method begin_object_drag]
##   to turn the rest of the gesture into an object drag;
## * one-finger drag — pan (with release velocity for inertia);
## * two-finger pinch — zoom around the fingers' center (+ pan);
## * mouse: left = same as one finger, right/middle drag = pan, wheel = zoom.

signal tapped(position: Vector2)
signal long_pressed(position: Vector2)
signal object_drag_moved(position: Vector2)
signal object_drag_ended(position: Vector2)
signal object_drag_cancelled
signal panned(screen_delta: Vector2)
signal pan_released(velocity: Vector2)
signal pinched(center: Vector2, zoom_factor: float)
signal wheel_zoomed(center: Vector2, zoom_factor: float)

enum State { IDLE, PRESSING, PANNING, OBJECT_DRAG, PINCHING }

## Max movement (viewport px) for a press to still count as a tap/long press.
@export var tap_move_threshold: float = 6.0
@export var long_press_time: float = 0.45
@export var wheel_zoom_step: float = 1.15

## Mouse "pointer" uses this index so it never collides with touch indices.
const MOUSE_INDEX: int = 1000

var state: State = State.IDLE
var _pointers: Dictionary = {}  # index -> Vector2
var _press_origin: Vector2
var _press_time: float = 0.0
var _long_press_fired: bool = false
var _last_pinch_distance: float = 0.0
var _last_pinch_center: Vector2
var _pan_velocity: Vector2 = Vector2.ZERO
var _mouse_pan_button: bool = false


func _process(delta: float) -> void:
	update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if handle_event(event):
		get_viewport().set_input_as_handled()


## Advances long-press timing.
func update(delta: float) -> void:
	_pan_velocity = _pan_velocity.lerp(Vector2.ZERO, clampf(delta * 8.0, 0.0, 1.0))
	if state != State.PRESSING or _long_press_fired:
		return
	_press_time += delta
	if _press_time >= long_press_time:
		_long_press_fired = true
		long_pressed.emit(_press_origin)


## Called by a listener of [signal long_pressed] to start dragging an object.
func begin_object_drag() -> void:
	if state == State.PRESSING:
		state = State.OBJECT_DRAG


func is_dragging_object() -> bool:
	return state == State.OBJECT_DRAG


## Returns true if the event was consumed.
func handle_event(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_pointer_down(t.index, t.position)
		else:
			_pointer_up(t.index, t.position, t.canceled)
		return true
	if event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_pointer_move(d.index, d.position)
		return true
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return false  # Mouse emulated from touch: already handled as touch.
	if event is InputEventMouseButton:
		return _handle_mouse_button(event as InputEventMouseButton)
	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		if _mouse_pan_button:
			panned.emit(m.relative)
			return true
		if _pointers.has(MOUSE_INDEX):
			_pointer_move(MOUSE_INDEX, m.position)
			return true
		return false
	if event is InputEventMagnifyGesture:  # Trackpads / some Android builds.
		var g := event as InputEventMagnifyGesture
		wheel_zoomed.emit(g.position, g.factor)
		return true
	return false


func _handle_mouse_button(mb: InputEventMouseButton) -> bool:
	match mb.button_index:
		MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pointer_down(MOUSE_INDEX, mb.position)
			else:
				_pointer_up(MOUSE_INDEX, mb.position, false)
			return true
		MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			_mouse_pan_button = mb.pressed
			return true
		MOUSE_BUTTON_WHEEL_UP:
			if mb.pressed:
				wheel_zoomed.emit(mb.position, wheel_zoom_step)
			return true
		MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				wheel_zoomed.emit(mb.position, 1.0 / wheel_zoom_step)
			return true
	return false


func _pointer_down(index: int, pos: Vector2) -> void:
	_pointers[index] = pos
	if _pointers.size() == 1:
		state = State.PRESSING
		_press_origin = pos
		_press_time = 0.0
		_long_press_fired = false
		_pan_velocity = Vector2.ZERO
	elif _pointers.size() == 2:
		if state == State.OBJECT_DRAG:
			object_drag_cancelled.emit()
		state = State.PINCHING
		_reset_pinch_reference()


func _pointer_move(index: int, pos: Vector2) -> void:
	if not _pointers.has(index):
		return
	var previous: Vector2 = _pointers[index]
	_pointers[index] = pos
	match state:
		State.PRESSING:
			if pos.distance_to(_press_origin) > tap_move_threshold:
				state = State.PANNING
				panned.emit(pos - previous)
		State.PANNING:
			var delta := pos - previous
			panned.emit(delta)
			# Smoothed velocity in px/s assuming ~60 events/s.
			_pan_velocity = _pan_velocity.lerp(delta * 60.0, 0.5)
		State.OBJECT_DRAG:
			object_drag_moved.emit(pos)
		State.PINCHING:
			if _pointers.size() >= 2:
				var center := _pinch_center()
				var distance := _pinch_distance()
				if _last_pinch_distance > 0.0 and distance > 0.0:
					pinched.emit(center, distance / _last_pinch_distance)
				panned.emit(center - _last_pinch_center)
				_last_pinch_distance = distance
				_last_pinch_center = center


func _pointer_up(index: int, pos: Vector2, canceled: bool) -> void:
	if not _pointers.has(index):
		return
	_pointers.erase(index)
	match state:
		State.PRESSING:
			if not canceled and not _long_press_fired:
				tapped.emit(pos)
			state = State.IDLE
		State.PANNING:
			pan_released.emit(_pan_velocity)
			state = State.IDLE
		State.OBJECT_DRAG:
			if canceled:
				object_drag_cancelled.emit()
			else:
				object_drag_ended.emit(pos)
			state = State.IDLE
		State.PINCHING:
			if _pointers.size() >= 2:
				_reset_pinch_reference()
			elif _pointers.size() == 1:
				# Continue as a pan with the remaining finger (no jump).
				state = State.PANNING
				_pan_velocity = Vector2.ZERO
			else:
				state = State.IDLE
	if _pointers.is_empty():
		state = State.IDLE


func _reset_pinch_reference() -> void:
	_last_pinch_distance = _pinch_distance()
	_last_pinch_center = _pinch_center()


func _two_pointers() -> Array:
	return _pointers.values().slice(0, 2)


func _pinch_center() -> Vector2:
	var p: Array = _two_pointers()
	return (p[0] + p[1]) * 0.5 if p.size() == 2 else _press_origin


func _pinch_distance() -> float:
	var p: Array = _two_pointers()
	return (p[0] as Vector2).distance_to(p[1]) if p.size() == 2 else 0.0
