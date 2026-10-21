extends SceneTree
## Validates a vehicle model file against a vehicle definition.
##   godot --headless --path . --script res://tools/validate_vehicle_model.gd -- --vehicle=bmw_m4_g82 --model=/abs/path/model.glb
## Exit code: 0 valid (warnings allowed), 1 errors, 2 usage.


func _initialize() -> void:
	var vid := ""
	var path := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--vehicle="):
			vid = a.trim_prefix("--vehicle=")
		elif a.begins_with("--model="):
			path = a.trim_prefix("--model=")
	var db := ContentDatabase.new().load_all()
	var vdef: VehicleDefinition = db.vehicles.get(StringName(vid), null)
	if vdef == null or path == "":
		printerr("usage: --vehicle=<id> --model=<file.glb|res://...>")
		quit(2)
		return
	var model := VehicleModelLoader.load_model(path)
	if model == null:
		printerr("could not load %s" % path)
		quit(1)
		return
	var r := VehicleModelValidator.validate(model, vdef)
	print("Model:    %s" % path)
	print("Vehicle:  %s" % vdef.display_name)
	print("Stats:    %s" % JSON.stringify(r["stats"]))
	for e: String in r["errors"]:
		print("ERROR    %s" % e)
	for w: String in r["warnings"]:
		print("WARNING  %s" % w)
	print("Result:   %s (%d errors, %d warnings)" % ["INVALID" if (r["errors"] as PackedStringArray).size() > 0 else "VALID", (r["errors"] as PackedStringArray).size(), (r["warnings"] as PackedStringArray).size()])
	model.free()
	quit(1 if (r["errors"] as PackedStringArray).size() > 0 else 0)
