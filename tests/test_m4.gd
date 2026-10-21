extends TestCase
## BMW M4 G82: JOB 101 (LT coolant leak), lift + wheels, thread damage,
## cross-vehicle compatibility, saves and migration.

const V := &"bmw_m4_g82"
static var _db: ContentDatabase
var s: GameSession
var d: RepairDriver


func before_each() -> void:
	if _db == null:
		_db = ContentDatabase.new().load_all()
	s = GameSession.new(_db, V, &"job_101")
	d = RepairDriver.new(s)


func after_each() -> void:
	s.dispose()


func _uid_of(component_id: String) -> String:
	for p: Dictionary in s.inventory.parts:
		if p.get("component_id", "") == component_id:
			return str(p["uid"])
	return ""


func _remove_bolts(prefix: String, ids: Array, seconds: float) -> void:
	for i: Variant in ids:
		d.hold_secondary(RepairDriver.fast(StringName("%s%s" % [prefix, i])), seconds)


func _fit_bolts(prefix: String, ids: Array, socket: int, torque: float, run_s: float) -> void:
	for i: Variant in ids:
		d.press(RepairDriver.fast(StringName("%s%s" % [prefix, i])))
	d.equip(&"ratchet", socket)
	for i: Variant in ids:
		d.hold_primary(RepairDriver.fast(StringName("%s%s" % [prefix, i])), run_s)
	d.equip(&"torque_wrench", socket)
	d.set_torque(torque)
	for i: Variant in ids:
		d.hold_primary(RepairDriver.fast(StringName("%s%s" % [prefix, i])), 6.0)


func _job101() -> ActionResult:
	var fc := s.vehicle.definition.get_fluid_circuit(&"m4_lt_circuit")
	s.record_event(&"approached_vehicle")
	d.press(RepairDriver.other(&"work_order", &"board"))
	d.press(RepairDriver.comp(&"m4_hood"))
	d.equip(&"flashlight")
	d.hold_primary({}, RepairDriver.STEP)
	s.inspect(RepairDriver.comp(&"m4_cc_hose"))
	d.equip(&"scanner")
	d.press(RepairDriver.other(&"obd"))
	d.tick(0.3)
	s.diagnostics.read_codes()
	d.press(RepairDriver.comp(&"m4_trunk"))
	d.equip(&"ratchet", 10)
	d.hold_secondary(RepairDriver.fast(&"m4_battery.NEG"), 2.0)
	d.equip(&"ratchet", 13)
	_remove_bolts("m4_strut_brace.BR", [1, 2, 3, 4], 3.0)
	d.press(RepairDriver.comp(&"m4_strut_brace"))
	d.press(RepairDriver.comp(&"m4_lt_radiator"))       # drain pan
	d.press(RepairDriver.comp(&"m4_lt_expansion_tank")) # cap open
	d.equip(&"ratchet", 10)
	d.hold_secondary(RepairDriver.fast(&"m4_lt_radiator.DRAIN"), 2.5)
	d.tick(10.0)
	d.equip(&"hose_clamp_pliers")
	d.press(RepairDriver.fast(&"m4_cc_hose.CLIP_A"))
	d.press(RepairDriver.fast(&"m4_cc_hose.CLIP_B"))
	d.press(RepairDriver.comp(&"m4_cc_hose"))
	d.press(RepairDriver.other(&"shelf", &"m4_cc_hose"))
	d.press(RepairDriver.comp(&"m4_cc_hose"))
	d.press(RepairDriver.fast(&"m4_cc_hose.CLIP_A"))
	d.press(RepairDriver.fast(&"m4_cc_hose.CLIP_B"))
	d.press(RepairDriver.fast(&"m4_lt_radiator.DRAIN"))
	d.equip(&"ratchet", 10)
	d.hold_primary(RepairDriver.fast(&"m4_lt_radiator.DRAIN"), 3.0)
	d.press(RepairDriver.other(&"shelf", &"fluid:coolant_lt"))
	d.press(RepairDriver.comp(&"m4_lt_expansion_tank"))  # pour
	s.hold_part(_uid_of("m4_strut_brace"))
	d.press(RepairDriver.comp(&"m4_strut_brace"))
	_fit_bolts("m4_strut_brace.BR", [1, 2, 3, 4], 13, 28.0, 2.5)
	d.press(RepairDriver.fast(&"m4_battery.NEG"))
	d.equip(&"ratchet", 10)
	d.hold_primary(RepairDriver.fast(&"m4_battery.NEG"), 2.0)
	d.press(RepairDriver.comp(&"m4_lt_expansion_tank"))  # close cap
	d.equip(&"scanner")
	s.diagnostics.bleed_routine(fc)
	d.press(RepairDriver.comp(&"m4_lt_expansion_tank"))  # open cap
	d.press(RepairDriver.comp(&"m4_lt_expansion_tank"))  # top up
	d.equip(&"pressure_tester")
	s.tool_primary(RepairDriver.comp(&"m4_lt_expansion_tank"), RepairDriver.STEP, true)
	d.press(RepairDriver.comp(&"m4_lt_expansion_tank"))  # close cap
	d.press(RepairDriver.comp(&"m4_lt_radiator"))       # remove pan
	s.job.evaluate()
	return s.try_sign_off()


