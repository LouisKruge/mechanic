class_name EngineAssemblyBuilder
extends RefCounted
## Builds a placeholder engine assembly from an [EngineConfiguration].
##
## Origin: centre of the cylinder block; crank axis along Z with the front of
## the engine (accessory drive) towards -Z. Parts are named ENG_* so an
## imported engine model can provide the same hierarchy (see
## docs/ASSET_PIPELINE.md). Inline, V and flat layouts are laid out
## differently — banks, heads, intake and turbo placement all follow the
## configuration, so a flat-six never reuses an inline-six arrangement.
##
## This is simplified original geometry, not a model of any specific engine.

var cfg: EngineConfiguration
var m: Dictionary


func _init(config: EngineConfiguration) -> void:
	cfg = config
	m = {
		"iron": WorkshopMaterials.get_mat(&"cast_iron"),
		"alu": WorkshopMaterials.get_mat(&"aluminium"),
		"alu_dark": WorkshopMaterials.get_mat(&"steel_dark"),
		"black": VehicleMaterials.shared(&"plastic_black"),
		"rubber": WorkshopMaterials.get_mat(&"rubber"),
		"steel": WorkshopMaterials.get_mat(&"steel"),
		"hot": WorkshopMaterials.get_mat(&"aluminium_burnt"),
		"copper": WorkshopMaterials.get_mat(&"copper"),
	}


func length() -> float:
	return cfg.bore_spacing_m * cfg.cylinders_per_bank() + 0.16


## Half extents of the assembly (for placing the interactable box).
func bounds() -> AABB:
	var L := length()
	match cfg.layout:
		EngineConfiguration.Layout.FLAT:
			return AABB(Vector3(-0.42, -0.2, -L * 0.5), Vector3(0.84, 0.46, L))
		EngineConfiguration.Layout.V:
			return AABB(Vector3(-0.36, -0.24, -L * 0.5), Vector3(0.72, 0.58, L))
	return AABB(Vector3(-cfg.block_width_m * 0.6, -cfg.block_height_m * 0.6, -L * 0.5), Vector3(cfg.block_width_m * 1.2, cfg.block_height_m * 1.45, L))


func build() -> Node3D:
	var root := Node3D.new()
	root.name = "EngineAssembly"
	var L := length()
	_block(root, L)
	var bank_axes := _bank_axes()
	for b: int in bank_axes.size():
		_bank(root, b, bank_axes[b], L)
	_intake(root, bank_axes, L)
	_exhaust_and_turbos(root, bank_axes, L)
	_ancillaries(root, L)
	return root


## Per bank: [direction from crank to head (unit, XY plane), lateral normal towards intake].
func _bank_axes() -> Array:
	match cfg.layout:
		EngineConfiguration.Layout.FLAT:
			return [[Vector3(-1, 0, 0)], [Vector3(1, 0, 0)]]
		EngineConfiguration.Layout.V:
			var half := deg_to_rad(cfg.bank_angle_deg * 0.5)
			return [[Vector3(-sin(half), cos(half), 0)], [Vector3(sin(half), cos(half), 0)]]
	return [[Vector3(0, 1, 0)]]


func _part(parent: Node3D, n: String) -> Node3D:
	var p := Node3D.new()
	p.name = n
	parent.add_child(p)
	return p


