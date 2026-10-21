class_name GarageBuilder
extends Node3D
## Builds the enclosed workshop from procedural primitives.
##
## Layout (metres, world space): floor spans X [-HALF_W, HALF_W] and
## Z [BACK_Z, FRONT_Z]. The entrance roller door is in the +Z wall. The repair
## bay is centred on the origin, where Project C01 is parked nose towards -Z.
## Interactable fixtures (parts shelf, core bin, info board, charger) are
## created here and registered via [signal interactable_created].

signal interactable_created(node: Interactable)

## Shelf slot positions (shelf-local) for job-supplied stock.
const STOCK_SLOTS: Array[Vector3] = [Vector3(0.2, 0.33, 0.02), Vector3(0.75, 0.33, 0.02), Vector3(0.15, 0.93, 0.02), Vector3(-0.35, 0.93, 0.02)]

var _shelf: Node3D
var props: WorkshopProps
var _lift_carriage: Node3D

const HALF_W: float = 9.0
const BACK_Z: float = -9.0
const FRONT_Z: float = 11.0
const WALL_H: float = 5.2
const WALL_T: float = 0.25
const DOOR_W: float = 5.0
const DOOR_H: float = 4.2

## Where the player spawns (inside, by the entrance).
const SPAWN_POINT: Vector3 = Vector3(2.5, 0.05, 9.4)
## Player Z below which "entered the workshop" fires.
const ENTRY_LINE_Z: float = 7.6


func build() -> void:
	_build_shell()
	_build_entrance()
	_build_lighting()
	_build_environment()
	_build_repair_bay()
	_build_lift()
	_build_workbench()
	_build_tool_trolley()
	_build_parts_shelf()
	_build_info_board()
	props = WorkshopProps.new(self)
	props.build()


func _m(n: StringName) -> StandardMaterial3D:
	return WorkshopMaterials.get_mat(n)


func _build_shell() -> void:
	var w := HALF_W * 2.0
	var d := FRONT_Z - BACK_Z
	var cz := (FRONT_Z + BACK_Z) * 0.5
	# Floor slab (top surface at y = 0).
	MeshKit.solid_box(self, Vector3(w, 0.2, d), Vector3(0, -0.1, cz), _m(&"concrete"), Vector3.ZERO, "Floor")
	# Roof.
	MeshKit.solid_box(self, Vector3(w + 0.5, 0.2, d + 0.5), Vector3(0, WALL_H + 0.1, cz), _m(&"roof"), Vector3.ZERO, "Roof")
	# Side and back walls, with a darker lower band.
	for side: float in [-1.0, 1.0]:
		var x := side * (HALF_W + WALL_T * 0.5)
		MeshKit.solid_box(self, Vector3(WALL_T, WALL_H, d), Vector3(x, WALL_H * 0.5, cz), _m(&"wall"))
		MeshKit.box(self, Vector3(0.02, 1.2, d), Vector3(side * (HALF_W - 0.01), 0.6, cz), _m(&"wall_lower"))
	MeshKit.solid_box(self, Vector3(w, WALL_H, WALL_T), Vector3(0, WALL_H * 0.5, BACK_Z - WALL_T * 0.5), _m(&"wall"))
	MeshKit.box(self, Vector3(w, 1.2, 0.02), Vector3(0, 0.6, BACK_Z + 0.01), _m(&"wall_lower"))
	# Roof trusses (visual).
	var z := BACK_Z + 2.0
	while z < FRONT_Z:
		MeshKit.box(self, Vector3(w, 0.3, 0.12), Vector3(0, WALL_H - 0.15, z), _m(&"steel_dark"))
		z += 4.0


