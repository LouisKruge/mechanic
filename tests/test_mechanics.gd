extends TestCase
## Tools, fasteners, dependency engine and the full alternator repair.

var s: GameSession
var d: RepairDriver
static var _db: ContentDatabase


func before_each() -> void:
	if _db == null:
		_db = ContentDatabase.new().load_all()
	s = GameSession.new(_db)
	d = RepairDriver.new(s)


func after_each() -> void:
	s.dispose()


func _prepare_bolt_access() -> void:
	# Everything that must happen before the alternator bolts may be turned.
	d.press(RepairDriver.comp(&"hood"))
	d.equip(&"ratchet", 10)
	d.hold_secondary(RepairDriver.fast(&"battery.NEG"), 2.0)
	d.hold_primary(RepairDriver.comp(&"belt_tensioner"), RepairDriver.STEP)
	d.press(RepairDriver.comp(&"accessory_belt"))


func test_wrong_tools_cannot_remove_bolts() -> void:
	_prepare_bolt_access()
	var b01 := s.vehicle.get_fastener(&"alternator.B01")
	var before := b01.to_dict()
	d.equip(&"")
	d.hold_secondary(RepairDriver.fast(&"alternator.B01"), 1.0)
	check_contains(d.last(), "requires a ratchet", "bare hands refused")
	d.equip(&"flashlight")
	s.tool_secondary(RepairDriver.fast(&"alternator.B01"), 0.5, true)
	check(b01.to_dict() == before, "flashlight does nothing to the bolt")
	d.equip(&"scanner")
	d.hold_secondary(RepairDriver.fast(&"alternator.B01"), 1.0)
	check(b01.to_dict() == before, "scanner does nothing to the bolt")
	d.equip(&"ratchet", 10)
	d.hold_secondary(RepairDriver.fast(&"alternator.B01"), 1.0)
	check_contains(d.last(), "wrong socket", "10 mm socket refused")
	check_contains(d.last(), "13 mm", "message names the right size")
	d.equip(&"torque_wrench", 13)
	d.hold_secondary(RepairDriver.fast(&"alternator.B01"), 1.0)
	check_contains(d.last(), "never loosen", "torque wrench refused for loosening")
	check(b01.to_dict() == before, "bolt unchanged after all wrong-tool attempts")
	check(not b01.removed, "bolt still installed")
	d.equip(&"ratchet", 13)
	d.hold_secondary(RepairDriver.fast(&"alternator.B01"), 4.0)
	check(b01.removed, "correct ratchet + 13 mm removes the bolt")
	check(s.inventory.tray_has(&"alternator.B01"), "bolt is in the tray")


func test_bolts_blocked_until_belt_off_and_battery_isolated() -> void:
	d.press(RepairDriver.comp(&"hood"))
	d.equip(&"ratchet", 13)
	d.hold_secondary(RepairDriver.fast(&"alternator.B01"), 1.0)
	check_contains(d.last(), "belt", "belt still loading alternator blocks bolt")
	check(not s.vehicle.get_fastener(&"alternator.B01").removed, "bolt not removed")


func test_fasteners_block_premature_part_removal() -> void:
	_prepare_bolt_access()
	d.press(RepairDriver.fast(&"alternator.CONN"))
	check(s.vehicle.get_fastener(&"alternator.CONN").removed, "connector disconnected")
	var msg := d.press(RepairDriver.comp(&"alternator"))
	check_contains(msg, "Cannot remove alternator: mounting bolt B01 is still installed.", "B01 named")
	d.equip(&"ratchet", 13)
	d.hold_secondary(RepairDriver.fast(&"alternator.B01"), 4.0)
	msg = d.press(RepairDriver.comp(&"alternator"))
	check_contains(msg, "Cannot remove alternator: mounting bolt B02 is still installed.", "B02 named")
	check(s.vehicle.get_component(&"alternator").installed, "alternator still installed")


