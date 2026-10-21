class_name ContentDatabase
extends RefCounted
## Loads every definition Resource under res://data and indexes it by ID.
##
## Directory listing handles exported builds, where .tres files appear as
## "<name>.tres.remap". Definitions referenced from other resources (e.g. a
## fastener used by a component) resolve to the same cached instance.

const DATA_ROOT: String = "res://data"

var tools: Dictionary = {}       # StringName -> ToolDefinition
var fasteners: Dictionary = {}   # StringName -> FastenerDefinition
var faults: Dictionary = {}      # StringName -> FaultDefinition
var components: Dictionary = {}  # StringName -> ComponentDefinition
var vehicles: Dictionary = {}    # StringName -> VehicleDefinition
var jobs: Dictionary = {}        # StringName -> JobDefinition
var duplicate_ids: PackedStringArray = PackedStringArray()
var load_errors: PackedStringArray = PackedStringArray()


## Loads all definitions. Returns self for chaining.
func load_all(root: String = DATA_ROOT) -> ContentDatabase:
	for path: String in _list_resources(root):
		var res := load(path)
		if res == null:
			load_errors.append("Failed to load %s" % path)
			continue
		register(res)
	return self


## Indexes a definition resource. Public so tests can build databases in code.
func register(res: Resource) -> void:
	if res is ToolDefinition:
		_put(tools, (res as ToolDefinition).id, res, "tool")
	elif res is FastenerDefinition:
		_put(fasteners, (res as FastenerDefinition).id, res, "fastener")
	elif res is FaultDefinition:
		_put(faults, (res as FaultDefinition).id, res, "fault")
	elif res is ComponentDefinition:
		var c := res as ComponentDefinition
		_put(components, c.id, res, "component")
		for slot: FastenerSlotDefinition in c.fasteners:
			if slot.fastener and not fasteners.has(slot.fastener.id):
				fasteners[slot.fastener.id] = slot.fastener
	elif res is VehicleDefinition:
		_put(vehicles, (res as VehicleDefinition).id, res, "vehicle")
	elif res is JobDefinition:
		_put(jobs, (res as JobDefinition).id, res, "job")


func _put(d: Dictionary, id: StringName, res: Resource, kind: String) -> void:
	if d.has(id) and d[id] != res:
		duplicate_ids.append("%s:%s" % [kind, id])
		return
	d[id] = res


func get_tool(id: StringName) -> ToolDefinition:
	return tools.get(id, null)


func get_fault(id: StringName) -> FaultDefinition:
	return faults.get(id, null)


func get_component(id: StringName) -> ComponentDefinition:
	return components.get(id, null)


static func _list_resources(root: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_list_resources(root.path_join(name)))
		else:
			var clean := name.trim_suffix(".remap")
			if clean.ends_with(".tres") or clean.ends_with(".res"):
				out.append(root.path_join(clean))
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out
