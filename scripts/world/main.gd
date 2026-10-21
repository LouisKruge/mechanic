class_name Main
extends Node3D
## Entry point. Builds the workshop, vehicle, player and UI around one
## [GameSession], routes global keys and persists settings.

const SETTINGS_PATH: String = "user://settings.cfg"
const DEFAULT_JOB: StringName = &"job_001"
## Distance from the car origin that counts as "approached the vehicle".
const APPROACH_RADIUS: float = 3.6
## How far the lift raises the vehicle (metres) and how long it takes.
const LIFT_HEIGHT: float = 1.25
const LIFT_SECONDS: float = 3.0

var db: ContentDatabase
var session: GameSession
var garage: GarageBuilder
var vehicle_view: VehicleView
var player: PlayerController
var interaction: InteractionManager
var ui: UIManager
var current_job: StringName = &""
var settings: Dictionary = {"mouse_sensitivity": 1.0, "quality": 2, "fullscreen": false, "last_job": String(DEFAULT_JOB)}
var _lift_tween: Tween


func _ready() -> void:
	InputConfig.ensure_actions()
	_load_settings()
	db = ContentDatabase.new().load_all()
	garage = GarageBuilder.new()
	garage.name = "Garage"
	add_child(garage)
	garage.build()
	player = PlayerController.new()
	player.name = "Player"
	add_child(player)
	interaction = InteractionManager.new()
	interaction.name = "InteractionManager"
	player.add_child(interaction)
	interaction.setup(player.camera, null)
	interaction.target_changed.connect(func(t: Interactable) -> void:
		if ui:
			ui.hud.set_target(t.get_target() if t else {}))
	var job := StringName(str(settings.get("last_job", DEFAULT_JOB)))
	var r := start_job(job)
	if not r.ok:
		start_job(DEFAULT_JOB)


## Playable jobs and catalogue vehicles for the job list.
func job_list() -> Array:
	var out: Array = []
	var ids: Array = db.jobs.keys()
	ids.sort()
	for jid: StringName in ids:
		var j: JobDefinition = db.jobs[jid]
		var v: VehicleDefinition = db.vehicles.get(j.vehicle_id, null)
		out.append({"job_id": String(jid), "label": "%s  ·  %s" % [j.title, v.display_name if v else "?"], "playable": v != null and v.playable and v.scene_path != "", "current": jid == current_job})
	for vid: StringName in db.vehicles:
		var vd: VehicleDefinition = db.vehicles[vid]
		if not vd.playable:
			out.append({"job_id": "", "label": "%s — catalogue only (%s, %s)" % [vd.display_name, vd.engine.layout_name() if vd.engine else "?", vd.drivetrain], "playable": false, "current": false})
	return out


## Loads a job: builds its session, vehicle scene, UI and shelf stock.
func start_job(job_id: StringName) -> ActionResult:
	var jdef: JobDefinition = db.jobs.get(job_id, null)
	if jdef == null:
		return ActionResult.fail("Unknown job '%s'." % job_id)
	var vdef: VehicleDefinition = db.vehicles.get(jdef.vehicle_id, null)
	if vdef == null or not vdef.playable or vdef.scene_path == "" or not ResourceLoader.exists(vdef.scene_path):
		return ActionResult.fail("%s is not playable yet." % (vdef.display_name if vdef else String(jdef.vehicle_id)))
	get_tree().paused = false
	_teardown()
	current_job = job_id
	session = GameSession.new(db, vdef.id, job_id)
	vehicle_view = (load(vdef.scene_path) as PackedScene).instantiate() as VehicleView
	add_child(vehicle_view)
	vehicle_view.setup(session)
	interaction.set_session(session)
	ui = UIManager.new()
	ui.name = "UI"
	add_child(ui)
	ui.setup(session, settings, job_list())
	ui.modal_changed.connect(_on_modal_changed)
	ui.save_requested.connect(save_game)
	ui.load_requested.connect(load_game)
	ui.settings_changed.connect(_apply_settings)
	ui.job_selected.connect(func(j: StringName) -> void:
		var r := start_job(j)
		if not r.ok and session:
			session.post_message(r.message, false))
	session.tools.changed.connect(func() -> void:
		player.set_flashlight(session.tools.is_illuminating())
		player.viewmodel.set_tool(session.tools.equipped))
	session.world_changed.connect(_update_world_props)
	session.job.progress_changed.connect(_update_board)
	session.lift_changed.connect(_on_lift_changed)
	garage.set_stock(_stock_items(jdef))
	garage.set_lift_height(0.0)
	player.global_position = GarageBuilder.SPAWN_POINT
	player.set_view(0.0, 0.0)
	player.set_flashlight(false)
	player.viewmodel.set_tool(&"")
	settings["last_job"] = String(job_id)
	_apply_settings(settings)
	_update_board()
	_update_world_props()
	if not session.validation_errors.is_empty():
		session.post_message("Content validation reported %d problem(s) — see the log." % session.validation_errors.size(), false)
	var has_save := FileAccess.file_exists(SaveManager.path_for(vdef.id))
	session.post_message("%s — %s. Read the work order (J).%s" % [jdef.title, vdef.display_name, "  Saved progress exists: F9 to load." if has_save else ""], true)
	return ActionResult.success("Job loaded.", false)


