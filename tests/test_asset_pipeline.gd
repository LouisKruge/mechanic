extends TestCase
## Vehicle asset pipeline: validator rules, GLB export/import round trip,
## binding imported anchors onto the vehicle scene, optional Blender output.

const V := &"bmw_m4_g82"
static var _db: ContentDatabase


func before_each() -> void:
	if _db == null:
		_db = ContentDatabase.new().load_all()


func _vdef() -> VehicleDefinition:
	return _db.vehicles[V]


func _procedural() -> Node3D:
	var prof := _vdef().body_profile
	return VehicleBodyBuilder.new(prof).build(VehicleMaterials.build(prof))


func test_procedural_body_follows_convention() -> void:
	var m := _procedural()
	var r := VehicleModelValidator.validate(m, _vdef())
	check((r["errors"] as PackedStringArray).is_empty(), "procedural body has no errors: %s" % r["errors"])
	check(int((r["stats"] as Dictionary)["anchors_missing"]) == int((r["stats"] as Dictionary)["anchors_required"]), "bare body has no anchors (scene markers are used)")
	m.free()


func test_validator_rejects_bad_models() -> void:
	var cases := {
		"rotated 90 degrees": func(m: Node3D) -> void: m.rotation_degrees.y = 90.0,
		"centimetre units": func(m: Node3D) -> void: m.scale = Vector3(100, 100, 100),
		"facing backwards": func(m: Node3D) -> void: m.rotation_degrees.y = 180.0,
		"hood pivot not at hinge": func(m: Node3D) -> void:
			# Shift the geometry away from the node origin (a pivot left in the panel middle).
			var hood := m.get_node("Panel_hood") as MeshInstance3D
			var st := SurfaceTool.new()
			st.append_from(hood.mesh, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.6)))
			hood.mesh = st.commit(),
		"missing wheel": func(m: Node3D) -> void: m.get_node("Wheel_RL").free(),
	}
	var expect := {"rotated 90 degrees": "rotated", "centimetre units": "units", "facing backwards": "backwards", "hood pivot not at hinge": "pivot", "missing wheel": "Wheel_RL"}
	for name: String in cases:
		var holder := Node3D.new()
		var m := _procedural()
		holder.add_child(m)
		(cases[name] as Callable).call(m)
		# Validate the holder so the root transform is part of the model.
		var r := VehicleModelValidator.validate(holder, _vdef())
		var joined := "\n".join(r["errors"])
		check(joined.contains(expect[name]), "%s rejected (errors: %s)" % [name, joined])
		holder.free()


func test_template_glb_round_trip_and_binding() -> void:
	var path := "user://test_assets/%s_template.glb" % V
	var tpl := VehicleTemplateExporter.build(_vdef())
	check_eq(VehicleModelLoader.save_gltf(tpl, path), OK, "template exported")
	tpl.free()
	var model := VehicleModelLoader.load_model(path)
	check(model != null, "GLB reloaded at runtime")
	var r := VehicleModelValidator.validate(model, _vdef())
	check((r["errors"] as PackedStringArray).is_empty() and (r["warnings"] as PackedStringArray).is_empty(), "template validates cleanly: %s %s" % [r["errors"], r["warnings"]])
	check_eq(int((r["stats"] as Dictionary)["anchors_missing"]), 0, "all anchors present")
	await _check_binding(model, "template")


func test_blender_output_if_available() -> void:
	var path := OS.get_environment("GARAGE_BLENDER_GLB")
	if path == "" or not FileAccess.file_exists(path):
		print("        SKIP: set GARAGE_BLENDER_GLB to a GLB produced by tools/blender/roundtrip_test.sh")
		check(true, "skipped")
		return
	var model := VehicleModelLoader.load_model(path)
	var r := VehicleModelValidator.validate(model, _vdef())
	check((r["errors"] as PackedStringArray).is_empty(), "Blender export validates: %s" % r["errors"])
	await _check_binding(model, "blender")


## Binds a model into the M4 scene and compares every anchored marker with
## the authored scene markers (1 mm tolerance), then checks interactables.
func _check_binding(model: Node3D, label: String) -> void:
	var reference := (load(_vdef().scene_path) as PackedScene).instantiate() as VehicleView
	var s := GameSession.new(_db, V, &"job_101")
	var view := (load(_vdef().scene_path) as PackedScene).instantiate() as VehicleView
	view.external_model = model
	tree.root.add_child(view)
	view.setup(s)
	await tree.process_frame
	check(int((view.model_report.get("binding", {}) as Dictionary).get("anchors", 0)) == VehicleModelConvention.required_anchors(_vdef()).size(), "%s: all anchors bound" % label)
	var worst := 0.0
	var worst_name := ""
	for c: ComponentDefinition in VehicleModelConvention.anchored_components(_vdef()):
		var a := reference.get_node("Mounts/%s" % c.id) as Marker3D
		var b := view.get_node("Mounts/%s" % c.id) as Marker3D
		var dist := a.transform.origin.distance_to(b.transform.origin)
		if dist > worst:
			worst = dist
			worst_name = String(c.id)
		for slot: FastenerSlotDefinition in c.fasteners:
			var fa := a.get_node(String(slot.slot_id)) as Marker3D
			var fb := b.get_node(String(slot.slot_id)) as Marker3D
			var fd := (a.transform * fa.transform).origin.distance_to((b.transform * fb.transform).origin)
			var axis_dot := (a.transform.basis * fa.transform.basis).z.normalized().dot((b.transform.basis * fb.transform.basis).z.normalized())
			if fd > worst:
				worst = fd
				worst_name = "%s.%s" % [c.id, slot.slot_id]
			check(axis_dot > 0.999, "%s: %s.%s orientation preserved" % [label, c.id, slot.slot_id])
	check(worst < 0.001, "%s: anchors match scene markers (worst %.4f m at %s)" % [label, worst, worst_name])
	check(view.get_interactable(&"component", &"m4_lt_expansion_tank") != null and view.get_interactable(&"fastener", &"m4_wheel_rr.L5") != null, "%s: interactables built from bound anchors" % label)
	view.queue_free()
	reference.free()
	s.dispose()
