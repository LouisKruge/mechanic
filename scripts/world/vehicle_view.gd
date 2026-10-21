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
const TRUNK_OPEN_DEG: float = 72.0
const PART_SLIDE_SECONDS: float = 0.35
const HOOD_LERP: float = 5.0
const BOLT_BACKOUT_M: float = 0.028
const CONNECTOR_PULL_M: float = 0.045
const TENSIONER_RELEASED_DEG: float = -26.0
const PULLEY_SPIN_RAD_S: float = 40.0
## Belt pulley radii; the alternator and tensioner mounts come from the vehicle definition.
const CRANK_PULLEY_R: float = 0.085
const WATER_PUMP_PULLEY_R: float = 0.055
const ALT_PULLEY_R: float = 0.032
const TENSIONER_PULLEY_R: float = 0.036

var session: GameSession
var profile: VehicleBodyProfile
var mats: Dictionary = {}
var body_model: Node3D
var _hood_panel: MeshInstance3D
## "type:id" -> Interactable
var interactables: Dictionary = {}
var _real: Dictionary = {}    # component id -> Node3D (placeholder or Model)
var _ghost: Dictionary = {}   # component id -> Node3D
var _fast: Dictionary = {}    # fastener id -> {"inter", "head", "ghost", "kind"}
## Openable panels: {component_id: {pivot, sign, angle, max}}.
var _lids: Dictionary = {}
var _pans: Dictionary = {}
var _belt_id: StringName = &""
var _tensioner_id: StringName = &""
## Components with a visual archetype but no mount marker (reported, not built).
var data_only: PackedStringArray = PackedStringArray()
var _tweens: Dictionary = {}
var _ready_for_anim: bool = false
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
	add_child(EngineBayDressing.build(self, PackedStringArray()))
	session.vehicle.component_changed.connect(_on_component_changed)
	session.vehicle.fastener_changed.connect(_on_fastener_changed)
	session.inventory.changed.connect(_refresh_ghosts)
	refresh_all()
	_ready_for_anim = true
	for cid: StringName in _lids:
		var lid: Dictionary = _lids[cid]
		var inst := session.vehicle.get_component(cid)
		lid["angle"] = deg_to_rad(float(lid["max"])) if inst and inst.get_flag(&"open") else 0.0
		(lid["pivot"] as Node3D).rotation.x = float(lid["angle"]) * float(lid["sign"])


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
	profile = session.vehicle.definition.body_profile
	if profile == null:
		profile = VehicleBodyProfile.new()
	mats = VehicleMaterials.build(profile)
	var model := VehicleBodyBuilder.new(profile).build(mats)
	body.add_child(model)
	body_model = model
	# The hood panel belongs to the hood component (it moves and is targetable).
	_hood_panel = model.get_node_or_null("Panel_hood") as MeshInstance3D
	if _hood_panel:
		model.remove_child(_hood_panel)
	_build_colliders(body, profile)