func test_dependency_order_is_enforced() -> void:
	var msg := d.press(RepairDriver.comp(&"alternator"))
	check_contains(msg, "hood is closed", "hood first")
	d.press(RepairDriver.comp(&"hood"))
	msg = d.press(RepairDriver.fast(&"alternator.CONN"))
	check_contains(msg, "battery is not isolated", "connector requires isolated battery")
	msg = d.press(RepairDriver.comp(&"accessory_belt"))
	check_contains(msg, "release the tensioner", "belt requires released tensioner")
	d.equip(&"")
	s.tool_primary(RepairDriver.comp(&"belt_tensioner"), 0.016, true)
	check_contains(d.last(), "ratchet", "tensioner needs the ratchet")
	d.equip(&"scanner")
	d.press(RepairDriver.other(&"obd"))
	d.press(RepairDriver.other(&"ignition"))
	check(s.electrical.engine_running, "engine running")
	d.equip(&"ratchet", 10)
	d.hold_primary(RepairDriver.comp(&"belt_tensioner"), RepairDriver.STEP)
	check_contains(d.last(), "engine is running", "cannot release tension with engine running")
	d.hold_secondary(RepairDriver.fast(&"battery.NEG"), 1.0)
	check_contains(d.last(), "engine is running", "cannot isolate battery with engine running")
	var msg2 := d.press(RepairDriver.comp(&"alternator"))
	check_contains(msg2, "Cannot remove alternator", "removal blocked")
	var blockers := s.assembly.removal_blockers(&"alternator")
	check(blockers.size() >= 5, "inspection lists every blocker (%d)" % blockers.size())


func test_alternator_removed_after_dependencies() -> void:
	d.arrive_and_diagnose()
	d.disassemble()
	var alt := s.vehicle.get_component(&"alternator")
	check(not alt.installed, "alternator removed")
	check(s.inventory.has_part(&"alternator", false), "removed alternator in inventory")
	var rec: Dictionary = s.inventory.parts[0]
	check(PackedStringArray(rec["faults"]).has("alternator_output_failure"), "removed part keeps its fault")
	check_near(float(rec["condition"]), 22.0, 0.01, "removed part keeps its condition (minus running wear)")
	check(s.job.is_complete(&"remove_alternator"), "objective complete")


func test_replacement_installs_and_snaps_to_mount() -> void:
	d.arrive_and_diagnose()
	d.disassemble()
	var msg := d.press(RepairDriver.comp(&"alternator"))
	check_contains(msg, "no replacement", "cannot install without holding a part")
	d.fit_new_alternator()
	var alt := s.vehicle.get_component(&"alternator")
	check(alt.installed, "new alternator installed")
	check(alt.is_fault_free(), "new alternator is fault-free")
	check_eq(alt.condition, 100.0, "new alternator condition")
	check_eq(s.shelf_stock(&"alternator"), 0, "shelf stock decremented")
	for f: FastenerInstance in s.vehicle.get_component_fasteners(&"alternator"):
		check(f.removed, "%s starts removed on the new part" % f.id)


func test_bolt_tightening_workflow() -> void:
	d.arrive_and_diagnose()
	d.disassemble()
	d.fit_new_alternator()
	var b01 := s.vehicle.get_fastener(&"alternator.B01")
	d.equip(&"ratchet", 13)
	d.hold_primary(RepairDriver.fast(&"alternator.B01"), 0.5)
	check_contains(d.last(), "start it by hand", "must hand-start first")
	d.press(RepairDriver.fast(&"alternator.B01"))
	check(not b01.removed and b01.thread_progress < 0.5, "hand-started")
	d.hold_primary(RepairDriver.fast(&"alternator.B01"), 4.0)
	check_near(b01.thread_progress, 1.0, 0.001, "seated by ratchet")
	check_near(b01.torque_nm, 22.5, 0.5, "ratchet stops at snug (50 %)")
	check_eq(b01.get_state(), FastenerInstance.State.LOOSE, "snug is not to spec")
	d.equip(&"torque_wrench", 13)
	d.set_torque(60.0)
	d.hold_primary(RepairDriver.fast(&"alternator.B01"), 3.0)
	check_eq(b01.get_state(), FastenerInstance.State.OVERTIGHT, "60 N·m detected as over-torque")
	d.equip(&"ratchet", 13)
	d.hold_secondary(RepairDriver.fast(&"alternator.B01"), 0.5)
	check_eq(b01.torque_nm, 0.0, "broken loose")
	d.hold_primary(RepairDriver.fast(&"alternator.B01"), 1.0)
	d.equip(&"torque_wrench", 13)
	d.set_torque(45.0)
	d.hold_primary(RepairDriver.fast(&"alternator.B01"), 3.0)
	check_eq(b01.get_state(), FastenerInstance.State.TIGHT, "re-torqued to spec")
	check_contains(d.last(), "within spec", "click message reports spec")


