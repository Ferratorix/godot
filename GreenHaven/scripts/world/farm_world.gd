class_name FarmWorld
extends Node2D
## Scene controller of the playable farm view.
##
## Wires TouchGestureHandler -> IsoCamera / FarmRoom and re-emits
## world events for the UI layer. Contains interaction policy only;
## grid rules live in FarmRoom/PlacementGrid, motion in IsoCamera.

signal selection_changed(object: WorldObject)
signal object_moved(instance_key: StringName, from_cell: Vector2i, to_cell: Vector2i)
signal move_mode_changed(active: bool)
## Ready plants were harvested by tapping a rack. result: product id -> amount.
signal harvested(screen_position: Vector2, result: Dictionary)
## First meaningful interaction (used to hide the onboarding hint).
signal player_interacted

## Viewport px from the screen edge where a carried object scrolls the view.
const EDGE_SCROLL_MARGIN: float = 28.0
const EDGE_SCROLL_SPEED: float = 220.0

@onready var room: FarmRoom = $Room
@onready var camera: IsoCamera = $Camera
@onready var gestures: TouchGestureHandler = $Gestures

var _drag_screen_pos: Vector2
var _move_mode_object: WorldObject


func _ready() -> void:
	gestures.tapped.connect(_on_tapped)
	gestures.long_pressed.connect(_on_long_pressed)
	gestures.object_drag_moved.connect(_on_drag_moved)
	gestures.object_drag_ended.connect(_on_drag_ended)
	gestures.object_drag_cancelled.connect(_on_drag_cancelled)
	gestures.panned.connect(camera.pan_by)
	gestures.pan_released.connect(camera.fling)
	gestures.pinched.connect(camera.zoom_at)
	gestures.wheel_zoomed.connect(camera.zoom_at)
	room.object_selected.connect(func(obj: WorldObject) -> void: selection_changed.emit(obj))
	room.selection_cleared.connect(func() -> void: selection_changed.emit(null))
	room.object_moved.connect(func(k: StringName, a: Vector2i, b: Vector2i) -> void:
		object_moved.emit(k, a, b))
	GameManager.farm_replaced.connect(_bind_farm)
	if GameManager.farm:
		_bind_farm(GameManager.farm)
	_setup_camera()


func _bind_farm(farm: FarmState) -> void:
	cancel_move_mode()
	var layout := GameManager.layout_for(farm)
	var room_changed := layout != room.layout
	room.build(layout, farm)
	selection_changed.emit(null)
	if room_changed and is_node_ready():
		_setup_camera()


func _process(delta: float) -> void:
	if room.is_dragging():
		_edge_scroll(delta)


## Frames the whole room at the largest pixel-perfect zoom that fits.
func recenter_camera() -> void:
	var rect := room.get_world_rect()
	var vp := get_viewport().get_visible_rect().size
	var fit: float = minf(vp.x / rect.size.x, vp.y / rect.size.y) * 0.92
	var stretch := camera.get_stretch_scale()
	var zoom_level := floorf(fit * stretch) / stretch if fit * stretch >= 1.0 else fit
	camera.snap_to(rect.get_center(), clampf(zoom_level, camera.min_zoom, camera.max_zoom))


func zoom_step(factor: float) -> void:
	camera.zoom_at(get_viewport().get_visible_rect().size * 0.5, factor)


## Accessibility alternative to long-press: the next tap on a cell moves
## [param obj] there.
func start_move_mode(obj: WorldObject) -> void:
	if obj and room.begin_drag(obj):
		_move_mode_object = obj
		move_mode_changed.emit(true)


func cancel_move_mode() -> void:
	if _move_mode_object:
		_move_mode_object = null
		room.end_drag(false)
		move_mode_changed.emit(false)


func is_in_move_mode() -> bool:
	return _move_mode_object != null


func screen_to_world(screen_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_point


func _setup_camera() -> void:
	camera.make_current()
	var rect := room.get_world_rect()
	camera.world_bounds = rect.grow(-minf(rect.size.x, rect.size.y) * 0.2)
	recenter_camera()


func _on_tapped(screen_pos: Vector2) -> void:
	player_interacted.emit()
	var world_pos := screen_to_world(screen_pos)
	if _move_mode_object:
		_move_mode_object = null
		room.update_drag(world_pos)
		room.end_drag(true)
		move_mode_changed.emit(false)
		return
	var obj := room.pick_object(world_pos)
	if obj:
		# One-tap harvest: tapping a rack with ripe plants collects them.
		if obj.has_grow_slots() and room.farm.count_ready(obj.instance_key) > 0:
			var result := room.farm.harvest_all(obj.instance_key)
			harvested.emit(screen_pos, result)
		room.select_object(obj)
	else:
		room.clear_selection()


func _on_long_pressed(screen_pos: Vector2) -> void:
	if _move_mode_object:
		return
	var obj := room.pick_object(screen_to_world(screen_pos))
	if obj and room.begin_drag(obj):
		player_interacted.emit()
		gestures.begin_object_drag()
		_drag_screen_pos = screen_pos
		Input.vibrate_handheld(25)


func _on_drag_moved(screen_pos: Vector2) -> void:
	_drag_screen_pos = screen_pos
	room.update_drag(screen_to_world(screen_pos))


func _on_drag_ended(screen_pos: Vector2) -> void:
	room.update_drag(screen_to_world(screen_pos))
	room.end_drag(true)


func _on_drag_cancelled() -> void:
	room.end_drag(false)


func _edge_scroll(delta: float) -> void:
	if not gestures.is_dragging_object():
		return
	var size := get_viewport().get_visible_rect().size
	var dir := Vector2.ZERO
	if _drag_screen_pos.x < EDGE_SCROLL_MARGIN:
		dir.x = 1.0
	elif _drag_screen_pos.x > size.x - EDGE_SCROLL_MARGIN:
		dir.x = -1.0
	if _drag_screen_pos.y < EDGE_SCROLL_MARGIN:
		dir.y = 1.0
	elif _drag_screen_pos.y > size.y - EDGE_SCROLL_MARGIN:
		dir.y = -1.0
	if dir != Vector2.ZERO:
		camera.pan_by(dir * EDGE_SCROLL_SPEED * delta)
		room.update_drag(screen_to_world(_drag_screen_pos))
