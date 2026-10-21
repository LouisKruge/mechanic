extends SceneTree
## Exports an artist template GLB (procedural placeholder + anchors) and an
## anchor manifest JSON for a vehicle.
##   godot --headless --path . --script res://tools/export_vehicle_template.gd -- --vehicle=bmw_m4_g82 --out=/abs/path/bmw_m4_g82_template.glb


func _initialize() -> void:
	var vid := ""
	var out := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--vehicle="):
			vid = a.trim_prefix("--vehicle=")
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var db := ContentDatabase.new().load_all()
	var vdef: VehicleDefinition = db.vehicles.get(StringName(vid), null)
	if vdef == null or out == "":
		printerr("usage: --vehicle=<id> --out=<file.glb>   (vehicles: %s)" % ", ".join(PackedStringArray(db.vehicles.keys())))
		quit(2)
		return
	var root := VehicleTemplateExporter.build(vdef)
	var err := VehicleModelLoader.save_gltf(root, out)
	if err != OK:
		printerr("export failed: %s" % error_string(err))
		quit(1)
		return
	var man := VehicleTemplateExporter.manifest(root, vdef)
	var f := FileAccess.open(out.get_basename() + "_anchors.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(man, "  "))
	f.close()
	print("wrote %s (%d anchors) and %s" % [out, (man["anchors"] as Array).size(), out.get_basename() + "_anchors.json"])
	root.free()
	quit(0)
