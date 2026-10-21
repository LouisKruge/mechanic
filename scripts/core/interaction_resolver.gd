class_name InteractionResolver
extends RefCounted
## Translates a raycast target plus player input into session actions, and
## describes targets for the HUD and inspection panel.
##
## Target dictionaries are {"type": StringName, "id": StringName}. Types:
## component, fastener, shelf, core_bin, work_order, charger, ignition, obd.

var session: GameSession


func _init(p_session: GameSession) -> void:
	session = p_session


func _type(t: Dictionary) -> StringName:
	return StringName(str(t.get("type", "")))


func _id(t: Dictionary) -> StringName:
	return StringName(str(t.get("id", "")))


# --- Actions ------------------------------------------------------------------

func interact(t: Dictionary) -> ActionResult:
	var id := _id(t)
	match _type(t):
		&"component":
			return _interact_component(id)
		&"fastener":
			return session.assembly.hand_operate_fastener(id)
		&"shelf":
			if String(id).begins_with("fluid:"):
				return session.take_fluid_from_shelf(StringName(String(id).trim_prefix("fluid:")))
			return session.take_from_shelf(id)
		&"lift":
			return session.toggle_lift()
		&"hardware":
			return session.take_hardware()
		&"core_bin":
			return session.deposit_core()
		&"work_order":
			session.record_event(&"read_work_order")
			session.panel_requested.emit(&"work_order")
			return null
		&"charger":
			session.electrical.charger_connected = not session.electrical.charger_connected
			session.electrical.recompute()
			session.world_changed.emit()
			if session.electrical.charger_connected:
				return ActionResult.success("Battery maintainer clamped to the battery posts — charging at %.0f A." % ElectricalSystem.CHARGER_CURRENT_A, false)
			return ActionResult.success("Battery maintainer disconnected.", false)
		&"ignition":
			return session.toggle_engine()
		&"obd":
			return _use_obd()
	return null


func _interact_component(id: StringName) -> ActionResult:
	var inst := session.vehicle.get_component(id)
	if inst == null:
		return ActionResult.fail("Unknown component.")
	# Fill point: with the cap open and fluid carried, E pours instead of closing the cap.
	var fc := session.fluids.circuit_for_fill(id)
	if fc and inst.get_flag(fc.cap_flag) and session.inventory.fluid_amount(fc.fluid_id) > 0.0 and not session.fluids.state(fc.id, &"full"):
		return session.fluids.refill(fc, session.inventory)
	for tg: ComponentToggleDefinition in inst.definition.toggles:
		if tg.input == &"interact":
			return session.assembly.try_toggle(id, tg.flag)
	if inst.definition.removable:
		if inst.installed:
			return session.assembly.try_remove_component(id)
		return session.assembly.try_install_component(id, session.inventory.held_part_uid)
	for tg: ComponentToggleDefinition in inst.definition.toggles:
		if tg.input == &"tool_primary":
			return ActionResult.fail("Use a %s on the %s (LMB)." % [" or ".join(tg.required_tools), inst.definition.display_name.to_lower()])
	return ActionResult.fail("%s: nothing to do by hand. Press F to inspect." % inst.definition.display_name)


func _use_obd() -> ActionResult:
	if session.tools.equipped != &"scanner":
		return ActionResult.fail("Diagnostic port. Equip the diagnostic scanner to connect.")
	if not session.diagnostics.connected:
		var r := session.diagnostics.connect_scanner()
		session.panel_requested.emit(&"scanner")
		return r
	session.panel_requested.emit(&"scanner")
	return null


