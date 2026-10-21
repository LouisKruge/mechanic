class_name VehicleModelValidator
extends RefCounted
## Checks an imported (or procedural) vehicle model against the naming
## convention and a vehicle definition: required nodes and anchors,
## orientation, real-world scale, pivot placement, transforms, materials and
## triangle budget. Returns {errors, warnings, stats}; errors mean the model
## cannot be bound safely, warnings mean it works but needs attention.

const TRIANGLE_BUDGET: int = 600000
const TRIANGLE_LIMIT: int = 2000000
## Relative tolerance against the body profile's length/width/height.
const DIMENSION_TOLERANCE: float = 0.12


static func validate(model: Node3D, vdef: VehicleDefinition) -> Dictionary:
	var errors := PackedStringArray()
	var warnings := PackedStringArray()
	var stats := {}
	var nodes := {}  # base name -> Node3D
	var dupes := PackedStringArray()
	_collect(model, model, nodes, dupes)
	for d: String in dupes:
		if not _significant(d):
			continue
		warnings.append("Duplicate node name '%s' (DCC suffixes like .001 are stripped when matching)." % d)
	# Body pieces.
	var has_body := false
	for n: String in nodes:
		if n.begins_with("Body_"):
			has_body = true
	if not has_body:
		errors.append("No Body_* mesh found.")
	# Panels required by the vehicle's openable components.
	for c: ComponentDefinition in vdef.components:
		if c.visual == &"hood" and not nodes.has("Panel_hood"):
			errors.append("Vehicle has an openable hood ('%s') but the model has no Panel_hood." % c.id)
		if c.visual == &"lid" and not nodes.has("Panel_trunk"):
			errors.append("Vehicle has a trunk lid ('%s') but the model has no Panel_trunk." % c.id)
	for w: String in VehicleModelConvention.WHEELS:
		if not nodes.has(w):
			errors.append("Missing %s." % w)
		elif VehicleModelConvention.wheel_spin(nodes[w]) == null:
			warnings.append("%s has no 'Spin' child; the whole wheel node will be treated as the rotating part." % w)
	var glass := false
	for n2: String in nodes:
		if n2.begins_with("Glass_"):
			glass = true
	if not glass:
		warnings.append("No Glass_* node found.")
	for l: String in VehicleModelConvention.LIGHTS:
		if not nodes.has(l):
			warnings.append("Missing %s (used for orientation checks and lighting)." % l)
	# Anchors for interactive components and fasteners.
	var missing := PackedStringArray()
	for a: String in VehicleModelConvention.required_anchors(vdef):
		if not nodes.has(a):
			missing.append(a)
	stats["anchors_required"] = VehicleModelConvention.required_anchors(vdef).size()
	stats["anchors_missing"] = missing.size()
	if not missing.is_empty():
		warnings.append("%d anchor(s) missing — the vehicle scene's markers will be used for: %s" % [missing.size(), ", ".join(missing.slice(0, 8)) + (" ..." if missing.size() > 8 else "")])
	for n3: String in nodes:
		if n3.begins_with(VehicleModelConvention.MOUNT_PREFIX) and vdef.get_component(StringName(n3.trim_prefix(VehicleModelConvention.MOUNT_PREFIX))) == null:
			warnings.append("Anchor %s does not match any component of %s." % [n3, vdef.id])
		if n3.begins_with(VehicleModelConvention.PART_PREFIX) and vdef.get_component(StringName(n3.trim_prefix(VehicleModelConvention.PART_PREFIX))) == null:
			warnings.append("Part mesh %s does not match any component of %s." % [n3, vdef.id])
	# Geometry: bounds, scale, orientation.
	var info := _mesh_info(model, model)
	var aabb: AABB = (_mesh_info(model, model, true) as Dictionary)["aabb"]  # body size excludes mirrors
	stats["triangles"] = info["triangles"]
	stats["meshes"] = info["meshes"]
	stats["materials"] = Array(info["materials"])
	stats["size_m"] = [snappedf(aabb.size.x, 0.001), snappedf(aabb.size.y, 0.001), snappedf(aabb.size.z, 0.001)]
	if info["meshes"] == 0:
		errors.append("Model contains no meshes.")
	else:
		if aabb.size.z < 2.5 or aabb.size.z > 6.5:
			errors.append("Length %.2f m is implausible — check export units (metres) and orientation (length along Z)." % aabb.size.z)
		if aabb.size.x > aabb.size.z:
			errors.append("Model is wider than it is long — it is probably rotated 90° (length must be along Z).")
		if aabb.position.y < -0.05:
			warnings.append("Model extends %.2f m below the ground plane (y = 0)." % -aabb.position.y)
		var prof := vdef.body_profile
		if prof:
			_check_dim(warnings, "Length", aabb.size.z, prof.length)
			_check_dim(warnings, "Width", aabb.size.x, prof.half_width * 2.0)
			_check_dim(warnings, "Height", aabb.end.y, prof.roof_y)
	var front_z := NAN
	var rear_z := NAN
	if nodes.has("Light_head_L") and nodes.has("Light_tail_L"):
		front_z = _model_pos(model, nodes["Light_head_L"]).z
		rear_z = _model_pos(model, nodes["Light_tail_L"]).z
	elif nodes.has("Panel_hood") and nodes.has("Panel_trunk"):
		front_z = _model_pos(model, nodes["Panel_hood"]).z
		rear_z = _model_pos(model, nodes["Panel_trunk"]).z
	if not is_nan(front_z) and front_z >= rear_z:
		errors.append("Model faces backwards: the front must point towards -Z.")
	# Pivots.
	if nodes.has("Panel_hood"):
		_check_panel_pivot(errors, nodes["Panel_hood"], -1.0)
	if nodes.has("Panel_trunk"):
		_check_panel_pivot(errors, nodes["Panel_trunk"], 1.0)
	for w2: String in VehicleModelConvention.WHEELS:
		if nodes.has(w2):
			var wa := _local_aabb(nodes[w2])
			if wa.size.length() > 0.0 and wa.get_center().length() > 0.03:
				errors.append("%s pivot is %.3f m from the wheel centre — the origin must be at the axle." % [w2, wa.get_center().length()])
	# Transforms on moving parts.
	for n4: String in ["Panel_hood", "Panel_trunk", "Panel_door_L", "Panel_door_R"] + Array(VehicleModelConvention.WHEELS):
		if nodes.has(n4):
			var s: Vector3 = (nodes[n4] as Node3D).scale
			if s.x < 0.0 or s.y < 0.0 or s.z < 0.0:
				errors.append("%s has a negative scale; apply transforms before export." % n4)
			elif not (is_equal_approx(s.x, s.y) and is_equal_approx(s.y, s.z)):
				warnings.append("%s has non-uniform scale %s; apply scale before export." % [n4, s])
	# Materials and budget.
	for mat: String in VehicleModelConvention.REQUIRED_MATERIALS:
		if not (info["materials"] as Array).has(mat):
			warnings.append("Material %s not found; placeholder materials will be used for those surfaces." % mat)
	if int(info["triangles"]) > TRIANGLE_LIMIT:
		errors.append("%d triangles exceeds the hard limit of %d." % [info["triangles"], TRIANGLE_LIMIT])
	elif int(info["triangles"]) > TRIANGLE_BUDGET:
		warnings.append("%d triangles exceeds the budget of %d; provide LODs." % [info["triangles"], TRIANGLE_BUDGET])
	return {"errors": errors, "warnings": warnings, "stats": stats}


