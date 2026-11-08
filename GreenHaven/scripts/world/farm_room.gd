class_name FarmRoom
extends Node2D
## An indoor isometric room: the VIEW of a FarmState.
##
## Builds floor/walls/decor from RoomLayoutData and spawns a WorldObject for
## every object in the FarmState's PlacementGrid (the model owns occupancy).
## Exposes grid <-> world conversion, picking, selection and the drag-to-move
## workflow. Does not handle input itself.

signal object_selected(object: WorldObject)
signal selection_cleared
signal object_moved(instance_key: StringName, from_cell: Vector2i, to_cell: Vector2i)

const WORLD_OBJECT_SCENE: PackedScene = preload("res://scenes/objects/world_object.tscn")
const WALL_LEFT_TEXTURE: Texture2D = preload("res://assets/placeholder/environment/wall_left.png")
const WALL_RIGHT_TEXTURE: Texture2D = preload("res://assets/placeholder/environment/wall_right.png")
const WINDOW_TEXTURE: Texture2D = preload("res://assets/placeholder/environment/window_right_wall.png")
const POSTER_TEXTURE: Texture2D = preload("res://assets/placeholder/environment/poster_left_wall.png")
const FLOOR_SOURCE_ID: int = 0

@export var layout: RoomLayoutData
## Build a standalone farm from [member layout] in _ready (previews/tests).
## FarmWorld turns this off and binds the session's FarmState instead.
@export var auto_build: bool = true

## The model shown by this room. Its placement grid is shared, not copied.
var farm: FarmState
var grid: PlacementGrid
var selected: WorldObject
var _objects: Dictionary = {}  # instance key -> WorldObject
var _drag_object: WorldObject
var _drag_target_cell: Vector2i
var _drag_valid: bool = false

@onready var floor_layer: TileMapLayer = $Floor
@onready var highlight: CellHighlight = $FloorOverlay
@onready var walls: Node2D = $Walls
@onready var objects_root: Node2D = $Objects
@onready var ambience: Node2D = $Ambience


func _ready() -> void:
	TimeManager.second_tick.connect(_on_second_tick)
	if auto_build and layout and farm == null:
		build(layout)


## (Re)builds the whole room. Without [param farm_state] a fresh farm is
## created from the layout (used by isolated tests / previews).
func build(room_layout: RoomLayoutData, farm_state: FarmState = null) -> void:
	layout = room_layout
	if farm and farm.object_added.is_connected(_on_object_added):
		farm.object_added.disconnect(_on_object_added)
		farm.slot_changed.disconnect(_on_slot_changed)
		farm.equipment_changed.disconnect(refresh_all_plants)
	farm = farm_state if farm_state else FarmState.from_layout(room_layout)
	farm.object_added.connect(_on_object_added)
	farm.slot_changed.connect(_on_slot_changed)
	farm.equipment_changed.connect(refresh_all_plants)
	clear_selection()
	floor_layer.clear()
	for container: Node in [walls, objects_root, ambience]:
		for child in container.get_children():
			container.remove_child(child)  # Gone now, not at frame end.
			child.queue_free()
	_objects.clear()
	grid = farm.placement
	_build_floor()
	_build_walls()
	for key in grid.get_keys():
		_on_object_added(key)
	refresh_all_plants()


## Creates the view of an object that already exists in the model.
func _spawn_view(data: PlaceableData, key: StringName, cell: Vector2i) -> WorldObject:
	var obj: WorldObject = WORLD_OBJECT_SCENE.instantiate()
	obj.setup(data, key, cell)
	obj.position = cell_to_local(cell)
	objects_root.add_child(obj)
	_objects[key] = obj
	return obj


func _on_object_added(key: StringName) -> void:
	var data := farm.get_object_data(key)
	if data == null or _objects.has(key):
		return
	var obj := _spawn_view(data, key, grid.get_origin(key))
	if obj and is_inside_tree() and grid.object_count() > 0:
		obj.refresh_plants(farm, TimeManager.now())


func _on_slot_changed(key: StringName, _index: int) -> void:
	var obj: WorldObject = _objects.get(key)
	if obj:
		obj.refresh_plants(farm, TimeManager.now())


## Updates plant sprites (stages advance with real time) and lighting.
func refresh_all_plants() -> void:
	var now := TimeManager.now()
	for obj: WorldObject in _objects.values():
		obj.refresh_plants(farm, now)


func _on_second_tick(_now: float) -> void:
	if farm:
		refresh_all_plants()


## All object views (read-only use).
func get_object_views() -> Array:
	return _objects.values()


# --- Coordinates ----------------------------------------------------------

func cell_to_local(cell: Vector2i) -> Vector2:
	return floor_layer.position + floor_layer.map_to_local(cell)


func cell_to_world(cell: Vector2i) -> Vector2:
	return to_global(cell_to_local(cell))


func world_to_cell(world_point: Vector2) -> Vector2i:
	return floor_layer.local_to_map(floor_layer.to_local(world_point))


func get_tile_size() -> Vector2:
	return Vector2(floor_layer.tile_set.tile_size)


## World rectangle covering floor and walls (camera bounds).
func get_world_rect() -> Rect2:
	var rect := Rect2(cell_to_world(Vector2i.ZERO), Vector2.ZERO)
	for corner in [Vector2i(0, 0), Vector2i(layout.size.x - 1, 0),
			Vector2i(0, layout.size.y - 1), layout.size - Vector2i.ONE]:
		var c: Vector2 = cell_to_world(corner)
		rect = rect.expand(c - get_tile_size() * 0.5).expand(c + get_tile_size() * 0.5)
	rect = rect.grow_side(SIDE_TOP, float(WALL_LEFT_TEXTURE.get_height()))
	return rect


