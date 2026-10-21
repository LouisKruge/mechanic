class_name VehicleTemplateExporter
extends RefCounted
## Builds an artist template for a vehicle: the procedural placeholder body
## plus every MNT_/FST_ anchor at the vehicle scene's marker positions. Export
## it as GLB, open it in Blender, model over the placeholder, keep the anchors
## and export back (see tools/blender/garage_vehicle_tools.py).


static func build(vdef: VehicleDefinition) -> Node3D:
	var prof := vdef.body_profile if vdef.body_profile else VehicleBodyProfile.new()
	var root := VehicleBodyBuilder.new(prof).build(VehicleMaterials.build(prof))
	root.name = "%s_template" % vdef.id
	var scene := (load(vdef.scene_path) as PackedScene).instantiate() if vdef.scene_path != "" else null
	var mounts: Node3D = scene.get_node_or_null("Mounts") if scene else null
	for c: ComponentDefinition in VehicleModelConvention.anchored_components(vdef):
		var m: Marker3D = mounts.get_node_or_null(String(c.id)) as Marker3D if mounts else null
		var anchor := Node3D.new()
		anchor.name = VehicleModelConvention.mount_name(c.id)
		anchor.transform = m.transform if m else Transform3D.IDENTITY
		root.add_child(anchor)
		for slot: FastenerSlotDefinition in c.fasteners:
			var fm: Marker3D = m.get_node_or_null(String(slot.slot_id)) as Marker3D if m else null
			var fa := Node3D.new()
			fa.name = VehicleModelConvention.fastener_name(c.id, slot.slot_id)
			# Fastener anchors are written in model space (flat hierarchy is easiest in DCC tools).
			fa.transform = anchor.transform * (fm.transform if fm else Transform3D.IDENTITY)
			root.add_child(fa)
	if scene:
		scene.free()
	_bake_materials(root)
	return root


## glTF export writes mesh surface materials, not material_override: bake them in.
static func _bake_materials(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.material_override and mi.mesh:
			var mesh := mi.mesh.duplicate() as Mesh
			for s: int in mesh.get_surface_count():
				mesh.surface_set_material(s, mi.material_override)
			mi.mesh = mesh
			mi.material_override = null
	for c: Node in n.get_children():
		_bake_materials(c)


## Anchor manifest for DCC tooling: [{name, position:[x,y,z], basis:[9 floats]}].
static func manifest(template: Node3D, vdef: VehicleDefinition) -> Dictionary:
	var anchors: Array = []
	for c: Node in template.get_children():
		var n := String(c.name)
		if n.begins_with(VehicleModelConvention.MOUNT_PREFIX) or n.begins_with(VehicleModelConvention.FASTENER_PREFIX):
			var t := (c as Node3D).transform
			anchors.append({"name": n, "position": [t.origin.x, t.origin.y, t.origin.z],
				"basis": [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z, t.basis.z.x, t.basis.z.y, t.basis.z.z]})
	return {"format": "garage-vehicle-anchors", "version": 1, "vehicle_id": String(vdef.id), "units": "metres",
		"axes": "glTF/Godot: +Y up, nose towards -Z", "anchors": anchors,
		"required_nodes": ["Body_*", "Panel_hood", "Panel_trunk", "Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"],
		"required_materials": Array(VehicleModelConvention.REQUIRED_MATERIALS)}
