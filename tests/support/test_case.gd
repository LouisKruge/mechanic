class_name TestCase
extends RefCounted
## Minimal assertion base for the headless test runner (tests/run_tests.gd).
## Test methods are named test_* and may be coroutines (await tree frames).

var tree: SceneTree
var failures: PackedStringArray = PackedStringArray()
var checks: int = 0


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func check(cond: bool, msg: String) -> bool:
	checks += 1
	if not cond:
		failures.append(msg)
	return cond


func check_eq(actual: Variant, expected: Variant, msg: String) -> bool:
	return check(actual == expected, "%s — expected <%s>, got <%s>" % [msg, expected, actual])


func check_contains(haystack: String, needle: String, msg: String) -> bool:
	return check(haystack.to_lower().contains(needle.to_lower()), "%s — '%s' not found in '%s'" % [msg, needle, haystack])


func check_near(actual: float, expected: float, tol: float, msg: String) -> bool:
	return check(absf(actual - expected) <= tol, "%s — expected %.3f ± %.3f, got %.3f" % [msg, expected, tol, actual])
