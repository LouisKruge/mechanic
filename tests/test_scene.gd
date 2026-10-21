extends TestCase
## Integration tests against the real main scene in the SceneTree.

const MAIN := "res://scenes/main.tscn"

var main: Main


func _load_main() -> void:
	var scene := load(MAIN) as PackedScene
	main = scene.instantiate() as Main
	tree.root.add_child(main)
	for i: int in 4:
		await tree.physics_frame


func after_each() -> void:
	if is_instance_valid(main):
		main.queue_free()
		main = null
	for k: StringName in ["move_forward", "move_back", "move_left", "move_right", "sprint", "crouch"]:
		Input.action_release(k)


func _aim_at(stand: Vector3, target: Vector3) -> void:
	var p := main.player
	stand.y = 0.0  # feet on the floor, so the eye height below is exact
	p.global_position = stand
	p.velocity = Vector3.ZERO
	p.head.position.y = PlayerController.STAND_EYE
	var eye := stand + Vector3(0, PlayerController.STAND_EYE, 0)
	var dir := target - eye
	var yaw := atan2(-dir.x, -dir.z)
	var pitch := atan2(dir.y, Vector2(dir.x, dir.z).length())
	p.set_view(yaw, pitch)


func _target_after_aim(stand: Vector3, target: Vector3) -> Dictionary:
	_aim_at(stand, target)
	await tree.physics_frame
	await tree.physics_frame
	main.interaction.refresh_target()
	return main.interaction.get_target_dict()


func test_main_scene_loads() -> void:
	await _load_main()
	check(main != null and main.is_inside_tree(), "main scene instantiated")
	check(main.session != null, "session created")
	check(main.session.validation_errors.is_empty(), "no content validation errors: %s" % main.session.validation_errors)
	check(main.get_node_or_null("Garage") != null, "garage built")
	check(main.get_node_or_null("Player") != null, "player present")
	check(main.get_node_or_null("UI") != null, "UI present")
	check(main.vehicle_view != null and main.vehicle_view.interactables.size() >= 12, "vehicle interactables built (%d)" % main.vehicle_view.interactables.size())
	for id: StringName in [&"hood", &"alternator", &"battery", &"starter", &"belt_tensioner", &"accessory_belt", &"engine_block", &"alternator_bracket"]:
		check(main.vehicle_view.get_interactable(&"component", id) != null, "component node for %s" % id)
	for fid: StringName in [&"alternator.B01", &"alternator.B02", &"alternator.CONN", &"battery.NEG"]:
		check(main.vehicle_view.get_interactable(&"fastener", fid) != null, "fastener node for %s" % fid)


func test_player_moves_and_collides() -> void:
	await _load_main()
	var p := main.player
	var start := p.global_position
	Input.action_press("move_forward")
	for i: int in 40:
		await tree.physics_frame
	Input.action_release("move_forward")
	check(p.global_position.z < start.z - 0.5, "walked forward (%.2f -> %.2f)" % [start.z, p.global_position.z])
	check(p.is_on_floor(), "standing on the floor")
	# Walk backwards into the closed roller door: collision must stop us inside.
	Input.action_press("move_back")
	for i: int in 200:
		await tree.physics_frame
	Input.action_release("move_back")
	check(p.global_position.z < GarageBuilder.FRONT_Z, "door/wall collision holds the player inside (z=%.2f)" % p.global_position.z)
	# Walk into the car from the side: must not pass through the body.
	p.global_position = Vector3(-2.0, 0.05, 0.6)
	p.set_view(-PI * 0.5, 0.0)  # face +X, towards the car
	Input.action_press("move_forward")
	for i: int in 120:
		await tree.physics_frame
	Input.action_release("move_forward")
	check(p.global_position.x < -0.92, "car body blocks the player (x=%.2f)" % p.global_position.x)
	# Jumping forward from the front of the car must not land in the engine bay.
	p.global_position = Vector3(0.0, 0.0, -2.7)
	p.set_view(PI, 0.0)  # face +Z, towards the bay
	Input.action_press("move_forward")
	for i: int in 90:
		if i % 30 == 0:
			Input.action_press("jump")
		await tree.physics_frame
		Input.action_release("jump")
	Input.action_release("move_forward")
	check(p.global_position.z < -2.0, "player kept out of the engine bay (pos %s)" % p.global_position)
	Input.action_press("crouch")
	for i: int in 20:
		await tree.physics_frame
	check(p.is_crouching and p.head.position.y < PlayerController.STAND_EYE - 0.2, "crouch lowers the camera")
	Input.action_release("crouch")


