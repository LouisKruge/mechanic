class_name MechanicalDependencyValidator
extends RefCounted
## Static validation of mechanical definitions.
##
## Checks run at startup and in the test-suite:
##  * unique, non-empty IDs for tools, fasteners, faults and components;
##  * every condition uses a known kind and references existing IDs;
##  * fasteners reference real tools and have sane torque data;
##  * no dependency cycles between mechanical actions (which would make a
##    procedure impossible to perform), and no cycles in job objective order.
##
## The action graph has one node per mechanical action:
##   C:<component>:remove / C:<component>:install
##   T:<component>:<flag>:<true|false>
##   F:<fastener>:remove / F:<fastener>:install / F:<fastener>:tight
## An edge A -> B means "A requires a state that only B produces".


## Returns a list of human-readable errors (empty = valid).
static func validate(db: ContentDatabase) -> PackedStringArray:
	var errors := PackedStringArray()
	_check_unique(db, errors)
	for v: VehicleDefinition in db.vehicles.values():
		_check_vehicle(v, db, errors)
		var graph := build_action_graph(v)
		for cycle: String in find_cycles(graph):
			errors.append("Dependency cycle in %s: %s" % [v.id, cycle])
	for j: JobDefinition in db.jobs.values():
		_check_job(j, db, errors)
	return errors


static func _check_unique(db: ContentDatabase, errors: PackedStringArray) -> void:
	for group: String in ["tools", "fasteners", "faults", "components"]:
		var d: Dictionary = db.get(group)
		for k: Variant in d:
			if String(k) == "":
				errors.append("Empty ID in %s" % group)
	for dup: String in db.duplicate_ids:
		errors.append("Duplicate ID: %s" % dup)


static func _check_vehicle(v: VehicleDefinition, db: ContentDatabase, errors: PackedStringArray) -> void:
	var where := "vehicle %s" % v.id
	var seen := {}
	for c: ComponentDefinition in v.components:
		if c == null:
			errors.append("%s: null component entry" % where)
			continue
		if seen.has(c.id):
			errors.append("%s: component '%s' listed twice" % [where, c.id])
		seen[c.id] = true
		if not (c.compatible_with.has(String(v.id)) or c.compatible_with.is_empty()):
			errors.append("%s: component '%s' is not compatible with this vehicle" % [where, c.id])
		for t: String in c.required_tools:
			if not db.tools.has(StringName(t)):
				errors.append("%s: component '%s' requires unknown tool '%s'" % [where, c.id, t])
		for fid: String in c.fault_capabilities:
			if not db.faults.has(StringName(fid)):
				errors.append("%s: component '%s' lists unknown fault '%s'" % [where, c.id, fid])
		var slot_ids := {}
		for slot: FastenerSlotDefinition in c.fasteners:
			if slot.fastener == null:
				errors.append("%s: %s.%s has no fastener definition" % [where, c.id, slot.slot_id])
				continue
			if slot_ids.has(slot.slot_id):
				errors.append("%s: duplicate fastener slot %s.%s" % [where, c.id, slot.slot_id])
			slot_ids[slot.slot_id] = true
			_check_fastener_def(slot.fastener, db, errors)
			_check_conditions(slot.removal_dependencies, v, db, errors, "%s.%s removal" % [c.id, slot.slot_id])
			_check_conditions(slot.installation_dependencies, v, db, errors, "%s.%s installation" % [c.id, slot.slot_id])
		_check_conditions(c.removal_dependencies, v, db, errors, "%s removal" % c.id)
		_check_conditions(c.installation_dependencies, v, db, errors, "%s installation" % c.id)
		for t: ComponentToggleDefinition in c.toggles:
			for tool: String in t.required_tools:
				if not db.tools.has(StringName(tool)):
					errors.append("%s: toggle %s.%s requires unknown tool '%s'" % [where, c.id, t.flag, tool])
			_check_conditions(t.set_true_dependencies, v, db, errors, "%s.%s=true" % [c.id, t.flag])
			_check_conditions(t.set_false_dependencies, v, db, errors, "%s.%s=false" % [c.id, t.flag])
	for key: Variant in v.initial_state:
		var cdef := v.get_component(StringName(str(key)))
		if cdef == null:
			errors.append("%s: initial_state references unknown component '%s'" % [where, key])
			continue
		for fid: Variant in (v.initial_state[key] as Dictionary).get("faults", []):
			if not cdef.fault_capabilities.has(str(fid)):
				errors.append("%s: initial fault '%s' is not a capability of '%s'" % [where, fid, key])
	_check_conditions(v.start_requirements, v, db, errors, "start requirements")
	_check_conditions(v.battery_connection, v, db, errors, "battery connection")
	_check_conditions(v.charging_path, v, db, errors, "charging path")
	for role: StringName in [v.battery_component, v.alternator_component, v.starter_component]:
		if v.get_component(role) == null:
			errors.append("%s: electrical role component '%s' not fitted" % [where, role])


