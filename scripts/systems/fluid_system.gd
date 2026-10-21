class_name FluidSystem
extends RefCounted
## Fluid circuits: draining through a removed drain fastener, leaks from
## faulty components while the engine runs, refilling from inventory and
## bleeding air. All volumes and rates are fictional demonstration values.

## Fill fraction counted as "full" / "empty".
const FULL_FRACTION: float = 0.97
const EMPTY_FRACTION: float = 0.03
## Refilling from below this fill fraction traps air that must be bled.
const AIR_TRAP_FRACTION: float = 0.5

var vehicle: VehicleState
var db: ContentDatabase


func _init(p_vehicle: VehicleState, p_db: ContentDatabase) -> void:
	vehicle = p_vehicle
	db = p_db


func tick(delta: float, engine_running: bool) -> void:
	for fc: FluidCircuitDefinition in vehicle.definition.fluid_circuits:
		var level := vehicle.fluid_level(fc.id)
		if level <= 0.0:
			continue
		var next := level
		var drain := vehicle.get_fastener(fc.drain_fastener)
		if drain and drain.removed:
			next -= fc.drain_rate_lps * delta
		if engine_running:
			next -= leak_rate_l_per_h(fc) * delta * ElectricalSystem.SIM_TIME_SCALE / 3600.0
		if vehicle.set_fluid_level(fc.id, next):
			vehicle.notify_fluid(fc.id)


## Litres per simulated hour lost through faulty or missing leak components.
func leak_rate_l_per_h(fc: FluidCircuitDefinition) -> float:
	var rate := 0.0
	for cid: String in fc.leak_components:
		var inst := vehicle.get_component(StringName(cid))
		if inst == null:
			continue
		if not inst.installed:
			rate += 600.0  # an open pipe
			continue
		for f: String in inst.faults:
			var fd := db.get_fault(StringName(f))
			if fd:
				rate += fd.leak_rate_l_per_h
	return rate


func state(circuit_id: StringName, key: StringName) -> bool:
	var fc := vehicle.definition.get_fluid_circuit(circuit_id)
	if fc == null:
		return false
	var lvl := vehicle.fluid_level(circuit_id)
	match key:
		&"full": return lvl >= fc.capacity_l * FULL_FRACTION
		&"empty": return lvl <= fc.capacity_l * EMPTY_FRACTION
		&"low": return lvl < fc.capacity_l * fc.low_level_fraction
		&"bled": return bool((vehicle.fluids.get(circuit_id, {}) as Dictionary).get("bled", true))
	return false


func circuit_for_fill(component_id: StringName) -> FluidCircuitDefinition:
	for fc: FluidCircuitDefinition in vehicle.definition.fluid_circuits:
		if fc.fill_component == component_id:
			return fc
	return null


func fill_blocker(fc: FluidCircuitDefinition) -> String:
	var fill := vehicle.get_component(fc.fill_component)
	if fill == null or not fill.get_flag(fc.cap_flag):
		return "the filler cap is closed"
	var drain := vehicle.get_fastener(fc.drain_fastener)
	if drain == null or drain.removed:
		return "the drain is open — refit the drain plug first"
	if state(fc.id, &"full"):
		return "the %s is already full" % fc.display_name.to_lower()
	return ""


## Pours fluid from inventory into the circuit up to capacity.
func refill(fc: FluidCircuitDefinition, inventory: InventoryManager) -> ActionResult:
	var why := fill_blocker(fc)
	if why != "":
		return ActionResult.fail("Cannot refill: %s." % why)
	var have := inventory.fluid_amount(fc.fluid_id)
	if have <= 0.0:
		return ActionResult.fail("Cannot refill: no %s in inventory (parts shelf)." % fc.fluid_id.replace("_", " "))
	var before := vehicle.fluid_level(fc.id)
	var need := fc.capacity_l - before
	var take := minf(need, have)
	inventory.take_fluid(fc.fluid_id, take)
	vehicle.set_fluid_level(fc.id, before + take)
	# Refilling a drained circuit traps air; a small top-up does not.
	if fc.requires_bleed and before < fc.capacity_l * AIR_TRAP_FRACTION:
		(vehicle.fluids[fc.id] as Dictionary)["bled"] = false
	vehicle.notify_fluid(fc.id)
	var tail := " Bleed the air out with the scanner routine." if fc.requires_bleed and not state(fc.id, &"bled") else ""
	return ActionResult.success("Added %.1f L — %s at %.1f / %.1f L.%s" % [take, fc.display_name.to_lower(), vehicle.fluid_level(fc.id), fc.capacity_l, tail])


## Marks the circuit bled; trapped air leaves and the level drops.
func bleed(fc: FluidCircuitDefinition) -> void:
	(vehicle.fluids[fc.id] as Dictionary)["bled"] = true
	vehicle.set_fluid_level(fc.id, vehicle.fluid_level(fc.id) - fc.capacity_l * fc.bleed_loss_fraction)
	vehicle.notify_fluid(fc.id)


func level_text(fc: FluidCircuitDefinition) -> String:
	var lvl := vehicle.fluid_level(fc.id)
	return "%.1f / %.1f L (%d %%)" % [lvl, fc.capacity_l, int(100.0 * lvl / fc.capacity_l)]
