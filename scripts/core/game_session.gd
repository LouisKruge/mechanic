class_name GameSession
extends ConditionContext
## Composition root for one play session (the "GameManager").
##
## Owns every gameplay system as plain objects so the full repair loop can be
## driven headlessly by tests. Scene nodes (player, vehicle view, UI) observe
## the session through signals and call its public input methods.

signal message_posted(text: String, ok: bool)
signal inspect_requested(target: Dictionary)
signal panel_requested(panel: StringName)
signal engine_state_changed(running: bool)
signal world_changed
signal job_finished(job_id: StringName)
signal lift_changed(raised: bool)

const DEFAULT_VEHICLE: StringName = &"project_c01"
const DEFAULT_JOB: StringName = &"job_001"
const OBJECTIVE_EVAL_INTERVAL: float = 0.2

var db: ContentDatabase
var vehicle: VehicleState
var inventory: InventoryManager
var tools: ToolManager
var electrical: ElectricalSystem
var fluids: FluidSystem
var diagnostics: DiagnosticManager
var job: JobManager
var assembly: AssemblyService
var resolver: InteractionResolver
## One-shot gameplay events (entered_workshop, read_work_order, ...).
var events: Dictionary = {}
## Workshop state outside the vehicle: {"shelf_stock": {component_id: count}}.
var world: Dictionary = {}
## Last known player pose, kept here so saves don't depend on scene nodes.
var player_state: Dictionary = {}
var validation_errors: PackedStringArray = PackedStringArray()

var _last_message: String = ""
var _eval_timer: float = 0.0
var _last_engine_running: bool = false
var _stock_counter: int = 0


## Builds a fresh session. Pass a preloaded database to share it between sessions.
func _init(p_db: ContentDatabase = null, vehicle_id: StringName = DEFAULT_VEHICLE, job_id: StringName = DEFAULT_JOB) -> void:
	db = p_db if p_db else ContentDatabase.new().load_all()
	validation_errors = MechanicalDependencyValidator.validate(db)
	validation_errors.append_array(db.load_errors)
	for e: String in validation_errors:
		push_error("Content validation: " + e)
	var vdef: VehicleDefinition = db.vehicles.get(vehicle_id, null)
	assert(vdef != null, "Vehicle definition '%s' missing" % vehicle_id)
	vehicle = VehicleState.new(vdef)
	inventory = InventoryManager.new()
	tools = ToolManager.new(db, inventory)
	electrical = ElectricalSystem.new(vehicle, self)
	fluids = FluidSystem.new(vehicle, db)
	diagnostics = DiagnosticManager.new(vehicle, electrical, tools, db)
	diagnostics.fluids = fluids
	for code: String in vdef.initial_dtcs:
		diagnostics.stored_codes.append(code)
	var jdef: JobDefinition = db.jobs.get(job_id, null)
	assert(jdef != null, "Job definition '%s' missing" % job_id)
	job = JobManager.new(jdef, self)
	assembly = AssemblyService.new(vehicle, inventory, tools, db, self)
	resolver = InteractionResolver.new(self)
	for tid: StringName in db.tools:
		inventory.owned_tools.append(String(tid))
	inventory.owned_tools.sort()
	world = {
		"shelf_stock": jdef.supplied_parts.duplicate(),
		"fluid_stock": jdef.supplied_fluids.duplicate(),
		"hardware_stock": jdef.supplied_hardware.duplicate(),
		"flags": {"lift_raised": false},
	}
	vehicle.revision_changed.connect(func(_r: int) -> void: _on_state_changed())
	tools.changed.connect(_on_state_changed)
	inventory.changed.connect(_on_state_changed)
	diagnostics.fault_discovered.connect(func(_c: StringName, _f: StringName) -> void: _on_state_changed())
	diagnostics.codes_read.connect(func() -> void: record_event(&"read_codes"))
	electrical.recompute()
	job.evaluate()


## Breaks reference cycles between the session and its systems. Call when the
## session is discarded (scene exit, tests) so RefCounted objects are freed.
func dispose() -> void:
	for obj: Object in [vehicle, inventory, tools, electrical, diagnostics, job, self]:
		if obj == null:
			continue
		for sig: Dictionary in obj.get_signal_list():
			for con: Dictionary in obj.get_signal_connection_list(sig["name"]):
				obj.disconnect(sig["name"], con["callable"])
	if resolver:
		resolver.session = null
	if electrical:
		electrical.ctx = null
	if diagnostics:
		diagnostics.electrical = null
	if job:
		job.ctx = null
	if assembly:
		assembly.ctx = null
	resolver = null
	assembly = null