func primary(t: Dictionary, delta: float, just_pressed: bool) -> ActionResult:
	var tool := session.tools.equipped
	if tool == &"flashlight":
		return session.tools.toggle_flashlight() if just_pressed else null
	if tool == &"pressure_tester":
		if not just_pressed:
			return null
		var fct := session.fluids.circuit_for_fill(_id(t)) if _type(t) == &"component" else null
		if fct == null or fct.pressure_test_id == &"":
			return ActionResult.fail("Fit the pressure tester to a coolant filler neck.")
		var lines := session.diagnostics.pressure_test(fct)
		session.job.evaluate()
		session.world_changed.emit()
		return ActionResult.success("\n".join(lines), false) if lines[0].contains("PASS") else ActionResult.fail("\n".join(lines))
	if tool == &"scanner":
		if not just_pressed:
			return null
		if _type(t) == &"obd" or session.diagnostics.connected:
			return _use_obd()
		return ActionResult.fail("Connect the scanner at the diagnostic port (driver side, under the dash).")
	if t.is_empty():
		return null
	match _type(t):
		&"fastener":
			var f := session.vehicle.get_fastener(_id(t))
			if f and f.definition().is_threaded():
				return session.assembly.turn_fastener(_id(t), true, delta, just_pressed)
			return ActionResult.fail("%s is operated by hand — press E." % (f.display_name() if f else "That")) if just_pressed else null
		&"component":
			if not just_pressed:
				return null
			var inst := session.vehicle.get_component(_id(t))
			if inst:
				for tg: ComponentToggleDefinition in inst.definition.toggles:
					if tg.input == &"tool_primary":
						return session.assembly.try_toggle(inst.component_id, tg.flag)
	if just_pressed and tool != &"":
		return ActionResult.fail("The %s has no use here." % session.tools.equipped_name().to_lower())
	return null


func secondary(t: Dictionary, delta: float, just_pressed: bool) -> ActionResult:
	if session.tools.equipped == &"scanner":
		if just_pressed and session.diagnostics.connected:
			session.diagnostics.disconnect_scanner()
			return ActionResult.success("Scanner disconnected.", false)
		return null
	if _type(t) == &"fastener":
		var f := session.vehicle.get_fastener(_id(t))
		if f and f.definition().is_threaded():
			return session.assembly.turn_fastener(_id(t), false, delta, just_pressed)
		if just_pressed:
			return ActionResult.fail("%s is operated by hand — press E." % (f.display_name() if f else "That"))
	return null


## Inspection: records what the player can learn by looking.
func inspect(t: Dictionary) -> ActionResult:
	if _type(t) != &"component":
		return null
	var inst := session.vehicle.get_component(_id(t))
	if inst == null or not inst.installed:
		return null
	var changed := false
	if inst.inspection == ComponentInstance.Inspection.NONE:
		inst.inspection = ComponentInstance.Inspection.VISUAL
		changed = true
	var lit := session.tools.is_illuminating()
	for f: String in inst.faults:
		var fd := session.db.get_fault(StringName(f))
		if fd == null:
			continue
		var visible := fd.discovery_methods.has("visual") or (lit and fd.discovery_methods.has("flashlight"))
		if visible and not inst.discovered_faults.has(f):
			inst.discovered_faults.append(f)
			changed = true
		if lit and fd.visual_clue != "" and not inst.parameters.has("observed_clue"):
			inst.parameters["observed_clue"] = fd.visual_clue
			changed = true
	# One event per category, e.g. inspected_electrical, inspected_cooling.
	session.record_event(StringName("inspected_" + String(ComponentDefinition.Category.keys()[inst.definition.category]).to_lower()))
	if changed:
		session.vehicle.component_changed.emit(inst.component_id)
		session.world_changed.emit()
	if not lit and _bay_component(inst) and not inst.parameters.has("observed_clue") and not inst.faults.is_empty():
		return ActionResult.success("It is dim inside the engine bay — a flashlight would show more detail.", false)
	return null


func _bay_component(inst: ComponentInstance) -> bool:
	return inst.definition.category != ComponentDefinition.Category.BODY


# --- Descriptions ---------------------------------------------------------------