static func _check_fastener_def(f: FastenerDefinition, db: ContentDatabase, errors: PackedStringArray) -> void:
	if f.is_threaded():
		if f.tool_type == &"" or not db.tools.has(f.tool_type):
			errors.append("Fastener '%s' references unknown tool '%s'" % [f.id, f.tool_type])
		if f.tool_size_mm <= 0:
			errors.append("Fastener '%s' has no tool size" % f.id)
		if f.torque_target_nm <= 0.0:
			errors.append("Fastener '%s' has no tightening target" % f.id)
		if f.torque_tolerance <= 0.0 or f.torque_tolerance >= 0.5:
			errors.append("Fastener '%s' has an implausible torque tolerance" % f.id)


## Validates each condition's kind and references against a vehicle.
static func _check_conditions(conds: Array[DependencyCondition], v: VehicleDefinition, db: ContentDatabase, errors: PackedStringArray, where: String) -> void:
	for c: DependencyCondition in conds:
		if c == null:
			errors.append("%s: null condition" % where)
			continue
		if not DependencyCondition.KINDS.has(String(c.kind)):
			errors.append("%s: unknown condition kind '%s'" % [where, c.kind])
			continue
		match c.kind:
			&"component_installed", &"component_fault_free", &"part_in_inventory":
				if v.get_component(c.subject_id) == null:
					errors.append("%s: unknown component '%s'" % [where, c.subject_id])
			&"component_flag":
				var cd := v.get_component(c.subject_id)
				if cd == null:
					errors.append("%s: unknown component '%s'" % [where, c.subject_id])
				elif cd.get_toggle(c.key) == null:
					errors.append("%s: component '%s' has no flag '%s'" % [where, c.subject_id, c.key])
			&"fastener_state":
				if _find_slot(v, c.subject_id) == null:
					errors.append("%s: unknown fastener '%s'" % [where, c.subject_id])
				if not [&"removed", &"installed", &"tight"].has(c.key):
					errors.append("%s: bad fastener state '%s'" % [where, c.key])
			&"component_fasteners":
				if v.get_component(c.subject_id) == null:
					errors.append("%s: unknown component '%s'" % [where, c.subject_id])
				if not [&"removed", &"installed", &"tight"].has(c.key):
					errors.append("%s: bad fastener state '%s'" % [where, c.key])
			&"fault_discovered":
				var cd := v.get_component(c.subject_id)
				if cd == null or not cd.fault_capabilities.has(String(c.key)):
					errors.append("%s: '%s' cannot have fault '%s'" % [where, c.subject_id, c.key])
			&"tool_equipped":
				if not db.tools.has(c.subject_id):
					errors.append("%s: unknown tool '%s'" % [where, c.subject_id])


static func _find_slot(v: VehicleDefinition, fastener_id: StringName) -> FastenerSlotDefinition:
	var parts := String(fastener_id).split(".")
	if parts.size() != 2:
		return null
	var cd := v.get_component(StringName(parts[0]))
	return cd.get_fastener_slot(StringName(parts[1])) if cd else null


static func _check_job(j: JobDefinition, db: ContentDatabase, errors: PackedStringArray) -> void:
	var v: VehicleDefinition = db.vehicles.get(j.vehicle_id, null)
	if v == null:
		errors.append("Job %s: unknown vehicle '%s'" % [j.id, j.vehicle_id])
		return
	var ids := {}
	for o: JobObjectiveDefinition in j.objectives:
		if ids.has(o.id):
			errors.append("Job %s: duplicate objective '%s'" % [j.id, o.id])
		ids[o.id] = true
	var graph := {}
	for o: JobObjectiveDefinition in j.objectives:
		_check_conditions(o.conditions, v, db, errors, "job %s objective %s" % [j.id, o.id])
		var edges := PackedStringArray()
		for a: String in o.after:
			if not ids.has(StringName(a)):
				errors.append("Job %s: objective '%s' is after unknown '%s'" % [j.id, o.id, a])
			edges.append(a)
		graph[String(o.id)] = edges
	for cycle: String in find_cycles(graph):
		errors.append("Job %s objective order cycle: %s" % [j.id, cycle])
	_check_conditions(j.completion_requirements, v, db, errors, "job %s completion" % j.id)
	for k: Variant in j.supplied_parts:
		if v.get_component(StringName(str(k))) == null:
			errors.append("Job %s: supplied part '%s' does not fit the vehicle" % [j.id, k])