## Physical collision (world layer) derived from the profile: lower body,
## cabin, bumper and fenders. The bay stays open above so components are
## reachable; an invisible guard keeps the player out of it.
func _build_colliders(body: Node3D, pr: VehicleBodyProfile) -> void:
	var hw := pr.half_width
	var zf := -pr.length * 0.5
	var zr := pr.length * 0.5
	var fire_z := pr.hood_rear_z + 0.03
	var top := pr.cowl_y
	var cz0 := pr.windscreen_base_z + 0.27
	var cz1 := pr.roof_rear_z + 0.25
	var wall := 0.15
	# Solid body ahead of and behind the cabin.
	MeshKit.static_box(body, Vector3(hw * 2, top - pr.sill_y, cz0 - fire_z), Vector3(0, (top + pr.sill_y) * 0.5, (cz0 + fire_z) * 0.5))
	MeshKit.static_box(body, Vector3(hw * 2, top - pr.sill_y, zr - cz1), Vector3(0, (top + pr.sill_y) * 0.5, (zr + cz1) * 0.5))
	# Cabin: solid door walls and floor; the passenger volume blocks the player
	# but not the interaction ray, so controls inside are reachable through the window.
	for side: float in [-1.0, 1.0]:
		MeshKit.static_box(body, Vector3(wall, top - pr.sill_y, cz1 - cz0), Vector3(side * (hw - wall * 0.5), (top + pr.sill_y) * 0.5, (cz0 + cz1) * 0.5))
	MeshKit.static_box(body, Vector3(hw * 2, 0.2, cz1 - cz0), Vector3(0, pr.sill_y + 0.1, (cz0 + cz1) * 0.5))
	MeshKit.furniture_box(body, Vector3((hw - wall) * 2, pr.roof_y - pr.sill_y - 0.2, cz1 - cz0), Vector3(0, (pr.roof_y + pr.sill_y + 0.2) * 0.5, (cz0 + cz1) * 0.5))
	MeshKit.static_box(body, Vector3(hw * 1.5, 0.05, cz1 - cz0 - 0.4), Vector3(0, pr.roof_y - 0.02, (cz0 + cz1) * 0.5))
	MeshKit.static_box(body, Vector3(hw * 2, 0.44, 0.14), Vector3(0, pr.sill_y + 0.22, zf + 0.07))
	var fz0 := zf + 0.13
	var fz1 := pr.hood_rear_z + 0.01
	for side: float in [-1.0, 1.0]:
		MeshKit.static_box(body, Vector3(0.2, top - pr.sill_y, fz1 - fz0), Vector3(side * (hw - 0.1), (top + pr.sill_y) * 0.5, (fz0 + fz1) * 0.5))
	MeshKit.static_box(body, Vector3((hw - 0.2) * 2, 0.04, fz1 - fz0), Vector3(0, pr.sill_y + 0.01, (fz0 + fz1) * 0.5))
	# Invisible guard filling the open bay: keeps the player (and camera) out
	# of the engine compartment without blocking the interaction ray.
	MeshKit.furniture_box(body, Vector3((hw - 0.2) * 2, 2.0, fz1 - fz0 + 0.02), Vector3(0, 1.2, (fz0 + fz1) * 0.5))
	# Dark inner aprons and bay floor.
	for side: float in [-1.0, 1.0]:
		MeshKit.box(body, Vector3(0.02, 0.5, fz1 - fz0 - 0.1), Vector3(side * (hw - 0.21), pr.sill_y + 0.27, (fz0 + fz1) * 0.5), VehicleMaterials.shared(&"bay"))
	MeshKit.box(body, Vector3((hw - 0.2) * 2, 0.02, fz1 - fz0), Vector3(0, pr.sill_y + 0.03, (fz0 + fz1) * 0.5), VehicleMaterials.shared(&"bay"))


