class_name ComponentInstance
extends RefCounted
## Mutable runtime state of one component slot on a specific vehicle.
##
## The slot keeps its identity (component_id) even when the physical part is
## removed; [member part_uid] identifies the individual part currently fitted.

enum Inspection { NONE, VISUAL, TESTED }

var component_id: StringName
var definition: ComponentDefinition
var installed: bool = true
## Unique ID of the physical part in this slot (persists into inventory when removed).
var part_uid: String = ""
## 0..100 condition percentage of the fitted part.
var condition: float = 100.0
## Fault IDs currently present on the fitted part (hidden truth).
var faults: PackedStringArray = PackedStringArray()
## Fault IDs the player has discovered on the fitted part.
var discovered_faults: PackedStringArray = PackedStringArray()
var inspection: Inspection = Inspection.NONE
## Boolean operating states, keyed by toggle flag.
var flags: Dictionary = {}
## Free-form operating parameters (e.g. measured output) for diagnostics.
var parameters: Dictionary = {}
## True when the part is a new (unused) unit.
var is_new: bool = false


func _init(def: ComponentDefinition) -> void:
	definition = def
	component_id = def.id
	for t: ComponentToggleDefinition in def.toggles:
		flags[t.flag] = t.default_value


func get_flag(flag: StringName) -> bool:
	return bool(flags.get(flag, false))


func has_fault(fault_id: StringName) -> bool:
	return faults.has(String(fault_id))


func is_condition_known() -> bool:
	return inspection != Inspection.NONE


## True if the part is installed and connected per its retaining fasteners.
## Full electrical connectivity is evaluated by the electrical system.
func is_fault_free() -> bool:
	return faults.is_empty()


## Converts the fitted part into a portable inventory part record.
func to_part_record() -> Dictionary:
	return {
		"uid": part_uid,
		"component_id": String(component_id),
		"condition": condition,
		"faults": Array(faults),
		"discovered_faults": Array(discovered_faults),
		"inspection": inspection,
		"is_new": is_new,
	}


## Fits a part record into this slot.
func load_part_record(rec: Dictionary) -> void:
	part_uid = String(rec.get("uid", ""))
	condition = clampf(float(rec.get("condition", 100.0)), 0.0, 100.0)
	faults = PackedStringArray(rec.get("faults", []))
	discovered_faults = PackedStringArray(rec.get("discovered_faults", []))
	inspection = clampi(int(rec.get("inspection", Inspection.NONE)), Inspection.NONE, Inspection.TESTED) as Inspection
	is_new = bool(rec.get("is_new", false))


func to_dict() -> Dictionary:
	var d := to_part_record()
	d["installed"] = installed
	d["flags"] = flags.duplicate()
	d["parameters"] = parameters.duplicate()
	return d


func from_dict(d: Dictionary) -> void:
	load_part_record(d)
	installed = bool(d.get("installed", installed))
	var saved_flags: Variant = d.get("flags", {})
	if saved_flags is Dictionary:
		for k: Variant in (saved_flags as Dictionary):
			# Only accept flags the definition actually declares.
			var key := StringName(str(k))
			if flags.has(key):
				flags[key] = bool((saved_flags as Dictionary)[k])
	var saved_params: Variant = d.get("parameters", {})
	if saved_params is Dictionary:
		parameters = (saved_params as Dictionary).duplicate()
