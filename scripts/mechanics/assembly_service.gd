class_name AssemblyService
extends RefCounted
## Performs mechanical actions on a [VehicleState], enforcing tools, fasteners
## and structured dependencies.
##
## Nothing in here is specific to the alternator: the procedure emerges from
## the dependency data in the component and fastener definitions.

## Turns per second when running a fastener in or out with a ratchet.
const RUN_RATE_TURNS_PER_S: float = 3.0
## Torque applied per second of tightening effort (N·m/s).
const TORQUE_RATE_NM_PER_S: float = 30.0
## Seconds of effort to break a tightened fastener loose.
const BREAKAWAY_SECONDS: float = 0.35
## Engagement given when a fastener is started by hand.
const HAND_START_PROGRESS: float = 0.15

var vehicle: VehicleState
var inventory: InventoryManager
var tools: ToolManager
var db: ContentDatabase
var ctx: ConditionContext


func _init(p_vehicle: VehicleState, p_inventory: InventoryManager, p_tools: ToolManager, p_db: ContentDatabase, p_ctx: ConditionContext) -> void:
	vehicle = p_vehicle
	inventory = p_inventory
	tools = p_tools
	db = p_db
	ctx = p_ctx


static func _because(prefix: String, reason: String) -> String:
	if reason == "":
		return prefix + "."
	return "%s: %s%s." % [prefix, reason.left(1).to_lower(), reason.substr(1)]


func _tool_names(ids: PackedStringArray) -> String:
	var names := PackedStringArray()
	for t: String in ids:
		var d := db.get_tool(StringName(t))
		names.append(d.display_name.to_lower() if d else t)
	return " or ".join(names)


func _has_required_tool(ids: PackedStringArray) -> bool:
	return ids.is_empty() or ids.has(String(tools.equipped))


# --- Components -------------------------------------------------------------