func _block(root: Node3D, L: float) -> void:
	var blk := _part(root, "ENG_block")
	var w := cfg.block_width_m
	var h := cfg.block_height_m
	if cfg.layout == EngineConfiguration.Layout.FLAT:
		ProcMesh.add(blk, ProcMesh.rounded_box(Vector3(0.36, 0.26, L), 0.05), m["alu"], Vector3(0, 0, 0), Vector3.ZERO, "Crankcase")
		ProcMesh.add(blk, ProcMesh.rounded_box(Vector3(0.3, 0.1, L * 0.9), 0.03), m["alu_dark"], Vector3(0, -0.17, 0), Vector3.ZERO, "Sump")
	else:
		ProcMesh.add(blk, ProcMesh.rounded_box(Vector3(w, h, L), 0.035), m["iron"], Vector3(0, 0, 0), Vector3.ZERO, "Block")
		# Cast ribs on the block sides.
		for side: float in [-1.0, 1.0]:
			for i: int in cfg.cylinders_per_bank() + 1:
				var z := -L * 0.5 + 0.08 + i * cfg.bore_spacing_m
				MeshKit.box(blk, Vector3(0.012, h * 0.7, 0.014), Vector3(side * w * 0.5, -h * 0.05, z), m["iron"])
		ProcMesh.add(blk, ProcMesh.rounded_box(Vector3(w * 0.9, 0.11, L * 0.92), 0.03), m["alu_dark"], Vector3(0, -h * 0.5 - 0.05, 0), Vector3.ZERO, "Sump")
	# Timing cover on the front face.
	ProcMesh.add(blk, ProcMesh.rounded_box(Vector3(w * 0.85, h * 0.9, 0.03), 0.04), m["alu"], Vector3(0, 0.02, -L * 0.5 - 0.012), Vector3.ZERO, "TimingCover")
	# Engine mounts: brackets to the chassis rails with rubber isolators.
	for side2: float in [-1.0, 1.0]:
		var mount := _part(blk, "ENG_mount_%s" % ("L" if side2 < 0 else "R"))
		mount.position = Vector3(side2 * (w * 0.5 + 0.06), -h * 0.15, -L * 0.12)
		ProcMesh.add(mount, ProcMesh.rounded_box(Vector3(0.1, 0.05, 0.12), 0.012), m["alu_dark"], Vector3(0, 0.03, 0))
		ProcMesh.add(mount, ProcMesh.lathe(PackedVector2Array([Vector2(0, -0.05), Vector2(0.035, -0.05), Vector2(0.04, -0.02), Vector2(0.035, 0.0), Vector2(0, 0.0)]), 16), m["rubber"])
		for bz: float in [-0.04, 0.04]:
			ProcMesh.add(mount, ProcMesh.hex_head(0.013, 0.008), m["steel"], Vector3(0, 0.055, bz))


func _bank(root: Node3D, b: int, axes: Array, L: float) -> void:
	var up: Vector3 = axes[0]
	var bank := _part(root, "ENG_bank_%d" % b)
	var flat := cfg.layout == EngineConfiguration.Layout.FLAT
	var base := up * (0.2 if flat else cfg.block_height_m * 0.5)
	if cfg.layout == EngineConfiguration.Layout.V:
		base = up * 0.2 + Vector3(0, 0.02, 0)
	bank.position = base
	# Orient the bank so its local +Y points along [up].
	bank.transform.basis = Basis(Vector3(up.y, -up.x, 0), up, Vector3(0, 0, 1))
	var hw := 0.2 if cfg.layout != EngineConfiguration.Layout.INLINE else cfg.block_width_m * 0.48
	if cfg.layout != EngineConfiguration.Layout.INLINE:
		ProcMesh.add(bank, ProcMesh.rounded_box(Vector3(0.2, 0.16, L * 0.96), 0.03), m["alu"] if flat else m["iron"], Vector3(0, -0.06, 0), Vector3.ZERO, "Cylinders")
	var head := _part(bank, "ENG_cylinder_head_%d" % b)
	ProcMesh.add(head, ProcMesh.rounded_box(Vector3(hw * 2.0, 0.11, L * 0.98), 0.025), m["alu"], Vector3(0, 0.07, 0), Vector3.ZERO, "Head")
	var cover := _part(bank, "ENG_cam_cover_%d" % b)
	ProcMesh.add(cover, ProcMesh.rounded_box(Vector3(hw * 1.7, 0.07, L * 0.94), 0.03), m["black"], Vector3(0, 0.155, 0), Vector3.ZERO, "Cover")
	for i: int in cfg.cylinders_per_bank():
		var z := -L * 0.5 + 0.08 + cfg.bore_spacing_m * (i + 0.5)
		var coil := _part(cover, "ENG_coil_%d_%d" % [b, i])
		coil.position = Vector3(0, 0.19, z)
		ProcMesh.add(coil, ProcMesh.rounded_box(Vector3(0.05, 0.035, 0.045), 0.01), m["black"], Vector3(0, 0, 0))
		ProcMesh.add(coil, ProcMesh.rounded_box(Vector3(0.018, 0.012, 0.02), 0.004), WorkshopMaterials.get_mat(&"plastic_grey"), Vector3(0.025, 0.006, 0))
	# Wiring harness along the cam cover with drops to each coil.
	var harness := PackedVector3Array()
	for i2: int in 9:
		harness.append(Vector3(hw * 0.55, 0.205 + sin(i2 * 1.3) * 0.004, -L * 0.48 + L * 0.96 * i2 / 8.0))
	ProcMesh.add(bank, ProcMesh.tube(harness, 0.009, 8), m["black"], Vector3.ZERO, Vector3.ZERO, "ENG_harness_%d" % b)
	for i3: int in cfg.cylinders_per_bank():
		var z3 := -L * 0.5 + 0.08 + cfg.bore_spacing_m * (i3 + 0.5)
		ProcMesh.add(bank, ProcMesh.hose(Vector3(hw * 0.55, 0.205, z3), Vector3(-1, 0.2, 0), Vector3(0.025, 0.2, z3), Vector3(-1, -0.4, 0), 0.004, 0.5), m["black"])
	# Fuel rail on the intake side of the head.
	var intake_side := -cfg.exhaust_side if cfg.layout == EngineConfiguration.Layout.INLINE else (1.0 if b == 0 else -1.0)
	var rail := PackedVector3Array([Vector3(intake_side * hw * 1.05, 0.03, -L * 0.46), Vector3(intake_side * hw * 1.05, 0.03, L * 0.46)])
	ProcMesh.add(bank, ProcMesh.tube(rail, 0.011, 10), m["steel"], Vector3.ZERO, Vector3.ZERO, "ENG_fuel_rail_%d" % b)
	# Head bolts visible along the cover flange.
	for i4: int in cfg.cylinders_per_bank() + 1:
		var z4 := -L * 0.5 + 0.08 + cfg.bore_spacing_m * i4
		for sx: float in [-1.0, 1.0]:
			ProcMesh.add(bank, ProcMesh.hex_head(0.01, 0.006), m["steel"], Vector3(sx * hw * 0.92, 0.123, z4))