func test_m4_definition_differs_from_c01() -> void:
	var m4: VehicleDefinition = _db.vehicles[V]
	var c01: VehicleDefinition = _db.vehicles[&"project_c01"]
	check(m4.engine.cylinders == 6 and c01.engine.cylinders == 4, "different engines")
	check(m4.engine.turbo_count() == 2, "twin turbo")
	check(m4.engine.charge_cooling == &"water_to_air", "water-to-air charge cooling")
	check(m4.battery_component == &"m4_battery" and m4.get_component(&"m4_battery").fasteners[0].removal_dependencies[0].subject_id == &"m4_trunk", "battery isolation goes through the trunk")
	check(m4.fluid_circuits.size() == 1, "LT coolant circuit defined")
	var gt3: VehicleDefinition = _db.vehicles[&"porsche_911_gt3_992"]
	var rs3: VehicleDefinition = _db.vehicles[&"audi_rs3_8y"]
	check(gt3.engine.layout == EngineConfiguration.Layout.FLAT and gt3.drivetrain_config.engine_position() == &"rear", "GT3: rear flat-six")
	check(rs3.engine.cylinders == 5 and rs3.engine.mounting == EngineConfiguration.Mounting.TRANSVERSE, "RS3: transverse inline-5")
	check(not gt3.playable and not rs3.playable, "catalogue entries are flagged not playable")
	check(m4.components.size() >= 40, "M4 component graph (%d components)" % m4.components.size())
	for cd: ComponentDefinition in m4.components:
		check(cd.compatible_with.has(String(V)), "%s compatible with the M4" % cd.id)


func test_job101_full_procedure() -> void:
	var r := _job101()
	check(r.ok, "JOB 101 signed off: %s\\nLOG:\\n%s" % [r.message, "\\n".join(d.log)])
	for o: JobObjectiveDefinition in s.job.definition.objectives:
		check(s.job.is_complete(o.id), "objective %s" % o.id)
	check(s.fluids.state(&"m4_lt_circuit", &"full") and s.fluids.state(&"m4_lt_circuit", &"bled"), "circuit full and bled")
	check(s.vehicle.get_component(&"m4_cc_hose").is_fault_free(), "new hose fitted")


func test_leak_blockers_and_drain_rules() -> void:
	d.press(RepairDriver.comp(&"m4_hood"))
	var msg := d.press(RepairDriver.comp(&"m4_cc_hose"))
	check_contains(msg, "strut brace is in the way", "brace blocks hose removal")
	d.equip(&"ratchet", 10)
	d.hold_secondary(RepairDriver.fast(&"m4_lt_radiator.DRAIN"), 1.0)
	check_contains(d.last(), "drain pan", "drain pan required before opening the drain")
	d.press(RepairDriver.comp(&"m4_lt_radiator"))
	d.hold_secondary(RepairDriver.fast(&"m4_lt_radiator.DRAIN"), 1.0)
	check_contains(d.last(), "filler cap", "cap must be opened to vent")
	d.equip(&"")
	d.press(RepairDriver.fast(&"m4_cc_hose.CLIP_A"))
	check_contains(d.last(), "hose clamp pliers", "clips need the pliers")
	d.equip(&"hose_clamp_pliers")
	d.press(RepairDriver.fast(&"m4_cc_hose.CLIP_A"))
	check_contains(d.last(), "drain it first", "clips cannot come off a full circuit")
	var lvl := s.vehicle.fluid_level(&"m4_lt_circuit")
	d.equip(&"scanner")
	d.press(RepairDriver.other(&"obd"))
	d.press(RepairDriver.other(&"ignition"))
	d.tick(20.0)
	check(s.vehicle.fluid_level(&"m4_lt_circuit") < lvl, "seeping hose loses coolant while running")
	check(s.diagnostics.stored_codes.has("SIM-LT01"), "level sensor logs the simulated code")
	d.press(RepairDriver.comp(&"m4_lt_expansion_tank"))
	check_contains(d.last(), "engine running", "cap cannot be opened with the engine running")