func test_raycast_detects_components() -> void:
	await _load_main()
	var v := main.vehicle_view
	var s := main.session
	# Hood closed: the bay is covered.
	var alt_pos := v.mount("alternator").global_position
	var t := await _target_after_aim(Vector3(0.28, 0.05, -2.75), alt_pos)
	check_eq(t.get("id"), &"hood", "closed hood occludes the alternator")
	s.interact(RepairDriver.comp(&"hood"))
	for i: int in 90:
		await tree.process_frame
	var cases := [
		[&"alternator", Vector3(0.28, 0.05, -2.75), alt_pos],
		[&"alternator.B01", Vector3(0.195, 0.05, -2.75), v.mount("alternator").get_node("B01").global_position],
		[&"alternator.B02", Vector3(0.37, 0.05, -2.75), v.mount("alternator").get_node("B02").global_position],
		[&"alternator.CONN", Vector3(0.28, 0.05, -2.75), v.mount("alternator").get_node("CONN").global_position + Vector3(0, 0.012, 0)],
		[&"battery.NEG", Vector3(-0.455, 0.05, -2.75), v.mount("battery").get_node("NEG").global_position + Vector3(0, 0.01, 0)],
		[&"battery", Vector3(-0.6, 0.05, -2.75), v.mount("battery").global_position + Vector3(-0.05, 0.15, -0.05)],
		[&"belt_tensioner", Vector3(0.13, 0.05, -2.75), v.mount("belt_tensioner").global_position],
		[&"accessory_belt", Vector3(0.28, 0.05, -2.75), v.mount("alternator").global_position + Vector3(0, -0.02, -0.124)],
		[&"engine_block", Vector3(0.0, 0.05, -2.75), v.mount("engine_block").global_position + Vector3(0, 0.3, 0.1)],
		[&"starter", Vector3(-1.3, 0.05, -1.05), v.mount("starter").global_position],
		[&"ignition", Vector3(-1.3, 0.0, -0.5), v.mount("ignition").global_position],
		[&"obd", Vector3(-1.3, 0.0, -0.5), v.mount("obd_port").global_position],
	]
	for c: Array in cases:
		var got := await _target_after_aim(c[1], c[2])
		check_eq(got.get("id", &""), c[0], "raycast finds %s" % c[0])
	# Workshop fixtures.
	var shelf := main.garage.get_node("PartsShelf/Stock_alternator") as Node3D
	var got_shelf := await _target_after_aim(Vector3(-7.6, 0.05, shelf.global_position.z), shelf.global_position)
	check_eq(got_shelf.get("type", &""), &"shelf", "raycast finds the replacement alternator on the shelf")
	var board := main.garage.get_node("InfoBoard") as Node3D
	var got_board := await _target_after_aim(Vector3(7.4, 0.05, board.global_position.z), board.global_position)
	check_eq(got_board.get("type", &""), &"work_order", "raycast finds the information board")
	var charger := main.garage.get_node("ToolTrolley/BatteryCharger") as Node3D
	var got_ch := await _target_after_aim(charger.global_position + Vector3(0, -1.05, 1.0), charger.global_position)
	check_eq(got_ch.get("type", &""), &"charger", "raycast finds the battery maintainer")
	# HUD shows the targeted name.
	await _target_after_aim(Vector3(0.195, 0.05, -2.75), v.mount("alternator").get_node("B01").global_position)
	await tree.process_frame
	check_eq(main.ui.hud._target_name.text, "Mounting bolt B01", "HUD shows the targeted bolt name")


func test_removed_parts_update_visuals() -> void:
	await _load_main()
	var s := main.session
	var d := RepairDriver.new(s)
	d.arrive_and_diagnose()
	d.disassemble()
	await tree.process_frame
	var v := main.vehicle_view
	var real: Node3D = v._real[&"alternator"]
	var ghost: Node3D = v._ghost[&"alternator"]
	check(not real.visible, "removed alternator hidden")
	check(ghost.visible, "empty mount shows a ghost")
	var b01 := v.get_interactable(&"fastener", &"alternator.B01")
	check_eq(b01.collision_layer, 0, "bolts on an empty mount are not targetable")
	d.fit_new_alternator()
	await tree.process_frame
	check(real.visible and not ghost.visible, "fitted alternator visible again")
	check_eq(b01.collision_layer, MeshKit.LAYER_INTERACT, "bolt holes targetable after fitting")


func test_ui_panels_toggle_input_mode() -> void:
	await _load_main()
	var ui := main.ui
	ui.toggle_panel(ui.inventory_panel)
	await tree.process_frame
	check(ui.inventory_panel.visible, "inventory opens")
	check(not main.player.input_enabled, "player input disabled while a panel is open")
	ui.handle_escape()
	await tree.process_frame
	check(not ui.inventory_panel.visible, "escape closes inventory")
	check(main.player.input_enabled, "input restored")
	ui.toggle_panel(ui.work_order)
	await tree.process_frame
	check(main.session.events.has(&"read_work_order"), "opening the work order counts as reading it")
	ui.handle_escape()
	ui.handle_escape()
	await tree.process_frame
	check(ui.pause_menu.visible, "escape with nothing open shows the pause menu")
	check(tree.paused, "pause menu pauses the simulation")
	ui.handle_escape()
	check(not tree.paused, "closing the pause menu resumes")
	main.session.inspect(RepairDriver.comp(&"battery"))
	await tree.process_frame
	check(ui.inspection.visible, "inspection panel opens on F")
	check(ui.inspection._title.text.begins_with("Battery"), "inspection title")


func test_quick_save_and_load_in_scene() -> void:
	await _load_main()
	var s := main.session
	s.interact(RepairDriver.comp(&"hood"))
	main.player.global_position = Vector3(3.0, 0.05, 2.0)
	await tree.process_frame
	main.save_game()
	s.interact(RepairDriver.comp(&"hood"))
	main.player.global_position = Vector3(-3.0, 0.05, 5.0)
	await tree.process_frame
	check(not s.vehicle.get_component(&"hood").get_flag(&"open"), "hood closed before load")
	main.load_game()
	await tree.process_frame
	check(s.vehicle.get_component(&"hood").get_flag(&"open"), "hood open after load")
	check_near(main.player.global_position.x, 3.0, 0.05, "player position restored")