# --- Picking & selection ------------------------------------------------------

## Front-most object under [param world_point]: pixel-accurate sprite hit
## first (tall objects), then the object occupying the touched cell.
func pick_object(world_point: Vector2) -> WorldObject:
	var best: WorldObject = null
	for obj: WorldObject in _objects.values():
		if obj.hit_test(world_point) and (best == null or obj.position.y > best.position.y):
			best = obj
	if best:
		return best
	var key: StringName = grid.get_owner_at(world_to_cell(world_point))
	return _objects.get(key) if key != &"" else null


func get_object(key: StringName) -> WorldObject:
	return _objects.get(key)


func select_object(obj: WorldObject) -> void:
	if obj == selected:
		return
	if selected:
		selected.set_selected(false)
	selected = obj
	if obj == null:
		highlight.clear()
		selection_cleared.emit()
		return
	obj.set_selected(true)
	_show_footprint(obj.cell, obj.data.footprint, CellHighlight.SELECT_COLOR)
	object_selected.emit(obj)


func clear_selection() -> void:
	select_object(null)


# --- Drag & drop placement -------------------------------------------------

func begin_drag(obj: WorldObject) -> bool:
	if obj == null or not obj.data.movable:
		return false
	select_object(obj)
	_drag_object = obj
	_drag_target_cell = obj.cell
	_drag_valid = true
	obj.set_drag_preview(true, true)
	_show_footprint(obj.cell, obj.data.footprint, CellHighlight.VALID_COLOR)
	return true


## Moves the carried object's preview to the cell under [param world_point].
## Returns whether the object could be dropped there.
func update_drag(world_point: Vector2) -> bool:
	if _drag_object == null:
		return false
	_drag_target_cell = world_to_cell(world_point)
	_drag_valid = grid.can_place(_drag_target_cell, _drag_object.data.footprint,
		_drag_object.instance_key)
	# Clamp the visual inside the room so the preview never flies off-grid.
	var shown := Vector2i(clampi(_drag_target_cell.x, 0, layout.size.x - 1),
		clampi(_drag_target_cell.y, 0, layout.size.y - 1))
	_drag_object.position = cell_to_local(shown)
	_drag_object.set_drag_preview(true, _drag_valid)
	_show_footprint(shown, _drag_object.data.footprint,
		CellHighlight.VALID_COLOR if _drag_valid else CellHighlight.INVALID_COLOR)
	return _drag_valid


## Drops the carried object. Invalid targets return it to its old cell.
func end_drag(commit: bool = true) -> bool:
	if _drag_object == null:
		return false
	var obj := _drag_object
	_drag_object = null
	var from_cell := obj.cell
	var moved := false
	if commit and _drag_valid and _drag_target_cell != from_cell:
		moved = farm.move_object(obj.instance_key, _drag_target_cell)
	if moved:
		obj.cell = _drag_target_cell
	obj.position = cell_to_local(obj.cell)
	obj.set_drag_preview(false)
	obj.play_place_animation()
	_show_footprint(obj.cell, obj.data.footprint, CellHighlight.SELECT_COLOR)
	if moved:
		object_moved.emit(obj.instance_key, from_cell, obj.cell)
	return moved


func is_dragging() -> bool:
	return _drag_object != null


# --- Building ---------------------------------------------------------------

func _build_floor() -> void:
	for x in layout.size.x:
		for y in layout.size.y:
			var cell := Vector2i(x, y)
			var atlas: Vector2i = layout.floor_tiles[(x + y) % layout.floor_tiles.size()]
			if layout.rug_rect.has_area() and layout.rug_rect.has_point(cell):
				atlas = layout.rug_tile
			floor_layer.set_cell(cell, FLOOR_SOURCE_ID, atlas)


## Walls stand on the back edges of the room: every cell whose top-left or
## top-right neighbour is outside the room gets a wall slice on that edge.
## Layout-agnostic: relies only on TileMapLayer neighbour queries.
func _build_walls() -> void:
	var half := get_tile_size() * 0.5
	for x in layout.size.x:
		for y in layout.size.y:
			var cell := Vector2i(x, y)
			var center := cell_to_local(cell)
			var left_n := floor_layer.get_neighbor_cell(cell, TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE)
			var right_n := floor_layer.get_neighbor_cell(cell, TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE)
			if not grid.is_inside(left_n):
				# Left slice spans from the left vertex to the top vertex.
				_add_wall_sprite(WALL_LEFT_TEXTURE,
					Vector2(center.x - half.x, center.y - WALL_LEFT_TEXTURE.get_height() + 1))
				if cell in layout.poster_cells:
					_add_wall_sprite(POSTER_TEXTURE, Vector2(center.x - half.x + 1, center.y - 48))
			if not grid.is_inside(right_n):
				_add_wall_sprite(WALL_RIGHT_TEXTURE,
					Vector2(center.x, center.y - WALL_RIGHT_TEXTURE.get_height() + 1))
				if cell in layout.window_cells:
					var top_left := Vector2(center.x - 4, center.y - 52)
					_add_wall_sprite(WINDOW_TEXTURE, top_left)
					var light := WindowLight.new()
					light.position = top_left + Vector2(0, 1)
					ambience.add_child(light)


func _add_wall_sprite(texture: Texture2D, top_left: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = texture
	s.centered = false
	s.position = top_left
	walls.add_child(s)


func _show_footprint(origin: Vector2i, footprint: Vector2i, color: Color) -> void:
	var centers := PackedVector2Array()
	for cell in grid.footprint_cells(origin, footprint):
		centers.append(cell_to_local(cell))
	highlight.show_cells(centers, get_tile_size(), color)
