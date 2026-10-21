class_name DiagnosticManager
extends RefCounted
## The handheld diagnostic scanner and the faults it can (and cannot) reveal.
##
## Reading codes reports what the engine computer has logged (a symptom), not
## which part failed. Only the charging-system test, run with the engine
## running, measures alternator output and can identify an alternator fault.
## Results are stamped with the vehicle's assembly revision so a pass is only
## valid until something is changed again.

signal scanner_changed
signal fault_discovered(component_id: StringName, fault_id: StringName)
signal codes_read

## Generic OBD-II codes used by the simulation. Descriptions follow the SAE
## generic meaning; freeze-frame details shown in game are simulated.
const DTC_INFO: Dictionary = {
	"P0562": "System Voltage Low",
	"P0563": "System Voltage High",
	# Codes prefixed SIM- are invented for this game and are not real fault codes.
	"SIM-LT01": "Low-temperature coolant level low (simulated code)",
}
const PASS_MIN_V: float = 13.4
const PASS_MAX_V: float = 14.8
## Real seconds of low system voltage before P0562 is logged.
const LOW_VOLTAGE_LOG_SECONDS: float = 3.0
const LOW_VOLTAGE_V: float = 12.6

var vehicle: VehicleState
var electrical: ElectricalSystem
var tools: ToolManager
var db: ContentDatabase
var connected: bool = false
var stored_codes: PackedStringArray = PackedStringArray()
## Results by test ID: {result, revision, summary, ...}. A result is valid only
## while the vehicle's assembly revision is unchanged.
var test_results: Dictionary = {}
## Last charging-system test (kept as a named accessor for the UI).
var last_test: Dictionary:
	get:
		return test_results.get("charging_system", {})
	set(value):
		test_results["charging_system"] = value
## Set by the session; used for fluid routines and level sensors.
var fluids: FluidSystem
var _low_voltage_time: float = 0.0


func _init(p_vehicle: VehicleState, p_electrical: ElectricalSystem, p_tools: ToolManager, p_db: ContentDatabase) -> void:
	vehicle = p_vehicle
	electrical = p_electrical
	tools = p_tools
	db = p_db


func connect_scanner() -> ActionResult:
	if tools.equipped != &"scanner":
		return ActionResult.fail("Equip the diagnostic scanner first.")
	connected = true
	scanner_changed.emit()
	return ActionResult.success("Scanner connected to the diagnostic port.", false)


func disconnect_scanner() -> void:
	connected = false
	scanner_changed.emit()


## The scanner is powered from the diagnostic port, i.e. from the vehicle battery.
func is_powered() -> bool:
	return connected and electrical.battery_connected


func _require_power() -> String:
	if not connected:
		return "Scanner is not connected to the vehicle."
	if not electrical.battery_connected:
		return "Scanner screen stays blank — no power at the diagnostic port (battery disconnected)."
	return ""


func read_codes() -> PackedStringArray:
	var err := _require_power()
	if err != "":
		return PackedStringArray([err])
	codes_read.emit()
	if stored_codes.is_empty():
		return PackedStringArray(["No stored diagnostic trouble codes."])
	var out := PackedStringArray()
	for c: String in stored_codes:
		out.append("%s  %s  (%s, stored)" % [c, DTC_INFO.get(c, "Unknown"), "game-specific" if c.begins_with("SIM-") else "generic OBD-II"])
	out.append("Codes describe symptoms. Run the charging-system test to locate the cause.")
	return out


func clear_codes() -> String:
	var err := _require_power()
	if err != "":
		return err
	stored_codes.clear()
	scanner_changed.emit()
	return "Stored codes cleared."


## Live data readout. Marks the battery as electrically tested.
func live_data() -> PackedStringArray:
	var err := _require_power()
	if err != "":
		return PackedStringArray([err])
	var batt := vehicle.get_component(vehicle.definition.battery_component)
	if batt and batt.inspection != ComponentInstance.Inspection.TESTED:
		batt.inspection = ComponentInstance.Inspection.TESTED
		vehicle.component_changed.emit(batt.component_id)
	var lines := PackedStringArray([
		"Engine:            %s" % ("RUNNING  %d rpm" % int(electrical.rpm()) if electrical.engine_running else "OFF"),
		"System voltage:    %.2f V" % electrical.system_voltage,
		"Charge lamp:       %s" % ("ON" if electrical.warning_lamp else "OFF"),
		"Electrical load:   %.0f A (est.)" % electrical.load_a,
		"Charging status:   %s" % ("CHARGING" if electrical.charging_ok else "NOT CHARGING"),
	])
	if fluids:
		for fc: FluidCircuitDefinition in vehicle.definition.fluid_circuits:
			lines.append("%s %s%s" % [(fc.display_name + ":").rpad(19), fluids.level_text(fc), "" if fluids.state(fc.id, &"bled") else "  (air in system)"])
	return lines


