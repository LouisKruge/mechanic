class_name MeshKit
extends RefCounted
## Helpers for building procedural placeholder geometry with matching collision.
##
## All dimensions are in metres. Collision is only created when requested, so
## decorative detail stays cheap and colliders remain simple boxes/cylinders.

const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 2
const LAYER_INTERACT: int = 4
## Solid furniture: blocks the player but not the interaction ray, so items
## resting on shelves and trolleys stay targetable.
const LAYER_FURNITURE: int = 8


## Adds a box mesh to [param parent]. Returns the MeshInstance3D.
static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, name: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	if name != "":
		mi.name = name
	parent.add_child(mi)
	return mi


## Adds a cylinder (axis along local Y before rotation).
static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, name: String = "", segments: int = 24) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = segments
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	if name != "":
		mi.name = name
	parent.add_child(mi)
	return mi


## Adds a static box collider on the world layer (blocks player movement and raycasts).
static func static_box(parent: Node3D, size: Vector3, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, layer: int = LAYER_WORLD) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = pos
	body.rotation_degrees = rot_deg
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	return body


## Furniture collider (see LAYER_FURNITURE).
static func furniture_box(parent: Node3D, size: Vector3, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> StaticBody3D:
	return static_box(parent, size, pos, rot_deg, LAYER_FURNITURE)


## Box mesh plus a matching world collider.
static func solid_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, name: String = "") -> MeshInstance3D:
	var mi := box(parent, size, pos, mat, rot_deg, name)
	static_box(parent, size, pos, rot_deg)
	return mi


## Adds a 3D text label facing +Z of its parent.
static func label(parent: Node3D, text: String, pos: Vector3, pixel_size: float = 0.002, font_size: int = 32, color: Color = Color(0.92, 0.92, 0.92)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.pixel_size = pixel_size
	l.font_size = font_size
	l.modulate = color
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	parent.add_child(l)
	return l