func _intake(root: Node3D, bank_axes: Array, L: float) -> void:
	var intake := _part(root, "ENG_intake")
	if cfg.layout == EngineConfiguration.Layout.INLINE:
		var side := -cfg.exhaust_side
		var px := side * (cfg.block_width_m * 0.5 + cfg.plenum_offset_m)
		var py := cfg.block_height_m * 0.5 + 0.12
		ProcMesh.add(intake, ProcMesh.rounded_box(Vector3(0.12, 0.13, L * 0.9), 0.05), m["black"] if cfg.charge_cooling == &"water_to_air" else m["alu"], Vector3(px, py, 0), Vector3.ZERO, "Plenum")
		for i: int in cfg.cylinders:
			var z := -L * 0.5 + 0.08 + cfg.bore_spacing_m * (i + 0.5)
			var a := Vector3(side * cfg.block_width_m * 0.48, cfg.block_height_m * 0.5 + 0.06, z)
			var b := Vector3(px - side * 0.04, py - 0.02, z)
			ProcMesh.add(intake, ProcMesh.hose(a, Vector3(side, 0.3, 0), b, Vector3(side, -0.2, 0), 0.022, 0.4), m["alu"], Vector3.ZERO, Vector3.ZERO, "Runner%d" % i)
		ProcMesh.add(intake, ProcMesh.lathe(PackedVector2Array([Vector2(0.04, 0), Vector2(0.045, 0.0), Vector2(0.045, 0.07), Vector2(0.04, 0.07)]), 20), m["alu"], Vector3(px, py, (-L * 0.45 - 0.07) if cfg.throttle_at_front else L * 0.45), Vector3(-90, 0, 0), "ENG_throttle_body")
		if cfg.charge_cooling == &"water_to_air":
			var cc := _part(intake, "ENG_charge_cooler")
			cc.position = Vector3(px * 0.55, py + 0.1, 0)
			ProcMesh.add(cc, ProcMesh.rounded_box(Vector3(0.22, 0.07, L * 0.7), 0.02), m["alu"], Vector3.ZERO)
			for i5: int in 14:
				MeshKit.box(cc, Vector3(0.2, 0.004, 0.012), Vector3(0, 0.037, -L * 0.33 + i5 * L * 0.66 / 13.0), m["alu_dark"])
			ProcMesh.add(cc, ProcMesh.hose(Vector3(0.05, 0.0, -L * 0.35), Vector3(0, 0, -1), Vector3(0.0, -0.05, -L * 0.62), Vector3(0, -1, -1), 0.012), m["rubber"], Vector3.ZERO, Vector3.ZERO, "CoolantFeed")
	else:
		# V and flat engines: plenum sits centrally above the crank.
		var y := 0.3 if cfg.layout == EngineConfiguration.Layout.V else 0.2
		ProcMesh.add(intake, ProcMesh.rounded_box(Vector3(0.24, 0.1, L * 0.85), 0.04), m["black"] if cfg.layout == EngineConfiguration.Layout.FLAT else m["alu"], Vector3(0, y, 0), Vector3.ZERO, "Plenum")
		for b: int in bank_axes.size():
			var up: Vector3 = bank_axes[b][0]
			for i: int in cfg.cylinders_per_bank():
				var z := -L * 0.5 + 0.08 + cfg.bore_spacing_m * (i + 0.5)
				var head_pt := up * 0.3 + Vector3(0, 0.05, z)
				var pl := Vector3(signf(up.x) * 0.1, y, z)
				ProcMesh.add(intake, ProcMesh.hose(pl, Vector3(signf(up.x), 0, 0), head_pt, Vector3(signf(up.x), -0.4, 0), 0.02, 0.4), m["alu"])
		ProcMesh.add(intake, ProcMesh.lathe(PackedVector2Array([Vector2(0.045, 0), Vector2(0.05, 0.0), Vector2(0.05, 0.07), Vector2(0.045, 0.07)]), 20), m["alu"], Vector3(0, y, L * 0.45 if cfg.layout == EngineConfiguration.Layout.FLAT else -L * 0.45 - 0.07), Vector3(-90, 0, 0), "ENG_throttle_body")


