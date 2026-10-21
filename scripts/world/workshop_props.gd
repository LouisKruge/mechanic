class_name WorkshopProps
extends RefCounted
## Workshop equipment and surface detail (original procedural placeholder art):
## tool cabinet, engine crane, tyre rack, compressor, diagnostic station,
## signage, floor joints, drain, walkway lines, oil stains and entrance detail.
## Solid equipment uses the furniture collision layer (blocks the player, not
## the interaction ray).

var g: GarageBuilder


func _init(garage: GarageBuilder) -> void:
	g = garage


func _m(n: StringName) -> StandardMaterial3D:
	return WorkshopMaterials.get_mat(n)


func build() -> void:
	_tool_cabinet(Vector3(1.8, 0, GarageBuilder.BACK_Z + 0.4))
	_engine_crane(Vector3(-6.4, 0, -7.0))
	_tyre_rack(Vector3(-GarageBuilder.HALF_W + 0.45, 0, 2.4))
	_compressor(Vector3(GarageBuilder.HALF_W - 0.6, 0, -6.8))
	_diagnostic_station(Vector3(GarageBuilder.HALF_W - 1.0, 0, 1.6))
	_signage()
	_floor_detail()
	_entrance_detail()


func _cabinet_paint() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.11, 0.115, 0.125)
	m.metallic = 0.6
	m.roughness = 0.35
	m.clearcoat_enabled = true
	return m


func _tool_cabinet(pos: Vector3) -> void:
	var cab := Node3D.new()
	cab.name = "ToolCabinet"
	cab.position = pos
	g.add_child(cab)
	var paint := _cabinet_paint()
	ProcMesh.add(cab, ProcMesh.rounded_box(Vector3(1.4, 0.95, 0.5), 0.02), paint, Vector3(0, 0.6, 0))
	ProcMesh.add(cab, ProcMesh.rounded_box(Vector3(1.38, 0.55, 0.46), 0.02), paint, Vector3(0, 1.38, -0.01))
	MeshKit.box(cab, Vector3(1.42, 0.03, 0.52), Vector3(0, 1.09, 0), _m(&"steel"))
	for i: int in 6:
		var y := 0.25 + i * 0.13
		MeshKit.box(cab, Vector3(1.32, 0.115, 0.006), Vector3(0, y, 0.252), paint)
		ProcMesh.add(cab, ProcMesh.rounded_box(Vector3(1.1, 0.014, 0.02), 0.006), _m(&"aluminium"), Vector3(0, y + 0.03, 0.265))
	for j: int in 4:
		var y2 := 1.18 + j * 0.11
		MeshKit.box(cab, Vector3(1.3, 0.095, 0.006), Vector3(0, y2, 0.222), paint)
		ProcMesh.add(cab, ProcMesh.rounded_box(Vector3(0.5, 0.012, 0.018), 0.005), _m(&"aluminium"), Vector3(0, y2 + 0.025, 0.234))
	for cx: float in [-0.62, 0.62]:
		for cz: float in [-0.2, 0.2]:
			MeshKit.cylinder(cab, 0.05, 0.035, Vector3(cx, 0.05, cz), _m(&"rubber"), Vector3(0, 0, 90))
	ProcMesh.add(cab, ProcMesh.rounded_box(Vector3(0.05, 0.4, 0.05), 0.02), _m(&"steel"), Vector3(0.74, 0.75, 0.0))
	MeshKit.furniture_box(cab, Vector3(1.45, 1.7, 0.55), Vector3(0, 0.85, 0))
	var lbl := MeshKit.label(cab, "TOOLS", Vector3(-0.12, 1.62, 0.235), 0.002, 32, Color(0.6, 0.6, 0.6))
	lbl.name = "Label"


