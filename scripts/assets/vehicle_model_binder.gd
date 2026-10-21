class_name VehicleModelBinder
extends RefCounted
## Applies an imported model's anchors and part meshes to a VehicleView before
## it builds interactables:
##   MNT_<component>              -> Mounts/<component> marker transform
##   FST_<component>__<slot>      -> Mounts/<component>/<slot> marker transform
##   Part_<component>             -> Mounts/<component>/Model (replaces the placeholder)
## Anchor and part nodes are removed from the body tree afterwards, so the
## remaining nodes (Body_*, Panel_*, Wheel_*, Glass_*, ...) form the body.


static func bind(view: VehicleView, model: Node3D) -> Dictionary:
	var mounts := view.get_node("Mounts") as Node3D
	var anchors := 0
	var parts := 0
	var nodes: Array[Node3D] = []
	_gather(model, nodes)
	# Mount anchors first: fastener anchors are expressed relative to them.
	for n: Node3D in nodes:
		var nm := VehicleModelConvention.base_name(String(n.name))
		if nm.begins_with(VehicleModelConvention.MOUNT_PREFIX):
			var cid := nm.trim_prefix(VehicleModelConvention.MOUNT_PREFIX)
			_marker(mounts, cid).transform = _model_xf(model, n)
			anchors += 1
	for n2: Node3D in nodes:
		var nm2 := VehicleModelConvention.base_name(String(n2.name))
		if nm2.begins_with(VehicleModelConvention.FASTENER_PREFIX):
			var rest := nm2.trim_prefix(VehicleModelConvention.FASTENER_PREFIX)
			var cut := rest.rfind(VehicleModelConvention.SLOT_SEPARATOR)
			if cut <= 0:
				push_warning("VehicleModelBinder: malformed fastener anchor %s" % nm2)
				continue
			var comp := _marker(mounts, rest.left(cut))
			var slot := _marker(comp, rest.substr(cut + VehicleModelConvention.SLOT_SEPARATOR.length()))
			slot.transform = comp.transform.affine_inverse() * _model_xf(model, n2)
			anchors += 1
	for n3: Node3D in nodes:
		var nm3 := VehicleModelConvention.base_name(String(n3.name))
		if nm3.begins_with(VehicleModelConvention.PART_PREFIX):
			var comp2 := _marker(mounts, nm3.trim_prefix(VehicleModelConvention.PART_PREFIX))
			var xf := comp2.transform.affine_inverse() * _model_xf(model, n3)
			n3.get_parent().remove_child(n3)
			n3.name = "Model"
			n3.transform = xf
			comp2.add_child(n3)
			parts += 1
	for n4: Node3D in nodes:
		var nm4 := VehicleModelConvention.base_name(String(n4.name))
		if is_instance_valid(n4) and (nm4.begins_with(VehicleModelConvention.MOUNT_PREFIX) or nm4.begins_with(VehicleModelConvention.FASTENER_PREFIX) or nm4.begins_with("COL_")) and n4.get_parent():
			n4.get_parent().remove_child(n4)
			n4.queue_free()
	return {"anchors": anchors, "parts": parts}


static func _gather(n: Node, out: Array[Node3D]) -> void:
	for c: Node in n.get_children():
		if c is Node3D:
			out.append(c as Node3D)
		_gather(c, out)


static func _model_xf(model: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur and cur != model:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


static func _marker(parent: Node3D, child_name: String) -> Marker3D:
	var m := parent.get_node_or_null(child_name) as Marker3D
	if m == null:
		m = Marker3D.new()
		m.name = child_name
		parent.add_child(m)
	return m