## HUD description: {name, state, prompts: PackedStringArray, progress: {label, value}}.
func describe(t: Dictionary) -> Dictionary:
	if t.is_empty():
		return {}
	var id := _id(t)
	var d := {"name": "", "state": "", "prompts": PackedStringArray(), "progress": {}}
	var prompts := PackedStringArray()
	match _type(t):
		&"component":
			var inst := session.vehicle.get_component(id)
			if inst == null:
				return {}
			var def := inst.definition
			d["name"] = def.display_name if inst.installed else "%s mount (empty)" % def.display_name
			var states := PackedStringArray()
			for tg: ComponentToggleDefinition in def.toggles:
				states.append(tg.state_true_text.capitalize() if inst.get_flag(tg.flag) else tg.state_false_text.capitalize())
				var verb := tg.label_set_false if inst.get_flag(tg.flag) else tg.label_set_true
				if tg.input == &"interact":
					prompts.append("[E] %s" % verb)
				else:
					prompts.append("[LMB] %s  (%s)" % [verb, " / ".join(tg.required_tools)])
			if def.removable:
				if inst.installed:
					prompts.append("[E] Remove %s" % def.display_name.to_lower())
				else:
					var held := session.inventory.get_held_part()
					if not held.is_empty() and str(held.get("component_id", "")) == String(id):
						prompts.append("[E] Install %s" % session.part_label(held).to_lower())
					else:
						prompts.append("Hold a replacement to install it  (Tab)")
			if inst.installed and inst.is_condition_known() and _condition_visible(inst):
				states.append("Condition %d%%" % int(inst.condition))
			var fcd := session.fluids.circuit_for_fill(id)
			if fcd:
				states.append(session.fluids.level_text(fcd))
				if inst.get_flag(fcd.cap_flag) and session.inventory.fluid_amount(fcd.fluid_id) > 0.0 and not session.fluids.state(fcd.id, &"full"):
					prompts.insert(0, "[E] Pour %s (%.1f L carried)" % [String(fcd.fluid_id).replace("_", " "), session.inventory.fluid_amount(fcd.fluid_id)])
				if session.tools.equipped == &"pressure_tester":
					prompts.append("[LMB] Pressure test")
			d["state"] = "  ·  ".join(states)
			prompts.append("[F] Inspect")
		&"fastener":
			var f := session.vehicle.get_fastener(id)
			if f == null:
				return {}
			var fd := f.definition()
			d["name"] = f.display_name()
			d["state"] = f.state_text()
			if fd.is_hand_operated():
				var verb := ("Fit" if f.removed else "Release") if fd.kind == FastenerDefinition.Kind.CLIP else ("Connect" if f.removed else "Disconnect")
				prompts.append("[E] %s%s" % [verb, ("  (%s)" % String(fd.tool_type).replace("_", " ")) if fd.tool_type != &"" else ""])
			elif f.removed:
				if session.inventory.tray_has(id):
					prompts.append("[E] Fit by hand (from tray)")
				elif session.inventory.spare_count(fd.id) > 0:
					prompts.append("[E] Fit new hardware (%d spare)" % session.inventory.spare_count(fd.id))
				else:
					prompts.append("Fastener not in tray — new hardware: workbench drawer")
			else:
				prompts.append("[LMB] Tighten   [RMB] Loosen   ·   %d mm socket" % fd.tool_size_mm)
				if f.thread_progress < 1.0:
					d["progress"] = {"label": "Thread engagement", "value": f.thread_progress}
				else:
					d["progress"] = {"label": "Torque %.0f / %.0f N·m (demo)" % [f.torque_nm, fd.torque_target_nm], "value": clampf(f.torque_nm / maxf(fd.torque_target_nm, 0.01), 0.0, 1.25)}
		&"shelf":
			if String(id).begins_with("fluid:"):
				var fid := String(id).trim_prefix("fluid:")
				d["name"] = "%s (jug)" % fid.replace("_", " ").capitalize()
				d["state"] = "%.1f L on the shelf" % float((session.world.get("fluid_stock", {}) as Dictionary).get(fid, 0.0))
			else:
				var def := session.db.get_component(id)
				d["name"] = "%s — new (boxed)" % (def.display_name if def else String(id))
				d["state"] = "In stock: %d  ·  %d cr" % [session.shelf_stock(id), def.purchase_price if def else 0]
			prompts.append("[E] Take")
		&"lift":
			var up := session.ctx_world_flag(&"lift_raised")
			d["name"] = "Lift control"
			d["state"] = "Raised" if up else "Lowered"
			prompts.append("[E] %s lift" % ("Lower" if up else "Raise"))
		&"hardware":
			d["name"] = "Hardware drawer"
			d["state"] = "Spare fasteners for this job"
			prompts.append("[E] Take spare hardware")
		&"core_bin":
			d["name"] = "Core return bin"
			d["state"] = "%d part(s) stored" % session.inventory.core_bin.size()
			prompts.append("[E] Deposit removed part")
		&"work_order":
			d["name"] = "Vehicle information board"
			d["state"] = session.job.definition.title
			prompts.append("[E] Read work order")
		&"charger":
			d["name"] = "Battery maintainer"
			d["state"] = ("Charging · %.1f V" % session.electrical.open_circuit_voltage()) if session.electrical.charger_connected else "Idle"
			prompts.append("[E] %s" % ("Disconnect" if session.electrical.charger_connected else "Connect to battery"))
		&"ignition":
			d["name"] = "Ignition switch"
			var running := session.electrical.engine_running
			d["state"] = "Engine %s  ·  Charge lamp %s" % ["running" if running else "off", "ON" if session.electrical.warning_lamp else "off"]
			prompts.append("[E] %s" % ("Stop engine" if running else "Start engine"))
		&"obd":
			d["name"] = "Diagnostic port (OBD)"
			d["state"] = "Scanner connected" if session.diagnostics.connected else "Not connected"
			prompts.append("[E] %s" % ("Open scanner" if session.diagnostics.connected else "Connect scanner"))
	d["prompts"] = prompts
	return d


