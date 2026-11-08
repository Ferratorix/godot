extends GHTestCase
## Smoke/integration test of the main scene: it loads, renders frames,
## and a tap on an object opens the info panel through the real input path.

const MAIN := preload("res://scenes/main/main.tscn")

var main: Node


func before_each() -> void:
	main = MAIN.instantiate()
	tree.root.add_child(main)
	await frames(3)


func after_each() -> void:
	main.queue_free()
	await frames(1)


func _world_to_screen(world_pos: Vector2) -> Vector2:
	return main.get_viewport().get_canvas_transform() * world_pos


func _tap(screen_pos: Vector2) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventScreenTouch.new()
		e.position = screen_pos
		e.pressed = pressed
		main.world.gestures.handle_event(e)


func test_scene_starts_with_room_in_view() -> void:
	var world: FarmWorld = main.world
	check(world.room.grid.object_count() > 0)
	check(world.camera.is_current(), "camera active")
	var vp_rect := main.get_viewport().get_visible_rect()
	check(vp_rect.has_point(_world_to_screen(world.room.get_world_rect().get_center())),
		"room centre on screen")


func _find(id: StringName) -> WorldObject:
	for obj: WorldObject in main.world.room.objects_root.get_children():
		if obj.data.id == id:
			return obj
	return null


func test_tap_object_opens_info_and_close_hides() -> void:
	var world: FarmWorld = main.world
	var obj: WorldObject = _find(&"storage_crate")
	_tap(_world_to_screen(world.room.cell_to_world(obj.cell)))
	await frames(2)
	check(world.room.selected == obj, "selected")
	check(main.hud.is_panel_open(), "info panel open")
	check_eq(main.hud.info_name.text, tr(obj.data.name_key))
	main.hud.deselect_requested.emit()
	await tree.create_timer(0.4).timeout  # Let the slide-out tween finish.
	check(world.room.selected == null, "deselected")
	check(not main.hud.is_panel_open(), "panel closed")


func test_move_mode_via_button() -> void:
	var world: FarmWorld = main.world
	var obj: WorldObject = world.room.objects_root.get_child(0)
	world.room.select_object(obj)
	main.hud.move_requested.emit(obj)
	check(world.is_in_move_mode())
	check(main.hud.move_banner.visible, "banner shown")
	_tap(_world_to_screen(world.room.cell_to_world(Vector2i(7, 6))))
	await frames(1)
	check(not world.is_in_move_mode())
	check(not main.hud.move_banner.visible, "banner hidden")
	check_eq(obj.cell, Vector2i(7, 6))


func test_back_closes_panel_before_quitting() -> void:
	var world: FarmWorld = main.world
	world.room.select_object(world.room.objects_root.get_child(0))
	main.hud.handle_back()
	check(world.room.selected == null, "back deselects instead of quitting")
