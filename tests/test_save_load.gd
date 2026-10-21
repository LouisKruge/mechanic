extends TestCase
## Versioned save/load round trip and invalid data handling.

const PATH: String = "user://test_saves/roundtrip.json"


func _strip(d: Dictionary) -> Dictionary:
	var c := d.duplicate(true)
	for k: String in ["saved_at_utc", "format", "version", "game_version"]:
		c.erase(k)
	return c


static func _diff(a: Variant, b: Variant, path: String) -> PackedStringArray:
	var out := PackedStringArray()
	if a is Dictionary and b is Dictionary:
		var keys: Dictionary = {}
		for k: Variant in a:
			keys[k] = true
		for k: Variant in b:
			keys[k] = true
		for k: Variant in keys:
			out.append_array(_diff((a as Dictionary).get(k), (b as Dictionary).get(k), "%s/%s" % [path, k]))
	elif a is Array and b is Array and (a as Array).size() == (b as Array).size():
		for i: int in (a as Array).size():
			out.append_array(_diff(a[i], b[i], "%s[%d]" % [path, i]))
	elif a != b:
		out.append("%s: %s != %s" % [path, a, b])
	return out


func test_round_trip_preserves_mechanical_state() -> void:
	var db := ContentDatabase.new().load_all()
	var a := GameSession.new(db)
	var d := RepairDriver.new(a)
	d.arrive_and_diagnose()
	d.disassemble()
	d.fit_new_alternator()
	d.press(RepairDriver.fast(&"alternator.B01"))
	d.equip(&"ratchet", 13)
	d.hold_primary(RepairDriver.fast(&"alternator.B01"), 1.0)  # part-threaded
	d.equip(&"torque_wrench", 13)
	d.set_torque(37.0)
	a.player_state = {"position": [1.0, 0.05, -2.8], "yaw": 0.5, "pitch": -0.4, "crouching": false}
	var saved := SaveManager.save_session(a, PATH)
	check(saved.ok, "saved: %s" % saved.message)
	var b := GameSession.new(db)
	var res := SaveManager.load_into(b, PATH)
	check(res.get("ok", false), "loaded: %s" % res.get("error", ""))
	check_eq((res.get("warnings", PackedStringArray()) as PackedStringArray).size(), 0, "no warnings")
	var da: Variant = JSON.parse_string(JSON.stringify(_strip(a.to_save_dict())))
	var dbb: Variant = JSON.parse_string(JSON.stringify(_strip(b.to_save_dict())))
	var diffs := _diff(da, dbb, "")
	check(diffs.is_empty(), "state identical after round trip; differences:\n%s" % "\n".join(diffs))
	var f := b.vehicle.get_fastener(&"alternator.B01")
	check(not f.removed and f.thread_progress > 0.15 and f.thread_progress < 1.0, "partially threaded bolt restored (%.2f)" % f.thread_progress)
	check(b.vehicle.get_fastener(&"alternator.B02").removed, "B02 removed")
	check(b.inventory.tray_has(&"alternator.B02"), "B02 in tray")
	check(b.vehicle.get_component(&"alternator").is_fault_free(), "new alternator fitted")
	check(b.inventory.has_part(&"alternator", false), "old alternator in inventory")
	check_eq(b.tools.equipped, &"torque_wrench", "equipped tool")
	check_eq(b.tools.torque_setting_nm, 37.0, "torque setting")
	check_eq(b.vehicle.get_component(&"alternator").component_id, &"alternator", "id")
	check_near(b.electrical.soc, a.electrical.soc, 0.0001, "battery charge")
	check(b.job.is_complete(&"install_replacement"), "job progress")
	check(not b.vehicle.get_fastener(&"battery.NEG").is_installed(), "battery still isolated")
	check_eq(b.player_state.get("yaw"), 0.5, "player view")
	# Continue the job in the loaded session.
	var d2 := RepairDriver.new(b)
	d2.equip(&"ratchet", 13)
	d2.press(RepairDriver.fast(&"alternator.B02"))
	d2.hold_primary(RepairDriver.fast(&"alternator.B01"), 3.5)
	d2.hold_primary(RepairDriver.fast(&"alternator.B02"), 3.5)
	d2.equip(&"torque_wrench", 13)
	d2.set_torque(45.0)
	d2.hold_primary(RepairDriver.fast(&"alternator.B01"), 2.5)
	d2.hold_primary(RepairDriver.fast(&"alternator.B02"), 2.5)
	d2.reassemble_rest()
	var r := d2.verify_and_sign_off()
	check(r.ok, "job completes after load: %s" % r.message)
	a.dispose()
	b.dispose()


func test_invalid_saves_are_rejected_gracefully() -> void:
	check(not SaveManager.parse_save_text("{ not json").get("ok", true), "corrupt JSON rejected")
	check(not SaveManager.parse_save_text("[1,2,3]").get("ok", true), "wrong structure rejected")
	check(not SaveManager.parse_save_text('{"format":"other","version":1}').get("ok", true), "wrong format rejected")
	check(not SaveManager.parse_save_text('{"format":"garage-save","version":99}').get("ok", true), "newer version rejected")
	check(not SaveManager.parse_save_text('{"format":"garage-save"}').get("ok", true), "missing version rejected")
	check(not SaveManager.read_save("user://test_saves/does_not_exist.json").get("ok", true), "missing file reported")


func test_partial_and_hostile_data_degrades_safely() -> void:
	var s := GameSession.new()
	var data := {
		"format": "garage-save", "version": 1,
		"vehicle": {"vehicle_id": "project_c01",
			"components": {"flux_capacitor": {"installed": true}, "hood": {"flags": {"open": true, "warp": true}}},
			"fasteners": {"alternator.B01": {"removed": false, "thread_progress": 7.0, "torque_nm": -50}, "nope.X": {}}},
		"inventory": {"tools": ["ratchet", "lightsaber"], "parts": [{"uid": "x1", "component_id": "unobtainium"}, "junk"]},
		"electrical": {"soc": 5.0},
		"job": {"job_id": "job_001", "completed_objectives": ["open_hood", "fly_to_moon"]},
		"tools": "not a dict",
	}
	var res := SaveManager.parse_save_text(JSON.stringify(data))
	check(res.get("ok", false), "structurally valid save accepted")
	var warnings := s.apply_save_dict(res["data"])
	var w := "\n".join(warnings)
	check_contains(w, "flux_capacitor", "unknown component warned")
	check_contains(w, "nope.X", "unknown fastener warned")
	check_contains(w, "lightsaber", "unknown tool warned")
	check_contains(w, "unobtainium", "unknown part warned")
	check_contains(w, "fly_to_moon", "unknown objective warned")
	check_contains(w, "tools", "invalid section warned")
	check(s.vehicle.get_component(&"hood").get_flag(&"open"), "valid flag applied")
	check(not s.vehicle.get_component(&"hood").flags.has(&"warp"), "undeclared flag ignored")
	var b01 := s.vehicle.get_fastener(&"alternator.B01")
	check_eq(b01.thread_progress, 1.0, "progress clamped")
	check_eq(b01.torque_nm, 0.0, "torque clamped")
	check_eq(s.electrical.soc, 1.0, "soc clamped")
	check(s.inventory.has_tool(&"ratchet") and not s.inventory.has_tool(&"lightsaber"), "tools filtered")
	check(s.inventory.parts.is_empty(), "bad parts dropped")
	s.dispose()