func _build_entrance() -> void:
	var side_w := HALF_W - DOOR_W * 0.5
	var fz := FRONT_Z + WALL_T * 0.5
	for side: float in [-1.0, 1.0]:
		var x := side * (DOOR_W * 0.5 + side_w * 0.5)
		MeshKit.solid_box(self, Vector3(side_w, WALL_H, WALL_T), Vector3(x, WALL_H * 0.5, fz), _m(&"wall"))
	MeshKit.solid_box(self, Vector3(DOOR_W, WALL_H - DOOR_H, WALL_T), Vector3(0, DOOR_H + (WALL_H - DOOR_H) * 0.5, fz), _m(&"wall"))
	# Closed sectional roller door: horizontal slats inside the opening.
	var door := Node3D.new()
	door.name = "RollerDoor"
	add_child(door)
	var slat_h := 0.35
	var y := slat_h * 0.5
	while y < DOOR_H:
		MeshKit.box(door, Vector3(DOOR_W, slat_h - 0.02, 0.06), Vector3(0, y, fz - 0.05), _m(&"steel"))
		y += slat_h
	MeshKit.static_box(door, Vector3(DOOR_W, DOOR_H, 0.1), Vector3(0, DOOR_H * 0.5, fz - 0.05))
	# Door frame rails and drum housing.
	for side: float in [-1.0, 1.0]:
		MeshKit.box(door, Vector3(0.12, DOOR_H, 0.15), Vector3(side * (DOOR_W * 0.5 + 0.06), DOOR_H * 0.5, fz - 0.15), _m(&"steel_dark"))
	MeshKit.box(door, Vector3(DOOR_W + 0.4, 0.45, 0.45), Vector3(0, DOOR_H + 0.25, fz - 0.3), _m(&"steel_dark"))
	MeshKit.label(self, "ENTRANCE  ·  BAY 01", Vector3(-1.2, DOOR_H + 0.75, fz - 0.14), 0.004, 48, Color(0.7, 0.7, 0.7)).rotation_degrees = Vector3(0, 180, 0)


