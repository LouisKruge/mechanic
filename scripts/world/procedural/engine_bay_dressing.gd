class_name EngineBayDressing
extends RefCounted
## Non-interactive engine-bay detail: radiator core and fan, coolant hoses,
## reservoirs, strut towers, air box and battery cables.
##
## Dressing has no collision, so it never blocks the interaction ray. Items
## whose role is played by an interactive component on this vehicle (listed in
## [param skip]) are not generated.


static func build(view: VehicleView, skip: PackedStringArray) -> Node3D:
	var root := Node3D.new()
	root.name = "BayDressing"
	var p := view.profile
	var hw := p.half_width - 0.22
	var zf := -p.length * 0.5 + p.bumper_depth + 0.06
	var zr := p.hood_rear_z
	var y0 := p.sill_y
	var alu := WorkshopMaterials.get_mat(&"aluminium")
	var dark := WorkshopMaterials.get_mat(&"steel_dark")
	var rubber := WorkshopMaterials.get_mat(&"rubber")
	var black := VehicleMaterials.shared(&"plastic_black")
	var tank_mat := StandardMaterial3D.new()
	tank_mat.albedo_color = Color(0.85, 0.85, 0.8, 0.82)
	tank_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tank_mat.roughness = 0.4
	# Radiator core with fins, side tanks and fan shroud.
	var rad := view.mount("radiator")
	if rad and not skip.has("radiator"):
		var core := Node3D.new()
		core.name = "BAY_radiator"
		rad.add_child(core)
		ProcMesh.add(core, ProcMesh.rounded_box(Vector3(hw * 1.6, 0.38, 0.03), 0.01), dark)
		for i: int in 36:
			MeshKit.box(core, Vector3(0.003, 0.36, 0.034), Vector3(-hw * 0.78 + i * hw * 1.56 / 35.0, 0, 0), alu)
		for side: float in [-1.0, 1.0]:
			ProcMesh.add(core, ProcMesh.rounded_box(Vector3(0.05, 0.4, 0.05), 0.015), black, Vector3(side * hw * 0.82, 0, 0))
		ProcMesh.add(core, ProcMesh.rounded_box(Vector3(hw * 1.2, 0.34, 0.06), 0.06), black, Vector3(0, -0.01, 0.06), Vector3.ZERO, "FanShroud")
		ProcMesh.add(core, ProcMesh.lathe(PackedVector2Array([Vector2(0.03, 0), Vector2(0.14, 0.0), Vector2(0.14, 0.01), Vector2(0.03, 0.01)]), 9, false), black, Vector3(0, -0.01, 0.09), Vector3(90, 0, 0), "Fan")
	var eng := view.mount("engine_block")
	var eng_front := eng.position + Vector3(0, 0.25, -0.3) if eng else Vector3(0, 0.7, -1.7)
	var rpos := rad.position if rad else Vector3(0, 0.46, zf)
	if not skip.has("coolant_hoses"):
		ProcMesh.add(root, ProcMesh.hose(Vector3(-0.02, eng_front.y, eng_front.z - 0.02), Vector3(0, 0, -1), rpos + Vector3(-hw * 0.82, 0.15, 0.04), Vector3(-1, 0, -1), 0.02, 0.45), rubber, Vector3.ZERO, Vector3.ZERO, "BAY_hose_upper")
		ProcMesh.add(root, ProcMesh.hose(Vector3(-0.1, eng_front.y - 0.42, eng_front.z + 0.02), Vector3(0, 0, -1), rpos + Vector3(hw * 0.82, -0.15, 0.04), Vector3(1, 0, -1), 0.02, 0.4), rubber, Vector3.ZERO, Vector3.ZERO, "BAY_hose_lower")
	# Coolant expansion tank (right rear), washer reservoir (front left), brake fluid (cowl, driver side).
	if not skip.has("expansion_tank"):
		var tank := Node3D.new()
		tank.name = "BAY_expansion_tank"
		tank.position = Vector3(hw * 0.82, y0 + 0.46, zr - 0.25)
		root.add_child(tank)
		ProcMesh.add(tank, ProcMesh.rounded_box(Vector3(0.12, 0.13, 0.16), 0.04), tank_mat)
		ProcMesh.add(tank, ProcMesh.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.032, 0), Vector2(0.034, 0.025), Vector2(0, 0.03)]), 18), black, Vector3(0, 0.065, 0))
		MeshKit.box(tank, Vector3(0.1, 0.003, 0.002), Vector3(0, 0.0, -0.081), WorkshopMaterials.get_mat(&"floor_marking"))
	var washer := Node3D.new()
	washer.name = "BAY_washer_reservoir"
	washer.position = Vector3(-hw * 0.9, y0 + 0.2, zf + 0.12)
	root.add_child(washer)
	ProcMesh.add(washer, ProcMesh.rounded_box(Vector3(0.12, 0.2, 0.14), 0.03), tank_mat)
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color(0.15, 0.45, 0.8)
	blue.roughness = 0.5
	ProcMesh.add(washer, ProcMesh.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.026, 0), Vector2(0.027, 0.02), Vector2(0, 0.024)]), 18), blue, Vector3(0, 0.1, 0))
	var brake := Node3D.new()
	brake.name = "BAY_brake_fluid_reservoir"
	brake.position = Vector3(-hw * 0.75, p.cowl_y - 0.16, zr - 0.09)
	root.add_child(brake)
	ProcMesh.add(brake, ProcMesh.rounded_box(Vector3(0.1, 0.07, 0.06), 0.02), tank_mat)
	ProcMesh.add(brake, ProcMesh.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.022, 0), Vector2(0.023, 0.018), Vector2(0, 0.02)]), 16), black, Vector3(0, 0.035, 0))
	ProcMesh.add(brake, ProcMesh.rounded_box(Vector3(0.05, 0.08, 0.06), 0.01), dark, Vector3(0, -0.07, 0.02), Vector3.ZERO, "MasterCylinder")
	# Strut towers with top-mount nuts.
	for side2: float in [-1.0, 1.0]:
		var tower := Node3D.new()
		tower.name = "BAY_strut_tower_%s" % ("L" if side2 < 0 else "R")
		tower.position = Vector3(side2 * (hw + 0.02), y0 + 0.28, p.front_axle_z)
		root.add_child(tower)
		ProcMesh.add(tower, ProcMesh.lathe(PackedVector2Array([Vector2(0.12, -0.28), Vector2(0.11, 0.3), Vector2(0.075, 0.34), Vector2(0.0, 0.345)]), 24), VehicleMaterials.shared(&"bay"))
		for k: int in 3:
			var a := TAU * k / 3.0
			ProcMesh.add(tower, ProcMesh.hex_head(0.013, 0.01), WorkshopMaterials.get_mat(&"zinc"), Vector3(sin(a) * 0.045, 0.345, cos(a) * 0.045))
		ProcMesh.add(tower, ProcMesh.hex_head(0.02, 0.02), WorkshopMaterials.get_mat(&"zinc"), Vector3(0, 0.345, 0))
	# Battery cables to the starter, if both exist.
	var bat := view.mount("battery")
	var st := view.mount("starter")
	if bat and st and not skip.has("battery_cables"):
		ProcMesh.add(root, ProcMesh.hose(bat.position + Vector3(0.045, 0.21, -0.085), Vector3(0, 1, 0), st.position + Vector3(0, 0.05, 0), Vector3(1, -1, 1), 0.009, 0.6), VehicleMaterials.shared(&"tail_glow") if false else black, Vector3.ZERO, Vector3.ZERO, "BAY_battery_cable_pos")
	return root