# --- ConditionContext -------------------------------------------------------

func ctx_component_def(component_id: StringName) -> ComponentDefinition:
	return vehicle.definition.get_component(component_id)


func ctx_component(component_id: StringName) -> ComponentInstance:
	return vehicle.get_component(component_id)


func ctx_fastener(fastener_id: StringName) -> FastenerInstance:
	return vehicle.get_fastener(fastener_id)


func ctx_component_fasteners(component_id: StringName) -> Array[FastenerInstance]:
	return vehicle.get_component_fasteners(component_id, true)


func ctx_engine_running() -> bool:
	return electrical.engine_running


func ctx_charging_test_passed() -> bool:
	return diagnostics.charging_test_valid()


func ctx_fluid_state(circuit_id: StringName, key: StringName) -> bool:
	return fluids.state(circuit_id, key)


func ctx_test_passed(test_id: StringName) -> bool:
	return diagnostics.test_valid(test_id)


func ctx_world_flag(flag: StringName) -> bool:
	return bool((world.get("flags", {}) as Dictionary).get(String(flag), false))


func ctx_event(event_id: StringName) -> bool:
	return events.has(event_id)


func ctx_tool_equipped(tool_id: StringName) -> bool:
	return tools.equipped == tool_id


func ctx_part_in_inventory(component_id: StringName, only_new: bool) -> bool:
	return inventory.has_part(component_id, only_new)


func ctx_objective_complete(objective_id: StringName) -> bool:
	return job.is_complete(objective_id)


func ctx_fault_def(fault_id: StringName) -> FaultDefinition:
	return db.get_fault(fault_id)


# --- Player input entry points ------------------------------------------------

## E key on the current target.
func interact(target: Dictionary) -> void:
	if target.is_empty():
		return
	_post(resolver.interact(target), true)


## F key: inspect the target and open the inspection panel.
func inspect(target: Dictionary) -> void:
	if target.is_empty():
		post_message("Nothing to inspect here.", false)
		return
	var r := resolver.inspect(target)
	if r:
		_post(r, true)
	inspect_requested.emit(target)


## Left mouse held. [param just_pressed] is true on the first frame.
func tool_primary(target: Dictionary, delta: float, just_pressed: bool) -> void:
	var r := resolver.primary(target, delta, just_pressed)
	if r:
		_post(r, just_pressed)


## Right mouse held.
func tool_secondary(target: Dictionary, delta: float, just_pressed: bool) -> void:
	var r := resolver.secondary(target, delta, just_pressed)
	if r:
		_post(r, just_pressed)


## No tool button held: resets message de-duplication for the next press.
func tool_released() -> void:
	_last_message = ""


func equip_tool(tool_id: StringName) -> void:
	_post(tools.equip(tool_id), true)
	_on_state_changed()


func cycle_socket(dir: int) -> void:
	_post(tools.cycle_socket(dir), true)


func adjust_tool(dir: int) -> void:
	if tools.equipped_def() and tools.equipped_def().can_final_torque:
		_post(tools.adjust_torque(dir), true)
	elif tools.equipped_def() and tools.equipped_def().uses_socket:
		_post(tools.cycle_socket(dir), true)


func hold_part(uid: String) -> void:
	if inventory.hold_part(uid):
		var rec := inventory.get_part(uid)
		post_message("Holding %s." % part_label(rec), true)
	else:
		post_message("Hands free of parts.", true)


func record_event(event_id: StringName) -> void:
	if events.has(event_id):
		return
	events[event_id] = true
	job.evaluate()
	_on_state_changed()


func toggle_engine() -> ActionResult:
	var r := electrical.toggle_engine()
	_check_engine_state()
	_on_state_changed()
	return r


func try_sign_off() -> ActionResult:
	job.evaluate()
	var r := job.try_sign_off()
	if r.ok:
		events[JobManager.SIGN_OFF_EVENT] = true
		job.finish()
		job_finished.emit(job.definition.id)
	_post(r, true)
	_on_state_changed()
	return r


func post_message(text: String, ok: bool) -> void:
	if text == "":
		return
	message_posted.emit(text, ok)


func _post(r: ActionResult, force: bool) -> void:
	if r == null or r.message == "":
		return
	if not force and r.message == _last_message:
		return
	_last_message = r.message
	message_posted.emit(r.message, r.ok)


# --- Simulation ---------------------------------------------------------------