func _build_wheels() -> void:
	# Wheels are part of the body model (Wheel_FL ... Wheel_RR).
	pass


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
	var vdef := session.vehicle.definition
	for cdef: ComponentDefinition in vdef.components:
		var arch := cdef.visual
		if arch == &"":
			continue
		if mount(String(cdef.id)) == null:
			push_warning("VehicleView: component '%s' has visual '%s' but no mount marker — data only" % [cdef.id, arch])
			data_only.append(String(cdef.id))
			continue
		var id := cdef.id
		match arch:
			&"hood", &"lid":
				_build_lid(cdef)
			&"engine":
				var ecfg := vdef.engine if vdef.engine else EngineConfiguration.new()
				var eb := EngineAssemblyBuilder.new(ecfg)
				var ebox := eb.bounds()
				_make_component(id, ebox.size, ebox.get_center(), func(v: Node3D) -> void:
					_engine_visual = v
					v.add_child(eb.build()))
			&"bracket":
				_make_component(id, Vector3(0.16, 0.22, 0.04), Vector3.ZERO, func(v: Node3D) -> void:
					ProcMesh.add(v, ProcMesh.rounded_box(Vector3(0.16, 0.22, 0.035), 0.02), _m(&"aluminium"))
					MeshKit.box(v, Vector3(0.04, 0.04, 0.05), Vector3(-0.08, 0.1, -0.02), _m(&"aluminium"))
					MeshKit.box(v, Vector3(0.04, 0.04, 0.05), Vector3(0.08, -0.065, -0.02), _m(&"aluminium")))
			&"alternator":
				_make_component(id, Vector3(0.15, 0.15, 0.15), Vector3.ZERO, _build_alternator_visual)
			&"tensioner":
				_tensioner_id = id
				_make_component(id, Vector3(0.09, 0.09, 0.03), Vector3(0, 0, -0.005), _build_tensioner_visual)
			&"belt":
				_belt_id = id
			&"battery":
				_make_component(id, Vector3(0.18, 0.2, 0.26), Vector3(0, 0.1, 0), _build_battery_visual)
			&"starter":
				_make_component(id, Vector3(0.12, 0.12, 0.22), Vector3.ZERO, func(v: Node3D) -> void:
					ProcMesh.add(v, ProcMesh.lathe(PackedVector2Array([Vector2(0, -0.09), Vector2(0.05, -0.09), Vector2(0.052, 0.07), Vector2(0.03, 0.09), Vector2(0, 0.09)]), 20), _m(&"steel_dark"), Vector3.ZERO, Vector3(90, 0, 0))
					ProcMesh.add(v, ProcMesh.lathe(PackedVector2Array([Vector2(0, -0.06), Vector2(0.028, -0.06), Vector2(0.028, 0.06), Vector2(0, 0.06)]), 16), _m(&"zinc"), Vector3(-0.055, 0.03, -0.02), Vector3(90, 0, 0))
					MeshKit.cylinder(v, 0.02, 0.04, Vector3(0, 0, -0.1), _m(&"steel"), Vector3(90, 0, 0)))
			&"hose":
				_build_hose(cdef)
			&"tank":
				_build_tank(cdef)
			&"radiator":
				_build_aux_radiator(cdef)
			&"brace":
				_build_brace(cdef)
			&"wheel":
				_build_wheel_component(cdef)
			_:
				var sz := cdef.visual_size
				_make_component(id, sz, Vector3.ZERO, func(v: Node3D) -> void:
					ProcMesh.add(v, ProcMesh.rounded_box(sz, minf(sz.x, sz.y) * 0.2), _m(&"steel_dark")))
	if _belt_id != &"":
		_build_belt()
	# Instrument cluster with the charge-warning lamp (fixture, visual only).
	var cl := mount("instrument_cluster")
	if cl:
		ProcMesh.add(cl, ProcMesh.rounded_box(Vector3(0.36, 0.1, 0.06), 0.03), VehicleMaterials.shared(&"trim"), Vector3.ZERO, Vector3(-20, 0, 0))
		for gx: float in [-0.08, 0.08]:
			MeshKit.cylinder(cl, 0.04, 0.005, Vector3(gx, 0.005, 0.032), _m(&"plastic_grey"), Vector3(70, 0, 0))
		_lamp = MeshKit.box(cl, Vector3(0.03, 0.02, 0.012), Vector3(0, 0.04, 0.03), _m(&"lamp_off"), Vector3(-20, 0, 0), "ChargeLamp")
		var cap := MeshKit.label(cl, "CHG", Vector3(0.022, 0.05, 0.034), 0.0008, 24, Color(0.8, 0.8, 0.8))
		cap.rotation_degrees = Vector3(-20, 0, 0)


## Hood or trunk lid: the marker is the hinge; the panel comes from the body model.
func _build_lid(cdef: ComponentDefinition) -> void:
	var pivot := mount(String(cdef.id))
	var hinge := pivot.position
	var panel_name := "Panel_hood" if cdef.visual == &"hood" else "Panel_trunk"
	var panel: MeshInstance3D = _hood_panel if cdef.visual == &"hood" else null
	if panel == null and body_model:
		panel = body_model.get_node_or_null(panel_name) as MeshInstance3D
		if panel:
			body_model.remove_child(panel)
	var box := AABB(Vector3(-0.7, -0.01, -1.2 if cdef.visual == &"hood" else 0.0), Vector3(1.4, 0.04, 1.2))
	if panel:
		box = panel.mesh.get_aabb()
		box.position -= hinge
	var sign := 1.0 if box.get_center().z < 0.0 else -1.0
	_lids[cdef.id] = {"pivot": pivot, "sign": sign, "angle": 0.0, "max": HOOD_OPEN_DEG if cdef.visual == &"hood" else TRUNK_OPEN_DEG}
	_make_component(cdef.id, Vector3(box.size.x, maxf(box.size.y, 0.04), box.size.z), box.get_center(), func(v: Node3D) -> void:
		if panel:
			panel.position = -hinge
			v.add_child(panel)
			var pad := MeshKit.box(v, Vector3(box.size.x * 0.82, 0.01, box.size.z * 0.8), box.get_center() + Vector3(0, -0.02, 0), VehicleMaterials.shared(&"trim"))
			pad.name = "LidPad")


