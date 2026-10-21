class_name InteriorBuilder
extends RefCounted
## Cabin interior placeholder: dashboard, binnacle, steering wheel, seats,
## centre console, door cards and floor. Driver on -X (left-hand drive).

var b: VehicleBodyBuilder


func _init(body: VehicleBodyBuilder) -> void:
	b = body


func build(mats: Dictionary) -> Node3D:
	var p := b.p
	var root := Node3D.new()
	root.name = "Interior"
	var hw := p.half_width * 0.78
	var dash_z := p.windscreen_base_z + 0.24
	var dash_y := p.cowl_y + 0.03
	var dash := ProcMesh.rounded_box(Vector3(hw * 2.0, 0.16, 0.34), 0.06)
	ProcMesh.add(root, dash, mats.get("trim"), Vector3(0, dash_y, dash_z), Vector3.ZERO, "Dashboard")
	ProcMesh.add(root, ProcMesh.rounded_box(Vector3(hw * 1.96, 0.02, 0.3), 0.01), mats.get("trim"), Vector3(0, dash_y + 0.085, dash_z - 0.01), Vector3.ZERO, "DashTop")
	var driver_x := -hw * 0.48
	ProcMesh.add(root, ProcMesh.rounded_box(Vector3(0.34, 0.07, 0.12), 0.03), mats.get("trim"), Vector3(driver_x, dash_y + 0.11, dash_z + 0.06), Vector3(-15, 0, 0), "Binnacle")
	var sw := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.165
	tm.outer_radius = 0.19
	tm.rings = 32
	sw.mesh = tm
	sw.material_override = mats.get("leather")
	sw.name = "SteeringWheel"
	sw.position = Vector3(driver_x, dash_y + 0.02, dash_z + 0.26)
	sw.rotation_degrees = Vector3(68, 0, 0)
	root.add_child(sw)
	ProcMesh.add(sw, ProcMesh.rounded_box(Vector3(0.12, 0.1, 0.05), 0.03), mats.get("trim"), Vector3.ZERO, Vector3(90, 0, 0), "Hub")
	ProcMesh.add(sw, ProcMesh.rounded_box(Vector3(0.34, 0.03, 0.02), 0.01), mats.get("trim"), Vector3(0, 0, 0), Vector3(90, 0, 0), "Spokes")
	var seat_z := p.roof_front_z + 0.62
	for side: float in [-1.0, 1.0]:
		var seat := Node3D.new()
		seat.name = "Seat_%s" % ("L" if side < 0 else "R")
		seat.position = Vector3(side * hw * 0.48, p.sill_y + 0.1, seat_z)
		root.add_child(seat)
		ProcMesh.add(seat, ProcMesh.rounded_box(Vector3(0.5, 0.12, 0.5), 0.05), mats.get("leather"), Vector3(0, 0.06, 0), Vector3.ZERO, "Cushion")
		ProcMesh.add(seat, ProcMesh.rounded_box(Vector3(0.5, 0.56, 0.12), 0.06), mats.get("leather"), Vector3(0, 0.38, 0.24), Vector3(-14, 0, 0), "Back")
		for bx: float in [-0.22, 0.22]:
			ProcMesh.add(seat, ProcMesh.rounded_box(Vector3(0.07, 0.42, 0.16), 0.03), mats.get("leather"), Vector3(bx, 0.36, 0.2), Vector3(-14, 0, 0), "Bolster")
		ProcMesh.add(seat, ProcMesh.rounded_box(Vector3(0.26, 0.16, 0.08), 0.04), mats.get("leather"), Vector3(0, 0.72, 0.31), Vector3(-10, 0, 0), "Headrest")
		# Door card.
		ProcMesh.add(root, ProcMesh.rounded_box(Vector3(0.03, 0.42, p.door_rear_z - p.door_front_z - 0.1), 0.01), mats.get("trim"), Vector3(side * (p.half_width - 0.06), p.sill_y + 0.45, (p.door_front_z + p.door_rear_z) * 0.5), Vector3.ZERO, "DoorCard_%s" % ("L" if side < 0 else "R"))
	ProcMesh.add(root, ProcMesh.rounded_box(Vector3(0.2, 0.18, 0.9), 0.04), mats.get("trim"), Vector3(0, p.sill_y + 0.18, seat_z - 0.3), Vector3.ZERO, "Console")
	ProcMesh.add(root, ProcMesh.rounded_box(Vector3(0.04, 0.06, 0.08), 0.015), mats.get("chrome_dark"), Vector3(0, p.sill_y + 0.3, seat_z - 0.45), Vector3.ZERO, "Selector")
	ProcMesh.add(root, ProcMesh.rounded_box(Vector3(hw * 2.0, 0.02, 1.8), 0.01), mats.get("carpet"), Vector3(0, p.sill_y + 0.06, seat_z - 0.2), Vector3.ZERO, "Floor")
	if p.roof_rear_z - p.roof_front_z > 0.85:
		ProcMesh.add(root, ProcMesh.rounded_box(Vector3(hw * 1.7, 0.12, 0.45), 0.05), mats.get("leather"), Vector3(0, p.sill_y + 0.3, seat_z + 0.75), Vector3.ZERO, "RearBench")
	return root