func _build_lighting() -> void:
	# Two rows of overhead linear fixtures with downward spot lights.
	var positions: Array[Vector3] = []
	for x: float in [-3.2, 3.2]:
		for z: float in [-5.5, -1.0, 3.5, 8.0]:
			positions.append(Vector3(x, WALL_H - 0.5, z))
	positions.append(Vector3(0, WALL_H - 0.6, -1.2))  # directly over the engine bay
	for i: int in positions.size():
		var p: Vector3 = positions[i]
		MeshKit.box(self, Vector3(0.35, 0.08, 1.6), p, _m(&"light_fixture"))
		MeshKit.box(self, Vector3(0.4, 0.06, 1.7), p + Vector3(0, 0.07, 0), _m(&"steel_dark"))
		var light := SpotLight3D.new()
		light.position = p + Vector3(0, -0.1, 0)
		light.rotation_degrees = Vector3(-90, 0, 0)
		light.spot_angle = 68.0
		light.spot_range = 9.5
		light.spot_attenuation = 0.75
		light.light_energy = 2.6 if i == positions.size() - 1 else 1.9
		light.light_size = 0.12  # soft (PCSS) shadows on Forward+
		light.shadow_blur = 1.5
		light.light_color = Color(1.0, 0.97, 0.92)
		light.shadow_enabled = (i % 2 == 0) or i == positions.size() - 1
		add_child(light)
	# Shadowless fill along the walls so the perimeter and equipment read.
	for fx: float in [-HALF_W + 1.2, HALF_W - 1.2]:
		for fz: float in [-6.5, -1.5, 3.5, 8.0]:
			var fill := OmniLight3D.new()
			fill.position = Vector3(fx, 3.6, fz)
			fill.omni_range = 7.0
			fill.omni_attenuation = 1.2
			fill.light_energy = 0.55
			fill.light_color = Color(0.95, 0.96, 1.0)
			fill.shadow_enabled = false
			add_child(fill)
	for bx: float in [-4.0, 4.0]:
		var back := OmniLight3D.new()
		back.position = Vector3(bx, 3.4, BACK_Z + 1.2)
		back.omni_range = 6.5
		back.light_energy = 0.5
		back.shadow_enabled = false
		add_child(back)
	# Task lights over the wall stations (shelf, workbench, information board).
	var stations: Array[Vector3] = [Vector3(-HALF_W + 1.4, WALL_H - 0.9, -3.0), Vector3(-2.5, WALL_H - 0.9, BACK_Z + 1.4), Vector3(HALF_W - 1.4, WALL_H - 0.9, -2.2)]
	for p: Vector3 in stations:
		MeshKit.box(self, Vector3(0.9, 0.06, 0.25), p, _m(&"light_fixture"))
		var task := SpotLight3D.new()
		task.position = p + Vector3(0, -0.08, 0)
		var aim := Vector3(signf(p.x) * HALF_W if absf(p.x) > 5.0 else p.x, 1.0, p.z if absf(p.x) > 5.0 else BACK_Z)
		task.transform = Transform3D(Basis.looking_at(aim - task.position, Vector3.UP), task.position)
		task.spot_angle = 55.0
		task.spot_range = 7.0
		task.light_energy = 1.6
		task.light_color = Color(1.0, 0.97, 0.92)
		add_child(task)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.03, 0.035)
	# A soft neutral sky (procedural, no external HDRI) feeds ambient light and
	# reflections; the room itself is enclosed, so it is never seen directly.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.38, 0.42)
	sky_mat.sky_horizon_color = Color(0.5, 0.5, 0.5)
	sky_mat.ground_bottom_color = Color(0.14, 0.14, 0.15)
	sky_mat.ground_horizon_color = Color(0.32, 0.32, 0.33)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_color = Color(0.34, 0.35, 0.37)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 0.9
	env.ssao_intensity = 1.6
	env.ssil_enabled = false
	env.ssr_enabled = false
	env.ssr_max_steps = 48
	env.glow_enabled = false  # deliberately no bloom
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 0.95
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	# Room-sized reflection probe so paint and chrome reflect the workshop (Forward+).
	var probe := ReflectionProbe.new()
	probe.name = "ReflectionProbe"
	probe.size = Vector3(HALF_W * 2, WALL_H, FRONT_Z - BACK_Z)
	probe.position = Vector3(0, WALL_H * 0.5, (FRONT_Z + BACK_Z) * 0.5)
	probe.origin_offset = Vector3(0, -WALL_H * 0.5 + 1.2, -((FRONT_Z + BACK_Z) * 0.5))
	probe.box_projection = true
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(probe)


func _build_repair_bay() -> void:
	# Painted bay outline around the car and an engine-bay inspection mat.
	var line_mat := _m(&"safety_line")
	var bw := 4.4
	var bl := 7.2
	var t := 0.08
	for side: float in [-1.0, 1.0]:
		MeshKit.box(self, Vector3(t, 0.005, bl), Vector3(side * bw * 0.5, 0.003, 0), line_mat)
		MeshKit.box(self, Vector3(bw, 0.005, t), Vector3(0, 0.003, side * bl * 0.5), line_mat)
	var mark := MeshKit.label(self, "REPAIR BAY 01", Vector3(-1.0, 0.006, 3.4), 0.006, 64, Color(0.75, 0.72, 0.55))
	mark.rotation_degrees = Vector3(-90, 0, 0)
	# Engine bay inspection area in front of the car.
	MeshKit.box(self, Vector3(2.6, 0.012, 1.6), Vector3(0, 0.006, -3.35), _m(&"mat"))
	var insp := MeshKit.label(self, "ENGINE BAY INSPECTION", Vector3(-1.1, 0.014, -2.75), 0.004, 48, Color(0.65, 0.65, 0.65))
	insp.rotation_degrees = Vector3(-90, 0, 0)
	# Portable work light on a stand beside the inspection area.
	var stand := Node3D.new()
	stand.position = Vector3(-1.6, 0, -3.6)
	add_child(stand)
	MeshKit.cylinder(stand, 0.25, 0.04, Vector3(0, 0.02, 0), _m(&"steel_dark"))
	MeshKit.cylinder(stand, 0.02, 1.6, Vector3(0, 0.8, 0), _m(&"steel"))
	MeshKit.box(stand, Vector3(0.3, 0.2, 0.06), Vector3(0.05, 1.62, 0.05), _m(&"light_fixture"), Vector3(-30, 35, 0))
	MeshKit.furniture_box(stand, Vector3(0.3, 1.7, 0.3), Vector3(0, 0.85, 0))
	var wl := SpotLight3D.new()
	var lamp_pos := Vector3(0.05, 1.62, 0.1)
	# Aim at the engine bay (world target converted to the unrotated stand's space).
	var aim := Vector3(0.0, 0.7, -1.6) - stand.position - lamp_pos
	wl.transform = Transform3D(Basis.looking_at(aim, Vector3.UP), lamp_pos)
	wl.spot_angle = 40.0
	wl.spot_range = 5.0
	wl.light_energy = 1.4
	wl.shadow_enabled = true
	stand.add_child(wl)


