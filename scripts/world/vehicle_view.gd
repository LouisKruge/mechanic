class_name VehicleView
extends Node3D
## Visual and interactive representation of a vehicle.
##
## Component and fastener positions come from Marker3D nodes under "Mounts"
## in the vehicle scene, so they can be adjusted in the editor without code.
## If a marker has a child named "Model" (e.g. an imported glTF), it is used
## instead of the procedural placeholder. Gameplay state is read from the
## session's [VehicleState]; this node never changes it.
##
## Convention for fastener markers: local -Z points out of the threaded hole,
## i.e. the direction a fastener travels while being removed.

@export var vehicle_id: StringName = &"project_c01"

const HOOD_OPEN_DEG: float = 68.0
const HOOD_LERP: float = 5.0
const BOLT_BACKOUT_M: float = 0.028
const CONNECTOR_PULL_M: float = 0.045
const TENSIONER_RELEASED_DEG: float = -26.0
const PULLEY_SPIN_RAD_S: float = 40.0
## Belt pulley layout in the accessory_belt marker's XY plane: [mount name, radius].
const BELT_PULLEYS: Array = [["crank_pulley", 0.085], ["water_pump_pulley", 0.055], ["alternator", 0.032], ["belt_tensioner", 0.036]]

var session: GameSession
## "type:id" -> Interactable
var interactables: Dictionary = {}
var _real: Dictionary = {}    # component id -> Node3D (placeholder or Model)
var _ghost: Dictionary = {}   # component id -> Node3D
var _fast: Dictionary = {}    # fastener id -> {"inter", "head", "ghost", "kind"}
var _hood_pivot: Node3D
var _hood_angle: float = 0.0
var _tensioner_arm: Node3D
var _belt_on: Node3D
var _belt_off: Node3D
var _spinners: Array[Node3D] = []
var _engine_visual: Node3D
var _lamp: MeshInstance3D
var _time: float = 0.0


func _m(n: StringName) -> StandardMaterial3D:
	return WorkshopMaterials.get_mat(n)


func mount(mount_name: String) -> Marker3D:
	return get_node_or_null("Mounts/" + mount_name) as Marker3D


## Builds all geometry and binds to the session's vehicle state.
func setup(p_session: GameSession) -> void:
	session = p_session
	_build_body()
	_build_wheels()
	_build_components()
	_build_fasteners()
	_build_cabin_controls()
	session.vehicle.component_changed.connect(_on_component_changed)
	session.vehicle.fastener_changed.connect(_on_fastener_changed)
	session.inventory.changed.connect(_refresh_ghosts)
	refresh_all()
	_hood_angle = _hood_target()
	_apply_hood()


## Looks up an interactable by session target type and id.
func get_interactable(type: StringName, id: StringName) -> Interactable:
	return interactables.get("%s:%s" % [type, id], null)


func _register(inter: Interactable) -> void:
	interactables["%s:%s" % [inter.target_type, inter.target_id]] = inter


# --- Body --------------------------------------------------------------------

