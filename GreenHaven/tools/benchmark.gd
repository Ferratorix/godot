extends SceneTree
## Dev tool: performance benchmark of a worst-case farm.
##   xvfb-run godot --path GreenHaven -s res://tools/benchmark.gd [-- seconds=10 mode=max|stress]
## Never touches the real save. Logic lives in benchmark_scenario.gd (loaded at
## runtime, because a -s main script compiles before autoloads exist).


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var scenario: Object = load("res://tools/benchmark_scenario.gd").new()
	var report: String = await scenario.run(self, float(args.get("seconds", "10")),
		args.get("mode", "max"))
	print(report)
	quit()