func _engine_crane(pos: Vector3) -> void:
	var cr := Node3D.new()
	cr.name = "EngineCrane"
	cr.position = pos
	cr.rotation_degrees = Vector3(0, 35, 0)
	g.add_child(cr)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.45, 0.07, 0.06)
	red.metallic = 0.4
	red.roughness = 0.45
	for side: float in [-1.0, 1.0]:
		MeshKit.box(cr, Vector3(0.08, 0.08, 1.4), Vector3(side * 0.42, 0.1, 0.55), red)
		MeshKit.cylinder(cr, 0.045, 0.04, Vector3(side * 0.42, 0.045, 1.2), _m(&"rubber"), Vector3(0, 0, 90))
		MeshKit.cylinder(cr, 0.045, 0.04, Vector3(side * 0.42, 0.045, 0.0), _m(&"rubber"), Vector3(0, 0, 90))
	MeshKit.box(cr, Vector3(0.92, 0.08, 0.1), Vector3(0, 0.1, -0.05), red)
	MeshKit.box(cr, Vector3(0.1, 1.6, 0.1), Vector3(0, 0.9, -0.05), red)
	var boom := Node3D.new()
	boom.position = Vector3(0, 1.62, -0.05)
	boom.rotation_degrees = Vector3(-14, 0, 0)
	cr.add_child(boom)
	MeshKit.box(boom, Vector3(0.09, 0.11, 1.5), Vector3(0, 0, 0.65), red)
	ProcMesh.add(boom, ProcMesh.tube(PackedVector3Array([Vector3(0, -0.06, 1.38), Vector3(0, -0.55, 1.38)]), 0.006, 6), _m(&"steel"))
	ProcMesh.add(boom, ProcMesh.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.025, -0.01), Vector2(0.03, -0.05), Vector2(0.012, -0.08), Vector2(0.0, -0.08)]), 12), _m(&"steel_dark"), Vector3(0, -0.56, 1.38))
	# Hydraulic ram from mast to boom.
	ProcMesh.add(cr, ProcMesh.tube(PackedVector3Array([Vector3(0, 0.6, 0.02), Vector3(0, 1.48, 0.42)]), 0.035, 12), _m(&"steel"))
	MeshKit.furniture_box(cr, Vector3(0.95, 1.7, 0.3), Vector3(0, 0.85, -0.05))


func _tyre_rack(pos: Vector3) -> void:
	var rack := Node3D.new()
	rack.name = "TyreRack"
	rack.position = pos
	rack.rotation_degrees = Vector3(0, 90, 0)
	g.add_child(rack)
	for x: float in [-1.0, 1.0]:
		for z: float in [-0.22, 0.22]:
			MeshKit.box(rack, Vector3(0.04, 1.9, 0.04), Vector3(x, 0.95, z), _m(&"steel_dark"))
	var tyre_mats := {"tyre": VehicleMaterials.shared(&"tyre")}
	for level: int in 2:
		var y := 0.42 + level * 0.85
		for z2: float in [-0.12, 0.12]:
			ProcMesh.add(rack, ProcMesh.tube(PackedVector3Array([Vector3(-1.0, y - 0.3, z2), Vector3(1.0, y - 0.3, z2)]), 0.015, 8), _m(&"steel"))
		for i: int in 5:
			var t := WheelBuilder.build(0.32, 0.23, 0.22, 5, false, VehicleMaterials.build(VehicleBodyProfile.new()), false)
			# Tyres only: the rims of stored tyres are not fitted.
			var spin := t.get_node("Spin")
			for c: Node in spin.get_children():
				if c.name != "Tire":
					c.queue_free()
			t.get_node("Brake").queue_free()
			t.position = Vector3(-0.8 + i * 0.4, y, 0)
			t.rotation_degrees = Vector3(0, 0, 0)
			rack.add_child(t)
	MeshKit.furniture_box(rack, Vector3(2.1, 1.9, 0.5), Vector3(0, 0.95, 0))


