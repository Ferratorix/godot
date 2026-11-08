extends SceneTree
## Dev tool: renders the main scene and saves a PNG (needs a real display,
## e.g. xvfb-run; does not work with --headless).
##   godot --path GreenHaven -s res://tools/screenshot.gd -- out=/tmp/shot.png \
##         [select=storage_crate] [drag=hydro_rack_basic:7,6] [zoom=2.0] [wait=1.0]

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	var world: FarmWorld = main.world
	if args.has("zoom"):
		world.camera.zoom_at(root.get_visible_rect().size * 0.5, float(args.zoom))
	if args.has("select"):
		for obj: WorldObject in world.room.objects_root.get_children():
			if String(obj.data.id) == args.select:
				world.room.select_object(obj)
				break
	if args.has("drag"):
		var parts: PackedStringArray = args.drag.split(":")
		var xy := parts[1].split(",")
		for obj: WorldObject in world.room.objects_root.get_children():
			if String(obj.data.id) == parts[0]:
				world.room.begin_drag(obj)
				world.room.update_drag(world.room.cell_to_world(Vector2i(int(xy[0]), int(xy[1]))))
				break
	await create_timer(float(args.get("wait", "1.0"))).timeout
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var out: String = args.get("out", "user://screenshot.png")
	var err := img.save_png(out)
	print("screenshot ", out, " ", img.get_size(), " err=", err)
	quit(0 if err == OK else 1)