func test_pressure_test_finds_leak_and_incomplete_assembly() -> void:
	var fc := s.vehicle.definition.get_fluid_circuit(&"m4_lt_circuit")
	s.vehicle.set_fluid_level(fc.id, fc.capacity_l)
	d.press(RepairDriver.comp(&"m4_hood"))
	d.press(RepairDriver.comp(&"m4_lt_expansion_tank"))
	d.equip(&"pressure_tester")
	s.tool_primary(RepairDriver.comp(&"m4_lt_expansion_tank"), RepairDriver.STEP, true)
	check_contains(d.last(), "FAIL", "pressure test fails with the leaking hose")
	check(s.vehicle.get_component(&"m4_cc_hose").discovered_faults.has("hose_seepage"), "pressure test identifies the leak")
	check(not s.diagnostics.test_valid(&"cooling_pressure_lt"), "failed test is not a pass")


func test_signoff_refused_when_not_bled() -> void:
	var r := _job101_without_bleed()
	check(not r.ok, "sign-off refused")
	check_contains(r.message, "not bled", "report says the circuit was not bled")


func _job101_without_bleed() -> ActionResult:
	# Same procedure as _job101 but skipping the bleed routine.
	var fc := s.vehicle.definition.get_fluid_circuit(&"m4_lt_circuit")
	s.vehicle.get_component(&"m4_cc_hose").faults = PackedStringArray()
	s.vehicle.set_fluid_level(fc.id, fc.capacity_l)
	(s.vehicle.fluids[fc.id] as Dictionary)["bled"] = false
	d.press(RepairDriver.comp(&"m4_hood"))
	d.press(RepairDriver.comp(&"m4_lt_expansion_tank"))
	d.equip(&"pressure_tester")
	s.tool_primary(RepairDriver.comp(&"m4_lt_expansion_tank"), RepairDriver.STEP, true)
	d.press(RepairDriver.comp(&"m4_lt_expansion_tank"))
	return s.try_sign_off()


func test_lift_and_wheel_removal() -> void:
	d.equip(&"ratchet", 17)
	d.hold_secondary(RepairDriver.fast(&"m4_wheel_fl.L1"), 1.0)
	check_contains(d.last(), "not raised on the lift", "wheel bolts need the lift")
	check(s.toggle_lift().ok, "lift raises")
	_remove_bolts("m4_wheel_fl.L", [1, 2, 3, 4, 5], 4.0)
	d.press(RepairDriver.comp(&"m4_wheel_fl"))
	check(not s.vehicle.get_component(&"m4_wheel_fl").installed, "wheel removed")
	var low := s.toggle_lift()
	check(not low.ok and low.message.contains("front left wheel is not fitted"), "lift will not lower onto a hub: %s" % low.message)
	s.hold_part(_uid_of("m4_wheel_fl"))
	d.press(RepairDriver.comp(&"m4_wheel_fl"))
	_fit_bolts("m4_wheel_fl.L", [1, 2, 3, 4, 5], 17, 130.0, 3.5)
	for i: int in range(1, 6):
		check(s.vehicle.get_fastener(StringName("m4_wheel_fl.L%d" % i)).is_to_spec(), "wheel bolt L%d torqued" % i)
	check(s.toggle_lift().ok, "lift lowers with all wheels fitted")