func _build_lift() -> void:
	# Two-post lift, lowered. Posts flank the car at the wheelbase centre.
	var lift := Node3D.new()
	lift.name = "VehicleLift"
	add_child(lift)
	_lift_carriage = Node3D.new()
	_lift_carriage.name = "Carriage"
	lift.add_child(_lift_carriage)
	for side: float in [-1.0, 1.0]:
		var x := side * 1.78
		MeshKit.solid_box(lift, Vector3(0.32, 3.9, 0.32), Vector3(x, 1.95, 0.1), _m(&"lift_paint"))
		MeshKit.box(lift, Vector3(0.6, 0.02, 0.6), Vector3(x, 0.01, 0.1), _m(&"steel_dark"))
		# Hydraulic cylinder and chain guard on the post.
		ProcMesh.add(lift, ProcMesh.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.05, 0), Vector2(0.05, 2.6), Vector2(0, 2.6)]), 16), _m(&"steel"), Vector3(x + side * 0.2, 0.05, 0.1))
		MeshKit.box(lift, Vector3(0.04, 3.4, 0.2), Vector3(x - side * 0.17, 1.9, 0.1), _m(&"steel_dark"))
		MeshKit.box(_lift_carriage, Vector3(0.12, 0.3, 0.36), Vector3(x - side * 0.2, 0.25, 0.1), _m(&"steel_dark"))
		for dz: float in [-0.9, 1.0]:
			MeshKit.box(_lift_carriage, Vector3(0.75, 0.06, 0.09), Vector3(x - side * 0.5, 0.12, dz * 0.62 + 0.1), _m(&"steel"), Vector3(0, side * dz * 18.0, 0))
			MeshKit.cylinder(_lift_carriage, 0.07, 0.04, Vector3(x - side * 0.85, 0.16, dz * 0.75 + 0.1), _m(&"rubber"))
	# Lift control box on the right post.
	var ctrl := Interactable.new()
	ctrl.name = "LiftControl"
	ctrl.target_type = &"lift"
	ctrl.target_id = &"lift"
	ctrl.display_name = "Lift control"
	ctrl.position = Vector3(1.78 + 0.22, 1.25, 0.32)
	lift.add_child(ctrl)
	ctrl.highlight_meshes.append(ProcMesh.add(ctrl, ProcMesh.rounded_box(Vector3(0.16, 0.24, 0.1), 0.015), _m(&"plastic_grey")))
	MeshKit.box(ctrl, Vector3(0.04, 0.04, 0.01), Vector3(0, 0.05, 0.052), _m(&"led_green"))
	MeshKit.box(ctrl, Vector3(0.04, 0.04, 0.01), Vector3(0, -0.03, 0.052), _m(&"lamp_on"))
	ctrl.add_box_shape(Vector3(0.18, 0.26, 0.14))
	interactable_created.emit(ctrl)
	MeshKit.box(lift, Vector3(3.9, 0.22, 0.32), Vector3(0, 3.95, 0.1), _m(&"lift_paint"))
	var tag := MeshKit.label(lift, "2-POST LIFT · LOWERED", Vector3(-1.95, 2.6, 0.27), 0.0025, 32, Color(0.6, 0.6, 0.6))
	tag.rotation_degrees = Vector3(0, 0, 0)


