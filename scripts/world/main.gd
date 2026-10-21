class_name Main
extends Node3D
## Entry point. Builds the workshop, vehicle, player and UI around one
## [GameSession], routes global keys and persists settings.

const VEHICLE_SCENE: PackedScene = preload("res://scenes/vehicles/project_c01.tscn")
const SETTINGS_PATH: String = "user://settings.cfg"
## Distance from the car origin that counts as "approached the vehicle".
const APPROACH_RADIUS: float = 3.4

var session: GameSession
var garage: GarageBuilder
var vehicle_view: VehicleView
var player: PlayerController
var interaction: InteractionManager
var ui: UIManager
var settings: Dictionary = {"mouse_sensitivity": 1.0, "quality": 2, "fullscreen": false}


func _ready() -> void:
	InputConfig.ensure_actions()
	_load_settings()
	session = GameSession.new()
	garage = GarageBuilder.new()
	garage.name = "Garage"
	add_child(garage)
	garage.build()
	vehicle_view = VEHICLE_SCENE.instantiate() as VehicleView
	add_child(vehicle_view)
	vehicle_view.setup(session)
	player = PlayerController.new()
	player.name = "Player"
	add_child(player)
	player.global_position = GarageBuilder.SPAWN_POINT
	interaction = InteractionManager.new()
	interaction.name = "InteractionManager"
	player.add_child(interaction)
	interaction.setup(player.camera, session)
	ui = UIManager.new()
	ui.name = "UI"
	add_child(ui)
	ui.setup(session, settings)
	interaction.target_changed.connect(func(t: Interactable) -> void: ui.hud.set_target(t.get_target() if t else {}))
	ui.modal_changed.connect(_on_modal_changed)
	ui.save_requested.connect(save_game)
	ui.load_requested.connect(load_game)
	ui.settings_changed.connect(_apply_settings)
	session.tools.changed.connect(func() -> void:
		player.set_flashlight(session.tools.is_illuminating())
		player.viewmodel.set_tool(session.tools.equipped))
	session.world_changed.connect(_update_world_props)
	session.job.progress_changed.connect(_update_board)
	_apply_settings(settings)
	_update_board()
	_update_world_props()
	if not session.validation_errors.is_empty():
		session.post_message("Content validation reported %d problem(s) — see the log." % session.validation_errors.size(), false)
	session.post_message("Welcome to the workshop. Read the work order on the information board (or press J).", true)


func _exit_tree() -> void:
	if session:
		session.dispose()


func _process(delta: float) -> void:
	session.tick(delta)
	var p := player.global_position
	if p.z < GarageBuilder.ENTRY_LINE_Z:
		session.record_event(&"entered_workshop")
	if Vector2(p.x, p.z).distance_to(Vector2(vehicle_view.global_position.x, vehicle_view.global_position.z)) < APPROACH_RADIUS:
		session.record_event(&"approached_vehicle")
	_sync_player_state()


## Copies the player pose into the session (explicit data, no node references).
func _sync_player_state() -> void:
	var p := player.global_position
	session.player_state = {
		"position": [snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)],
		"yaw": snappedf(player.get_yaw(), 0.0001),
		"pitch": snappedf(player.get_pitch(), 0.0001),
		"crouching": player.is_crouching,
	}


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		save_game()
		return
	if event.is_action_pressed("quick_load"):
		load_game()
		return
	if event.is_action_pressed("inventory"):
		ui.toggle_panel(ui.inventory_panel)
		return
	if event.is_action_pressed("work_order"):
		ui.toggle_panel(ui.work_order)
		return
	if ui.is_modal_open():
		return
	for i: int in range(1, 6):
		if event.is_action_pressed("tool_slot_%d" % i):
			_equip_slot(i)
			return
	if event.is_action_pressed("holster"):
		session.equip_tool(&"")
	elif event.is_action_pressed("socket_next"):
		session.cycle_socket(1)
	elif event.is_action_pressed("socket_prev"):
		session.cycle_socket(-1)
	elif event.is_action_pressed("tool_adjust_up"):
		session.adjust_tool(1)
	elif event.is_action_pressed("tool_adjust_down"):
		session.adjust_tool(-1)