func test_full_repair_completes_job() -> void:
	var r := d.full_repair()
	check(r.ok, "sign-off succeeded: %s\nLOG:\n%s" % [r.message, "\n".join(d.log)])
	for o: JobObjectiveDefinition in s.job.definition.objectives:
		check(s.job.is_complete(o.id), "objective %s complete" % o.id)
	check(s.job.signed_off, "job signed off")
	check(s.electrical.charging_ok, "charging restored")
	check(s.electrical.system_voltage >= 13.8, "regulated voltage %.2f" % s.electrical.system_voltage)
	check(not s.electrical.warning_lamp, "warning lamp off")


func test_signoff_refused_with_incomplete_assembly() -> void:
	d.arrive_and_diagnose()
	d.disassemble()
	d.fit_new_alternator()
	# Run B02 down with the ratchet only: snug, but not torqued to spec.
	d.press(RepairDriver.fast(&"alternator.B01"))
	d.press(RepairDriver.fast(&"alternator.B02"))
	d.equip(&"ratchet", 13)
	d.hold_primary(RepairDriver.fast(&"alternator.B01"), 3.5)
	d.hold_primary(RepairDriver.fast(&"alternator.B02"), 3.5)
	d.equip(&"torque_wrench", 13)
	d.set_torque(45.0)
	d.hold_primary(RepairDriver.fast(&"alternator.B01"), 2.5)
	d.reassemble_rest()
	var r := d.verify_and_sign_off()
	check(not r.ok, "sign-off refused")
	check_contains(r.message, "Mounting bolt B02 is not tightened to spec", "report names B02")
	check(s.electrical.charging_ok, "charging works even though assembly is incomplete")
	check(not s.job.signed_off, "job not signed off")
	# Fix it: the earlier charging test is now stale (assembly changed).
	d.equip(&"torque_wrench", 13)
	d.press(RepairDriver.other(&"ignition"))  # stop engine before working
	d.hold_primary(RepairDriver.fast(&"alternator.B02"), 2.5)
	check(not s.diagnostics.charging_test_valid(), "test invalidated by later change")
	var r2 := d.verify_and_sign_off()
	check(r2.ok, "sign-off succeeds after correction: %s" % r2.message)


func test_reinstalling_faulty_part_does_not_fix() -> void:
	d.arrive_and_diagnose()
	d.disassemble()
	var old_uid := str(s.inventory.parts[0]["uid"])
	s.hold_part(old_uid)
	d.press(RepairDriver.comp(&"alternator"))
	check(s.vehicle.get_component(&"alternator").installed, "old alternator refitted")
	d.refit_and_torque_bolts()
	d.reassemble_rest()
	var r := d.verify_and_sign_off()
	check(not r.ok, "sign-off refused")
	check_contains(r.message, "still faulty", "faulty part reported")
	check(not s.electrical.charging_ok, "still not charging")


func test_parts_storage_core_return() -> void:
	d.arrive_and_diagnose()
	d.disassemble()
	var r := s.deposit_core()
	check(r.ok, "used part deposited")
	check_eq(s.inventory.core_bin.size(), 1, "core bin holds the old alternator")
	check(not s.inventory.has_part(&"alternator", false), "inventory empty")