func _turbo(parent: Node3D, n: String, pos: Vector3, rot: Vector3) -> Node3D:
	var t := _part(parent, n)
	t.position = pos
	t.rotation_degrees = rot
	ProcMesh.add(t, ProcMesh.lathe(PackedVector2Array([Vector2(0, -0.04), Vector2(0.06, -0.04), Vector2(0.075, -0.02), Vector2(0.07, 0.0), Vector2(0.03, 0.005)]), 28), m["hot"], Vector3(0, 0.0, 0), Vector3.ZERO, "TurbineHousing")
	ProcMesh.add(t, ProcMesh.lathe(PackedVector2Array([Vector2(0.025, 0.0), Vector2(0.03, 0.0), Vector2(0.03, 0.04), Vector2(0.025, 0.04)]), 16), m["steel"], Vector3.ZERO, Vector3.ZERO, "CentreSection")
	ProcMesh.add(t, ProcMesh.lathe(PackedVector2Array([Vector2(0.03, 0.04), Vector2(0.07, 0.045), Vector2(0.075, 0.06), Vector2(0.05, 0.085), Vector2(0.035, 0.11), Vector2(0.03, 0.11)]), 28), m["alu"], Vector3.ZERO, Vector3.ZERO, "CompressorHousing")
	ProcMesh.add(t, ProcMesh.hose(Vector3(0.06, 0.06, 0), Vector3(1, 0, 0), Vector3(0.14, 0.12, 0.08), Vector3(0, 1, 0.5), 0.022), m["black"], Vector3.ZERO, Vector3.ZERO, "ChargePipe")
	ProcMesh.add(t, ProcMesh.tube(PackedVector3Array([Vector3(0, -0.04, 0), Vector3(0, -0.12, 0.02)]), 0.03, 12), m["hot"], Vector3.ZERO, Vector3.ZERO, "Downpipe")
	return t