func _build_battery_visual(v: Node3D) -> void:
	ProcMesh.add(v, ProcMesh.rounded_box(Vector3(0.18, 0.19, 0.26), 0.012), VehicleMaterials.shared(&"plastic_black"), Vector3(0, 0.095, 0))
	ProcMesh.add(v, ProcMesh.rounded_box(Vector3(0.18, 0.012, 0.26), 0.01), _m(&"plastic_grey"), Vector3(0, 0.196, 0))
	ProcMesh.add(v, ProcMesh.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.012, 0), Vector2(0.01, 0.02), Vector2(0, 0.02)]), 16), _m(&"copper"), Vector3(0.045, 0.2, -0.085))
	ProcMesh.add(v, ProcMesh.rounded_box(Vector3(0.045, 0.02, 0.045), 0.008), _m(&"lamp_on"), Vector3(0.045, 0.222, -0.085))
	ProcMesh.add(v, ProcMesh.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.012, 0), Vector2(0.01, 0.02), Vector2(0, 0.02)]), 16), _m(&"steel"), Vector3(0.045, 0.195, 0.085))
	var lbl := MeshKit.label(v, "12V", Vector3(-0.091, 0.15, 0.03), 0.0012, 32, Color(0.85, 0.85, 0.85))
	lbl.rotation_degrees = Vector3(0, -90, 0)


## Hose between child markers A and B of the component marker.
func _build_hose(cdef: ComponentDefinition) -> void:
	var m := mount(String(cdef.id))
	var a := (m.get_node_or_null("A") as Marker3D)
	var b := (m.get_node_or_null("B") as Marker3D)
	var pa := a.position if a else Vector3(-0.1, 0, 0)
	var pb := b.position if b else Vector3(0.1, 0, 0)
	var path := ProcMesh.bezier(pa, pa + (-(a.basis.z) if a else Vector3.RIGHT) * 0.12, pb + (-(b.basis.z) if b else Vector3.LEFT) * 0.12, pb, 16)
	var mid := path[8]
	var inter := _make_component(cdef.id, Vector3(0.07, 0.07, 0.07), mid, func(v: Node3D) -> void:
		ProcMesh.add(v, ProcMesh.tube(path, 0.019, 12), _m(&"rubber"), Vector3.ZERO, Vector3.ZERO, "Hose"))
	if inter:
		inter.add_box_shape(Vector3(0.06, 0.06, 0.06), path[4])
		inter.add_box_shape(Vector3(0.06, 0.06, 0.06), path[12])


## Coolant expansion tank with a cap that lifts off when open.
func _build_tank(cdef: ComponentDefinition) -> void:
	var tank_mat := StandardMaterial3D.new()
	tank_mat.albedo_color = Color(0.86, 0.86, 0.82, 0.85)
	tank_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tank_mat.roughness = 0.4
	_make_component(cdef.id, Vector3(0.16, 0.18, 0.2), Vector3(0, 0.05, 0), func(v: Node3D) -> void:
		ProcMesh.add(v, ProcMesh.rounded_box(Vector3(0.14, 0.14, 0.18), 0.04), tank_mat, Vector3(0, 0.0, 0))
		ProcMesh.add(v, ProcMesh.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.026, 0), Vector2(0.026, 0.03), Vector2(0, 0.03)]), 18), tank_mat, Vector3(0, 0.07, 0), Vector3.ZERO, "Neck")
		var cap := Node3D.new()
		cap.name = "Cap"
		cap.position = Vector3(0, 0.1, 0)
		v.add_child(cap)
		ProcMesh.add(cap, ProcMesh.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.034, 0), Vector2(0.036, 0.022), Vector2(0.03, 0.03), Vector2(0, 0.03)]), 18, false), VehicleMaterials.shared(&"plastic_black"))
		MeshKit.box(v, Vector3(0.12, 0.003, 0.002), Vector3(0, 0.02, -0.091), _m(&"floor_marking"), Vector3.ZERO, "MaxLine")
		MeshKit.box(v, Vector3(0.12, 0.003, 0.002), Vector3(0, -0.04, -0.091), _m(&"floor_marking"), Vector3.ZERO, "MinLine"))