func test_stripped_thread_needs_new_hardware() -> void:
	d.press(RepairDriver.comp(&"m4_hood"))
	d.equip(&"ratchet", 13)
	d.hold_secondary(RepairDriver.fast(&"m4_strut_brace.BR1"), 3.0)
	d.press(RepairDriver.fast(&"m4_strut_brace.BR1"))
	d.hold_primary(RepairDriver.fast(&"m4_strut_brace.BR1"), 3.0)
	d.equip(&"torque_wrench", 13)
	d.set_torque(50.0)  # well over the 28 N·m demo target
	d.hold_primary(RepairDriver.fast(&"m4_strut_brace.BR1"), 3.0)
	var f := s.vehicle.get_fastener(&"m4_strut_brace.BR1")
	check(f.damaged and f.get_state() == FastenerInstance.State.DAMAGED, "threads stripped by over-torque")
	check_contains(ConditionEvaluator.describe_unmet(DependencyCondition.make(&"fastener_state", f.id, &"tight"), s), "stripped", "blocker explains stripped threads")
	d.equip(&"ratchet", 13)
	d.hold_secondary(RepairDriver.fast(&"m4_strut_brace.BR1"), 3.0)
	check(f.removed and not s.inventory.tray_has(f.id), "stripped bolt discarded, not returned to the tray")
	d.press(RepairDriver.fast(&"m4_strut_brace.BR1"))
	check_contains(d.last(), "hardware drawer", "needs new hardware")
	check(s.take_hardware().ok, "hardware drawer supplies spares")
	d.press(RepairDriver.fast(&"m4_strut_brace.BR1"))
	check(not f.removed and not f.damaged, "new bolt fitted")


func test_parts_are_vehicle_specific() -> void:
	d.press(RepairDriver.comp(&"m4_hood"))
	s.vehicle.get_component(&"m4_alternator").installed = false  # empty mount for the check
	var c01_part := {"uid": "x-alt", "component_id": "alternator", "condition": 100.0, "faults": [], "is_new": true}
	var blockers := s.assembly.installation_blockers(&"m4_alternator", c01_part)
	check(blockers.size() > 0 and "\\n".join(blockers).contains("does not fit"), "C01 alternator does not fit the M4: %s" % blockers)


func test_m4_save_round_trip_with_fluids_and_lift() -> void:
	d.press(RepairDriver.comp(&"m4_hood"))
	d.press(RepairDriver.comp(&"m4_lt_radiator"))
	d.press(RepairDriver.comp(&"m4_lt_expansion_tank"))
	d.equip(&"ratchet", 10)
	d.hold_secondary(RepairDriver.fast(&"m4_lt_radiator.DRAIN"), 2.5)
	d.tick(2.0)
	s.toggle_lift()
	s.take_fluid_from_shelf(&"coolant_lt")
	var path := "user://test_saves/m4.json"
	check(SaveManager.save_session(s, path).ok, "saved")
	var b := GameSession.new(_db, V, &"job_101")
	var res := SaveManager.load_into(b, path)
	check(res.get("ok", false), "loaded")
	check_near(b.vehicle.fluid_level(&"m4_lt_circuit"), s.vehicle.fluid_level(&"m4_lt_circuit"), 0.001, "fluid level restored")
	check(b.ctx_world_flag(&"lift_raised"), "lift state restored")
	check_near(b.inventory.fluid_amount(&"coolant_lt"), 6.0, 0.001, "carried coolant restored")
	check(b.vehicle.get_fastener(&"m4_lt_radiator.DRAIN").removed, "drain plug state restored")
	b.dispose()


func test_v1_save_migrates() -> void:
	var v1 := {"format": "garage-save", "version": 1, "vehicle": {"vehicle_id": "project_c01"},
		"diagnostics": {"connected": true, "stored_codes": ["P0562"], "last_test": {"result": "FAIL", "revision": 3}}}
	var res := SaveManager.parse_save_text(JSON.stringify(v1))
	check(res.get("ok", false), "v1 accepted")
	var data: Dictionary = res["data"]
	check_eq(int(data["version"]), SaveManager.VERSION, "upgraded to current version")
	check(((data["diagnostics"] as Dictionary)["test_results"] as Dictionary).has("charging_system"), "last_test moved to test_results")
	var c01 := GameSession.new(_db)
	c01.apply_save_dict(data)
	check_eq(str(c01.diagnostics.last_test.get("result")), "FAIL", "migrated result readable")
	c01.dispose()