func _build_body() -> void:
	var body := Node3D.new()
	body.name = "Body"
	add_child(body)
	var paint := _m(&"paint_body")
	var dark := _m(&"paint_dark")
	var w := 0.92
	# Upper body slab behind the bay (bonnet line to tail).
	MeshKit.box(body, Vector3(w * 2, 0.16, 2.95), Vector3(0, 0.72, 0.725), paint)
	# Front fenders either side of the engine bay, and the nose.
	for side: float in [-1.0, 1.0]:
		MeshKit.box(body, Vector3(0.2, 0.16, 1.33), Vector3(side * 0.82, 0.72, -1.415), paint)
		MeshKit.box(body, Vector3(0.2, 0.42, 0.44), Vector3(side * 0.8, 0.43, -1.93), paint)  # front corner
		MeshKit.box(body, Vector3(0.12, 0.42, 1.9), Vector3(side * 0.84, 0.43, -0.03), paint)  # sill / door
		MeshKit.box(body, Vector3(0.2, 0.42, 0.52), Vector3(side * 0.8, 0.43, 1.94), paint)  # rear corner
		# Inner fender aprons forming the engine bay walls.
		MeshKit.box(body, Vector3(0.02, 0.5, 1.3), Vector3(side * 0.71, 0.45, -1.42), dark)
		# Door shut line.
		MeshKit.box(body, Vector3(0.005, 0.5, 0.006), Vector3(side * 0.921, 0.55, 0.55), dark)
		MeshKit.box(body, Vector3(0.005, 0.5, 0.006), Vector3(side * 0.921, 0.55, -0.62), dark)
	MeshKit.box(body, Vector3(w * 2, 0.24, 0.12), Vector3(0, 0.68, -2.14), paint)  # nose panel
	MeshKit.box(body, Vector3(1.86, 0.2, 0.16), Vector3(0, 0.32, -2.14), dark)  # front bumper
	MeshKit.box(body, Vector3(1.0, 0.1, 0.02), Vector3(0, 0.52, -2.205), _m(&"plastic_black"))  # grille
	MeshKit.box(body, Vector3(1.4, 0.4, 2.7), Vector3(0, 0.42, 0.65), dark)  # lower tub (hidden core)
	MeshKit.box(body, Vector3(1.86, 0.22, 0.16), Vector3(0, 0.36, 2.14), dark)  # rear bumper
	MeshKit.box(body, Vector3(1.4, 0.03, 1.32), Vector3(0, 0.2, -1.42), _m(&"steel_dark"))  # bay floor / undertray
	MeshKit.box(body, Vector3(1.42, 0.5, 0.04), Vector3(0, 0.55, -0.76), dark)  # firewall
	MeshKit.box(body, Vector3(1.42, 0.03, 0.12), Vector3(0, 0.8, -0.72), _m(&"plastic_black"))  # cowl
	for side: float in [-1.0, 1.0]:
		MeshKit.box(body, Vector3(0.28, 0.06, 0.02), Vector3(side * 0.6, 0.66, -2.205), _m(&"light_fixture"))  # headlamps
		MeshKit.box(body, Vector3(0.32, 0.06, 0.02), Vector3(side * 0.62, 0.7, 2.205), _m(&"lamp_on"))  # tail lamps
	MeshKit.box(body, Vector3(1.5, 0.03, 0.18), Vector3(0, 0.86, 2.05), dark)  # duck-tail spoiler
	# Greenhouse.
	MeshKit.box(body, Vector3(1.34, 0.05, 1.0), Vector3(0, 1.28, 0.45), paint)  # roof
	MeshKit.box(body, Vector3(1.36, 0.01, 0.81), Vector3(0, 1.04, -0.375), _m(&"glass"), Vector3(-36.4, 0, 0))  # windscreen
	MeshKit.box(body, Vector3(1.3, 0.01, 0.84), Vector3(0, 1.05, 1.3), _m(&"glass"), Vector3(33.3, 0, 0))  # rear screen
	MeshKit.box(body, Vector3(0.01, 0.44, 0.96), Vector3(0.69, 1.03, 0.45), _m(&"glass"))  # passenger window
	MeshKit.box(body, Vector3(0.01, 0.04, 0.96), Vector3(-0.69, 0.82, 0.45), _m(&"glass"))  # driver window, lowered
	for side: float in [-1.0, 1.0]:
		MeshKit.box(body, Vector3(0.04, 0.05, 0.84), Vector3(side * 0.68, 1.04, -0.37), paint, Vector3(-36.4, 0, 0))  # A-pillars
		MeshKit.box(body, Vector3(0.05, 0.47, 0.08), Vector3(side * 0.68, 1.03, 0.97), paint)  # B/C pillar
	# Interior.
	MeshKit.box(body, Vector3(1.3, 0.12, 0.26), Vector3(0, 0.86, -0.46), _m(&"plastic_black"))  # dashboard
	var wheel := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.15
	tm.outer_radius = 0.18
	wheel.mesh = tm
	wheel.material_override = _m(&"rubber")
	wheel.position = Vector3(-0.38, 0.95, -0.25)
	wheel.rotation_degrees = Vector3(70, 0, 0)
	body.add_child(wheel)
	for side: float in [-1.0, 1.0]:
		MeshKit.box(body, Vector3(0.48, 0.1, 0.5), Vector3(side * 0.36, 0.62, 0.25), _m(&"plastic_grey"))
		MeshKit.box(body, Vector3(0.48, 0.6, 0.1), Vector3(side * 0.36, 0.95, 0.52), _m(&"plastic_grey"), Vector3(-12, 0, 0))
	MeshKit.label(body, "C01", Vector3(-0.08, 0.66, 2.225), 0.002, 48, Color(0.15, 0.15, 0.15))
	# Physical collision (world layer): lower body, cabin, bay walls. The bay
	# itself is open so engine components stay reachable from above.
	MeshKit.static_box(body, Vector3(1.84, 0.62, 2.95), Vector3(0, 0.49, 0.725))
	MeshKit.static_box(body, Vector3(1.4, 0.5, 1.6), Vector3(0, 1.05, 0.35))
	MeshKit.static_box(body, Vector3(1.84, 0.44, 0.14), Vector3(0, 0.40, -2.13))
	for side: float in [-1.0, 1.0]:
		MeshKit.static_box(body, Vector3(0.2, 0.62, 1.3), Vector3(side * 0.82, 0.49, -1.42))
	MeshKit.static_box(body, Vector3(1.4, 0.04, 1.3), Vector3(0, 0.19, -1.42))
	# Invisible guard filling the open bay: keeps the player (and camera) out
	# of the engine compartment without blocking the interaction ray.
	MeshKit.furniture_box(body, Vector3(1.44, 2.0, 1.31), Vector3(0, 1.2, -1.42))


