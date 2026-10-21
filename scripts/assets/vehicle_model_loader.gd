class_name VehicleModelLoader
extends RefCounted
## Loads vehicle models: imported resources (res://*.glb/.gltf/.tscn, imported
## by the editor) or external glTF/GLB files at runtime via GLTFDocument
## (user:// or absolute paths, e.g. community mods). Returns null on failure.


static func load_model(path: String) -> Node3D:
	if path == "":
		return null
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var res := load(path)
		if res is PackedScene:
			return (res as PackedScene).instantiate() as Node3D
	var ext := path.get_extension().to_lower()
	if (ext == "glb" or ext == "gltf") and FileAccess.file_exists(path):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var err := doc.append_from_file(path, state)
		if err != OK:
			push_error("VehicleModelLoader: cannot read %s (%s)" % [path, error_string(err)])
			return null
		return doc.generate_scene(state) as Node3D
	push_error("VehicleModelLoader: unsupported or missing model '%s'" % path)
	return null


## Writes a node tree to a .glb/.gltf file.
static func save_gltf(root: Node3D, path: String) -> Error:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(root, state)
	if err != OK:
		return err
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	return doc.write_to_filesystem(state, path)