func _condition_visible(inst: ComponentInstance) -> bool:
	# Electrical parts cannot be judged by eye; their condition needs a test.
	if inst.definition.category == ComponentDefinition.Category.ELECTRICAL:
		return inst.inspection == ComponentInstance.Inspection.TESTED
	return inst.inspection != ComponentInstance.Inspection.NONE


func _fault_names(ids: PackedStringArray) -> String:
	var names := PackedStringArray()
	for f: String in ids:
		var fd := session.db.get_fault(StringName(f))
		names.append(fd.display_name if fd else f)
	return ", ".join(names)


func _tools_text(def: ComponentDefinition) -> String:
	var parts := PackedStringArray()
	for tid: String in def.required_tools:
		var td := session.db.get_tool(StringName(tid))
		parts.append(td.display_name if td else tid)
	for tg: ComponentToggleDefinition in def.toggles:
		for tid: String in tg.required_tools:
			var td := session.db.get_tool(StringName(tid))
			var n := td.display_name if td else tid
			if not parts.has(n):
				parts.append(n)
	for slot: FastenerSlotDefinition in def.fasteners:
		var fd := slot.fastener
		var n := ""
		if fd.is_hand_operated():
			n = "Hands (%s)" % fd.kind_name().to_lower()
		else:
			n = "Ratchet + %d mm socket" % fd.tool_size_mm
			if fd.requires_torque_wrench:
				n += ", torque wrench"
		if not parts.has(n):
			parts.append(n)
	return ", ".join(parts) if not parts.is_empty() else "Hands"