func _build_wheels() -> void:
	for x: float in [-0.8, 0.8]:
		for z: float in [-1.35, 1.32]:
			var wheel := Node3D.new()
			wheel.name = "Wheel_%s%s" % ["F" if z < 0 else "R", "L" if x < 0 else "R"]
			wheel.position = Vector3(x, 0.33, z)
			add_child(wheel)
			MeshKit.cylinder(wheel, 0.33, 0.235, Vector3.ZERO, _m(&"rubber"), Vector3(0, 0, 90), "Tyre", 32)
			MeshKit.cylinder(wheel, 0.225, 0.24, Vector3.ZERO, _m(&"aluminium"), Vector3(0, 0, 90), "Rim", 24)
			for i: int in 5:
				MeshKit.box(wheel, Vector3(0.245, 0.035, 0.2), Vector3.ZERO, _m(&"steel_dark"), Vector3(i * 72.0, 0, 0))
			MeshKit.cylinder(wheel, 0.14, 0.02, Vector3(0, 0, 0), _m(&"cast_iron"), Vector3(0, 0, 90), "Disc", 24)


# --- Components ----------------------------------------------------------------

## Creates the component's interactable at its marker, the placeholder (or
## the artist "Model"), and a ghost copy shown while the part is removed.
func _make_component(id: StringName, shape: Vector3, shape_offset: Vector3, builder: Callable) -> Interactable:
	var m := mount(String(id))
	if m == null:
		push_error("VehicleView: no mount marker for '%s'" % id)
		return null
	var inter := Interactable.new()
	inter.name = "Interact_%s" % id
	inter.target_type = &"component"
	inter.target_id = id
	m.add_child(inter)
	inter.add_box_shape(shape, shape_offset)
	var real := Node3D.new()
	real.name = "Visual"
	inter.add_child(real)
	var model := m.get_node_or_null("Model") as Node3D
	if model:
		model.reparent(real, false)
	else:
		builder.call(real)
	for mi: MeshInstance3D in _meshes_in(real):
		inter.highlight_meshes.append(mi)
	_real[id] = real
	var def := session.vehicle.definition.get_component(id)
	if def and def.removable:
		var ghost := real.duplicate() as Node3D
		ghost.name = "Ghost"
		_ghostify(ghost)
		ghost.visible = false
		m.add_child(ghost)
		_ghost[id] = ghost
	_register(inter)
	return inter


