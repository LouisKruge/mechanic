class_name HUD
extends Control
## In-world overlay: crosshair, target readout, prompts, equipped tool,
## objective, held part and transient messages.

const MESSAGE_SECONDS: float = 5.0
const MAX_MESSAGES: int = 4

var session: GameSession
var crosshair: Crosshair
var _target_box: PanelContainer
var _target_name: Label
var _target_state: Label
var _target_prompts: Label
var _target_bar: ProgressBar
var _target_bar_label: Label
var _objective_title: Label
var _objective_text: Label
var _objective_hint: Label
var _checklist: Label
var _tool_text: Label
var _hotbar: HBoxContainer
var _held_text: Label
var _status_text: Label
var _messages: VBoxContainer
var _target: Dictionary = {}


func setup(p_session: GameSession) -> void:
	session = p_session
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair = Crosshair.new()
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_target_box()
	_build_objective_box()
	_build_tool_box()
	_build_status()
	_messages = VBoxContainer.new()
	add_child(_messages)
	_place(_messages, Vector4(0.5, 1.0, 0.5, 1.0), Vector4(-380, -330, 380, -170))
	_messages.alignment = BoxContainer.ALIGNMENT_END
	_messages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	session.message_posted.connect(show_message)
	session.message_posted.connect(func(_t: String, ok: bool) -> void:
		if not ok:
			crosshair.flash())
	refresh()


## Sets anchors (left, top, right, bottom) and offsets. Must be called after
## the control is in the tree, otherwise Godot recomputes the offsets.
static func _place(c: Control, anchors: Vector4, offsets: Vector4) -> void:
	c.anchor_left = anchors.x
	c.anchor_top = anchors.y
	c.anchor_right = anchors.z
	c.anchor_bottom = anchors.w
	c.offset_left = offsets.x
	c.offset_top = offsets.y
	c.offset_right = offsets.z
	c.offset_bottom = offsets.w


func _build_target_box() -> void:
	_target_box = PanelContainer.new()
	add_child(_target_box)
	_target_box.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.BG, UITheme.BORDER, 12))
	_place(_target_box, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(40, 24, 40, 24))
	_target_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_target_box.add_child(v)
	_target_name = UITheme.label("", 19)
	_target_state = UITheme.label("", UITheme.SIZE_SMALL, UITheme.TEXT_DIM)
	_target_bar_label = UITheme.label("", UITheme.SIZE_SMALL, UITheme.TEXT_DIM)
	_target_bar = ProgressBar.new()
	_target_bar.custom_minimum_size = Vector2(260, 4)
	_target_bar.show_percentage = false
	_target_bar.max_value = 1.25
	_target_prompts = UITheme.label("", UITheme.SIZE_BODY)
	for c: Control in [_target_name, _target_state, _target_bar_label, _target_bar, _target_prompts]:
		v.add_child(c)
	_target_box.visible = false