## Inspection panel content: {title, rows: [[label, value]], blockers, blocker_title}.
func inspection_data(t: Dictionary) -> Dictionary:
	var id := _id(t)
	var rows: Array = []
	var out := {"title": "", "rows": rows, "blockers": PackedStringArray(), "blocker_title": ""}
	match _type(t):
		&"component":
			var inst := session.vehicle.get_component(id)
			if inst == null:
				return out
			var def := inst.definition
			out["title"] = def.display_name
			rows.append(["Category", def.category_name()])
			rows.append(["Fits", ", ".join(def.compatible_with) if not def.compatible_with.is_empty() else "any"])
			var fitted := 0
			var total := 0
			for ff: FastenerInstance in session.vehicle.get_component_fasteners(id):
				total += 1
				if ff.is_installed():
					fitted += 1
			if total > 0:
				rows.append(["Assembly", "%d / %d fasteners fitted" % [fitted, total]])
			if not def.removable and def.visual == &"" :
				rows.append(["Service", "Data only — not serviceable in this build"])
			rows.append(["Status", "Installed" if inst.installed else "Removed — mount empty"])
			if inst.installed:
				rows.append(["Condition", ("%d %%" % int(inst.condition)) if _condition_visible(inst) else ("Unknown — needs an electrical test" if def.category == ComponentDefinition.Category.ELECTRICAL else "Unknown — not inspected")])
				if not inst.discovered_faults.is_empty():
					rows.append(["Faults", _fault_names(inst.discovered_faults)])
				elif inst.inspection == ComponentInstance.Inspection.TESTED:
					rows.append(["Faults", "None found"])
				else:
					rows.append(["Faults", "Not yet diagnosed"])
				if inst.parameters.has("observed_clue"):
					rows.append(["Observation", str(inst.parameters["observed_clue"])])
				if id == session.vehicle.definition.battery_component and inst.inspection == ComponentInstance.Inspection.TESTED:
					rows.append(["Resting voltage", "%.2f V  (≈ %d %% charge)" % [session.electrical.open_circuit_voltage(), int(session.electrical.soc * 100.0)]])
			for tg: ComponentToggleDefinition in def.toggles:
				rows.append([tg.flag.capitalize(), tg.state_true_text.capitalize() if inst.get_flag(tg.flag) else tg.state_false_text.capitalize()])
			for f: FastenerInstance in session.vehicle.get_component_fasteners(id):
				var spec := ""
				if f.definition().is_threaded():
					spec = "   [target %.0f N·m, demo]" % f.definition().torque_target_nm
				rows.append([f.slot.slot_id, "%s%s" % [f.state_text(), spec]])
			rows.append(["Required tools", _tools_text(def)])
			if def.performance.has("rated_output_a"):
				rows.append(["Rated output", "%.0f A @ %.1f V" % [def.perf("rated_output_a"), def.perf("regulator_setpoint_v", 14.2)]])
			rows.append(["Part data", "%.1f kg  ·  %d cr" % [def.mass_kg, def.purchase_price]])
			var fcc := session.fluids.circuit_for_fill(id)
			if fcc:
				rows.append(["Fluid level", session.fluids.level_text(fcc)])
				rows.append(["Air", "bled" if session.fluids.state(fcc.id, &"bled") else "AIR IN SYSTEM — bleed required"])
			if def.removable:
				if inst.installed:
					out["blocker_title"] = "Removal blocked by"
					out["blockers"] = session.assembly.removal_blockers(id)
				else:
					out["blocker_title"] = "Installation blocked by"
					out["blockers"] = session.assembly.installation_blockers(id, session.inventory.get_held_part())
			else:
				for tg: ComponentToggleDefinition in def.toggles:
					var why := session.assembly.toggle_blocker(id, tg.flag)
					if why != "":
						out["blocker_title"] = "Blocked"
						(out["blockers"] as PackedStringArray).append("%s: %s" % [tg.label_set_false if inst.get_flag(tg.flag) else tg.label_set_true, why])
		&"fastener":
			var f := session.vehicle.get_fastener(id)
			if f == null:
				return out
			var fd := f.definition()
			out["title"] = f.display_name()
			rows.append(["Type", fd.display_name])
			rows.append(["State", f.state_text()])
			if fd.is_threaded():
				rows.append(["Drive", "Ratchet + %d mm socket" % fd.tool_size_mm])
				rows.append(["Tightening target", "%.0f N·m ±%d %%  (fictional demo value)" % [fd.torque_target_nm, int(fd.torque_tolerance * 100)]])
				rows.append(["Final torque", "Torque wrench required" if fd.requires_torque_wrench else "Ratchet acceptable"])
				rows.append(["Thread engagement", "%d %%" % int(f.thread_progress * 100.0)])
			else:
				rows.append(["Operation", "By hand"])
			var deps := f.slot.installation_dependencies if f.removed else f.slot.removal_dependencies
			out["blocker_title"] = "Fitting blocked by" if f.removed else "Removal blocked by"
			out["blockers"] = ConditionEvaluator.unmet_messages(deps, session)
	return out


## Inspection data for a part record in inventory or storage.
func part_inspection(rec: Dictionary) -> Dictionary:
	var def := session.db.get_component(StringName(str(rec.get("component_id", ""))))
	var rows: Array = []
	var known := int(rec.get("inspection", 0)) == ComponentInstance.Inspection.TESTED or bool(rec.get("is_new", false))
	rows.append(["Part", session.part_label(rec)])
	rows.append(["Serial", str(rec.get("uid", ""))])
	rows.append(["Condition", ("%d %%" % int(float(rec.get("condition", 0.0)))) if known else "Unknown"])
	var disc := PackedStringArray(rec.get("discovered_faults", []))
	rows.append(["Faults", _fault_names(disc) if not disc.is_empty() else ("None" if bool(rec.get("is_new", false)) else "None identified")])
	if def:
		rows.append(["Part data", "%.1f kg  ·  %d cr" % [def.mass_kg, def.purchase_price]])
	return {"title": def.display_name if def else "Part", "rows": rows, "blockers": PackedStringArray(), "blocker_title": ""}