func _stock_items(jdef: JobDefinition) -> Array:
	var items: Array = []
	for k: Variant in jdef.supplied_parts:
		var cd := db.get_component(StringName(str(k)))
		items.append({"id": str(k), "label": cd.display_name if cd else str(k), "kind": "part"})
	for k: Variant in jdef.supplied_fluids:
		items.append({"id": "fluid:%s" % k, "label": str(k).replace("_", " "), "kind": "fluid"})
	return items


func _teardown() -> void:
	if ui:
		remove_child(ui)
		ui.queue_free()
		ui = null
	if vehicle_view:
		remove_child(vehicle_view)
		vehicle_view.queue_free()
		vehicle_view = null
	if session:
		session.dispose()
		session = null


func _on_lift_changed(raised: bool) -> void:
	if _lift_tween and _lift_tween.is_valid():
		_lift_tween.kill()
	var h := LIFT_HEIGHT if raised else 0.0
	_lift_tween = create_tween().set_parallel(true)
	_lift_tween.tween_property(vehicle_view, "position:y", h, LIFT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_lift_tween.tween_method(garage.set_lift_height, garage._lift_carriage.position.y if garage._lift_carriage else 0.0, h, LIFT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _exit_tree() -> void:
	if session:
		session.dispose()


func _process(delta: float) -> void:
	if session == null:
		return
	session.tick(delta)
	# Inspection framing: ease the view in while the inspection panel is open.
	var want_fov := 56.0 if (ui and ui.inspection.visible) else 72.0
	player.camera.fov = lerpf(player.camera.fov, want_fov, clampf(5.0 * delta, 0.0, 1.0))
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
	if ui == null or ui.is_modal_open():
		return
	for i: int in range(1, 8):
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
	var r := SaveManager.save_session(session, SaveManager.path_for(session.vehicle.vehicle_id))
	session.post_message(r.message, r.ok)
	ui.pause_menu.set_status(r.message)


func load_game() -> void:
	var res := SaveManager.load_into(session, SaveManager.path_for(session.vehicle.vehicle_id))
	if not res.get("ok", false):
		session.post_message(str(res.get("error", "Load failed.")), false)
		ui.pause_menu.set_status(str(res.get("error", "Load failed.")))
		return
	apply_player_state(session.player_state)
	vehicle_view.refresh_all()
	var up := session.ctx_world_flag(&"lift_raised")
	vehicle_view.position.y = LIFT_HEIGHT if up else 0.0
	garage.set_lift_height(vehicle_view.position.y)
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
		settings["quality"] = clampi(int(cfg.get_value("graphics", "quality", 2)), 0, 3)
		settings["fullscreen"] = bool(cfg.get_value("graphics", "fullscreen", false))
		settings["last_job"] = str(cfg.get_value("game", "last_job", String(DEFAULT_JOB)))


func _apply_settings(s: Dictionary) -> void:
	settings = s.duplicate()
	if player:
		player.mouse_sensitivity = float(settings["mouse_sensitivity"])
	# Quality presets: 0 Low, 1 Medium, 2 High, 3 Ultra.
	var q := clampi(int(settings["quality"]), 0, 3)
	var vp := get_viewport()
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_4X][q]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q >= 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.scaling_3d_scale = [0.75, 1.0, 1.0, 1.0][q]
	var we := garage.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		we.environment.ssao_enabled = q >= 1
		we.environment.ssil_enabled = q >= 3
		we.environment.ssr_enabled = q >= 2
	RenderingServer.positional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][q])
	for light: Node in garage.find_children("*", "SpotLight3D", true, false):
		(light as SpotLight3D).shadow_enabled = q >= 2 or (q == 1 and light.get_index() % 4 == 0)
	var probe := garage.get_node_or_null("ReflectionProbe") as ReflectionProbe
	if probe:
		probe.visible = q >= 2
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(settings["fullscreen"]) else DisplayServer.WINDOW_MODE_WINDOWED)
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sensitivity", settings["mouse_sensitivity"])
	cfg.set_value("graphics", "quality", settings["quality"])
	cfg.set_value("graphics", "fullscreen", settings["fullscreen"])
	cfg.set_value("game", "last_job", settings.get("last_job", String(DEFAULT_JOB)))
	cfg.save(SETTINGS_PATH)