func _meshes_in(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c: Node in n.get_children():
		if c is MeshInstance3D:
			out.append(c as MeshInstance3D)
		out.append_array(_meshes_in(c))
	return out


func _ghostify(n: Node) -> void:
	for c: Node in n.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = _m(&"ghost")
			(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif c is Label3D:
			c.queue_free()
			continue
		_ghostify(c)


func _build_components() -> void:
	# Hood: the marker is the hinge; the panel extends forward (-Z).
	_hood_pivot = mount("hood")
	_make_component(&"hood", Vector3(1.44, 0.04, 1.3), Vector3(0, 0.02, -0.65), func(v: Node3D) -> void:
		MeshKit.box(v, Vector3(1.44, 0.025, 1.3), Vector3(0, 0.02, -0.65), _m(&"paint_body"))
		MeshKit.box(v, Vector3(1.3, 0.01, 1.16), Vector3(0, 0.003, -0.65), _m(&"paint_dark"))
		MeshKit.box(v, Vector3(0.5, 0.012, 0.6), Vector3(0, 0.036, -0.75), _m(&"paint_dark")))  # bonnet vent
	_make_component(&"engine_block", Vector3(0.5, 0.42, 0.62), Vector3(0, 0.0, 0), _build_engine_visual)
	var rad := mount("radiator")
	if rad:
		MeshKit.box(rad, Vector3(1.1, 0.42, 0.04), Vector3.ZERO, _m(&"steel_dark"))
		MeshKit.box(rad, Vector3(1.04, 0.36, 0.045), Vector3.ZERO, _m(&"cast_iron"))
		MeshKit.cylinder(rad, 0.022, 0.32, Vector3(-0.2, 0.18, 0.18), _m(&"rubber"), Vector3(90, 0, 0))  # top hose
	_make_component(&"alternator_bracket", Vector3(0.16, 0.22, 0.04), Vector3.ZERO, func(v: Node3D) -> void:
		MeshKit.box(v, Vector3(0.16, 0.22, 0.035), Vector3.ZERO, _m(&"aluminium"))
		MeshKit.box(v, Vector3(0.04, 0.04, 0.05), Vector3(-0.08, 0.1, -0.02), _m(&"aluminium"))
		MeshKit.box(v, Vector3(0.04, 0.04, 0.05), Vector3(0.08, -0.065, -0.02), _m(&"aluminium")))
	_make_component(&"alternator", Vector3(0.15, 0.15, 0.15), Vector3(0, 0, 0.0), _build_alternator_visual)
	_make_component(&"belt_tensioner", Vector3(0.09, 0.09, 0.03), Vector3(0, 0, -0.005), _build_tensioner_visual)
	_build_belt()
	_make_component(&"battery", Vector3(0.18, 0.2, 0.26), Vector3(0, 0.1, 0), func(v: Node3D) -> void:
		MeshKit.box(v, Vector3(0.18, 0.19, 0.26), Vector3(0, 0.095, 0), _m(&"plastic_black"))
		MeshKit.box(v, Vector3(0.18, 0.012, 0.26), Vector3(0, 0.196, 0), _m(&"plastic_grey"))
		MeshKit.cylinder(v, 0.011, 0.02, Vector3(0.045, 0.21, -0.085), _m(&"copper"))  # positive post
		MeshKit.box(v, Vector3(0.04, 0.02, 0.04), Vector3(0.045, 0.222, -0.085), _m(&"lamp_on"))  # red cover
		MeshKit.cylinder(v, 0.011, 0.02, Vector3(0.045, 0.205, 0.085), _m(&"steel"))  # negative post
		var lbl := MeshKit.label(v, "12V 50Ah", Vector3(-0.091, 0.15, 0.08), 0.0012, 32, Color(0.85, 0.85, 0.85))
		lbl.rotation_degrees = Vector3(0, -90, 0))
	_make_component(&"starter", Vector3(0.12, 0.12, 0.22), Vector3.ZERO, func(v: Node3D) -> void:
		MeshKit.cylinder(v, 0.05, 0.18, Vector3.ZERO, _m(&"steel_dark"), Vector3(90, 0, 0))
		MeshKit.cylinder(v, 0.028, 0.12, Vector3(-0.055, 0.03, -0.02), _m(&"zinc"), Vector3(90, 0, 0))
		MeshKit.cylinder(v, 0.02, 0.04, Vector3(0, 0, -0.1), _m(&"steel"), Vector3(90, 0, 0)))
	# Instrument cluster with the charge-warning lamp (visual only).
	var cl := mount("instrument_cluster")
	if cl:
		MeshKit.box(cl, Vector3(0.36, 0.1, 0.06), Vector3(0, 0.0, 0), _m(&"plastic_black"), Vector3(-20, 0, 0))
		for gx: float in [-0.08, 0.08]:
			MeshKit.cylinder(cl, 0.04, 0.005, Vector3(gx, 0.005, 0.032), _m(&"plastic_grey"), Vector3(70, 0, 0))
		_lamp = MeshKit.box(cl, Vector3(0.03, 0.02, 0.012), Vector3(0, 0.04, 0.03), _m(&"lamp_off"), Vector3(-20, 0, 0), "ChargeLamp")
		var cap := MeshKit.label(cl, "CHG", Vector3(0.022, 0.05, 0.034), 0.0008, 24, Color(0.8, 0.8, 0.8))
		cap.rotation_degrees = Vector3(-20, 0, 0)


func _build_engine_visual(v: Node3D) -> void:
	_engine_visual = v
	MeshKit.box(v, Vector3(0.48, 0.38, 0.62), Vector3(0, -0.02, 0), _m(&"cast_iron"))  # block
	MeshKit.box(v, Vector3(0.42, 0.1, 0.6), Vector3(0, 0.22, 0), _m(&"aluminium"))  # head
	MeshKit.box(v, Vector3(0.34, 0.07, 0.56), Vector3(0, 0.3, 0), _m(&"paint_dark"))  # cam cover
	# Reads correctly for a mechanic standing at the front of the car.
	var lbl := MeshKit.label(v, "C01  2.0", Vector3(0.07, 0.336, -0.1), 0.0018, 40, Color(0.75, 0.75, 0.75))
	lbl.rotation_degrees = Vector3(-90, 180, 0)
	MeshKit.cylinder(v, 0.025, 0.03, Vector3(0.08, 0.345, -0.15), _m(&"plastic_black"))  # oil filler
	for i: int in 4:
		MeshKit.cylinder(v, 0.026, 0.2, Vector3(-0.27, 0.18, -0.21 + i * 0.14), _m(&"aluminium"), Vector3(0, 0, 70))  # intake runners
	MeshKit.box(v, Vector3(0.08, 0.1, 0.56), Vector3(-0.35, 0.24, 0), _m(&"aluminium"))  # plenum
	for i: int in 4:
		MeshKit.cylinder(v, 0.022, 0.12, Vector3(0.27, 0.05, -0.21 + i * 0.14), _m(&"cast_iron"), Vector3(0, 0, -80))  # exhaust
	MeshKit.box(v, Vector3(0.36, 0.3, 0.02), Vector3(0, -0.02, -0.32), _m(&"aluminium"))  # timing cover


func _build_alternator_visual(v: Node3D) -> void:
	# Body axis along Z; pulley faces the front of the car (-Z).
	MeshKit.cylinder(v, 0.075, 0.13, Vector3(0, 0, 0.0), _m(&"aluminium"), Vector3(90, 0, 0), "Body")
	MeshKit.cylinder(v, 0.068, 0.02, Vector3(0, 0, 0.072), _m(&"aluminium_burnt"), Vector3(90, 0, 0), "RearCover")
	for i: int in 6:
		MeshKit.box(v, Vector3(0.152, 0.006, 0.07), Vector3(0, 0, -0.01), _m(&"steel_dark"), Vector3(0, 0, i * 30.0))
	MeshKit.cylinder(v, 0.066, 0.008, Vector3(0, 0, -0.07), _m(&"steel"), Vector3(90, 0, 0), "Fan")
	var pulley := MeshKit.cylinder(v, 0.032, 0.026, Vector3(0, 0, -0.088), _m(&"steel"), Vector3(90, 0, 0), "Pulley", 16)
	MeshKit.box(pulley, Vector3(0.05, 0.03, 0.004), Vector3.ZERO, _m(&"steel_dark"))
	_spinners.append(pulley)
	# Mounting ears matching the B01/B02 markers.
	MeshKit.box(v, Vector3(0.03, 0.05, 0.025), Vector3(-0.07, 0.07, -0.07), _m(&"aluminium"), Vector3(0, 0, 40))
	MeshKit.box(v, Vector3(0.03, 0.05, 0.025), Vector3(0.075, -0.06, -0.07), _m(&"aluminium"), Vector3(0, 0, 40))
	MeshKit.box(v, Vector3(0.025, 0.02, 0.02), Vector3(0.05, 0.05, 0.075), _m(&"copper"))  # B+ stud


func _build_tensioner_visual(v: Node3D) -> void:
	MeshKit.box(v, Vector3(0.05, 0.05, 0.03), Vector3(0.03, -0.03, 0.02), _m(&"cast_iron"))  # base
	_tensioner_arm = Node3D.new()
	_tensioner_arm.name = "Arm"
	_tensioner_arm.position = Vector3(0.03, -0.03, 0)
	v.add_child(_tensioner_arm)
	MeshKit.box(_tensioner_arm, Vector3(0.07, 0.022, 0.015), Vector3(-0.025, 0.02, -0.01), _m(&"aluminium"), Vector3(0, 0, 40))
	var p := MeshKit.cylinder(_tensioner_arm, 0.036, 0.024, Vector3(-0.03, 0.03, -0.012), _m(&"plastic_grey"), Vector3(90, 0, 0), "Pulley", 18)
	MeshKit.box(p, Vector3(0.05, 0.026, 0.004), Vector3.ZERO, _m(&"steel_dark"))
	_spinners.append(p)
	MeshKit.box(_tensioner_arm, Vector3(0.012, 0.012, 0.01), Vector3(0.0, 0.0, -0.02), _m(&"steel"))  # square drive


func _belt_points(include_alternator: bool) -> Array[Vector3]:
	var belt := mount("accessory_belt")
	var pts: Array[Vector3] = []
	var centres: Array[Vector3] = []
	var radii: Array[float] = []
	for entry: Array in BELT_PULLEYS:
		var mk := mount(entry[0])
		if mk == null:
			continue
		var c := belt.to_local(mk.global_position) if belt.is_inside_tree() else (mk.position - belt.position)
		c.z = 0.0
		if entry[0] == "alternator" and not include_alternator:
			c = Vector3(c.x - 0.03, c.y - 0.12, 0.0)  # slack loop hangs below the pulley
		if entry[0] == "belt_tensioner":
			c += Vector3(0.0, 0.0, 0.0)
		centres.append(c)
		radii.append(float(entry[1]))
	var centroid := Vector3.ZERO
	for c: Vector3 in centres:
		centroid += c
	centroid /= maxf(centres.size(), 1)
	for i: int in centres.size():
		var out := (centres[i] - centroid).normalized()
		# The tensioner presses on the back of the belt (inside the loop).
		var sign := -1.0 if i == centres.size() - 1 else 1.0
		pts.append(centres[i] + out * radii[i] * sign)
	return pts


func _belt_mesh(parent: Node3D, pts: Array[Vector3]) -> void:
	for i: int in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var mid := (a + b) * 0.5
		var seg := MeshKit.box(parent, Vector3(0.008, (b - a).length(), 0.022), mid, _m(&"rubber"))
		seg.rotation.z = atan2(b.y - a.y, b.x - a.x) - PI * 0.5


func _build_belt() -> void:
	var belt := mount("accessory_belt")
	var crank := mount("crank_pulley")
	if crank:
		var cp := MeshKit.cylinder(crank, 0.085, 0.03, Vector3.ZERO, _m(&"cast_iron"), Vector3(90, 0, 0), "Pulley", 28)
		MeshKit.box(cp, Vector3(0.12, 0.032, 0.006), Vector3.ZERO, _m(&"steel_dark"))
		_spinners.append(cp)
	var wp := mount("water_pump_pulley")
	if wp:
		var wpp := MeshKit.cylinder(wp, 0.055, 0.026, Vector3.ZERO, _m(&"steel"), Vector3(90, 0, 0), "Pulley", 22)
		MeshKit.box(wpp, Vector3(0.08, 0.028, 0.006), Vector3.ZERO, _m(&"steel_dark"))
		_spinners.append(wpp)
	if belt == null:
		return
	var inter := Interactable.new()
	inter.name = "Interact_accessory_belt"
	inter.target_type = &"component"
	inter.target_id = &"accessory_belt"
	belt.add_child(inter)
	var alt := mount("alternator")
	var alt_local := alt.position - belt.position
	inter.add_box_shape(Vector3(0.1, 0.1, 0.035), Vector3(alt_local.x, alt_local.y - 0.02, -0.004))
	_belt_on = Node3D.new()
	_belt_on.name = "Routed"
	inter.add_child(_belt_on)
	_belt_mesh(_belt_on, _belt_points(true))
	_belt_off = Node3D.new()
	_belt_off.name = "Slack"
	inter.add_child(_belt_off)
	_belt_mesh(_belt_off, _belt_points(false))
	for mi: MeshInstance3D in _meshes_in(inter):
		inter.highlight_meshes.append(mi)
	_real[&"accessory_belt"] = inter
	_register(inter)


# --- Fasteners -------------------------------------------------------------------

func _build_fasteners() -> void:
	for fid: StringName in session.vehicle.fasteners:
		var f: FastenerInstance = session.vehicle.fasteners[fid]
		var comp_marker := mount(String(f.component_id))
		var m: Marker3D = comp_marker.get_node_or_null(String(f.slot.slot_id)) as Marker3D if comp_marker else null
		if m == null:
			push_error("VehicleView: no marker for fastener '%s'" % fid)
			continue
		var inter := Interactable.new()
		inter.name = "Interact_%s" % f.slot.slot_id
		inter.target_type = &"fastener"
		inter.target_id = fid
		m.add_child(inter)
		var head := Node3D.new()
		head.name = "Head"
		inter.add_child(head)
		var kind := f.definition().kind
		match kind:
			FastenerDefinition.Kind.ELECTRICAL_CONNECTOR:
				MeshKit.box(head, Vector3(0.036, 0.026, 0.03), Vector3(0, 0, -0.012), _m(&"plastic_black"))
				MeshKit.box(head, Vector3(0.01, 0.006, 0.012), Vector3(0, 0.016, -0.012), _m(&"plastic_grey"))  # latch
				MeshKit.cylinder(head, 0.006, 0.12, Vector3(0, 0, -0.08), _m(&"plastic_black"), Vector3(90, 0, 0))  # loom
				inter.add_box_shape(Vector3(0.05, 0.04, 0.05), Vector3(0, 0, -0.012))
			FastenerDefinition.Kind.NUT:
				# Battery clamp: clamp body + nut, lifts off the post when removed.
				MeshKit.box(head, Vector3(0.03, 0.03, 0.018), Vector3(0, 0, -0.005), _m(&"zinc"))
				MeshKit.cylinder(head, 0.008, 0.008, Vector3(0.012, 0, -0.018), _m(&"steel"), Vector3(90, 0, 0), "Nut", 6)
				MeshKit.box(head, Vector3(0.012, 0.09, 0.012), Vector3(0, 0.05, -0.01), _m(&"plastic_black"))  # cable
				inter.add_box_shape(Vector3(0.05, 0.05, 0.05), Vector3(0, 0, -0.01))
			_:
				MeshKit.cylinder(head, 0.0115, 0.009, Vector3(0, 0, -0.0045), _m(&"zinc"), Vector3(90, 0, 0), "Hex", 6)
				MeshKit.cylinder(head, 0.015, 0.002, Vector3(0, 0, 0.001), _m(&"zinc"), Vector3(90, 0, 0), "Flange", 16)
				MeshKit.cylinder(head, 0.004, 0.05, Vector3(0, 0, 0.026), _m(&"steel"), Vector3(90, 0, 0), "Shank", 8)
				inter.add_box_shape(Vector3(0.045, 0.045, 0.04), Vector3(0, 0, -0.012))
		for mi: MeshInstance3D in _meshes_in(head):
			inter.highlight_meshes.append(mi)
		var ghost := head.duplicate() as Node3D
		ghost.name = "Ghost"
		_ghostify(ghost)
		ghost.visible = false
		inter.add_child(ghost)
		_fast[fid] = {"inter": inter, "head": head, "ghost": ghost, "kind": kind}
		_register(inter)


func _build_cabin_controls() -> void:
	var ign := mount("ignition")
	if ign:
		var inter := Interactable.new()
		inter.name = "Interact_ignition"
		inter.target_type = &"ignition"
		inter.target_id = &"ignition"
		ign.add_child(inter)
		inter.highlight_meshes.append(MeshKit.cylinder(inter, 0.022, 0.02, Vector3.ZERO, _m(&"steel_dark"), Vector3(0, 0, 90)))
		inter.highlight_meshes.append(MeshKit.box(inter, Vector3(0.012, 0.03, 0.008), Vector3(-0.014, 0, 0), _m(&"steel"), Vector3.ZERO, "Key"))
		MeshKit.label(inter, "IGNITION", Vector3(-0.012, 0.05, 0.03), 0.0009, 24, Color(0.8, 0.8, 0.8)).rotation_degrees = Vector3(0, -90, 0)
		inter.add_box_shape(Vector3(0.06, 0.08, 0.08))
		_register(inter)
	var obd := mount("obd_port")
	if obd:
		var inter2 := Interactable.new()
		inter2.name = "Interact_obd"
		inter2.target_type = &"obd"
		inter2.target_id = &"obd"
		obd.add_child(inter2)
		inter2.highlight_meshes.append(MeshKit.box(inter2, Vector3(0.02, 0.03, 0.05), Vector3.ZERO, _m(&"plastic_black")))
		MeshKit.label(inter2, "OBD", Vector3(-0.012, 0.035, 0.02), 0.0009, 24, Color(0.8, 0.8, 0.8)).rotation_degrees = Vector3(0, -90, 0)
		inter2.add_box_shape(Vector3(0.06, 0.06, 0.08))
		_register(inter2)


# --- State sync ------------------------------------------------------------------

func refresh_all() -> void:
	for cid: StringName in session.vehicle.components:
		_on_component_changed(cid)
	for fid: StringName in session.vehicle.fasteners:
		_on_fastener_changed(fid)


func _hood_target() -> float:
	var hood := session.vehicle.get_component(&"hood")
	return deg_to_rad(HOOD_OPEN_DEG) if hood and hood.get_flag(&"open") else 0.0


func _apply_hood() -> void:
	if _hood_pivot:
		_hood_pivot.rotation.x = _hood_angle


func _on_component_changed(cid: StringName) -> void:
	var inst := session.vehicle.get_component(cid)
	if inst == null:
		return
	var real: Node3D = _real.get(cid, null)
	if real and cid != &"accessory_belt":
		real.visible = inst.installed
	_refresh_ghost(cid)
	match cid:
		&"belt_tensioner":
			if _tensioner_arm:
				_tensioner_arm.rotation_degrees.z = TENSIONER_RELEASED_DEG if inst.get_flag(&"released") else 0.0
		&"accessory_belt":
			var on := inst.get_flag(&"on_alternator_pulley")
			if _belt_on:
				_belt_on.visible = on
				_belt_off.visible = not on
				var inter := get_interactable(&"component", &"accessory_belt")
				if inter and inter.get_child_count() > 0:
					var cs := inter.get_child(0) as CollisionShape3D
					if cs:
						var alt_local := mount("alternator").position - mount("accessory_belt").position
						cs.position = Vector3(alt_local.x, alt_local.y - (0.02 if on else 0.13), -0.004)
	for f: FastenerInstance in session.vehicle.get_component_fasteners(cid):
		_on_fastener_changed(f.id)


func _refresh_ghosts() -> void:
	for cid: StringName in _ghost:
		_refresh_ghost(cid)


func _refresh_ghost(cid: StringName) -> void:
	var ghost: Node3D = _ghost.get(cid, null)
	if ghost == null:
		return
	var inst := session.vehicle.get_component(cid)
	ghost.visible = inst != null and not inst.installed


func _on_fastener_changed(fid: StringName) -> void:
	var f := session.vehicle.get_fastener(fid)
	var vis: Dictionary = _fast.get(fid, {})
	if f == null or vis.is_empty():
		return
	var comp := session.vehicle.get_component(f.component_id)
	var mounted := comp != null and comp.installed
	var inter: Interactable = vis["inter"]
	var head: Node3D = vis["head"]
	var ghost: Node3D = vis["ghost"]
	inter.set_targetable(mounted)
	var def := f.definition()
	if def.kind == FastenerDefinition.Kind.ELECTRICAL_CONNECTOR or def.kind == FastenerDefinition.Kind.CLIP:
		head.visible = mounted
		ghost.visible = false
		head.position = Vector3(0, 0, -CONNECTOR_PULL_M) if f.removed else Vector3.ZERO
		head.rotation_degrees = Vector3(25, 0, 0) if f.removed else Vector3.ZERO
		return
	head.visible = mounted and not f.removed
	ghost.visible = mounted and f.removed
	var out := (1.0 - f.thread_progress) * BOLT_BACKOUT_M
	if def.kind == FastenerDefinition.Kind.NUT:
		out = (1.0 - f.thread_progress) * 0.012
	head.position = Vector3(0, 0, -out)
	head.rotation.z = f.thread_progress * def.thread_turns * TAU


func _process(delta: float) -> void:
	if session == null:
		return
	_time += delta
	var target := _hood_target()
	if not is_equal_approx(_hood_angle, target):
		_hood_angle = lerpf(_hood_angle, target, clampf(HOOD_LERP * delta, 0.0, 1.0))
		if absf(_hood_angle - target) < 0.002:
			_hood_angle = target
		_apply_hood()
	var running := session.electrical.engine_running
	var belt := session.vehicle.get_component(&"accessory_belt")
	if running and belt and belt.get_flag(&"on_alternator_pulley"):
		for s: Node3D in _spinners:
			if is_instance_valid(s) and s.is_visible_in_tree():
				s.rotate_object_local(Vector3.UP, PULLEY_SPIN_RAD_S * delta)
	if _engine_visual:
		_engine_visual.position = Vector3(0, sin(_time * 90.0) * 0.0006, 0) if running else Vector3.ZERO
	if _lamp:
		_lamp.material_override = _m(&"lamp_on") if session.electrical.warning_lamp else _m(&"lamp_off")