func _compressor(pos: Vector3) -> void:
	var c := Node3D.new()
	c.name = "AirCompressor"
	c.position = pos
	g.add_child(c)
	var tank := StandardMaterial3D.new()
	tank.albedo_color = Color(0.5, 0.48, 0.42)
	tank.metallic = 0.5
	tank.roughness = 0.4
	ProcMesh.add(c, ProcMesh.lathe(PackedVector2Array([Vector2(0, -0.45), Vector2(0.18, -0.43), Vector2(0.2, -0.38), Vector2(0.2, 0.38), Vector2(0.18, 0.43), Vector2(0, 0.45)]), 28), tank, Vector3(0, 0.3, 0), Vector3(0, 0, 90))
	ProcMesh.add(c, ProcMesh.rounded_box(Vector3(0.3, 0.22, 0.26), 0.03), _m(&"steel_dark"), Vector3(-0.15, 0.62, 0))
	ProcMesh.add(c, ProcMesh.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.11, 0), Vector2(0.11, 0.06), Vector2(0, 0.06)]), 24), _m(&"cast_iron"), Vector3(0.18, 0.62, 0), Vector3(0, 0, 90))
	ProcMesh.add(c, ProcMesh.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.035, 0), Vector2(0.035, 0.015), Vector2(0, 0.015)]), 20), _m(&"aluminium"), Vector3(0.05, 0.55, 0.2), Vector3(90, 0, 0))
	for x: float in [-0.35, 0.35]:
		MeshKit.box(c, Vector3(0.05, 0.1, 0.35), Vector3(x, 0.05, 0), _m(&"steel_dark"))
	# Hose reel on the wall.
	var reel := Node3D.new()
	reel.position = Vector3(0.3, 1.6, 0.0)
	reel.rotation_degrees = Vector3(0, -90, 0)
	c.add_child(reel)
	ProcMesh.add(reel, ProcMesh.lathe(PackedVector2Array([Vector2(0, -0.08), Vector2(0.22, -0.08), Vector2(0.22, -0.07), Vector2(0.1, -0.07), Vector2(0.1, 0.07), Vector2(0.22, 0.07), Vector2(0.22, 0.08), Vector2(0, 0.08)]), 28), _m(&"steel_dark"), Vector3.ZERO, Vector3(90, 0, 0))
	var hose_mat := StandardMaterial3D.new()
	hose_mat.albedo_color = Color(0.55, 0.12, 0.05)
	hose_mat.roughness = 0.6
	ProcMesh.add(reel, ProcMesh.lathe(PackedVector2Array([Vector2(0.1, -0.065), Vector2(0.17, -0.065), Vector2(0.17, 0.065), Vector2(0.1, 0.065)]), 28), hose_mat, Vector3.ZERO, Vector3(90, 0, 0))
	MeshKit.furniture_box(c, Vector3(1.0, 0.85, 0.45), Vector3(0, 0.42, 0))


