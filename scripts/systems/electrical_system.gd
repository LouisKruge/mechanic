class_name ElectricalSystem
extends RefCounted
## Simplified 12 V charging-system model.
##
## Relationships (all values are simulated, not measured from a real car):
##  * Battery open-circuit voltage rises linearly with state of charge,
##    from OCV_EMPTY (0 %) to OCV_FULL (100 %).
##  * With the engine running, the alternator can supply up to
##    rated_output × idle fraction × health factor, but only when the
##    vehicle's charging_path conditions hold (belt driven, wired, tensioned).
##  * If that covers the running load, the surplus charges the battery (limited
##    by charge acceptance) and the regulator holds the system near its setpoint.
##  * Otherwise the battery supplies the deficit: its terminal voltage sags
##    below OCV and the state of charge falls.
##  * Cranking draws the starter current through the battery's internal
##    resistance; below MIN_CRANK_V the engine will not turn over.
##
## Time is accelerated by SIM_TIME_SCALE so charge changes are visible in play.

signal state_changed

const SIM_TIME_SCALE: float = 20.0
const OCV_EMPTY: float = 11.89
const OCV_FULL: float = 12.65
const MIN_CRANK_V: float = 9.6
const SLOW_CRANK_V: float = 10.5
const MAX_CHARGE_ACCEPT_A: float = 30.0
const MIN_CHARGE_ACCEPT_A: float = 2.0
const CHARGER_CURRENT_A: float = 12.0
## Voltage the charge-warning lamp compares against while running.
const LAMP_THRESHOLD_V: float = 13.0
const CRANK_SECONDS: float = 2.0
const IDLE_RPM: float = 850.0

var vehicle: VehicleState
var ctx: ConditionContext
var soc: float = 0.8
var engine_running: bool = false
var charger_connected: bool = false

# Last computed operating point (read by diagnostics/UI).
var battery_connected: bool = false
var system_voltage: float = 0.0
var alternator_capacity_a: float = 0.0
var alternator_output_a: float = 0.0
var load_a: float = 0.0
var battery_current_a: float = 0.0  # + charging, - discharging
var charging_ok: bool = false
var warning_lamp: bool = false


func _init(p_vehicle: VehicleState, p_ctx: ConditionContext) -> void:
	vehicle = p_vehicle
	ctx = p_ctx
	soc = p_vehicle.definition.initial_battery_soc
	recompute()


func _battery() -> ComponentInstance:
	return vehicle.get_component(vehicle.definition.battery_component)


func _alternator() -> ComponentInstance:
	return vehicle.get_component(vehicle.definition.alternator_component)


func _starter() -> ComponentInstance:
	return vehicle.get_component(vehicle.definition.starter_component)


func capacity_ah() -> float:
	var b := _battery()
	return b.definition.perf("capacity_ah", 50.0) if b else 50.0


func internal_resistance() -> float:
	var b := _battery()
	var r := b.definition.perf("internal_resistance_ohm", 0.012) if b else 0.012
	# A worn battery has higher internal resistance.
	if b:
		r *= lerpf(2.0, 1.0, clampf(b.condition / 100.0, 0.0, 1.0))
	return r


## Battery open-circuit voltage from state of charge.
func open_circuit_voltage() -> float:
	return OCV_EMPTY + (OCV_FULL - OCV_EMPTY) * clampf(soc, 0.0, 1.0)


## Maximum current the alternator can deliver right now (A).
func alternator_capability() -> float:
	if not engine_running:
		return 0.0
	var alt := _alternator()
	if alt == null or not alt.installed:
		return 0.0
	if not ConditionEvaluator.all_met(vehicle.definition.charging_path, ctx):
		return 0.0
	if alt.condition < alt.definition.min_functional_condition:
		return 0.0
	var rated := alt.definition.perf("rated_output_a", 90.0)
	var idle_fraction := alt.definition.perf("idle_output_fraction", 0.65)
	var health := lerpf(0.6, 1.0, clampf(alt.condition / 100.0, 0.0, 1.0))
	var fault_factor := 1.0
	for f: String in alt.faults:
		var fd := ctx.ctx_fault_def(StringName(f))
		if fd:
			fault_factor *= fd.output_factor
	return rated * idle_fraction * health * fault_factor


func regulator_setpoint() -> float:
	var alt := _alternator()
	return alt.definition.perf("regulator_setpoint_v", 14.2) if alt else 14.2


