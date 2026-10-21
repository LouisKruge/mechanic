extends SceneTree
## Headless test runner.
##   godot --headless --path . --script res://tests/run_tests.gd [-- --only=<suite>]
## Exit code 0 = all passed, 1 = failures.

const SUITES: PackedStringArray = [
	"res://tests/test_content.gd",
	"res://tests/test_mechanics.gd",
	"res://tests/test_diagnostics.gd",
	"res://tests/test_save_load.gd",
	"res://tests/test_m4.gd",
	"res://tests/test_scene.gd",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	InputConfig.ensure_actions()
	var only := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
	var passed := 0
	var failed := 0
	var total_checks := 0
	var t0 := Time.get_ticks_msec()
	for path: String in SUITES:
		if only != "" and not path.contains(only):
			continue
		var script := load(path) as GDScript
		if script == null:
			print("ERROR  cannot load suite %s" % path)
			failed += 1
			continue
		print("\n== %s" % path.get_file())
		var methods: Array = []
		for m: Dictionary in script.get_script_method_list():
			var n: String = m["name"]
			if n.begins_with("test_") and not methods.has(n):
				methods.append(n)
		for n: String in methods:
			var tc: TestCase = script.new()
			tc.tree = self
			tc.before_each()
			await tc.call(n)
			tc.after_each()
			total_checks += tc.checks
			if tc.failures.is_empty() and tc.checks > 0:
				passed += 1
				print("  PASS  %s  (%d checks)" % [n, tc.checks])
			else:
				failed += 1
				print("  FAIL  %s" % n)
				if tc.checks == 0:
					print("        no checks executed")
				for f: String in tc.failures:
					print("        - %s" % f)
	print("\n%d passed, %d failed, %d checks, %.1f s" % [passed, failed, total_checks, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(1 if failed > 0 else 0)
