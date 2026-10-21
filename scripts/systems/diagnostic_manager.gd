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

## Generic OBD-II codes used by the simulation. Descriptions follow the SAE
## generic meaning; freeze-frame details shown in game are simulated.
const DTC_INFO: Dictionary = {
	"P0562": "System Voltage Low",
	"P0563": "System Voltage High",
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
## Last charging test: {result, voltage, output_a, load_a, revision, summary}.
var last_test: Dictionary = {}
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
	if stored_codes.is_empty():
		return PackedStringArray(["No stored diagnostic trouble codes."])
	var out := PackedStringArray()
	for c: String in stored_codes:
		out.append("%s  %s  (generic OBD-II, stored)" % [c, DTC_INFO.get(c, "Unknown")])
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
	return PackedStringArray([
		"Engine:            %s" % ("RUNNING  %d rpm" % int(electrical.rpm()) if electrical.engine_running else "OFF"),
		"System voltage:    %.2f V" % electrical.system_voltage,
		"Charge lamp:       %s" % ("ON" if electrical.warning_lamp else "OFF"),
		"Electrical load:   %.0f A (est.)" % electrical.load_a,
		"Charging status:   %s" % ("CHARGING" if electrical.charging_ok else "NOT CHARGING"),
	])


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
	last_test = {
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
	return last_test.get("result", "") == "PASS" and int(last_test.get("revision", -1)) == vehicle.revision


func tick(delta: float) -> void:
	if electrical.engine_running and electrical.battery_connected and electrical.system_voltage < LOW_VOLTAGE_V:
		_low_voltage_time += delta
		if _low_voltage_time >= LOW_VOLTAGE_LOG_SECONDS and not stored_codes.has("P0562"):
			stored_codes.append("P0562")
			scanner_changed.emit()
	else:
		_low_voltage_time = 0.0


func to_dict() -> Dictionary:
	return {
		"connected": connected,
		"stored_codes": Array(stored_codes),
		"last_test": last_test.duplicate(),
	}


func from_dict(d: Dictionary) -> void:
	connected = bool(d.get("connected", false))
	stored_codes = PackedStringArray()
	for c: Variant in d.get("stored_codes", []):
		if DTC_INFO.has(str(c)):
			stored_codes.append(str(c))
	var lt: Variant = d.get("last_test", {})
	last_test = (lt as Dictionary).duplicate() if lt is Dictionary else {}
	scanner_changed.emit()