func _build_workbench() -> void:
	var bench := Node3D.new()
	bench.name = "Workbench"
	bench.position = Vector3(-2.5, 0, BACK_Z + 0.45)
	add_child(bench)
	MeshKit.box(bench, Vector3(3.2, 0.06, 0.8), Vector3(0, 0.92, 0), _m(&"wood"))
	MeshKit.furniture_box(bench, Vector3(3.2, 0.06, 0.8), Vector3(0, 0.92, 0))
	MeshKit.box(bench, Vector3(3.1, 0.7, 0.75), Vector3(0, 0.45, 0.0), _m(&"steel_dark"))
	MeshKit.furniture_box(bench, Vector3(3.1, 0.9, 0.75), Vector3(0, 0.45, 0))
	for i: int in 4:
		MeshKit.box(bench, Vector3(0.7, 0.015, 0.02), Vector3(-1.15 + i * 0.77, 0.7, 0.39), _m(&"steel"))
	# Pegboard and vice.
	MeshKit.box(bench, Vector3(3.2, 1.3, 0.03), Vector3(0, 1.75, -0.38), _m(&"steel_dark"))
	MeshKit.box(bench, Vector3(0.18, 0.14, 0.25), Vector3(1.3, 1.02, 0.15), _m(&"cast_iron"))
	for i: int in 7:
		MeshKit.box(bench, Vector3(0.03, 0.22 + 0.03 * i, 0.02), Vector3(-1.2 + i * 0.16, 1.7, -0.35), _m(&"steel"))
	MeshKit.label(bench, "WORKBENCH", Vector3(-1.5, 2.45, -0.36), 0.003, 40, Color(0.6, 0.6, 0.6))
	var drawer := Interactable.new()
	drawer.name = "HardwareDrawer"
	drawer.target_type = &"hardware"
	drawer.target_id = &"hardware"
	drawer.display_name = "Hardware drawer"
	drawer.position = Vector3(-0.38, 1.02, 0.15)
	bench.add_child(drawer)
	drawer.highlight_meshes.append(ProcMesh.add(drawer, ProcMesh.rounded_box(Vector3(0.4, 0.14, 0.28), 0.01), _m(&"steel_dark")))
	for i: int in 3:
		MeshKit.box(drawer, Vector3(0.36, 0.035, 0.005), Vector3(0, -0.045 + i * 0.045, 0.142), _m(&"plastic_grey"))
	MeshKit.label(drawer, "HARDWARE", Vector3(-0.1, 0.1, 0.1), 0.0012, 28, Color(0.75, 0.75, 0.75))
	drawer.add_box_shape(Vector3(0.42, 0.16, 0.3))
	interactable_created.emit(drawer)