## Runs the charging-system test. Returns the report lines.
func charging_test() -> PackedStringArray:
	var err := _require_power()
	if err != "":
		return PackedStringArray([err])
	if not electrical.engine_running:
		return PackedStringArray(["Charging-system test requires the engine to be running."])
	electrical.recompute()
	var v := electrical.system_voltage
	var out_a := electrical.alternator_output_a
	var load := electrical.load_a
	var passed := v >= PASS_MIN_V and v <= PASS_MAX_V and electrical.alternator_capacity_a >= load
	var lines := PackedStringArray()
	lines.append("CHARGING SYSTEM TEST — %s" % ("PASS" if passed else "FAIL"))
	lines.append("Regulated voltage:  %.2f V   (expected %.1f – %.1f V)" % [v, PASS_MIN_V, PASS_MAX_V])
	lines.append("Generator output:   %.0f A   (demand %.0f A)" % [out_a, load])
	var alt := vehicle.get_component(vehicle.definition.alternator_component)
	var summary := ""
	if passed:
		summary = "Charging system operating normally."
		if alt:
			alt.inspection = ComponentInstance.Inspection.TESTED
	else:
		var path_ok := ConditionEvaluator.all_met(vehicle.definition.charging_path, electrical.ctx)
		if not path_ok or alt == null or not alt.installed:
			summary = "No generator output detected. Check the drive belt, tension and wiring."
		elif not alt.faults.is_empty():
			alt.inspection = ComponentInstance.Inspection.TESTED
			var names := PackedStringArray()
			for f: String in alt.faults:
				var fd := db.get_fault(StringName(f))
				if fd and fd.discovery_methods.has("charging_test"):
					names.append(fd.display_name)
					if not alt.discovered_faults.has(f):
						alt.discovered_faults.append(f)
						fault_discovered.emit(alt.component_id, StringName(f))
			summary = "Diagnosis: %s. Generator output far below demand with drive and wiring intact." % ", ".join(names)
		else:
			summary = "Generator output low. Alternator worn (condition %.0f %%)." % alt.condition
			alt.inspection = ComponentInstance.Inspection.TESTED
		if alt:
			vehicle.component_changed.emit(alt.component_id)
	lines.append(summary)
	test_results["charging_system"] = {
		"result": "PASS" if passed else "FAIL",
		"voltage": snappedf(v, 0.01),
		"output_a": snappedf(out_a, 0.1),
		"load_a": load,
		"revision": vehicle.revision,
		"summary": summary,
	}
	scanner_changed.emit()
	return lines


## True when the last charging test passed and nothing changed since.
func charging_test_valid() -> bool:
	return test_valid(&"charging_system")


func test_valid(test_id: StringName) -> bool:
	var r: Dictionary = test_results.get(String(test_id), {})
	return r.get("result", "") == "PASS" and int(r.get("revision", -1)) == vehicle.revision


