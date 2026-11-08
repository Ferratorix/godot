extends SceneTree
## Dev tool: renders the main scene and saves a PNG (needs a real display,
## e.g. xvfb-run; does not work with --headless). Never touches the real save.
##   godot --path GreenHaven -s res://tools/screenshot.gd -- out=/tmp/shot.png \
##         [demo] [select=<placeable id>] [drag=<id>:x,y] [zoom=2.0]
##         [panel=shop|storage|skills] [tab=N] [coins=N] [level=N] [wait=1.0]
## The scenario lives in screenshot_scenario.gd, loaded at runtime because a
## -s main script is compiled before autoloads are registered.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var scenario: Object = load("res://tools/screenshot_scenario.gd").new()
	await scenario.run(self, args)
	await create_timer(float(args.get("wait", "1.0"))).timeout
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var out: String = args.get("out", "user://screenshot.png")
	var err := img.save_png(out)
	print("screenshot ", out, " ", img.get_size(), " err=", err)
	quit(0 if err == OK else 1)