## Small auxiliary radiator with a drain plug; a drain pan appears on the floor when placed.
func _build_aux_radiator(cdef: ComponentDefinition) -> void:
	_make_component(cdef.id, Vector3(0.3, 0.26, 0.06), Vector3.ZERO, func(v: Node3D) -> void:
		ProcMesh.add(v, ProcMesh.rounded_box(Vector3(0.28, 0.24, 0.035), 0.01), _m(&"steel_dark"))
		for i: int in 14:
			MeshKit.box(v, Vector3(0.003, 0.22, 0.038), Vector3(-0.12 + i * 0.0185, 0, 0), _m(&"aluminium"))
		for side: float in [-1.0, 1.0]:
			ProcMesh.add(v, ProcMesh.rounded_box(Vector3(0.035, 0.26, 0.05), 0.012), VehicleMaterials.shared(&"plastic_black"), Vector3(side * 0.155, 0, 0)))
	var pan := Node3D.new()
	pan.name = "DrainPan_%s" % cdef.id
	var m := mount(String(cdef.id))
	pan.position = Vector3(m.position.x, 0.02, m.position.z + 0.05)
	pan.visible = false
	add_child(pan)
	var pan_mat := StandardMaterial3D.new()
	pan_mat.albedo_color = Color(0.1, 0.1, 0.11)
	pan_mat.roughness = 0.5
	ProcMesh.add(pan, ProcMesh.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.2, 0.0), Vector2(0.24, 0.09), Vector2(0.235, 0.095), Vector2(0.19, 0.01)]), 28), pan_mat)
	_pans[cdef.id] = pan


## Strut brace along child markers P0..Pn.
func _build_brace(cdef: ComponentDefinition) -> void:
	var m := mount(String(cdef.id))
	var pts := PackedVector3Array()
	var i := 0
	while m.get_node_or_null("P%d" % i):
		pts.append((m.get_node("P%d" % i) as Marker3D).position)
		i += 1
	if pts.size() < 2:
		pts = PackedVector3Array([Vector3(-0.4, 0, 0), Vector3(0.4, 0, 0)])
	var inter := _make_component(cdef.id, Vector3(0.06, 0.05, 0.06), pts[0], func(v: Node3D) -> void:
		var carbon := StandardMaterial3D.new()
		carbon.albedo_color = Color(0.05, 0.05, 0.055)
		carbon.metallic = 0.3
		carbon.roughness = 0.25
		carbon.clearcoat_enabled = true
		carbon.normal_enabled = true
		carbon.normal_texture = VehicleMaterials._shared_tex(&"weave", 600.0, 0.5)
		carbon.uv1_scale = Vector3(8, 8, 8)
		ProcMesh.add(v, ProcMesh.tube(pts, 0.024, 12), carbon, Vector3.ZERO, Vector3.ZERO, "Bar")
		for p: Vector3 in [pts[0], pts[pts.size() - 1]]:
			ProcMesh.add(v, ProcMesh.rounded_box(Vector3(0.09, 0.012, 0.09), 0.02), _m(&"aluminium"), p + Vector3(0, -0.012, 0)))
	if inter:
		for k: int in pts.size() - 1:
			var mid := (pts[k] + pts[k + 1]) * 0.5
			var ext := (pts[k + 1] - pts[k]).abs() + Vector3(0.05, 0.05, 0.05)
			inter.add_box_shape(ext, mid)


