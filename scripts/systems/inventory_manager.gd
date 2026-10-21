class_name InventoryManager
extends RefCounted
## Player-carried tools, parts and the fastener tray.
##
## Parts are plain records (see [method ComponentInstance.to_part_record]) so a
## removed component keeps its identity, condition and faults while it sits in
## inventory or storage.

signal changed

var owned_tools: PackedStringArray = PackedStringArray()
var parts: Array[Dictionary] = []
## Fastener runtime IDs whose hardware is in the tray (removed from the vehicle).
var fastener_tray: PackedStringArray = PackedStringArray()
## UID of the part currently held for installation ("" = none).
var held_part_uid: String = ""
## Parts deposited in workshop storage (core return bin).
var core_bin: Array[Dictionary] = []
## Consumable fluids carried: {fluid_id: litres}.
var fluids: Dictionary = {}
## Spare fastener hardware: {fastener_definition_id: count}.
var spare_fasteners: Dictionary = {}


func has_tool(tool_id: StringName) -> bool:
	return owned_tools.has(String(tool_id))


func add_tool(tool_id: StringName) -> void:
	if not has_tool(tool_id):
		owned_tools.append(String(tool_id))
		changed.emit()


func add_part(rec: Dictionary) -> void:
	parts.append(rec)
	changed.emit()


func get_part(uid: String) -> Dictionary:
	for p: Dictionary in parts:
		if p.get("uid", "") == uid:
			return p
	return {}


func remove_part(uid: String) -> Dictionary:
	for i: int in parts.size():
		if parts[i].get("uid", "") == uid:
			var rec: Dictionary = parts[i]
			parts.remove_at(i)
			if held_part_uid == uid:
				held_part_uid = ""
			changed.emit()
			return rec
	return {}


func has_part(component_id: StringName, only_new: bool) -> bool:
	for p: Dictionary in parts:
		if p.get("component_id", "") == String(component_id) and (not only_new or bool(p.get("is_new", false))):
			return true
	return false


func get_held_part() -> Dictionary:
	return get_part(held_part_uid) if held_part_uid != "" else {}


func hold_part(uid: String) -> bool:
	if uid == "" or get_part(uid).is_empty():
		held_part_uid = ""
		changed.emit()
		return false
	held_part_uid = uid
	changed.emit()
	return true


func fluid_amount(fluid_id: StringName) -> float:
	return float(fluids.get(String(fluid_id), 0.0))


func add_fluid(fluid_id: StringName, litres: float) -> void:
	fluids[String(fluid_id)] = fluid_amount(fluid_id) + litres
	changed.emit()


func take_fluid(fluid_id: StringName, litres: float) -> void:
	fluids[String(fluid_id)] = maxf(0.0, fluid_amount(fluid_id) - litres)
	changed.emit()


func spare_count(def_id: StringName) -> int:
	return int(spare_fasteners.get(String(def_id), 0))


func add_spare(def_id: StringName, n: int) -> void:
	spare_fasteners[String(def_id)] = spare_count(def_id) + n
	changed.emit()


func take_spare(def_id: StringName) -> bool:
	if spare_count(def_id) <= 0:
		return false
	spare_fasteners[String(def_id)] = spare_count(def_id) - 1
	changed.emit()
	return true


func tray_add(fastener_id: StringName) -> void:
	if not fastener_tray.has(String(fastener_id)):
		fastener_tray.append(String(fastener_id))
		changed.emit()


func tray_take(fastener_id: StringName) -> bool:
	var i := fastener_tray.find(String(fastener_id))
	if i < 0:
		return false
	fastener_tray.remove_at(i)
	changed.emit()
	return true


func tray_has(fastener_id: StringName) -> bool:
	return fastener_tray.has(String(fastener_id))


func deposit_core(uid: String) -> Dictionary:
	var rec := remove_part(uid)
	if not rec.is_empty():
		core_bin.append(rec)
		changed.emit()
	return rec


func to_dict() -> Dictionary:
	return {
		"tools": Array(owned_tools),
		"parts": parts.duplicate(true),
		"fastener_tray": Array(fastener_tray),
		"held_part_uid": held_part_uid,
		"core_bin": core_bin.duplicate(true),
		"fluids": fluids.duplicate(),
		"spare_fasteners": spare_fasteners.duplicate(),
	}


func from_dict(d: Dictionary, db: ContentDatabase, warnings: PackedStringArray) -> void:
	owned_tools = PackedStringArray()
	for t: Variant in d.get("tools", []):
		if db.tools.has(StringName(str(t))):
			owned_tools.append(str(t))
		else:
			warnings.append("Unknown tool '%s' in save ignored." % t)
	parts = _clean_parts(d.get("parts", []), db, warnings)
	core_bin = _clean_parts(d.get("core_bin", []), db, warnings)
	fastener_tray = PackedStringArray()
	for f: Variant in d.get("fastener_tray", []):
		fastener_tray.append(str(f))
	fluids = {}
	var fl: Variant = d.get("fluids", {})
	if fl is Dictionary:
		for k: Variant in fl:
			fluids[str(k)] = clampf(float(fl[k]), 0.0, 100.0)
	spare_fasteners = {}
	var sp: Variant = d.get("spare_fasteners", {})
	if sp is Dictionary:
		for k: Variant in sp:
			if db.fasteners.has(StringName(str(k))):
				spare_fasteners[str(k)] = clampi(int(sp[k]), 0, 99)
			else:
				warnings.append("Unknown spare fastener '%s' in save ignored." % k)
	held_part_uid = str(d.get("held_part_uid", ""))
	if get_part(held_part_uid).is_empty():
		held_part_uid = ""
	changed.emit()


static func _clean_parts(raw: Variant, db: ContentDatabase, warnings: PackedStringArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (raw is Array):
		return out
	for p: Variant in raw:
		if not (p is Dictionary):
			continue
		var rec: Dictionary = p
		if not db.components.has(StringName(str(rec.get("component_id", "")))):
			warnings.append("Unknown part '%s' in save ignored." % rec.get("component_id", "?"))
			continue
		if str(rec.get("uid", "")) == "":
			continue
		out.append(rec)
	return out
