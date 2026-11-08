extends GHTestCase
## FarmRoom: data-driven building, picking, selection and drag placement.

const ROOM_SCENE := preload("res://scenes/farm/farm_room.tscn")
const LAYOUT := preload("res://resources/rooms/home_garden_room.tres")

var room: FarmRoom


func before_each() -> void:
	room = ROOM_SCENE.instantiate()
	room.layout = LAYOUT
	tree.root.add_child(room)


func after_each() -> void:
	room.queue_free()
	await frames(1)


func test_room_is_built_from_data() -> void:
	check_eq(room.floor_layer.get_used_cells().size(), LAYOUT.size.x * LAYOUT.size.y)
	check_eq(room.grid.object_count(), LAYOUT.initial_objects.size())
	check_eq(room.objects_root.get_child_count(), LAYOUT.initial_objects.size())
	# One wall slice per back edge + decorations.
	var expected_walls: int = LAYOUT.size.x + LAYOUT.size.y \
		+ LAYOUT.window_cells.size() + LAYOUT.poster_cells.size()
	check_eq(room.walls.get_child_count(), expected_walls)
	check_eq(room.ambience.get_child_count(), LAYOUT.window_cells.size(), "window light per window")


func test_rug_tiles_follow_layout() -> void:
	var rug_cell := LAYOUT.rug_rect.position
	check_eq(room.floor_layer.get_cell_atlas_coords(rug_cell), LAYOUT.rug_tile)
	check(room.floor_layer.get_cell_atlas_coords(Vector2i(0, 0)) != LAYOUT.rug_tile)


func test_cell_world_roundtrip() -> void:
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(3, 2), Vector2i(7, 6)]:
		check_eq(room.world_to_cell(room.cell_to_world(cell)), cell)


func test_pick_by_cell_and_by_sprite() -> void:
	var first: RoomObjectPlacement = LAYOUT.initial_objects[0]
	var obj := room.pick_object(room.cell_to_world(first.cell))
	check(obj != null and obj.cell == first.cell, "pick by footprint cell")
	# The upper part of a tall rack overlaps cells behind it: sprite hit wins.
	var rack_top := room.cell_to_world(first.cell) + Vector2(0, -40)
	var top_hit := room.pick_object(rack_top)
	check(top_hit != null and top_hit.data.id == &"hydro_rack_basic", "pick tall sprite")
	check(room.pick_object(room.cell_to_world(Vector2i(7, 6))) == null, "empty cell")


func test_selection_signals() -> void:
	var got: Array = []
	room.object_selected.connect(func(o: WorldObject) -> void: got.append(o))
	room.selection_cleared.connect(func() -> void: got.append(null))
	var obj: WorldObject = room.objects_root.get_child(0)
	room.select_object(obj)
	check(obj.is_selected)
	room.clear_selection()
	check(not obj.is_selected)
	check_eq(got.size(), 2)
	check(got[1] == null)


func test_drag_to_free_cell_moves_object() -> void:
	var obj: WorldObject = room.objects_root.get_child(0)
	var from := obj.cell
	var target := Vector2i(7, 6)
	check(room.begin_drag(obj))
	check(room.update_drag(room.cell_to_world(target)), "free cell is valid")
	check(room.end_drag(true))
	check_eq(obj.cell, target)
	check_eq(room.grid.get_owner_at(target), obj.instance_key)
	check_eq(room.grid.get_owner_at(from), &"")
	check_eq(obj.position, room.cell_to_local(target))


func test_drag_onto_occupied_or_outside_reverts() -> void:
	var a: WorldObject = room.objects_root.get_child(0)
	var b: WorldObject = room.objects_root.get_child(1)
	var from := a.cell
	room.begin_drag(a)
	check(not room.update_drag(room.cell_to_world(b.cell)), "occupied is invalid")
	check(not room.end_drag(true))
	check_eq(a.cell, from)
	room.begin_drag(a)
	check(not room.update_drag(room.cell_to_world(Vector2i(-3, 20))), "outside is invalid")
	room.end_drag(true)
	check_eq(a.cell, from)
	check_eq(a.position, room.cell_to_local(from))


func test_cancelled_drag_reverts() -> void:
	var a: WorldObject = room.objects_root.get_child(0)
	var from := a.cell
	room.begin_drag(a)
	room.update_drag(room.cell_to_world(Vector2i(7, 6)))
	check(not room.end_drag(false))
	check_eq(a.cell, from)
	check_eq(room.grid.get_owner_at(Vector2i(7, 6)), &"")