## Every reason the component cannot be removed right now (empty = removable).
func removal_blockers(component_id: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	var inst := vehicle.get_component(component_id)
	if inst == null:
		return PackedStringArray(["unknown component"])
	if not inst.definition.removable:
		out.append("%s is not removable in this workshop" % inst.definition.display_name)
		return out
	if not inst.installed:
		out.append("%s is already removed" % inst.definition.display_name)
		return out
	out.append_array(ConditionEvaluator.unmet_messages(inst.definition.removal_dependencies, ctx))
	for f: FastenerInstance in vehicle.get_component_fasteners(component_id, true):
		if not f.removed:
			out.append(ConditionEvaluator.fastener_message(f.display_name(), f, &"removed", true))
	if not _has_required_tool(inst.definition.required_tools):
		out.append("requires %s" % _tool_names(inst.definition.required_tools))
	return out


func try_remove_component(component_id: StringName) -> ActionResult:
	var inst := vehicle.get_component(component_id)
	if inst == null:
		return ActionResult.fail("Unknown component '%s'." % component_id)
	var blockers := removal_blockers(component_id)
	if not blockers.is_empty():
		return ActionResult.fail(_because("Cannot remove %s" % inst.definition.display_name.to_lower(), blockers[0]))
	var rec := inst.to_part_record()
	inventory.add_part(rec)
	inst.installed = false
	inst.part_uid = ""
	inst.faults = PackedStringArray()
	inst.discovered_faults = PackedStringArray()
	inst.inspection = ComponentInstance.Inspection.NONE
	inst.condition = 0.0
	vehicle.notify_component(component_id)
	return ActionResult.success("%s removed and placed in your inventory." % inst.definition.display_name)


## Every reason [param part] cannot be installed into the slot.
func installation_blockers(component_id: StringName, part: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var inst := vehicle.get_component(component_id)
	if inst == null:
		return PackedStringArray(["unknown component"])
	if inst.installed:
		out.append("%s is already installed" % inst.definition.display_name)
		return out
	if part.is_empty():
		out.append("no replacement %s is being held (Tab → Parts)" % inst.definition.display_name.to_lower())
	else:
		var part_def := db.get_component(StringName(str(part.get("component_id", ""))))
		if part_def == null or part_def.id != component_id:
			out.append("%s does not fit the %s mount" % [part_def.display_name if part_def else "That part", inst.definition.display_name.to_lower()])
		elif not (part_def.compatible_with.is_empty() or part_def.compatible_with.has(String(vehicle.vehicle_id))):
			out.append("%s is not compatible with %s" % [part_def.display_name, vehicle.definition.display_name])
	out.append_array(ConditionEvaluator.unmet_messages(inst.definition.installation_dependencies, ctx))
	for f: FastenerInstance in vehicle.get_component_fasteners(component_id, true):
		if not f.removed:
			out.append("%s is in the way" % f.display_name())
	if not _has_required_tool(inst.definition.required_tools):
		out.append("requires %s" % _tool_names(inst.definition.required_tools))
	return out


func try_install_component(component_id: StringName, part_uid: String) -> ActionResult:
	var inst := vehicle.get_component(component_id)
	if inst == null:
		return ActionResult.fail("Unknown component '%s'." % component_id)
	var part := inventory.get_part(part_uid)
	var blockers := installation_blockers(component_id, part)
	if not blockers.is_empty():
		return ActionResult.fail(_because("Cannot install %s" % inst.definition.display_name.to_lower(), blockers[0]))
	inventory.remove_part(part_uid)
	inst.load_part_record(part)
	inst.installed = true
	vehicle.notify_component(component_id)
	var tail := ""
	if not vehicle.get_component_fasteners(component_id, true).is_empty():
		tail = " Refit its fasteners."
	return ActionResult.success("%s fitted to its mount.%s" % [inst.definition.display_name, tail])


# --- Toggles ----------------------------------------------------------------

## Reason the toggle cannot change right now ("" = allowed).
func toggle_blocker(component_id: StringName, flag: StringName) -> String:
	var inst := vehicle.get_component(component_id)
	if inst == null:
		return "unknown component"
	var t := inst.definition.get_toggle(flag)
	if t == null:
		return "no such operation"
	if not inst.installed:
		return "%s is not installed" % inst.definition.display_name
	var target := not inst.get_flag(flag)
	if not _has_required_tool(t.required_tools):
		return "requires a %s" % _tool_names(t.required_tools)
	return ConditionEvaluator.first_unmet(t.set_true_dependencies if target else t.set_false_dependencies, ctx)


func try_toggle(component_id: StringName, flag: StringName) -> ActionResult:
	var inst := vehicle.get_component(component_id)
	if inst == null:
		return ActionResult.fail("Unknown component '%s'." % component_id)
	var t := inst.definition.get_toggle(flag)
	if t == null:
		return ActionResult.fail("%s has no '%s' operation." % [inst.definition.display_name, flag])
	var target := not inst.get_flag(flag)
	var verb := t.label_set_true if target else t.label_set_false
	var blocker := toggle_blocker(component_id, flag)
	if blocker != "":
		return ActionResult.fail(_because("Cannot %s" % verb.to_lower(), blocker))
	inst.flags[flag] = target
	vehicle.notify_component(component_id)
	return ActionResult.success("%s %s." % [inst.definition.display_name, t.state_true_text if target else t.state_false_text])


# --- Fasteners --------------------------------------------------------------

func _fastener_component_installed(f: FastenerInstance) -> bool:
	var inst := vehicle.get_component(f.component_id)
	return inst != null and inst.installed


## Hand action (E): connect/disconnect connectors and clips, or start a
## threaded fastener by hand from the parts tray.
func hand_operate_fastener(fastener_id: StringName) -> ActionResult:
	var f := vehicle.get_fastener(fastener_id)
	if f == null:
		return ActionResult.fail("Unknown fastener '%s'." % fastener_id)
	var def := f.definition()
	if not _fastener_component_installed(f):
		return ActionResult.fail("Install the %s first." % vehicle.get_component(f.component_id).definition.display_name.to_lower())
	if def.is_hand_operated():
		if f.removed:
			var why := ConditionEvaluator.first_unmet(f.slot.installation_dependencies, ctx)
			if why != "":
				return ActionResult.fail(_because("Cannot connect %s" % f.display_name().to_lower(), why))
			f.removed = false
			f.thread_progress = 1.0
			vehicle.notify_fastener(fastener_id)
			return ActionResult.success("%s connected — it clicks home." % f.display_name())
		var why_r := ConditionEvaluator.first_unmet(f.slot.removal_dependencies, ctx)
		if why_r != "":
			return ActionResult.fail(_because("Cannot disconnect %s" % f.display_name().to_lower(), why_r))
		f.removed = true
		f.thread_progress = 0.0
		vehicle.notify_fastener(fastener_id)
		return ActionResult.success("%s disconnected." % f.display_name())
	# Threaded fastener.
	if f.removed:
		if not inventory.tray_has(fastener_id):
			return ActionResult.fail("%s is not in your parts tray." % f.display_name())
		var why_i := ConditionEvaluator.first_unmet(f.slot.installation_dependencies, ctx)
		if why_i != "":
			return ActionResult.fail(_because("Cannot fit %s" % f.display_name().to_lower(), why_i))
		inventory.tray_take(fastener_id)
		f.removed = false
		f.thread_progress = HAND_START_PROGRESS
		f.torque_nm = 0.0
		vehicle.notify_fastener(fastener_id)
		return ActionResult.success("%s started by hand. Run it down with a ratchet (hold LMB)." % f.display_name())
	if f.torque_nm <= 0.0 and f.thread_progress <= HAND_START_PROGRESS + 0.001:
		f.removed = true
		f.thread_progress = 0.0
		inventory.tray_add(fastener_id)
		vehicle.notify_fastener(fastener_id)
		return ActionResult.success("%s backed out by hand and returned to the tray." % f.display_name())
	return ActionResult.fail("%s is threaded in — use a ratchet: LMB tighten, RMB loosen." % f.display_name())


## Validates the equipped tool for turning a threaded fastener. "" = OK.
func tool_problem(f: FastenerInstance, loosening: bool) -> String:
	var def := f.definition()
	var tool := tools.equipped_def()
	var need := "a %s with a %d mm socket" % [_tool_names(PackedStringArray([String(def.tool_type)])), def.tool_size_mm]
	if tool == null:
		return "Requires %s." % need
	if loosening and tool.can_final_torque and tool.id != def.tool_type:
		return "A torque wrench is a measuring tool — never loosen fasteners with it. Use the ratchet."
	var allowed := tool.id == def.tool_type or (tool.can_final_torque and tool.uses_socket)
	if not allowed or not tool.uses_socket:
		return "Wrong tool: the %s cannot turn %s. Requires %s." % [tool.display_name.to_lower(), f.display_name(), need]
	if tools.socket_mm == 0:
		return "No socket fitted. Select one with [ / ] (socket set)."
	if tools.socket_mm != def.tool_size_mm:
		return "Wrong socket: %s needs %d mm, %d mm fitted. Change with [ / ]." % [f.display_name(), def.tool_size_mm, tools.socket_mm]
	return ""


## Continuous tool work on a threaded fastener (call every frame while held).
## [param first_frame] is true on the frame the button was pressed; repeated
## "already at torque" notices are only reported then.
func turn_fastener(fastener_id: StringName, tighten: bool, delta: float, first_frame: bool = true) -> ActionResult:
	var f := vehicle.get_fastener(fastener_id)
	if f == null:
		return ActionResult.fail("Unknown fastener '%s'." % fastener_id)
	var def := f.definition()
	if def.is_hand_operated():
		return ActionResult.fail("%s is operated by hand — press E." % f.display_name())
	if not _fastener_component_installed(f):
		return ActionResult.fail("Nothing to fasten — the %s is not installed." % vehicle.get_component(f.component_id).definition.display_name.to_lower())
	if f.removed:
		if tighten:
			return ActionResult.fail("%s is not fitted. Start it by hand first [E]." % f.display_name())
		return ActionResult.fail("%s is already removed." % f.display_name())
	var problem := tool_problem(f, not tighten)
	if problem != "":
		return ActionResult.fail(problem)
	var deps := f.slot.installation_dependencies if tighten else f.slot.removal_dependencies
	var why := ConditionEvaluator.first_unmet(deps, ctx)
	if why != "":
		return ActionResult.fail(_because("Cannot %s %s" % ["tighten" if tighten else "loosen", f.display_name().to_lower()], why))
	var tool := tools.equipped_def()
	var run_step := delta * RUN_RATE_TURNS_PER_S / maxf(def.thread_turns, 0.1)
	if tighten:
		if f.thread_progress < 1.0:
			f.thread_progress = minf(1.0, f.thread_progress + run_step)
			vehicle.notify_fastener(fastener_id)
			if f.thread_progress >= 1.0:
				return ActionResult.success("%s seated." % f.display_name())
			return ActionResult.progress()
		var cap := def.torque_target_nm
		if tool.can_final_torque:
			cap = tools.torque_setting_nm
		elif def.requires_torque_wrench:
			cap = def.torque_target_nm * def.ratchet_snug_fraction
		if f.torque_nm >= cap - 0.001:
			if not first_frame:
				return ActionResult.success("", false)
			if tool.can_final_torque:
				return ActionResult.success("Click — the wrench is set to %.0f N·m and has released." % cap, false)
			if def.requires_torque_wrench:
				return ActionResult.success("Snug. Final tightening needs the torque wrench (target %.0f N·m, demo value)." % def.torque_target_nm, false)
			return ActionResult.success("%s tight." % f.display_name(), false)
		f.torque_nm = minf(cap, f.torque_nm + delta * TORQUE_RATE_NM_PER_S)
		vehicle.notify_fastener(fastener_id)
		if f.torque_nm >= cap - 0.001:
			if tool.can_final_torque:
				var verdict := ""
				match f.get_state():
					FastenerInstance.State.TIGHT: verdict = "within spec"
					FastenerInstance.State.OVERTIGHT: verdict = "OVER the %.0f N·m target" % def.torque_target_nm
					_: verdict = "below the %.0f N·m target" % def.torque_target_nm
				return ActionResult.success("Click — %s torqued to %.0f N·m (%s)." % [f.display_name(), f.torque_nm, verdict])
			if not def.requires_torque_wrench:
				return ActionResult.success("%s tightened." % f.display_name())
		return ActionResult.progress()
	# Loosening.
	if f.torque_nm > 0.0:
		f.breakaway_effort += delta
		if f.breakaway_effort >= BREAKAWAY_SECONDS:
			f.torque_nm = 0.0
			f.breakaway_effort = 0.0
			vehicle.notify_fastener(fastener_id)
			return ActionResult.success("%s breaks loose." % f.display_name())
		return ActionResult.success("", false)
	f.thread_progress = maxf(0.0, f.thread_progress - run_step)
	if f.thread_progress <= 0.0:
		f.removed = true
		inventory.tray_add(fastener_id)
		vehicle.notify_fastener(fastener_id)
		return ActionResult.success("%s removed — placed in your parts tray." % f.display_name())
	vehicle.notify_fastener(fastener_id)
	return ActionResult.progress()