## Recomputes the operating point without advancing time.
func recompute() -> void:
	battery_connected = ConditionEvaluator.all_met(vehicle.definition.battery_connection, ctx)
	if engine_running and not battery_connected:
		# Losing the battery connection stops the (ignition-powered) engine.
		engine_running = false
	var ocv := open_circuit_voltage()
	load_a = vehicle.definition.running_load_a if engine_running else 0.0
	alternator_capacity_a = alternator_capability()
	var charger_a := CHARGER_CURRENT_A if (charger_connected and soc < 0.999) else 0.0
	if not battery_connected:
		# Vehicle side sees nothing; battery itself may still be on the maintainer.
		system_voltage = 0.0
		alternator_output_a = 0.0
		battery_current_a = charger_a
		charging_ok = false
	elif engine_running and alternator_capacity_a >= load_a:
		var surplus := alternator_capacity_a - load_a
		var accept := lerpf(MAX_CHARGE_ACCEPT_A, MIN_CHARGE_ACCEPT_A, clampf(soc, 0.0, 1.0))
		var reg := regulator_setpoint()
		if surplus >= accept:
			battery_current_a = accept
			system_voltage = reg
		else:
			battery_current_a = surplus
			system_voltage = ocv + (reg - ocv) * (surplus / maxf(accept, 0.001))
		alternator_output_a = load_a + battery_current_a
		battery_current_a += charger_a
		charging_ok = system_voltage >= LAMP_THRESHOLD_V
	else:
		var deficit := load_a - alternator_capacity_a
		alternator_output_a = alternator_capacity_a
		battery_current_a = charger_a - deficit
		system_voltage = ocv - deficit * internal_resistance()
		if charger_a > 0.0 and not engine_running:
			system_voltage = ocv + 0.35
		charging_ok = false
	warning_lamp = engine_running and not charging_ok
	state_changed.emit()


## Advances the model by [param delta] real seconds.
func tick(delta: float) -> void:
	recompute()
	var hours := delta * SIM_TIME_SCALE / 3600.0
	soc = clampf(soc + battery_current_a * hours / capacity_ah(), 0.0, 1.0)
	if engine_running:
		var alt := _alternator()
		if alt and alt.installed and alt.definition.wear_per_hour > 0.0:
			alt.condition = maxf(0.0, alt.condition - alt.definition.wear_per_hour * hours)


## Voltage at the battery while cranking.
func cranking_voltage() -> float:
	var starter := _starter()
	var crank_a := starter.definition.perf("crank_current_a", 150.0) if starter else 150.0
	return open_circuit_voltage() - crank_a * internal_resistance()


## Ignition key: starts a stopped engine or stops a running one.
func toggle_engine() -> ActionResult:
	if engine_running:
		engine_running = false
		recompute()
		return ActionResult.success("Engine stopped.", false)
	return try_start()


func try_start() -> ActionResult:
	battery_connected = ConditionEvaluator.all_met(vehicle.definition.battery_connection, ctx)
	if not battery_connected:
		return ActionResult.fail("Nothing happens — no power. The battery is disconnected.")
	var blocker := ConditionEvaluator.first_unmet(vehicle.definition.start_requirements, ctx)
	if blocker != "":
		return ActionResult.fail("Engine start refused: %s." % blocker)
	var starter := _starter()
	if starter == null or not starter.installed or starter.condition < starter.definition.min_functional_condition:
		return ActionResult.fail("Nothing but a click — the starter does not engage.")
	var vcrank := cranking_voltage()
	if vcrank < MIN_CRANK_V:
		return ActionResult.fail("Starter clicks but cannot turn the engine (cranking voltage %.1f V). Battery charge is too low — use the battery maintainer." % vcrank)
	# Cranking consumes a little charge.
	var crank_a := starter.definition.perf("crank_current_a", 150.0)
	soc = clampf(soc - crank_a * CRANK_SECONDS / 3600.0 / capacity_ah(), 0.0, 1.0)
	engine_running = true
	recompute()
	if vcrank < SLOW_CRANK_V:
		return ActionResult.success("The engine cranks slowly (%.1f V) ... and starts." % vcrank, false)
	return ActionResult.success("Engine started (cranking voltage %.1f V)." % vcrank, false)


func rpm() -> float:
	return IDLE_RPM if engine_running else 0.0


func to_dict() -> Dictionary:
	return {
		"soc": snappedf(soc, 0.0001),
		"engine_running": engine_running,
		"charger_connected": charger_connected,
	}


func from_dict(d: Dictionary) -> void:
	soc = clampf(float(d.get("soc", soc)), 0.0, 1.0)
	engine_running = bool(d.get("engine_running", false))
	charger_connected = bool(d.get("charger_connected", false))
	recompute()