## Advances time-dependent systems. Call once per frame.
func tick(delta: float) -> void:
	electrical.tick(delta)
	fluids.tick(delta, electrical.engine_running)
	diagnostics.tick(delta)
	if electrical.engine_running:
		_apply_wear(delta)
	_check_engine_state()
	_eval_timer += delta
	if _eval_timer >= OBJECTIVE_EVAL_INTERVAL:
		_eval_timer = 0.0
		job.evaluate()


## Generic wear: every installed component loses condition while the engine runs.
func _apply_wear(delta: float) -> void:
	var hours := delta * ElectricalSystem.SIM_TIME_SCALE / 3600.0
	for cid: StringName in vehicle.components:
		var inst: ComponentInstance = vehicle.components[cid]
		if inst.installed and inst.definition.wear_per_hour > 0.0:
			inst.condition = maxf(0.0, inst.condition - inst.definition.wear_per_hour * hours)


## Raises or lowers the two-post lift (subject to the vehicle's lift requirements).
func toggle_lift() -> ActionResult:
	var flags: Dictionary = world.get("flags", {})
	var raised := bool(flags.get("lift_raised", false))
	var reqs := vehicle.definition.lift_lower_requirements if raised else vehicle.definition.lift_raise_requirements
	if electrical.engine_running:
		return ActionResult.fail("Cannot operate the lift: the engine is running.")
	var why := ConditionEvaluator.first_unmet(reqs, self)
	if why != "":
		return ActionResult.fail("Cannot %s the lift: %s." % ["lower" if raised else "raise", why])
	flags["lift_raised"] = not raised
	world["flags"] = flags
	lift_changed.emit(not raised)
	_on_state_changed()
	return ActionResult.success("Lift %s." % ("lowered" if raised else "raised — vehicle on the lift arms"), false)


func take_fluid_from_shelf(fluid_id: StringName) -> ActionResult:
	var stock: Dictionary = world.get("fluid_stock", {})
	var litres := float(stock.get(String(fluid_id), 0.0))
	if litres <= 0.0:
		return ActionResult.fail("No %s left on the shelf." % String(fluid_id).replace("_", " "))
	stock[String(fluid_id)] = 0.0
	inventory.add_fluid(fluid_id, litres)
	world_changed.emit()
	return ActionResult.success("Took %.1f L of %s." % [litres, String(fluid_id).replace("_", " ")], false)


func take_hardware() -> ActionResult:
	var stock: Dictionary = world.get("hardware_stock", {})
	var got := PackedStringArray()
	for k: Variant in stock:
		var n := int(stock[k])
		if n > 0:
			inventory.add_spare(StringName(str(k)), n)
			var fd := db.fasteners.get(StringName(str(k))) as FastenerDefinition
			got.append("%d × %s" % [n, fd.display_name if fd else str(k)])
			stock[k] = 0
	if got.is_empty():
		return ActionResult.fail("The hardware drawer has nothing for this job.")
	world_changed.emit()
	return ActionResult.success("Spare hardware taken: %s." % ", ".join(got), false)


func _check_engine_state() -> void:
	if electrical.engine_running != _last_engine_running:
		_last_engine_running = electrical.engine_running
		engine_state_changed.emit(_last_engine_running)


func _on_state_changed() -> void:
	electrical.recompute()
	_check_engine_state()
	# Evaluate immediately so transient states (e.g. battery isolated, then
	# reconnected) are credited even between periodic ticks.
	job.evaluate()
	world_changed.emit()


# --- Parts helpers --------------------------------------------------------------

func shelf_stock(component_id: StringName) -> int:
	return int((world.get("shelf_stock", {}) as Dictionary).get(String(component_id), (world.get("shelf_stock", {}) as Dictionary).get(component_id, 0)))


func _set_shelf_stock(component_id: StringName, n: int) -> void:
	var stock: Dictionary = world.get("shelf_stock", {})
	stock.erase(component_id)
	stock[String(component_id)] = n
	world["shelf_stock"] = stock


## Takes a new part from the parts shelf into inventory and holds it.
func take_from_shelf(component_id: StringName) -> ActionResult:
	var def := db.get_component(component_id)
	if def == null:
		return ActionResult.fail("Unknown part.")
	var n := shelf_stock(component_id)
	if n <= 0:
		return ActionResult.fail("No %s left on the shelf." % def.display_name.to_lower())
	_set_shelf_stock(component_id, n - 1)
	_stock_counter += 1
	var rec := {
		"uid": "stock-%s-%04d" % [component_id, _stock_counter + vehicle.revision],
		"component_id": String(component_id),
		"condition": 100.0,
		"faults": [],
		"discovered_faults": [],
		"inspection": ComponentInstance.Inspection.TESTED,
		"is_new": true,
	}
	inventory.add_part(rec)
	inventory.hold_part(rec["uid"])
	world_changed.emit()
	return ActionResult.success("Took a new %s from the shelf (now held). Price %d cr." % [def.display_name.to_lower(), def.purchase_price])


