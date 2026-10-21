class_name Interactable
extends StaticBody3D
## A raycast target. Holds only identity (type + id) and visual highlight.
##
## All gameplay rules live in [GameSession] / [InteractionResolver]; this node
## never decides whether an action is allowed. That keeps visuals swappable
## (placeholder primitives today, imported glTF models later).

## Target category: component, fastener, shelf, core_bin, work_order, charger, ignition, obd.
@export var target_type: StringName = &""
## Stable identifier within the category (e.g. "alternator", "alternator.B01").
@export var target_id: StringName = &""
## Fallback display name; the resolver usually supplies a richer one.
@export var display_name: String = ""

var highlight_meshes: Array[MeshInstance3D] = []
var _highlighted: bool = false


func _init() -> void:
	collision_layer = MeshKit.LAYER_INTERACT
	collision_mask = 0


## Adds a box collision shape in local space.
func add_box_shape(size: Vector3, offset: Vector3 = Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = offset
	add_child(cs)
	return cs


## Adds a box collision shape aligned with [param axis] (e.g. along a bar).
func add_oriented_box(length: float, thickness: float, center: Vector3, axis: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(thickness, thickness, length)
	cs.shape = shape
	var fwd := axis.normalized()
	var up := Vector3.UP if absf(fwd.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	cs.transform = Transform3D(Basis.looking_at(fwd, up), center)
	add_child(cs)
	return cs


## Returns the {type, id} dictionary used by the session API.
func get_target() -> Dictionary:
	return {"type": target_type, "id": target_id}


## Enables or disables raycast detection (e.g. hidden parts, removed bolts).
func set_targetable(on: bool) -> void:
	collision_layer = MeshKit.LAYER_INTERACT if on else 0


func set_highlighted(on: bool) -> void:
	if on == _highlighted:
		return
	_highlighted = on
	var overlay: Material = WorkshopMaterials.get_mat(&"highlight") if on else null
	for mi: MeshInstance3D in highlight_meshes:
		if is_instance_valid(mi):
			mi.material_overlay = overlay