func _build_tool_trolley() -> void:
	var trolley := Node3D.new()
	trolley.name = "ToolTrolley"
	trolley.position = Vector3(2.25, 0, -3.3)
	trolley.rotation_degrees = Vector3(0, -20, 0)
	add_child(trolley)
	MeshKit.box(trolley, Vector3(0.75, 0.85, 0.45), Vector3(0, 0.52, 0), _m(&"paint_dark"))
	MeshKit.furniture_box(trolley, Vector3(0.75, 0.95, 0.45), Vector3(0, 0.5, 0))
	for i: int in 4:
		MeshKit.box(trolley, Vector3(0.68, 0.17, 0.01), Vector3(0, 0.22 + i * 0.2, 0.226), _m(&"plastic_grey"))
		MeshKit.box(trolley, Vector3(0.3, 0.015, 0.02), Vector3(0, 0.28 + i * 0.2, 0.235), _m(&"steel"))
	MeshKit.box(trolley, Vector3(0.78, 0.03, 0.48), Vector3(0, 0.96, 0), _m(&"rubber"))
	for cx: float in [-0.32, 0.32]:
		for cz: float in [-0.18, 0.18]:
			MeshKit.cylinder(trolley, 0.045, 0.03, Vector3(cx, 0.045, cz), _m(&"rubber"), Vector3(0, 0, 90))
	# Battery maintainer on top of the trolley (interactable).
	var charger := Interactable.new()
	charger.name = "BatteryCharger"
	charger.target_type = &"charger"
	charger.target_id = &"charger"
	charger.display_name = "Battery maintainer"
	charger.position = Vector3(-0.15, 1.05, 0)
	trolley.add_child(charger)
	charger.highlight_meshes.append(MeshKit.box(charger, Vector3(0.26, 0.14, 0.18), Vector3.ZERO, _m(&"plastic_black")))
	MeshKit.box(charger, Vector3(0.1, 0.04, 0.005), Vector3(0, 0.02, 0.092), _m(&"led_green"), Vector3.ZERO, "Led")
	charger.add_box_shape(Vector3(0.3, 0.18, 0.22))
	interactable_created.emit(charger)
	# Decorative scanner dock.
	MeshKit.box(trolley, Vector3(0.14, 0.04, 0.2), Vector3(0.22, 1.0, 0), _m(&"plastic_grey"))


func _build_parts_shelf() -> void:
	var shelf := Node3D.new()
	shelf.name = "PartsShelf"
	shelf.position = Vector3(-HALF_W + 0.35, 0, -3.0)
	shelf.rotation_degrees = Vector3(0, 90, 0)
	add_child(shelf)
	var width := 2.4
	for x: float in [-width * 0.5, width * 0.5]:
		for z: float in [-0.25, 0.25]:
			MeshKit.box(shelf, Vector3(0.04, 2.2, 0.04), Vector3(x, 1.1, z), _m(&"steel_dark"))
	for i: int in 4:
		var y := 0.15 + i * 0.6
		MeshKit.box(shelf, Vector3(width, 0.03, 0.55), Vector3(0, y, 0), _m(&"steel"))
	MeshKit.furniture_box(shelf, Vector3(width, 2.2, 0.55), Vector3(0, 1.1, 0))
	MeshKit.label(shelf, "PARTS STORAGE", Vector3(-1.1, 2.45, 0.28), 0.003, 40, Color(0.65, 0.65, 0.65))
	# Decorative stock boxes.
	var deco := [Vector3(-0.8, 0.32, 0), Vector3(-0.35, 0.32, 0.05), Vector3(0.7, 0.92, 0), Vector3(-0.9, 1.52, 0), Vector3(0.4, 1.52, 0)]
	for p: Vector3 in deco:
		MeshKit.box(shelf, Vector3(0.36, 0.3, 0.38), p, _m(&"plastic_grey"))
	_shelf = shelf
	# Core return bin on the floor beside the shelf (removed parts go here).
	var bin := Interactable.new()
	bin.name = "CoreBin"
	bin.target_type = &"core_bin"
	bin.target_id = &"core_bin"
	bin.display_name = "Core return bin"
	bin.position = Vector3(width * 0.5 + 0.55, 0.3, 0.05)
	shelf.add_child(bin)
	bin.highlight_meshes.append(MeshKit.box(bin, Vector3(0.6, 0.6, 0.5), Vector3.ZERO, _m(&"steel_dark")))
	MeshKit.label(bin, "CORE\nRETURN", Vector3(-0.2, 0.2, 0.256), 0.0015, 32, Color(0.75, 0.75, 0.75))
	bin.add_box_shape(Vector3(0.6, 0.6, 0.5))
	# The bin is also a physical obstacle for the player.
	MeshKit.furniture_box(bin, Vector3(0.6, 0.6, 0.5), Vector3.ZERO)
	interactable_created.emit(bin)


