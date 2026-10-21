class_name UIManager
extends CanvasLayer
## Owns the HUD and all panels, and the mouse/input mode that goes with them.

signal modal_changed(open: bool)
signal save_requested
signal load_requested
signal settings_changed(settings: Dictionary)
signal job_selected(job_id: StringName)

var session: GameSession
var root: Control
var hud: HUD
var inspection: InspectionPanel
var inventory_panel: InventoryPanel
var work_order: WorkOrderPanel
var scanner: ScannerPanel
var pause_menu: PauseMenu
var completion: CompletionPanel
var _modals: Array[ModalPanel] = []


func setup(p_session: GameSession, settings: Dictionary, jobs: Array = []) -> void:
	session = p_session
	layer = 10
	# The UI keeps working while the tree is paused by the pause menu.
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.name = "UIRoot"
	root.theme = UITheme.build()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# Anchor after entering the tree; doing it before leaves stale offsets.
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud = HUD.new()
	hud.name = "HUD"
	root.add_child(hud)
	hud.setup(session)
	inspection = InspectionPanel.new()
	root.add_child(inspection)
	inspection.setup(session)
	inventory_panel = InventoryPanel.new()
	work_order = WorkOrderPanel.new()
	scanner = ScannerPanel.new()
	pause_menu = PauseMenu.new()
	completion = CompletionPanel.new()
	for m: ModalPanel in [inventory_panel, work_order, scanner, completion, pause_menu]:
		root.add_child(m)
		_modals.append(m)
		m.opened.connect(_update_mode)
		m.closed.connect(_update_mode)
	inventory_panel.setup(session)
	work_order.setup(session)
	scanner.setup(session)
	completion.setup(session)
	pause_menu.setup(settings, jobs)
	pause_menu.job_selected.connect(func(j: StringName) -> void: job_selected.emit(j))
	pause_menu.opened.connect(func() -> void: get_tree().paused = true)
	pause_menu.closed.connect(func() -> void: get_tree().paused = false)
	pause_menu.save_requested.connect(func() -> void: save_requested.emit())
	pause_menu.load_requested.connect(func() -> void: load_requested.emit())
	pause_menu.settings_changed.connect(func(s: Dictionary) -> void: settings_changed.emit(s))
	inventory_panel.inspect_part.connect(func(rec: Dictionary) -> void: inspection.show_part(rec))
	session.panel_requested.connect(open_panel)
	session.inspect_requested.connect(_on_inspect)
	session.world_changed.connect(hud.refresh)
	session.job.progress_changed.connect(hud.refresh)
	session.engine_state_changed.connect(func(_r: bool) -> void: hud.refresh())
	_update_mode()


func _unhandled_input(event: InputEvent) -> void:
	# Handled here (not in Main) so Escape still works while the tree is paused.
	if event.is_action_pressed("pause"):
		handle_escape()
		get_viewport().set_input_as_handled()


func is_modal_open() -> bool:
	for m: ModalPanel in _modals:
		if m.visible:
			return true
	return false


func open_panel(panel: StringName) -> void:
	match panel:
		&"inventory": inventory_panel.open()
		&"work_order": work_order.open()
		&"scanner": scanner.open()
		&"pause": pause_menu.open()


func toggle_panel(p: ModalPanel) -> void:
	if p.visible:
		p.close()
	elif not is_modal_open():
		p.open()


## Escape: close the top-most panel, else open the pause menu.
func handle_escape() -> void:
	for m: ModalPanel in [pause_menu, completion, scanner, work_order, inventory_panel]:
		if m.visible:
			m.close()
			return
	if inspection.visible:
		inspection.hide_panel()
		return
	pause_menu.open()


func _on_inspect(target: Dictionary) -> void:
	if inspection.is_showing(target):
		inspection.hide_panel()
	else:
		inspection.show_target(target)


func _update_mode() -> void:
	var modal := is_modal_open()
	hud.crosshair.visible = not modal
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if modal else Input.MOUSE_MODE_CAPTURED
	modal_changed.emit(modal)