## Removable road wheel: takes the tyre/rim ("Spin") from the body model.
func _build_wheel_component(cdef: ComponentDefinition) -> void:
	var suffix := String(cdef.id).get_slice("_", String(cdef.id).get_slice_count("_") - 1).to_upper()
	var wheel: Node3D = body_model.get_node_or_null("Wheel_%s" % suffix) if body_model else null
	var spin: Node3D = wheel.get_node_or_null("Spin") if wheel else null
	var r := profile.wheel_radius_front if suffix.begins_with("F") else profile.wheel_radius_rear
	var w := profile.tyre_width_front if suffix.begins_with("F") else profile.tyre_width_rear
	_make_component(cdef.id, Vector3(w, r * 2.0, r * 2.0), Vector3.ZERO, func(v: Node3D) -> void:
		if spin:
			wheel.remove_child(spin)
			spin.position = Vector3.ZERO
			v.add_child(spin))


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


func _belt_pulleys() -> Array:
	return [["crank_pulley", CRANK_PULLEY_R], ["water_pump_pulley", WATER_PUMP_PULLEY_R], [String(session.vehicle.definition.alternator_component), ALT_PULLEY_R], [String(_tensioner_id), TENSIONER_PULLEY_R]]


func _belt_points(include_alternator: bool) -> Array[Vector3]:
	var belt := mount(String(_belt_id))
	var alt_name := String(session.vehicle.definition.alternator_component)
	var pts: Array[Vector3] = []
	var centres: Array[Vector3] = []
	var radii: Array[float] = []
	for entry: Array in _belt_pulleys():
		var mk := mount(entry[0])
		if mk == null:
			continue
		var c := belt.to_local(mk.global_position) if belt.is_inside_tree() else (mk.position - belt.position)
		c.z = 0.0
		if entry[0] == alt_name and not include_alternator:
			c = Vector3(c.x - 0.03, c.y - 0.12, 0.0)  # slack loop hangs below the pulley
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
	var belt := mount(String(_belt_id))
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
	inter.name = "Interact_%s" % _belt_id
	inter.target_type = &"component"
	inter.target_id = _belt_id
	belt.add_child(inter)
	var alt := mount(String(session.vehicle.definition.alternator_component))
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
	_real[_belt_id] = inter
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
		# Key barrel on the steering column shroud.
		inter.highlight_meshes.append(ProcMesh.add(inter, ProcMesh.rounded_box(Vector3(0.07, 0.06, 0.12), 0.02), VehicleMaterials.shared(&"trim")))
		inter.highlight_meshes.append(ProcMesh.add(inter, ProcMesh.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.016, 0), Vector2(0.016, 0.012), Vector2(0, 0.012)]), 20), VehicleMaterials.shared(&"chrome"), Vector3(-0.036, 0.005, 0.0), Vector3(0, 0, 90)))
		inter.highlight_meshes.append(MeshKit.box(inter, Vector3(0.012, 0.035, 0.006), Vector3(-0.05, 0.005, 0), _m(&"steel"), Vector3.ZERO, "Key"))
		inter.add_box_shape(Vector3(0.1, 0.1, 0.14))
		_register(inter)
	var obd := mount("obd_port")
	if obd:
		var inter2 := Interactable.new()
		inter2.name = "Interact_obd"
		inter2.target_type = &"obd"
		inter2.target_id = &"obd"
		obd.add_child(inter2)
		inter2.highlight_meshes.append(ProcMesh.add(inter2, ProcMesh.rounded_box(Vector3(0.05, 0.025, 0.03), 0.006), VehicleMaterials.shared(&"plastic_black")))
		MeshKit.label(inter2, "OBD", Vector3(-0.015, 0.03, 0.02), 0.0007, 24, Color(0.8, 0.8, 0.8)).rotation_degrees = Vector3(0, -90, 0)
		inter2.add_box_shape(Vector3(0.08, 0.06, 0.08))
		_register(inter2)


# --- State sync ------------------------------------------------------------------

## Re-applies all state without animation (used after loading a save).
func refresh_all() -> void:
	var was := _ready_for_anim
	_ready_for_anim = false
	_refresh_all_now()
	_ready_for_anim = was


