class_name GHTestCase
extends RefCounted
## Minimal test base class (no third-party framework needed).
## Test methods start with "test_" and may be coroutines (use await).

var tree: SceneTree
var failures: PackedStringArray = PackedStringArray()
var _current_test: String = ""


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func fail(message: String) -> void:
	failures.append("%s: %s" % [_current_test, message])


func check(condition: bool, message: String = "condition is false") -> void:
	if not condition:
		fail(message)


func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		fail("%s expected <%s> got <%s>" % [message, expected, actual])


func check_near(actual: float, expected: float, tolerance: float = 0.0001, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		fail("%s expected ~%s got %s" % [message, expected, actual])


func frames(count: int = 1) -> void:
	for i in count:
		await tree.process_frame