func _exhaust_and_turbos(root: Node3D, bank_axes: Array, L: float) -> void:
	var ex := _part(root, "ENG_exhaust")
	var turbos := cfg.turbo_count()
	if cfg.layout == EngineConfiguration.Layout.INLINE:
		var side := cfg.exhaust_side
		var x0 := side * cfg.block_width_m * 0.5
		var y0 := cfg.block_height_m * 0.5 + 0.03
		var groups := maxi(1, turbos)
		var per := cfg.cylinders / groups
		for g: int in groups:
			var zc := -L * 0.5 + 0.08 + cfg.bore_spacing_m * (g * per + per * 0.5)
			var collector := Vector3(x0 + side * 0.15, y0 - 0.14, zc)
			for i: int in per:
				var z := -L * 0.5 + 0.08 + cfg.bore_spacing_m * (g * per + i + 0.5)
				ProcMesh.add(ex, ProcMesh.hose(Vector3(x0, y0, z), Vector3(side, -0.1, 0), collector, Vector3(0, -1, 0), 0.019, 0.5), m["hot"], Vector3.ZERO, Vector3.ZERO, "Primary%d" % (g * per + i))
			if turbos > 0:
				_turbo(root, "ENG_turbo_%d" % g, collector + Vector3(side * 0.05, -0.05, 0), Vector3(0, 0, side * -90.0))
			else:
				ProcMesh.add(ex, ProcMesh.tube(PackedVector3Array([collector, collector + Vector3(0, -0.2, 0.1)]), 0.026, 12), m["hot"])
		# Heat shield over the manifold.
		ProcMesh.add(ex, ProcMesh.rounded_box(Vector3(0.012, 0.12, L * 0.85), 0.005), WorkshopMaterials.get_mat(&"zinc"), Vector3(x0 + side * 0.09, y0 - 0.04, 0), Vector3(0, 0, side * -20.0), "HeatShield")
	elif cfg.layout == EngineConfiguration.Layout.V:
		# Hot-vee: exhaust inside the V, turbos on top between the banks.
		for g: int in maxi(1, turbos):
			var side2 := -1.0 if g == 0 else 1.0
			_turbo(root, "ENG_turbo_%d" % g, Vector3(side2 * 0.08, 0.38, -L * 0.1), Vector3(0, 0, side2 * 25.0))
	else:
		# Flat engine: exhaust leaves each head downward; turbos sit low behind the banks.
		for b: int in bank_axes.size():
			var up: Vector3 = bank_axes[b][0]
			for i: int in cfg.cylinders_per_bank():
				var z := -L * 0.5 + 0.08 + cfg.bore_spacing_m * (i + 0.5)
				ProcMesh.add(ex, ProcMesh.hose(up * 0.36 + Vector3(0, -0.08, z), Vector3(0, -1, 0), up * 0.22 + Vector3(0, -0.24, L * 0.5), Vector3(0, 0, 1), 0.018, 0.5), m["hot"])
			if turbos > 0:
				_turbo(root, "ENG_turbo_%d" % b, up * 0.3 + Vector3(0, -0.22, L * 0.55), Vector3(90, 0, 0))


func _ancillaries(root: Node3D, L: float) -> void:
	var anc := _part(root, "ENG_ancillaries")
	var side := -cfg.exhaust_side
	# Oil filter housing and filler cap.
	ProcMesh.add(anc, ProcMesh.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.04, 0), Vector2(0.042, 0.1), Vector2(0.035, 0.11), Vector2(0, 0.11)]), 20), m["alu"], Vector3(side * (cfg.block_width_m * 0.5 + 0.05), -0.02, L * 0.25), Vector3.ZERO, "ENG_oil_filter_housing")
	var top := cfg.block_height_m * 0.5 + 0.2 if cfg.layout == EngineConfiguration.Layout.INLINE else 0.3
	ProcMesh.add(anc, ProcMesh.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.026, 0), Vector2(0.028, 0.02), Vector2(0.022, 0.025), Vector2(0, 0.025)]), 20), m["black"], Vector3(0.05, top - 0.02, -L * 0.3), Vector3.ZERO, "ENG_oil_filler_cap")
	# Thermostat housing at the front of the head with the top radiator hose stub.
	ProcMesh.add(anc, ProcMesh.rounded_box(Vector3(0.07, 0.06, 0.05), 0.015), m["alu"], Vector3(0.05, top - 0.12, -L * 0.5 - 0.02), Vector3.ZERO, "ENG_thermostat_housing")
	# Dipstick.
	ProcMesh.add(anc, ProcMesh.tube(PackedVector3Array([Vector3(side * 0.2, -0.1, L * 0.1), Vector3(side * 0.24, 0.2, L * 0.12)]), 0.005, 6), m["steel"], Vector3.ZERO, Vector3.ZERO, "ENG_dipstick")
	ProcMesh.add(anc, ProcMesh.rounded_box(Vector3(0.025, 0.015, 0.025), 0.005), WorkshopMaterials.get_mat(&"safety_line"), Vector3(side * 0.24, 0.205, L * 0.12), Vector3.ZERO, "ENG_dipstick_handle")
