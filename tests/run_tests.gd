extends SceneTree
## Headless test runner:
##   godot --headless --path . --import          (first run only: builds the class cache)
##   godot --headless --path . -s res://tests/run_tests.gd
## Exit code 0 = all passed.

const SUITES: Array = [
	"res://tests/unit/test_calendar_schedule.gd",
	"res://tests/unit/test_economy.gd",
	"res://tests/unit/test_material.gd",
	"res://tests/unit/test_performance.gd",
	"res://tests/unit/test_kill_tony.gd",
	"res://tests/unit/test_save_load.gd",
	"res://tests/unit/test_progression.gd",
	"res://tests/unit/test_content.gd",
	"res://tests/unit/test_life.gd",
	"res://tests/unit/test_touring.gd",
	"res://tests/unit/test_legacy.gd",
]


func _initialize() -> void:
	var total_checks := 0
	var total_fail := 0
	var skipped: Array = []
	for path in SUITES:
		var script: GDScript = load(path)
		if script == null:
			print("LOAD FAILED: ", path)
			total_fail += 1
			continue
		var methods: Array = []
		for m in script.get_script_method_list():
			var mname: String = str(m["name"])
			if mname.begins_with("test_") and not methods.has(mname):
				methods.append(mname)
		for mname in methods:
			var inst: TestCase = script.new()
			var ret: Variant = inst.call(mname)
			if typeof(ret) == TYPE_STRING and str(ret).begins_with("SKIP"):
				skipped.append("%s::%s %s" % [path.get_file(), mname, ret])
				continue
			total_checks += inst.checks
			if inst.failures.is_empty():
				print("  ok   %s::%s (%d checks)" % [path.get_file(), mname, inst.checks])
			else:
				total_fail += inst.failures.size()
				print("  FAIL %s::%s" % [path.get_file(), mname])
				for f in inst.failures:
					print("         - ", f)
	for sk in skipped:
		print("  skip ", sk)
	print("\n%d checks, %d failures, %d skipped" % [total_checks, total_fail, skipped.size()])
	quit(1 if total_fail > 0 else 0)
