extends TestCase
## Definition loading, validation, cycle detection and definition/state separation.


func test_definitions_load() -> void:
	var db := ContentDatabase.new().load_all()
	check(db.load_errors.is_empty(), "no load errors: %s" % db.load_errors)
	check_eq(db.tools.size(), 7, "tool count")
	for t: StringName in [&"ratchet", &"socket_set", &"torque_wrench", &"scanner", &"flashlight", &"hose_clamp_pliers", &"pressure_tester"]:
		check(db.tools.has(t), "tool %s present" % t)
	check(db.components.has(&"alternator"), "alternator definition present")
	check(db.vehicles.has(&"project_c01"), "vehicle present")
	check(db.jobs.has(&"job_001"), "job present")
	check_eq((db.jobs[&"job_001"] as JobDefinition).objectives.size(), 22, "JOB 001 has 22 objectives")


func test_validator_accepts_shipped_content() -> void:
	var db := ContentDatabase.new().load_all()
	var errors := MechanicalDependencyValidator.validate(db)
	check(errors.is_empty(), "validator errors: %s" % "\n".join(errors))


func _mini_db(a_deps: Array[DependencyCondition], b_deps: Array[DependencyCondition]) -> ContentDatabase:
	var a := ComponentDefinition.new()
	a.id = &"part_a"
	a.removable = true
	a.removal_dependencies = a_deps
	var b := ComponentDefinition.new()
	b.id = &"part_b"
	b.removable = true
	b.removal_dependencies = b_deps
	var v := VehicleDefinition.new()
	v.id = &"test_car"
	v.components = [a, b]
	v.battery_component = &"part_a"
	v.alternator_component = &"part_a"
	v.starter_component = &"part_a"
	var db := ContentDatabase.new()
	db.register(a)
	db.register(b)
	db.register(v)
	return db


func test_validator_detects_dependency_cycle() -> void:
	var a_deps: Array[DependencyCondition] = [DependencyCondition.make(&"component_installed", &"part_b", &"", false)]
	var b_deps: Array[DependencyCondition] = [DependencyCondition.make(&"component_installed", &"part_a", &"", false)]
	var errors := MechanicalDependencyValidator.validate(_mini_db(a_deps, b_deps))
	var found := false
	for e: String in errors:
		if e.contains("cycle") and e.contains("C:part_a:remove") and e.contains("C:part_b:remove"):
			found = true
	check(found, "mutual removal dependency reported as a cycle; got %s" % errors)


func test_validator_accepts_acyclic_chain() -> void:
	var a_deps: Array[DependencyCondition] = [DependencyCondition.make(&"component_installed", &"part_b", &"", false)]
	var b_deps: Array[DependencyCondition] = []
	var errors := MechanicalDependencyValidator.validate(_mini_db(a_deps, b_deps))
	for e: String in errors:
		check(not e.contains("cycle"), "no false cycle: %s" % e)
	check(true, "ran")


func test_validator_detects_bad_references() -> void:
	var a_deps: Array[DependencyCondition] = [
		DependencyCondition.make(&"component_installed", &"ghost_part"),
		DependencyCondition.make(&"component_flag", &"part_b", &"no_such_flag"),
		DependencyCondition.make(&"fastener_state", &"part_b.X99", &"removed"),
		DependencyCondition.make(&"teleport", &"part_b"),
	]
	var b_deps: Array[DependencyCondition] = []
	var joined := "\n".join(MechanicalDependencyValidator.validate(_mini_db(a_deps, b_deps)))
	check_contains(joined, "unknown component 'ghost_part'", "unknown component reported")
	check_contains(joined, "no flag 'no_such_flag'", "unknown flag reported")
	check_contains(joined, "unknown fastener 'part_b.X99'", "unknown fastener reported")
	check_contains(joined, "unknown condition kind 'teleport'", "unknown kind reported")


func test_cycle_finder_reports_self_loop_and_long_cycle() -> void:
	var g := {"A": PackedStringArray(["A"]), "B": PackedStringArray(["C"]), "C": PackedStringArray(["D"]), "D": PackedStringArray(["B"])}
	var cycles := MechanicalDependencyValidator.find_cycles(g)
	check_eq(cycles.size(), 2, "two cycles found (%s)" % cycles)


func test_runtime_state_does_not_mutate_definitions() -> void:
	var db := ContentDatabase.new().load_all()
	var s1 := GameSession.new(db)
	var s2 := GameSession.new(db)
	var d := RepairDriver.new(s1)
	d.press(RepairDriver.comp(&"hood"))
	var hood_def := db.get_component(&"hood")
	check_eq(hood_def.toggles[0].default_value, false, "hood definition default unchanged")
	check(s1.vehicle.get_component(&"hood").get_flag(&"open"), "session 1 hood open")
	check(not s2.vehicle.get_component(&"hood").get_flag(&"open"), "session 2 hood unaffected")
	var vdef: VehicleDefinition = db.vehicles[&"project_c01"]
	check_eq(float(vdef.initial_state["alternator"]["condition"]), 22.0, "initial_state untouched")
	check_eq(s1.vehicle.get_component(&"alternator").definition, s2.vehicle.get_component(&"alternator").definition, "definitions are shared")
	check(s1.vehicle.get_component(&"alternator") != s2.vehicle.get_component(&"alternator"), "instances are separate")
	s1.dispose()
	s2.dispose()