static func _significant(n: String) -> bool:
	for pre: String in ["Body_", "Panel_", "Wheel_", "Glass_", "Light_", VehicleModelConvention.MOUNT_PREFIX, VehicleModelConvention.FASTENER_PREFIX, VehicleModelConvention.PART_PREFIX]:
		if n.begins_with(pre):
			return true
	return false


static func _check_dim(warnings: PackedStringArray, what: String, actual: float, expected: float) -> void:
	if expected > 0.0 and absf(actual - expected) / expected > DIMENSION_TOLERANCE:
		warnings.append("%s %.2f m differs from the vehicle profile (%.2f m) by more than %d %%." % [what, actual, expected, int(DIMENSION_TOLERANCE * 100)])


## dir = -1: panel must extend towards -Z from its hinge (hood); +1: towards +Z (trunk).
static func _check_panel_pivot(errors: PackedStringArray, n: Node3D, dir: float) -> void:
	var a := _local_aabb(n)
	if a.size.length() == 0.0:
		return
	# The hinge edge (rear of a hood, front of a trunk lid) must be at the origin.
	var edge := a.end.z if dir < 0.0 else a.position.z
	if absf(edge) > 0.08:
		errors.append("%s pivot is not at its hinge edge (edge is %.2f m from the origin)." % [n.name, absf(edge)])


static func _collect(root: Node, n: Node, out: Dictionary, dupes: PackedStringArray) -> void:
	for c: Node in n.get_children():
		if c is Node3D:
			var b := VehicleModelConvention.base_name(String(c.name))
			if out.has(b):
				dupes.append(b)
			else:
				out[b] = c
		_collect(root, c, out, dupes)


static func _model_pos(model: Node3D, n: Node3D) -> Vector3:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur and cur != model:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	var a := _local_aabb(n)
	return t * (a.get_center() if a.size.length() > 0.0 else Vector3.ZERO)


## AABB of all meshes under n, in n's local space.
static func _local_aabb(n: Node3D) -> AABB:
	var info := _mesh_info(n, n)
	return info["aabb"]


static func _mesh_info(root: Node3D, n: Node, skip_mirrors: bool = false) -> Dictionary:
	# Array (not PackedStringArray): packed arrays read from a Dictionary are copies.
	var acc := {"aabb": AABB(), "has": false, "triangles": 0, "meshes": 0, "materials": [], "skip_mirrors": skip_mirrors}
	_walk(root, n, Transform3D.IDENTITY, acc)
	return acc


static func _walk(root: Node3D, n: Node, xf: Transform3D, acc: Dictionary) -> void:
	if bool(acc.get("skip_mirrors", false)) and String(n.name).begins_with("Mirror_"):
		return
	var t := xf
	if n != root and n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		var a := t * mi.mesh.get_aabb()
		acc["aabb"] = (acc["aabb"] as AABB).merge(a) if acc["has"] else a
		acc["has"] = true
		acc["meshes"] = int(acc["meshes"]) + 1
		for s: int in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var idx: Variant = arrays[Mesh.ARRAY_INDEX]
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			acc["triangles"] = int(acc["triangles"]) + ((idx as PackedInt32Array).size() / 3 if idx != null and (idx as PackedInt32Array).size() > 0 else verts.size() / 3)
			var mat := mi.get_active_material(s)
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			if mat and mat.resource_name != "" and not (acc["materials"] as Array).has(mat.resource_name):
				(acc["materials"] as Array).append(mat.resource_name)
	for c: Node in n.get_children():
		_walk(root, c, t, acc)
