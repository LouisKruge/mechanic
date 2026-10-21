class_name ScannerPanel
extends ModalPanel
## Diagnostic scanner screen.

var session: GameSession
var _out: Label
var _mode: StringName = &""
var _timer: float = 0.0


func setup(p_session: GameSession) -> void:
	session = p_session
	title_label.text = "Diagnostic scanner — Project C01"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	body.add_child(row)
	row.add_child(UITheme.button("Read codes", func() -> void: _show(&"codes")))
	row.add_child(UITheme.button("Live data", func() -> void: _show(&"live")))
	row.add_child(UITheme.button("Charging-system test", func() -> void: _show(&"test")))
	row.add_child(UITheme.button("Clear codes", func() -> void: _show(&"clear")))
	row.add_child(UITheme.button("Disconnect", func() -> void:
		session.diagnostics.disconnect_scanner()
		session.post_message("Scanner disconnected.", true)
		close()))
	var screen := PanelContainer.new()
	screen.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0, 0, 0, 1), UITheme.BORDER, 18))
	screen.custom_minimum_size = Vector2(860, 300)
	body.add_child(screen)
	_out = UITheme.label("", UITheme.SIZE_BODY)
	_out.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_out.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	screen.add_child(_out)
	body.add_child(UITheme.label("The charging-system test needs the engine running: close the scanner (Esc) and use the ignition switch beside the port.", UITheme.SIZE_SMALL, UITheme.TEXT_FAINT))


func _on_open() -> void:
	_mode = &""
	_out.text = "Connected.  Select a function."


func _show(mode: StringName) -> void:
	_mode = mode
	match mode:
		&"codes":
			_out.text = "STORED CODES\n\n" + "\n".join(session.diagnostics.read_codes())
		&"live":
			_out.text = "LIVE DATA\n\n" + "\n".join(session.diagnostics.live_data())
		&"test":
			_out.text = "\n".join(session.diagnostics.charging_test())
			session.job.evaluate()
			session.world_changed.emit()
		&"clear":
			_out.text = session.diagnostics.clear_codes()


func _process(delta: float) -> void:
	if not visible or _mode != &"live":
		return
	_timer += delta
	if _timer > 0.25:
		_timer = 0.0
		_out.text = "LIVE DATA\n\n" + "\n".join(session.diagnostics.live_data())
