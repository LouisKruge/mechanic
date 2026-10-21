class_name VehicleModelConvention
extends RefCounted
## Node-naming convention shared by the procedural placeholder body and
## imported glTF/GLB vehicle models (see docs/ASSET_PIPELINE.md).
##
##   Body_*                 painted body shell pieces (at least one)
##   Panel_hood, Panel_trunk, Panel_door_L/R    openable panels; origin = hinge
##   Glass_*                glazing
##   Light_head_L/R, Light_tail_L/R
##   Wheel_FL/FR/RL/RR      origin = wheel centre; child "Spin" = parts that
##                          rotate and leave with the wheel (tyre, rim)
##   MNT_<component_id>     empty: mount anchor for an interactive component
##   FST_<component_id>__<slot_id>   empty: fastener anchor, local -Z = out of the hole
##   Part_<component_id>    mesh replacing that component's placeholder
##   ENG_*                  engine sub-assembly (optional)
##   COL_*                  optional collision proxies (ignored at runtime;
##                          vehicle colliders come from the body profile)
## Materials: MAT_paint (body colour), MAT_glass, MAT_tyre, MAT_rim, MAT_lens,
## MAT_tail_lens, MAT_chrome, MAT_trim ... (MAT_paint and MAT_glass required).
##
## Space: metres, +Y up, nose towards -Z (glTF and Godot share this; in
## Blender the nose points +Y with +Z up and the exporter's "+Y up" option).

const WHEELS: PackedStringArray = ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]
const LIGHTS: PackedStringArray = ["Light_head_L", "Light_head_R", "Light_tail_L", "Light_tail_R"]
const MOUNT_PREFIX: String = "MNT_"
const FASTENER_PREFIX: String = "FST_"
const PART_PREFIX: String = "Part_"
const SLOT_SEPARATOR: String = "__"
const REQUIRED_MATERIALS: PackedStringArray = ["MAT_paint", "MAT_glass"]


static func mount_name(component_id: StringName) -> String:
	return MOUNT_PREFIX + String(component_id)


static func fastener_name(component_id: StringName, slot_id: StringName) -> String:
	return FASTENER_PREFIX + String(component_id) + SLOT_SEPARATOR + String(slot_id)


## The rotating group of a wheel: first child whose name starts with "Spin"
## (glTF requires unique names, so exporters may rename it Spin2, Spin_FL ...).
static func wheel_spin(wheel: Node) -> Node3D:
	if wheel == null:
		return null
	for c: Node in wheel.get_children():
		if String(c.name).begins_with("Spin") and c is Node3D:
			return c as Node3D
	return null


## Strips importer/DCC duplicate suffixes such as ".001" or "_001" added on name clashes.
static func base_name(n: String) -> String:
	var re := RegEx.create_from_string("([._]\\d{3})+$")
	return re.sub(n, "")


## Components that need an anchor (those with a visual archetype).
static func anchored_components(vdef: VehicleDefinition) -> Array[ComponentDefinition]:
	var out: Array[ComponentDefinition] = []
	for c: ComponentDefinition in vdef.components:
		if c.visual != &"":
			out.append(c)
	return out


## Every anchor name the model should provide for [param vdef].
static func required_anchors(vdef: VehicleDefinition) -> PackedStringArray:
	var out := PackedStringArray()
	for c: ComponentDefinition in anchored_components(vdef):
		out.append(mount_name(c.id))
		for slot: FastenerSlotDefinition in c.fasteners:
			out.append(fastener_name(c.id, slot.slot_id))
	return out