## Cooling-system pressure test on a fluid circuit. Needs the tester fitted to
## the open filler neck and a full circuit. Fails on leaks, missing clips or an
## open drain, and identifies leak faults that list "pressure_test" discovery.
func pressure_test(fc: FluidCircuitDefinition) -> PackedStringArray:
	var lines := PackedStringArray()
	var fill := vehicle.get_component(fc.fill_component)
	if fill == null or not fill.get_flag(fc.cap_flag):
		return PackedStringArray(["Open the filler cap and fit the tester adapter to the filler neck first."])
	if not fluids.state(fc.id, &"full"):
		return PackedStringArray(["Circuit not full (%s). Fill it before pressure testing." % fluids.level_text(fc)])
	var problems := PackedStringArray()
	var drain := vehicle.get_fastener(fc.drain_fastener)
	if drain == null or drain.removed or drain.damaged:
		problems.append("Pressure escapes at the drain plug.")
	for cid: String in fc.leak_components:
		var inst := vehicle.get_component(StringName(cid))
		if inst == null or not inst.installed:
			problems.append("Open connection: %s missing." % (inst.definition.display_name if inst else cid))
			continue
		for f: FastenerInstance in vehicle.get_component_fasteners(inst.component_id):
			if f.removed:
				problems.append("Pressure escapes at %s (not fitted)." % f.display_name().to_lower())
		for fid: String in inst.faults:
			var fd := db.get_fault(StringName(fid))
			if fd and fd.leak_rate_l_per_h > 0.0:
				problems.append("Pressure drops: seepage at the %s." % inst.definition.display_name.to_lower())
				if fd.discovery_methods.has("pressure_test") and not inst.discovered_faults.has(fid):
					inst.discovered_faults.append(fid)
					inst.inspection = ComponentInstance.Inspection.TESTED
					fault_discovered.emit(inst.component_id, StringName(fid))
					vehicle.component_changed.emit(inst.component_id)
	var passed := problems.is_empty()
	lines.append("PRESSURE TEST — %s — %s" % [fc.display_name.to_upper(), "PASS" if passed else "FAIL"])
	lines.append("Hold pressure: %s  (test pressure is a fictional demonstration value)" % ("stable" if passed else "falling"))
	lines.append_array(problems)
	test_results[String(fc.pressure_test_id)] = {"result": "PASS" if passed else "FAIL", "revision": vehicle.revision, "summary": "\n".join(problems)}
	scanner_changed.emit()
	return lines


## Scanner routine: runs the electric pump to purge air. Needs power, a
## closed cap and a nearly full circuit; the level drops as air leaves.
func bleed_routine(fc: FluidCircuitDefinition) -> PackedStringArray:
	var err := _require_power()
	if err != "":
		return PackedStringArray([err])
	var fill := vehicle.get_component(fc.fill_component)
	if fill and fill.get_flag(fc.cap_flag):
		return PackedStringArray(["Close the filler cap before running the bleed routine."])
	if vehicle.fluid_level(fc.id) < fc.capacity_l * 0.9:
		return PackedStringArray(["Level too low to bleed (%s). Fill the circuit first." % fluids.level_text(fc)])
	if fluids.state(fc.id, &"bled"):
		return PackedStringArray(["%s: no air detected." % fc.display_name])
	fluids.bleed(fc)
	return PackedStringArray(["BLEED ROUTINE — %s" % fc.display_name.to_upper(), "Electric pump cycled; air purged.", "Level now %s — top up to full." % fluids.level_text(fc)])


func bleedable_circuits() -> Array[FluidCircuitDefinition]:
	var out: Array[FluidCircuitDefinition] = []
	for fc: FluidCircuitDefinition in vehicle.definition.fluid_circuits:
		if fc.requires_bleed:
			out.append(fc)
	return out


func tick(delta: float) -> void:
	if electrical.engine_running and electrical.battery_connected and electrical.system_voltage < LOW_VOLTAGE_V:
		_low_voltage_time += delta
		if _low_voltage_time >= LOW_VOLTAGE_LOG_SECONDS and not stored_codes.has("P0562"):
			stored_codes.append("P0562")
			scanner_changed.emit()
	else:
		_low_voltage_time = 0.0
	if fluids and electrical.battery_connected:
		for fc: FluidCircuitDefinition in vehicle.definition.fluid_circuits:
			if fc.low_level_dtc != "" and fluids.state(fc.id, &"low") and not stored_codes.has(fc.low_level_dtc):
				stored_codes.append(fc.low_level_dtc)
				scanner_changed.emit()


func to_dict() -> Dictionary:
	return {
		"connected": connected,
		"stored_codes": Array(stored_codes),
		"test_results": test_results.duplicate(true),
	}


func from_dict(d: Dictionary) -> void:
	connected = bool(d.get("connected", false))
	stored_codes = PackedStringArray()
	for c: Variant in d.get("stored_codes", []):
		if DTC_INFO.has(str(c)):
			stored_codes.append(str(c))
	test_results = {}
	var tr: Variant = d.get("test_results", {})
	if tr is Dictionary:
		for k: Variant in tr:
			if tr[k] is Dictionary:
				test_results[str(k)] = (tr[k] as Dictionary).duplicate()
	scanner_changed.emit()