## Builds {node: PackedStringArray(edges)} for a vehicle's mechanical actions.
static func build_action_graph(v: VehicleDefinition) -> Dictionary:
	var g := {}
	for c: ComponentDefinition in v.components:
		var remove_edges := _edges_for(c.removal_dependencies, v)
		for slot: FastenerSlotDefinition in c.fasteners:
			var fid := "%s.%s" % [c.id, slot.slot_id]
			if slot.retains_component:
				remove_edges.append("F:%s:remove" % fid)
			g["F:%s:remove" % fid] = _edges_for(slot.removal_dependencies, v)
			var install_edges := _edges_for(slot.installation_dependencies, v)
			if c.removable:
				install_edges.append("C:%s:install" % c.id)
			g["F:%s:install" % fid] = install_edges
			g["F:%s:tight" % fid] = PackedStringArray(["F:%s:install" % fid])
		g["C:%s:remove" % c.id] = remove_edges
		g["C:%s:install" % c.id] = _edges_for(c.installation_dependencies, v)
		for t: ComponentToggleDefinition in c.toggles:
			g["T:%s:%s:true" % [c.id, t.flag]] = _edges_for(t.set_true_dependencies, v)
			g["T:%s:%s:false" % [c.id, t.flag]] = _edges_for(t.set_false_dependencies, v)
	return g


static func _edges_for(conds: Array[DependencyCondition], v: VehicleDefinition) -> PackedStringArray:
	var out := PackedStringArray()
	for c: DependencyCondition in conds:
		if c == null:
			continue
		match c.kind:
			&"component_installed":
				out.append("C:%s:%s" % [c.subject_id, "install" if c.expected else "remove"])
			&"component_flag":
				out.append("T:%s:%s:%s" % [c.subject_id, c.key, "true" if c.expected else "false"])
			&"fastener_state":
				out.append(_fastener_node(String(c.subject_id), c.key, c.expected))
			&"component_fasteners":
				var cd := v.get_component(c.subject_id)
				if cd:
					for slot: FastenerSlotDefinition in cd.fasteners:
						if slot.retains_component:
							out.append(_fastener_node("%s.%s" % [cd.id, slot.slot_id], c.key, c.expected))
	return out


static func _fastener_node(fid: String, key: StringName, expected: bool) -> String:
	if key == &"removed":
		return "F:%s:%s" % [fid, "remove" if expected else "install"]
	if key == &"tight":
		return "F:%s:%s" % [fid, "tight" if expected else "remove"]
	return "F:%s:%s" % [fid, "install" if expected else "remove"]


## Returns one description per cycle found (e.g. "A -> B -> A"). Uses
## iterative-colour DFS; nodes referenced but not defined are treated as leaves.
static func find_cycles(graph: Dictionary) -> PackedStringArray:
	var cycles := PackedStringArray()
	var colour := {}  # 0 white, 1 grey, 2 black
	var keys: Array = graph.keys()
	keys.sort()
	for start: Variant in keys:
		if int(colour.get(start, 0)) != 0:
			continue
		var stack: Array = [[start, 0]]
		var path: Array = [start]
		colour[start] = 1
		while not stack.is_empty():
			var top: Array = stack[stack.size() - 1]
			var node: Variant = top[0]
			var edges: PackedStringArray = graph.get(node, PackedStringArray())
			var idx: int = top[1]
			if idx < edges.size():
				top[1] = idx + 1
				var nxt: String = edges[idx]
				var c := int(colour.get(nxt, 0))
				if c == 1:
					var from := path.find(nxt)
					var loop: Array = path.slice(from) + [nxt]
					cycles.append(" -> ".join(PackedStringArray(loop)))
				elif c == 0:
					colour[nxt] = 1
					stack.append([nxt, 0])
					path.append(nxt)
			else:
				colour[node] = 2
				stack.pop_back()
				path.pop_back()
	return cycles
