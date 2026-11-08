extends SceneTree
## Headless test runner.
##   godot --headless --path GreenHaven -s res://tests/run_tests.gd
## Exit code 0 = all passed, 1 = failures.

const TEST_DIR := "res://tests/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame  # Let autoloads finish _ready().
	var total := 0
	var failed := 0
	var files := Array(DirAccess.get_files_at(TEST_DIR))
	files.sort()
	for file: String in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var script: GDScript = load(TEST_DIR + file)
		if script == null or not script.can_instantiate():
			total += 1
			failed += 1
			print("  FAIL ", file, " (script failed to load/parse)")
			continue
		var suite: GHTestCase = script.new()
		suite.tree = self
		for method in script.get_script_method_list():
			var method_name: String = method.name
			if not method_name.begins_with("test_"):
				continue
			total += 1
			suite._current_test = "%s::%s" % [file, method_name]
			var before := suite.failures.size()
			suite.before_each()
			await suite.call(method_name)
			await suite.after_each()
			if suite.failures.size() > before:
				failed += 1
				print("  FAIL ", suite._current_test)
				for i in range(before, suite.failures.size()):
					print("       ", suite.failures[i])
			else:
				print("  ok   ", suite._current_test)
	print("\n%d tests, %d passed, %d failed" % [total, total - failed, failed])
	quit(1 if failed > 0 else 0)
