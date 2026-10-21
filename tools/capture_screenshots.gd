extends SceneTree
## Captures reference screenshots of the main scene from fixed viewpoints.
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/capture_screenshots.gd -- --out=<dir>
## Needs a real (or virtual) display; the headless dummy renderer has no pixels.

var out_dir := "user://screenshots"
## Comma-separated shot-name prefixes to capture (empty = all).
var only: PackedStringArray = PackedStringArray()
var job: StringName = &"job_001"


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
		if a.begins_with("--job="):
			job = StringName(a.trim_prefix("--job="))
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
	_run.call_deferred()


func _shot(main: Main, name: String, stand: Vector3, look: Vector3, frames: int = 30) -> void:
	if not only.is_empty() and not Array(only).any(func(o: String) -> bool: return name.begins_with(o)):
		return
	var p := main.player
	stand.y = 0.0
	p.global_position = stand
	p.velocity = Vector3.ZERO
	var eye := stand + Vector3(0, PlayerController.STAND_EYE, 0)
	var d := look - eye
	p.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	for i: int in frames:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var path := out_dir.path_join(name + ".png")
	img.save_png(path)
	print("saved ", path)


func _run() -> void:
	InputConfig.ensure_actions()
	root.size = Vector2i(1600, 900)
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i: int in 10:
		await process_frame
	if main.current_job != job:
		main.start_job(job)
		for i: int in 10:
			await process_frame
	if job == &"job_101":
		await _m4_shots(main)
		quit()
		return
	await _shot(main, "01_entrance", Vector3(2.5, 0, 9.4), Vector3(0, 1.0, 0))
	await _shot(main, "02_workshop_overview", Vector3(6.5, 0, 7.0), Vector3(-1, 0.8, -2))
	await _shot(main, "03_car_front", Vector3(1.8, 0, -4.6), Vector3(0, 0.7, -1.2))
	main.session.interact({"type": &"component", "id": &"hood"})
	await _shot(main, "04_hood_open", Vector3(1.6, 0, -3.8), Vector3(0, 0.7, -1.4), 90)
	await _shot(main, "05_engine_bay_alternator", Vector3(0.28, 0, -2.6), main.vehicle_view.mount("alternator").global_position)
	main.session.equip_tool(&"ratchet")
	await _shot(main, "06_target_bolt", Vector3(0.195, 0, -2.6), main.vehicle_view.mount("alternator").get_node("B01").global_position)
	await _shot(main, "07_driver_side_ignition", Vector3(-1.3, 0, -0.6), main.vehicle_view.mount("ignition").global_position)
	await _shot(main, "08_parts_shelf", Vector3(-6.8, 0, -2.6), Vector3(-8.6, 0.9, -3.0))
	await _shot(main, "09_info_board", Vector3(6.6, 0, -2.2), Vector3(8.9, 1.6, -2.2))
	main.session.inspect({"type": &"component", "id": &"alternator"})
	await _shot(main, "10_inspection_panel", Vector3(0.28, 0, -2.6), main.vehicle_view.mount("alternator").global_position)
	main.ui.toggle_panel(main.ui.work_order)
	await _shot(main, "11_work_order", Vector3(0.28, 0, -2.6), main.vehicle_view.mount("alternator").global_position, 10)
	main.ui.handle_escape()
	main.ui.toggle_panel(main.ui.inventory_panel)
	await _shot(main, "12_inventory", Vector3(0.28, 0, -2.6), main.vehicle_view.mount("alternator").global_position, 10)
	quit()


func _m4_shots(main: Main) -> void:
	var v := main.vehicle_view
	await _shot(main, "m4_01_front_three_quarter", Vector3(2.6, 0, -4.4), Vector3(0, 0.6, -0.6))
	await _shot(main, "m4_02_rear_three_quarter", Vector3(-2.6, 0, 4.3), Vector3(0, 0.7, 0.6))
	await _shot(main, "m4_03_side", Vector3(-4.2, 0, 0.0), Vector3(0, 0.6, 0.0))
	main.session.interact({"type": &"component", "id": &"m4_hood"})
	await _shot(main, "m4_04_bay", Vector3(0.0, 0, -2.85), Vector3(0, 0.55, -1.55), 120)
	main.session.equip_tool(&"hose_clamp_pliers")
	await _shot(main, "m4_05_clip", Vector3(-0.19, 0, -2.75), v.mount("m4_cc_hose").get_node("CLIP_A").global_position)
	main.session.interact({"type": &"component", "id": &"m4_trunk"})
	main.session.equip_tool(&"ratchet")
	await _shot(main, "m4_06_trunk_battery", Vector3(0.56, 0, 2.9), v.mount("m4_battery").get_node("NEG").global_position, 120)
	main.session.interact({"type": &"component", "id": &"m4_trunk"})
	main.session.toggle_lift()
	await _shot(main, "m4_07_lifted", Vector3(-2.2, 0, -2.6), Vector3(0, 1.4, -0.6), 240)
