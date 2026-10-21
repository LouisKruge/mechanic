class_name VehicleState
extends RefCounted
## All mutable mechanical state of one vehicle instance.
##
## Every mechanical change bumps [member revision]; verification results (e.g.
## the charging test) are only valid for the revision they were taken at, so
## changing anything after a test invalidates it.

signal component_changed(component_id: StringName)
signal fastener_changed(fastener_id: StringName)
signal revision_changed(revision: int)

var definition: VehicleDefinition
var vehicle_id: StringName
var components: Dictionary = {}  # StringName -> ComponentInstance
var fasteners: Dictionary = {}   # StringName -> FastenerInstance
var revision: int = 0
var _uid_counter: int = 0


func _init(def: VehicleDefinition) -> void:
	definition = def
	vehicle_id = def.id
	for cdef: ComponentDefinition in def.components:
		var inst := ComponentInstance.new(cdef)
		inst.part_uid = make_part_uid(cdef.id)
		components[cdef.id] = inst
		for slot: FastenerSlotDefinition in cdef.fasteners:
			var f := FastenerInstance.new(cdef.id, slot)
			fasteners[f.id] = f
	_apply_initial_state(def.initial_state)


func _apply_initial_state(init: Dictionary) -> void:
	for key: Variant in init:
		var cid := StringName(str(key))
		var inst := get_component(cid)
		if inst == null:
			push_warning("VehicleDefinition initial_state references unknown component '%s'" % cid)
			continue
		var d: Dictionary = init[key]
		if d.has("condition"):
			inst.condition = float(d["condition"])
		if d.has("faults"):
			inst.faults = PackedStringArray(d["faults"])
		if d.has("flags"):
			for fk: Variant in (d["flags"] as Dictionary):
				inst.flags[StringName(str(fk))] = bool(d["flags"][fk])


## Generates a stable, unique part identifier.
func make_part_uid(component_id: StringName) -> String:
	_uid_counter += 1
	return "%s-%s-%04d" % [vehicle_id, component_id, _uid_counter]


func get_component(component_id: StringName) -> ComponentInstance:
	return components.get(component_id, null)


func get_fastener(fastener_id: StringName) -> FastenerInstance:
	return fasteners.get(fastener_id, null)


## Fasteners belonging to a component slot, in definition order.
func get_component_fasteners(component_id: StringName, retaining_only: bool = false) -> Array[FastenerInstance]:
	var out: Array[FastenerInstance] = []
	var inst := get_component(component_id)
	if inst == null:
		return out
	for slot: FastenerSlotDefinition in inst.definition.fasteners:
		if retaining_only and not slot.retains_component:
			continue
		var f := get_fastener(StringName("%s.%s" % [component_id, slot.slot_id]))
		if f:
			out.append(f)
	return out


func notify_component(component_id: StringName) -> void:
	revision += 1
	component_changed.emit(component_id)
	revision_changed.emit(revision)


func notify_fastener(fastener_id: StringName) -> void:
	revision += 1
	fastener_changed.emit(fastener_id)
	revision_changed.emit(revision)


func to_dict() -> Dictionary:
	var comps := {}
	for cid: StringName in components:
		comps[String(cid)] = (components[cid] as ComponentInstance).to_dict()
	var fs := {}
	for fid: StringName in fasteners:
		fs[String(fid)] = (fasteners[fid] as FastenerInstance).to_dict()
	return {
		"vehicle_id": String(vehicle_id),
		"revision": revision,
		"uid_counter": _uid_counter,
		"components": comps,
		"fasteners": fs,
	}


## Restores from saved data. Unknown IDs are reported and skipped.
func from_dict(d: Dictionary, warnings: PackedStringArray) -> void:
	revision = maxi(0, int(d.get("revision", 0)))
	_uid_counter = maxi(_uid_counter, int(d.get("uid_counter", 0)))
	var comps: Variant = d.get("components", {})
	if comps is Dictionary:
		for k: Variant in (comps as Dictionary):
			var inst := get_component(StringName(str(k)))
			if inst == null:
				warnings.append("Unknown component '%s' in save ignored." % k)
				continue
			var cd: Variant = comps[k]
			if cd is Dictionary:
				inst.from_dict(cd)
	var fs: Variant = d.get("fasteners", {})
	if fs is Dictionary:
		for k: Variant in (fs as Dictionary):
			var f := get_fastener(StringName(str(k)))
			if f == null:
				warnings.append("Unknown fastener '%s' in save ignored." % k)
				continue
			var fd: Variant = fs[k]
			if fd is Dictionary:
				f.from_dict(fd)
	for cid: StringName in components:
		component_changed.emit(cid)
	for fid: StringName in fasteners:
		fastener_changed.emit(fid)
	revision_changed.emit(revision)