func _build_info_board() -> void:
	var board := Interactable.new()
	board.name = "InfoBoard"
	board.target_type = &"work_order"
	board.target_id = &"board"
	board.display_name = "Vehicle information board"
	board.position = Vector3(HALF_W - 0.06, 1.7, -2.2)
	board.rotation_degrees = Vector3(0, -90, 0)
	add_child(board)
	board.highlight_meshes.append(MeshKit.box(board, Vector3(2.2, 1.3, 0.04), Vector3.ZERO, _m(&"plastic_black")))
	MeshKit.box(board, Vector3(2.26, 1.36, 0.03), Vector3(0, 0, -0.01), _m(&"steel"))
	board.add_box_shape(Vector3(2.2, 1.3, 0.1))
	var text := MeshKit.label(board, "", Vector3(-1.02, 0.58, 0.025), 0.0016, 36)
	text.name = "BoardText"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.width = 2.04 / text.pixel_size
	interactable_created.emit(board)


## Rebuilds the job's stock on the parts shelf. [param items]: Array of
## {"id": target id ("alternator" or "fluid:coolant_lt"), "label": String, "kind": "part"|"fluid"}.
func set_stock(items: Array) -> void:
	if _shelf == null:
		return
	for c: Node in _shelf.get_children():
		if c.name.begins_with("Stock_"):
			_shelf.remove_child(c)
			c.queue_free()
	for i: int in mini(items.size(), STOCK_SLOTS.size()):
		var it: Dictionary = items[i]
		var stock := Interactable.new()
		stock.name = "Stock_%s" % String(it["id"]).replace(":", "_")
		stock.target_type = &"shelf"
		stock.target_id = StringName(it["id"])
		stock.display_name = it["label"]
		stock.position = STOCK_SLOTS[i]
		_shelf.add_child(stock)
		if it.get("kind", "part") == "fluid":
			var jug := StandardMaterial3D.new()
			jug.albedo_color = Color(0.85, 0.85, 0.82)
			jug.roughness = 0.5
			stock.highlight_meshes.append(ProcMesh.add(stock, ProcMesh.rounded_box(Vector3(0.18, 0.28, 0.12), 0.03), jug, Vector3(0, 0.0, 0)))
			stock.highlight_meshes.append(ProcMesh.add(stock, ProcMesh.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.025, 0), Vector2(0.025, 0.03), Vector2(0, 0.03)]), 16), WorkshopMaterials.get_mat(&"plastic_black"), Vector3(0.04, 0.14, 0)))
			MeshKit.label(stock, String(it["label"]).to_upper(), Vector3(-0.08, 0.08, 0.062), 0.001, 28, Color(0.15, 0.15, 0.15))
			stock.add_box_shape(Vector3(0.2, 0.3, 0.14))
		else:
			stock.highlight_meshes.append(MeshKit.box(stock, Vector3(0.36, 0.32, 0.32), Vector3.ZERO, _m(&"wood"), Vector3.ZERO, "Box"))
			MeshKit.label(stock, String(it["label"]).to_upper(), Vector3(-0.16, 0.1, 0.162), 0.0011, 28, Color(0.1, 0.1, 0.1))
			stock.add_box_shape(Vector3(0.38, 0.34, 0.34))
		interactable_created.emit(stock)


## Moves the lift arms (the vehicle itself is moved by Main).
func set_lift_height(h: float) -> void:
	if _lift_carriage:
		_lift_carriage.position.y = h


## Updates the information board text (called by Main when job data changes).
func set_board_text(text: String) -> void:
	var l := get_node_or_null("InfoBoard/BoardText") as Label3D
	if l:
		l.text = text


## Updates the charger status LED.
func set_charger_on(on: bool) -> void:
	var led := get_node_or_null("ToolTrolley/BatteryCharger/Led") as MeshInstance3D
	if led:
		led.material_override = _m(&"led_green") if on else _m(&"lamp_off")