func _diagnostic_station(pos: Vector3) -> void:
	var d := Node3D.new()
	d.name = "DiagnosticStation"
	d.position = pos
	d.rotation_degrees = Vector3(0, -90, 0)
	g.add_child(d)
	var paint := _cabinet_paint()
	ProcMesh.add(d, ProcMesh.rounded_box(Vector3(0.6, 0.85, 0.5), 0.02), paint, Vector3(0, 0.5, 0))
	MeshKit.box(d, Vector3(0.62, 0.02, 0.52), Vector3(0, 0.93, 0), _m(&"rubber"))
	ProcMesh.add(d, ProcMesh.rounded_box(Vector3(0.5, 0.32, 0.03), 0.01), _m(&"plastic_black"), Vector3(0, 1.3, -0.12), Vector3(-8, 0, 0))
	ProcMesh.add(d, ProcMesh.rounded_box(Vector3(0.06, 0.32, 0.04), 0.01), _m(&"steel_dark"), Vector3(0, 1.08, -0.15))
	var screen := StandardMaterial3D.new()
	screen.albedo_color = Color(0.05, 0.07, 0.08)
	screen.emission_enabled = true
	screen.emission = Color(0.25, 0.35, 0.4)
	screen.emission_energy_multiplier = 0.8
	MeshKit.box(d, Vector3(0.46, 0.27, 0.005), Vector3(0, 1.3, -0.103), screen, Vector3(-8, 0, 0))
	var txt := MeshKit.label(d, "WORKSHOP DIAGNOSTICS\n\nVehicle  —\nSession  idle\n\nConnect the handheld\nscanner at the vehicle.", Vector3(-0.21, 1.42, -0.098), 0.0009, 26, Color(0.75, 0.88, 0.95))
	txt.name = "ScreenText"
	txt.rotation_degrees = Vector3(-8, 0, 0)
	ProcMesh.add(d, ProcMesh.rounded_box(Vector3(0.4, 0.015, 0.14), 0.005), _m(&"plastic_black"), Vector3(0, 0.95, 0.08))
	for cx: float in [-0.25, 0.25]:
		for cz: float in [-0.2, 0.2]:
			MeshKit.cylinder(d, 0.04, 0.03, Vector3(cx, 0.04, cz), _m(&"rubber"), Vector3(0, 0, 90))
	MeshKit.furniture_box(d, Vector3(0.62, 1.5, 0.52), Vector3(0, 0.75, 0))


func _sign(text: String, pos: Vector3, rot_y: float, warn: bool = false) -> void:
	var s := Node3D.new()
	s.position = pos
	s.rotation_degrees = Vector3(0, rot_y, 0)
	g.add_child(s)
	var plate := StandardMaterial3D.new()
	plate.albedo_color = Color(0.78, 0.72, 0.45) if warn else Color(0.9, 0.9, 0.9)
	plate.roughness = 0.6
	MeshKit.box(s, Vector3(0.6, 0.3, 0.01), Vector3.ZERO, plate)
	MeshKit.box(s, Vector3(0.56, 0.26, 0.002), Vector3(0, 0, 0.006), plate)
	MeshKit.label(s, text, Vector3(-0.27, 0.1, 0.008), 0.0011, 36, Color(0.08, 0.08, 0.08))


func _signage() -> void:
	var w := GarageBuilder.HALF_W - 0.02
	_sign("EYE PROTECTION\nREQUIRED", Vector3(-w, 2.2, -1.0), 90.0, true)
	_sign("NO OPEN FLAMES\nFUEL & SOLVENTS", Vector3(-w, 2.2, 4.0), 90.0, true)
	_sign("LIFT: READ\nOPERATING CARD", Vector3(2.6, 2.2, 0.6), 0.0, true)
	_sign("BAY 01\nREPAIR", Vector3(w, 2.6, 0.6), -90.0)
	_sign("FIRST AID\nEXTINGUISHER", Vector3(w, 1.7, 5.5), -90.0)
	# Wall rib panels above the dado.
	var z := GarageBuilder.BACK_Z + 0.5
	while z < GarageBuilder.FRONT_Z - 0.4:
		for side: float in [-1.0, 1.0]:
			MeshKit.box(g, Vector3(0.03, 3.6, 0.06), Vector3(side * (GarageBuilder.HALF_W - 0.02), 3.1, z), _m(&"steel_dark"))
		z += 1.2