func _refresh_all_now() -> void:
	for cid: StringName in session.vehicle.components:
		_on_component_changed(cid)
	for fid: StringName in session.vehicle.fasteners:
		_on_fastener_changed(fid)


func _on_component_changed(cid: StringName) -> void:
	var inst := session.vehicle.get_component(cid)
	if inst == null:
		return
	var real: Node3D = _real.get(cid, null)
	if real and cid != _belt_id:
		_set_part_visible(cid, real, inst.installed)
	_refresh_ghost(cid)
	var arch := inst.definition.visual
	match arch:
		&"tensioner":
			if _tensioner_arm:
				_tensioner_arm.rotation_degrees.z = TENSIONER_RELEASED_DEG if inst.get_flag(&"released") else 0.0
		&"belt":
			var on := inst.get_flag(&"on_alternator_pulley")
			if _belt_on:
				_belt_on.visible = on
				_belt_off.visible = not on
				var inter := get_interactable(&"component", _belt_id)
				if inter and inter.get_child_count() > 0:
					var cs := inter.get_child(0) as CollisionShape3D
					if cs:
						var alt_local := mount(String(session.vehicle.definition.alternator_component)).position - mount(String(_belt_id)).position
						cs.position = Vector3(alt_local.x, alt_local.y - (0.02 if on else 0.13), -0.004)
		&"tank":
			var fc := session.fluids.circuit_for_fill(cid)
			var cap := real.get_node_or_null("Cap") as Node3D if real else null
			if fc and cap:
				var open := inst.get_flag(fc.cap_flag)
				cap.position = Vector3(0.06, 0.12, 0.0) if open else Vector3(0, 0.1, 0)
				cap.rotation_degrees = Vector3(0, 0, -70) if open else Vector3.ZERO
		&"radiator":
			var pan: Node3D = _pans.get(cid, null)
			if pan:
				pan.visible = inst.get_flag(&"drain_pan_in_place")
	for f: FastenerInstance in session.vehicle.get_component_fasteners(cid):
		_on_fastener_changed(f.id)


## Shows or hides a part. After setup, removal slides the part out of its
## mount before hiding it and installation slides it in and snaps it home, so
## the animation always follows an actual state change.
func _set_part_visible(cid: StringName, real: Node3D, show: bool) -> void:
	var tw: Tween = _tweens.get(cid, null)
	if tw and tw.is_valid():
		tw.kill()
	_tweens.erase(cid)
	if not _ready_for_anim or real.visible == show:
		real.visible = show
		real.position = Vector3.ZERO
		return
	var out := Vector3(0, 0.12, -0.18)
	tw = create_tween()
	_tweens[cid] = tw
	if show:
		real.position = out
		real.visible = true
		tw.tween_property(real, "position", Vector3.ZERO, PART_SLIDE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(real, "position", out, PART_SLIDE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			real.visible = false
			real.position = Vector3.ZERO)


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
	for cid: StringName in _lids:
		var lid: Dictionary = _lids[cid]
		var inst := session.vehicle.get_component(cid)
		var target := deg_to_rad(float(lid["max"])) if inst and inst.get_flag(&"open") else 0.0
		var ang: float = lid["angle"]
		if not is_equal_approx(ang, target):
			# Ease out like a gas-strut assisted panel.
			ang = lerpf(ang, target, clampf(HOOD_LERP * delta, 0.0, 1.0))
			if absf(ang - target) < 0.002:
				ang = target
			lid["angle"] = ang
			(lid["pivot"] as Node3D).rotation.x = ang * float(lid["sign"])
	var running := session.electrical.engine_running
	var belt := session.vehicle.get_component(_belt_id)
	if running and belt and belt.get_flag(&"on_alternator_pulley"):
		for s: Node3D in _spinners:
			if is_instance_valid(s) and s.is_visible_in_tree():
				s.rotate_object_local(Vector3.UP, PULLEY_SPIN_RAD_S * delta)
	if _engine_visual:
		_engine_visual.position = Vector3(0, sin(_time * 90.0) * 0.0006, 0) if running else Vector3.ZERO
	if _lamp:
		_lamp.material_override = _m(&"lamp_on") if session.electrical.warning_lamp else _m(&"lamp_off")