func _equip_slot(slot: int) -> void:
	for t: ToolDefinition in session.db.tools.values():
		if t.hotbar_slot == slot:
			session.equip_tool(&"" if session.tools.equipped == t.id else t.id)
			return


func _on_modal_changed(open: bool) -> void:
	player.input_enabled = not open
	interaction.input_enabled = not open


func _update_board() -> void:
	var j := session.job.definition
	var v := session.vehicle.definition
	var lines := PackedStringArray()
	lines.append("%s" % j.title)
	lines.append("")
	lines.append("VEHICLE    %s · %s" % [v.display_name, v.body_style])
	lines.append("LAYOUT     %s" % v.drivetrain)
	lines.append("COMPLAINT  %s" % j.customer_complaint)
	lines.append("")
	var o := session.job.current_objective()
	lines.append("PROGRESS   %d / %d objectives" % [session.job.completed_count(), j.objectives.size()])
	lines.append("NEXT       %s" % (o.text if o else "Signed off"))
	lines.append("")
	lines.append("[E] open the full work order")
	garage.set_board_text("\n".join(lines))


func _update_world_props() -> void:
	garage.set_charger_on(session.electrical.charger_connected)


# --- Save / load ------------------------------------------------------------------

func save_game() -> void:
	_sync_player_state()
	var r := SaveManager.save_session(session)
	session.post_message(r.message, r.ok)
	ui.pause_menu.set_status(r.message)


func load_game() -> void:
	var res := SaveManager.load_into(session)
	if not res.get("ok", false):
		session.post_message(str(res.get("error", "Load failed.")), false)
		ui.pause_menu.set_status(str(res.get("error", "Load failed.")))
		return
	apply_player_state(session.player_state)
	vehicle_view.refresh_all()
	var warnings: PackedStringArray = res.get("warnings", PackedStringArray())
	for w: String in warnings:
		push_warning("Load: " + w)
	var msg := "Game loaded." + (" (%d warning(s) — see log)" % warnings.size() if not warnings.is_empty() else "")
	session.post_message(msg, true)
	ui.pause_menu.set_status(msg)
	_update_board()


## Applies a saved player pose with validation.
func apply_player_state(ps: Dictionary) -> void:
	var pos: Variant = ps.get("position", null)
	if pos is Array and (pos as Array).size() == 3:
		var v := Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		var lim := Vector3(GarageBuilder.HALF_W, GarageBuilder.WALL_H, maxf(-GarageBuilder.BACK_Z, GarageBuilder.FRONT_Z))
		if absf(v.x) <= lim.x and v.y > -1.0 and v.y < lim.y and v.z >= GarageBuilder.BACK_Z and v.z <= GarageBuilder.FRONT_Z:
			player.global_position = v
			player.velocity = Vector3.ZERO
	player.set_view(float(ps.get("yaw", player.get_yaw())), float(ps.get("pitch", player.get_pitch())))


# --- Settings ----------------------------------------------------------------------

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		settings["mouse_sensitivity"] = clampf(float(cfg.get_value("input", "mouse_sensitivity", 1.0)), 0.2, 3.0)
		settings["quality"] = clampi(int(cfg.get_value("graphics", "quality", 2)), 0, 2)
		settings["fullscreen"] = bool(cfg.get_value("graphics", "fullscreen", false))


func _apply_settings(s: Dictionary) -> void:
	settings = s.duplicate()
	if player:
		player.mouse_sensitivity = float(settings["mouse_sensitivity"])
	var q := int(settings["quality"])
	var vp := get_viewport()
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][q]
	vp.scaling_3d_scale = [0.75, 1.0, 1.0][q]
	var we := garage.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		we.environment.ssao_enabled = q >= 1
	for light: Node in garage.find_children("*", "SpotLight3D", true, false):
		(light as SpotLight3D).shadow_enabled = q >= 2 or (q == 1 and light.get_index() % 4 == 0)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(settings["fullscreen"]) else DisplayServer.WINDOW_MODE_WINDOWED)
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sensitivity", settings["mouse_sensitivity"])
	cfg.set_value("graphics", "quality", settings["quality"])
	cfg.set_value("graphics", "fullscreen", settings["fullscreen"])
	cfg.save(SETTINGS_PATH)