## Deposits the held part (or the first used part) into the core return bin.
func deposit_core() -> ActionResult:
	var uid := inventory.held_part_uid
	if uid == "" or bool(inventory.get_part(uid).get("is_new", false)):
		uid = ""
		for p: Dictionary in inventory.parts:
			if not bool(p.get("is_new", false)):
				uid = str(p.get("uid", ""))
				break
	if uid == "":
		return ActionResult.fail("No used parts to return. New parts stay with you.")
	var rec := inventory.deposit_core(uid)
	return ActionResult.success("%s placed in the core return bin." % part_label(rec))


func part_label(rec: Dictionary) -> String:
	var def := db.get_component(StringName(str(rec.get("component_id", ""))))
	var n := def.display_name if def else str(rec.get("component_id", "?"))
	return ("New " + n.to_lower()) if bool(rec.get("is_new", false)) else ("Removed " + n.to_lower())


# --- Save / load ------------------------------------------------------------------

## Explicit conversion of all persistent state to JSON-safe data.
func to_save_dict() -> Dictionary:
	return {
		"player": player_state.duplicate(true),
		"inventory": inventory.to_dict(),
		"tools": tools.to_dict(),
		"vehicle": vehicle.to_dict(),
		"electrical": electrical.to_dict(),
		"diagnostics": diagnostics.to_dict(),
		"job": job.to_dict(),
		"events": events.keys().map(func(k: Variant) -> String: return String(k)),
		"world": {
			"shelf_stock": (world.get("shelf_stock", {}) as Dictionary).duplicate(),
			"fluid_stock": (world.get("fluid_stock", {}) as Dictionary).duplicate(),
			"hardware_stock": (world.get("hardware_stock", {}) as Dictionary).duplicate(),
			"flags": (world.get("flags", {}) as Dictionary).duplicate(),
			"stock_counter": _stock_counter,
		},
		"vehicle_id": String(vehicle.vehicle_id),
		"job_id": String(job.definition.id),
	}


## Restores state from validated save data. Returns warnings (never fatal).
func apply_save_dict(d: Dictionary) -> PackedStringArray:
	var warnings := PackedStringArray()
	var section := func(key: String) -> Dictionary:
		var v: Variant = d.get(key, {})
		if v is Dictionary:
			return v
		warnings.append("Section '%s' missing or invalid; defaults kept." % key)
		return {}
	var vd: Dictionary = section.call("vehicle")
	if str(vd.get("vehicle_id", vehicle.vehicle_id)) != String(vehicle.vehicle_id):
		warnings.append("Save is for a different vehicle; vehicle state not loaded.")
	else:
		vehicle.from_dict(vd, warnings)
	inventory.from_dict(section.call("inventory"), db, warnings)
	tools.from_dict(section.call("tools"))
	electrical.from_dict(section.call("electrical"))
	diagnostics.from_dict(section.call("diagnostics"))
	events.clear()
	var ev: Variant = d.get("events", [])
	if ev is Array:
		for e: Variant in ev:
			events[StringName(str(e))] = true
	var jd: Dictionary = section.call("job")
	if str(jd.get("job_id", job.definition.id)) == String(job.definition.id):
		job.from_dict(jd, warnings)
	else:
		warnings.append("Save is for a different job; job progress not loaded.")
	var wd: Dictionary = section.call("world")
	var stock: Variant = wd.get("shelf_stock", null)
	if stock is Dictionary:
		var clean := {}
		for k: Variant in stock:
			if db.components.has(StringName(str(k))):
				clean[str(k)] = maxi(0, int(stock[k]))
		world["shelf_stock"] = clean
	for key: String in ["fluid_stock", "hardware_stock"]:
		var st: Variant = wd.get(key, null)
		if st is Dictionary:
			world[key] = (st as Dictionary).duplicate()
	var fl: Variant = wd.get("flags", null)
	if fl is Dictionary:
		var clean_flags := {"lift_raised": bool((fl as Dictionary).get("lift_raised", false))}
		world["flags"] = clean_flags
		lift_changed.emit(clean_flags["lift_raised"])
	_stock_counter = maxi(0, int(wd.get("stock_counter", 0)))
	player_state = section.call("player")
	_last_engine_running = not electrical.engine_running  # force a notification
	_on_state_changed()
	job.evaluate()
	return warnings