func _floor_detail() -> void:
	var joint := StandardMaterial3D.new()
	joint.albedo_color = Color(0.24, 0.24, 0.245)
	joint.roughness = 1.0
	for x: float in [-6.0, -2.0, 2.0, 6.0]:
		MeshKit.box(g, Vector3(0.012, 0.002, GarageBuilder.FRONT_Z - GarageBuilder.BACK_Z), Vector3(x, 0.001, (GarageBuilder.FRONT_Z + GarageBuilder.BACK_Z) * 0.5), joint)
	for zz: float in [-5.0, -1.0, 3.0, 7.0]:
		MeshKit.box(g, Vector3(GarageBuilder.HALF_W * 2, 0.002, 0.012), Vector3(0, 0.001, zz), joint)
	# Drain grate in front of the bay.
	var drain := Node3D.new()
	drain.position = Vector3(0, 0.002, -4.6)
	g.add_child(drain)
	MeshKit.box(drain, Vector3(2.4, 0.004, 0.18), Vector3.ZERO, _m(&"cast_iron"))
	for i: int in 30:
		MeshKit.box(drain, Vector3(0.02, 0.006, 0.16), Vector3(-1.16 + i * 0.08, 0.001, 0), _m(&"steel_dark"))
	# Walkway lines along the sides.
	for x2: float in [-4.6, 4.6]:
		MeshKit.box(g, Vector3(0.06, 0.003, 14.0), Vector3(x2, 0.0025, 1.5), _m(&"floor_marking"))
	# Oil stains: translucent dark decals (work in every renderer).
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for p: Vector3 in [Vector3(0.1, 0, -1.3), Vector3(-0.3, 0, -1.8), Vector3(0.4, 0, 1.4), Vector3(2.0, 0, -3.0), Vector3(-5.8, 0, -6.3), Vector3(3.3, 0, 6.0)]:
		var q := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		var sz := rng.randf_range(0.35, 0.9)
		pm.size = Vector2(sz, sz * rng.randf_range(0.6, 1.0))
		q.mesh = pm
		q.material_override = _stain_material(rng.randi())
		q.position = p + Vector3(0, 0.0035, 0)
		q.rotation_degrees = Vector3(0, rng.randf_range(0, 360), 0)
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(q)


func _stain_material(seed: int) -> StandardMaterial3D:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.05
	for y: int in 128:
		for x: int in 128:
			var d := Vector2(x - 64, y - 64).length() / 64.0
			var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var a := clampf((1.0 - d) * 1.6 * n - 0.15, 0.0, 0.75)
			img.set_pixel(x, y, Color(0.02, 0.018, 0.015, a))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.25
	m.metallic = 0.1
	return m


func _entrance_detail() -> void:
	var fz := GarageBuilder.FRONT_Z - 0.6
	for x: float in [-GarageBuilder.DOOR_W * 0.5 - 0.4, GarageBuilder.DOOR_W * 0.5 + 0.4]:
		var b := Node3D.new()
		b.position = Vector3(x, 0, fz)
		g.add_child(b)
		ProcMesh.add(b, ProcMesh.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.09, 0), Vector2(0.09, 0.95), Vector2(0.0, 1.0)]), 20), _m(&"safety_line"))
		for k: int in 2:
			ProcMesh.add(b, ProcMesh.lathe(PackedVector2Array([Vector2(0.092, 0), Vector2(0.092, 0.08)]), 20), _m(&"plastic_black"), Vector3(0, 0.55 + k * 0.2, 0))
		MeshKit.furniture_box(b, Vector3(0.2, 1.0, 0.2), Vector3(0, 0.5, 0))
	# Translucent daylight transom above the door.
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.85, 0.9, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(0.8, 0.86, 0.95)
	glow.emission_energy_multiplier = 1.2
	MeshKit.box(g, Vector3(GarageBuilder.DOOR_W - 0.2, 0.35, 0.02), Vector3(0, GarageBuilder.DOOR_H + 0.7, GarageBuilder.FRONT_Z - 0.03), glow)
	# Door control box.
	ProcMesh.add(g, ProcMesh.rounded_box(Vector3(0.16, 0.24, 0.08), 0.015), _m(&"plastic_grey"), Vector3(GarageBuilder.DOOR_W * 0.5 + 0.35, 1.3, GarageBuilder.FRONT_Z - 0.06))


## Updates the diagnostic-station screen.
func set_screen(text: String) -> void:
	var l := g.get_node_or_null("DiagnosticStation/ScreenText") as Label3D
	if l:
		l.text = text
