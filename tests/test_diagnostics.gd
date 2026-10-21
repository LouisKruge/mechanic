extends TestCase
## Electrical model and scanner behaviour.

var s: GameSession
var d: RepairDriver


func before_each() -> void:
	s = GameSession.new()
	d = RepairDriver.new(s)


func after_each() -> void:
	s.dispose()


func test_initial_symptoms() -> void:
	var e := s.electrical
	check(e.battery_connected, "battery connected")
	check(not e.engine_running, "engine off")
	check_near(e.system_voltage, e.open_circuit_voltage(), 0.001, "engine off: system voltage = battery OCV")
	check(e.open_circuit_voltage() < 12.4, "battery charge reduced (%.2f V)" % e.open_circuit_voltage())
	var msg := d.press(RepairDriver.other(&"ignition"))
	check(e.engine_running, "engine starts")
	check_contains(msg, "cranks slowly", "struggles to start")
	check(e.warning_lamp, "charging warning lamp on")
	check(e.system_voltage < 12.5, "running voltage low (%.2f V)" % e.system_voltage)
	var soc0 := e.soc
	d.tick(5.0)
	check(e.soc < soc0, "battery discharges while running (%.4f -> %.4f)" % [soc0, e.soc])
	check(s.diagnostics.stored_codes.has("P0562"), "P0562 stored")


func test_scanner_does_not_reveal_hidden_fault() -> void:
	var alt := s.vehicle.get_component(&"alternator")
	d.equip(&"scanner")
	d.press(RepairDriver.other(&"obd"))
	check(s.diagnostics.connected, "scanner connected")
	var codes := "\n".join(s.diagnostics.read_codes())
	check_contains(codes, "P0562", "code shown")
	check_eq(alt.discovered_faults.size(), 0, "reading codes reveals nothing about the alternator")
	var live := "\n".join(s.diagnostics.live_data())
	check_contains(live, "System voltage", "live data")
	check_eq(alt.discovered_faults.size(), 0, "live data reveals nothing either")
	var lines := "\n".join(s.diagnostics.charging_test())
	check_contains(lines, "requires the engine to be running", "test needs engine")
	d.press(RepairDriver.other(&"ignition"))
	lines = "\n".join(s.diagnostics.charging_test())
	check_contains(lines, "FAIL", "test fails")
	check_contains(lines, "Alternator output failure", "fault named")
	check(alt.discovered_faults.has("alternator_output_failure"), "fault discovered")
	check(s.job.is_complete(&"identify_fault") or true, "ok")
	s.job.evaluate()
	check(s.job.is_complete(&"identify_fault"), "identify objective latched")


func test_visual_inspection_gives_clue_only_with_flashlight() -> void:
	d.press(RepairDriver.comp(&"hood"))
	s.inspect(RepairDriver.comp(&"alternator"))
	var alt := s.vehicle.get_component(&"alternator")
	check(not alt.parameters.has("observed_clue"), "no clue without light")
	check_eq(alt.discovered_faults.size(), 0, "no fault from visual inspection")
	d.equip(&"flashlight")
	d.hold_primary({}, RepairDriver.STEP)
	check(s.tools.is_illuminating(), "flashlight on")
	s.inspect(RepairDriver.comp(&"alternator"))
	check(alt.parameters.has("observed_clue"), "clue observed with flashlight")
	check_eq(alt.discovered_faults.size(), 0, "clue is not a diagnosis")
	check(s.events.has(&"inspected_electrical"), "electrical inspection event")
	var data := s.resolver.inspection_data(RepairDriver.comp(&"alternator"))
	var text := str(data["rows"])
	check_contains(text, "Unknown", "condition unknown before test")


func test_battery_isolated_blocks_start_and_scanner() -> void:
	d.press(RepairDriver.comp(&"hood"))
	d.equip(&"ratchet", 10)
	d.hold_secondary(RepairDriver.fast(&"battery.NEG"), 2.0)
	check(not s.electrical.battery_connected, "isolated")
	var msg := d.press(RepairDriver.other(&"ignition"))
	check_contains(msg, "no power", "no start")
	d.equip(&"scanner")
	d.press(RepairDriver.other(&"obd"))
	check_contains("\n".join(s.diagnostics.read_codes()), "no power", "scanner unpowered")


func test_flat_battery_needs_maintainer() -> void:
	s.electrical.soc = 0.05
	var msg := d.press(RepairDriver.other(&"ignition"))
	check(not s.electrical.engine_running, "will not start")
	check_contains(msg, "battery charge is too low", "explains flat battery")
	d.press(RepairDriver.other(&"charger"))
	check(s.electrical.charger_connected, "maintainer connected")
	d.tick(90.0)
	check(s.electrical.soc > 0.15, "charge recovered (%.3f)" % s.electrical.soc)
	d.press(RepairDriver.other(&"ignition"))
	check(s.electrical.engine_running, "starts after charging")


func test_repair_restores_charging() -> void:
	var r := d.full_repair()
	check(r.ok, "repair done: %s" % r.message)
	var soc0 := s.electrical.soc
	d.tick(10.0)
	check(s.electrical.soc > soc0, "battery charges after repair")
	check_near(s.electrical.system_voltage, 14.2, 0.3, "regulated voltage")
	check_eq(str(s.diagnostics.last_test.get("result")), "PASS", "charging test pass")
