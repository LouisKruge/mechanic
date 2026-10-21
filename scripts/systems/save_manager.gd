class_name SaveManager
extends RefCounted
## Versioned JSON save files.
##
## Saves contain only explicit, stable-ID data produced by
## [method GameSession.to_save_dict] — never serialized engine objects. Files
## are written to a temporary path and renamed, so a crash mid-write cannot
## corrupt the previous save.

const FORMAT: String = "garage-save"
const VERSION: int = 1
const DEFAULT_PATH: String = "user://saves/slot_1.json"


static func save_session(session: GameSession, path: String = DEFAULT_PATH) -> ActionResult:
	var payload := session.to_save_dict()
	payload["format"] = FORMAT
	payload["version"] = VERSION
	payload["game_version"] = str(ProjectSettings.get_setting("application/config/version", "0"))
	payload["saved_at_utc"] = Time.get_datetime_string_from_system(true)
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var mk := DirAccess.make_dir_recursive_absolute(dir)
		if mk != OK:
			return ActionResult.fail("Could not create save folder (%s)." % error_string(mk))
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return ActionResult.fail("Could not write save (%s)." % error_string(FileAccess.get_open_error()))
	file.store_string(JSON.stringify(payload, "  ", false))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		return ActionResult.fail("Could not finalise save (%s)." % error_string(err))
	return ActionResult.success("Game saved.", false)


## Reads and validates a save file. Returns {ok, data, error}.
static func read_save(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "No save file found."}
	var text := FileAccess.get_file_as_string(path)
	return parse_save_text(text)


## Parses and validates save JSON text (separate for testing).
static func parse_save_text(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {"ok": false, "error": "Save file is corrupt (line %d: %s)." % [json.get_error_line(), json.get_error_message()]}
	var data: Variant = json.data
	if not (data is Dictionary):
		return {"ok": false, "error": "Save file has an invalid structure."}
	var d: Dictionary = data
	if str(d.get("format", "")) != FORMAT:
		return {"ok": false, "error": "Not a GARAGE save file."}
	var version := int(d.get("version", 0))
	if version > VERSION:
		return {"ok": false, "error": "Save was made by a newer version (v%d)." % version}
	if version < 1:
		return {"ok": false, "error": "Save version is missing or invalid."}
	return {"ok": true, "data": migrate(d, version)}


## Upgrades older save layouts to the current VERSION.
static func migrate(d: Dictionary, from_version: int) -> Dictionary:
	var out := d.duplicate(true)
	# v1 is the first format; future migrations chain here, e.g.:
	# if from_version < 2: out = _migrate_1_to_2(out)
	out["version"] = VERSION
	return out


## Convenience: reads, validates and applies a save to the session.
static func load_into(session: GameSession, path: String = DEFAULT_PATH) -> Dictionary:
	var res := read_save(path)
	if not res.get("ok", false):
		return res
	var warnings := session.apply_save_dict(res["data"])
	return {"ok": true, "warnings": warnings, "data": res["data"]}