## A panel pinned to a screen corner, 28 px from the edges.
func _corner_box(anchor_x: float, anchor_y: float) -> PanelContainer:
	var p := PanelContainer.new()
	add_child(p)
	var ox := -28.0 if anchor_x > 0.5 else 28.0
	var oy := -28.0 if anchor_y > 0.5 else 28.0
	_place(p, Vector4(anchor_x, anchor_y, anchor_x, anchor_y), Vector4(ox, oy, ox, oy))
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN if anchor_x > 0.5 else Control.GROW_DIRECTION_END
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN if anchor_y > 0.5 else Control.GROW_DIRECTION_END
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _build_objective_box() -> void:
	var p := _corner_box(0.0, 0.0)
	p.custom_minimum_size = Vector2(420, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	_objective_title = UITheme.caption("")
	_objective_text = UITheme.label("", UITheme.SIZE_BODY)
	_objective_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_text.custom_minimum_size = Vector2(392, 0)
	_objective_hint = UITheme.label("", UITheme.SIZE_SMALL, UITheme.TEXT_DIM)
	_objective_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_hint.custom_minimum_size = Vector2(392, 0)
	_checklist = UITheme.label("", UITheme.SIZE_SMALL, UITheme.TEXT_FAINT)
	v.add_child(_objective_title)
	v.add_child(_objective_text)
	v.add_child(_objective_hint)
	v.add_child(_checklist)
	v.add_child(UITheme.label("J  work order   ·   Tab  inventory   ·   Esc  menu", UITheme.SIZE_SMALL, UITheme.TEXT_FAINT))


func _build_tool_box() -> void:
	var p := _corner_box(0.0, 1.0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(UITheme.caption("Equipped"))
	_tool_text = UITheme.label("", UITheme.SIZE_TITLE)
	v.add_child(_tool_text)
	_hotbar = HBoxContainer.new()
	_hotbar.add_theme_constant_override("separation", 6)
	v.add_child(_hotbar)
	v.add_child(UITheme.label("1–5 tools  ·  H hands  ·  [ ] socket  ·  wheel adjust", UITheme.SIZE_SMALL, UITheme.TEXT_FAINT))
	var hp := _corner_box(1.0, 1.0)
	var hv := VBoxContainer.new()
	hp.add_child(hv)
	hv.add_child(UITheme.caption("Holding"))
	_held_text = UITheme.label("", UITheme.SIZE_BODY)
	hv.add_child(_held_text)


func _build_status() -> void:
	var p := _corner_box(1.0, 0.0)
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(UITheme.caption(session.vehicle.definition.display_name))
	_status_text = UITheme.label("", UITheme.SIZE_SMALL, UITheme.TEXT_DIM)
	v.add_child(_status_text)


func set_target(target: Dictionary) -> void:
	_target = target
	crosshair.active = not target.is_empty()
	_refresh_target()


func _refresh_target() -> void:
	var d := session.resolver.describe(_target) if not _target.is_empty() else {}
	_target_box.visible = not d.is_empty()
	if d.is_empty():
		return
	_target_name.text = str(d.get("name", ""))
	_target_state.text = str(d.get("state", ""))
	_target_state.visible = _target_state.text != ""
	_target_prompts.text = "\n".join(d.get("prompts", PackedStringArray()))
	var prog: Dictionary = d.get("progress", {})
	_target_bar.visible = not prog.is_empty()
	_target_bar_label.visible = not prog.is_empty()
	if not prog.is_empty():
		_target_bar.value = float(prog.get("value", 0.0))
		_target_bar_label.text = str(prog.get("label", ""))


func refresh() -> void:
	if session == null:
		return
	var o := session.job.current_objective()
	var total := session.job.definition.objectives.size()
	_objective_title.text = "%s   ·   %d / %d" % [session.job.definition.title.split(" — ")[0], session.job.completed_count(), total]
	if o:
		_objective_text.text = o.text
		_objective_hint.text = o.hint
	else:
		_objective_text.text = "Work order complete."
		_objective_hint.text = ""
	# Mini checklist: the next pending objectives after the current one.
	var upcoming := PackedStringArray()
	var seen_current := false
	for ob: JobObjectiveDefinition in session.job.definition.objectives:
		if session.job.is_complete(ob.id):
			continue
		if not seen_current:
			seen_current = true
			continue
		upcoming.append("·  " + ob.text)
		if upcoming.size() >= 3:
			break
	_checklist.text = "\n".join(upcoming)
	_checklist.visible = not upcoming.is_empty()
	_tool_text.text = session.tools.hud_text()
	_rebuild_hotbar()
	var held := session.inventory.get_held_part()
	var tray := session.inventory.fastener_tray.size()
	_held_text.text = (session.part_label(held) if not held.is_empty() else "—") + ("\nTray: %d fastener(s)" % tray if tray > 0 else "")
	var e := session.electrical
	_status_text.text = "Engine %s   ·   Charge lamp %s%s" % ["RUNNING" if e.engine_running else "off", "ON" if e.warning_lamp else "off", "\nMaintainer connected" if e.charger_connected else ""]
	_refresh_target()


func _rebuild_hotbar() -> void:
	for c: Node in _hotbar.get_children():
		c.queue_free()
	var slots: Array = []
	for t: ToolDefinition in session.db.tools.values():
		if t.hotbar_slot > 0 and session.inventory.has_tool(t.id):
			slots.append(t)
	slots.sort_custom(func(a: ToolDefinition, b: ToolDefinition) -> bool: return a.hotbar_slot < b.hotbar_slot)
	for t: ToolDefinition in slots:
		var p := PanelContainer.new()
		var on := session.tools.equipped == t.id
		p.add_theme_stylebox_override("panel", UITheme.panel_style(Color(1, 1, 1, 0.14) if on else UITheme.CHARCOAL, UITheme.BORDER_STRONG if on else UITheme.BORDER, 6))
		p.custom_minimum_size = Vector2(52, 44)
		var l := UITheme.label("%d\n%s" % [t.hotbar_slot, t.ui_glyph], UITheme.SIZE_SMALL, UITheme.TEXT if on else UITheme.TEXT_DIM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(l)
		p.tooltip_text = t.display_name
		_hotbar.add_child(p)


## Shows a transient feedback line.
func show_message(text: String, ok: bool) -> void:
	var p := PanelContainer.new()
	var style := UITheme.panel_style(UITheme.BG_SOLID, UITheme.BORDER if ok else UITheme.BORDER_STRONG, 10)
	if not ok:
		style.border_width_left = 3
	p.add_theme_stylebox_override("panel", style)
	var l := UITheme.label(("" if ok else "×  ") + text, UITheme.SIZE_BODY, UITheme.TEXT if ok else Color(0.85, 0.85, 0.85))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(700, 0)
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_messages.add_child(p)
	while _messages.get_child_count() > MAX_MESSAGES:
		var old := _messages.get_child(0)
		_messages.remove_child(old)
		old.queue_free()
	var tw := p.create_tween()
	tw.tween_interval(MESSAGE_SECONDS)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


func _process(_delta: float) -> void:
	# Live values (torque, voltages) change continuously.
	if session and not _target.is_empty():
		_refresh_target()
