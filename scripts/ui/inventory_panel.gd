class_name InventoryPanel
extends ModalPanel
## Tab: tools (equip), sockets, carried parts (hold / inspect) and fastener tray.

signal inspect_part(rec: Dictionary)

var session: GameSession
var _tools_box: VBoxContainer
var _sockets_box: HFlowContainer
var _parts_box: VBoxContainer
var _tray_label: Label
var _storage_label: Label


func setup(p_session: GameSession) -> void:
	session = p_session
	title_label.text = "Inventory"
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	body.add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(430, 0)
	cols.add_child(left)
	left.add_child(UITheme.caption("Tools"))
	_tools_box = VBoxContainer.new()
	left.add_child(_tools_box)
	left.add_child(UITheme.caption("Socket fitted to drive tools"))
	_sockets_box = HFlowContainer.new()
	left.add_child(_sockets_box)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(470, 0)
	cols.add_child(right)
	right.add_child(UITheme.caption("Parts"))
	_parts_box = VBoxContainer.new()
	right.add_child(_parts_box)
	right.add_child(UITheme.caption("Fastener tray"))
	_tray_label = UITheme.label("", UITheme.SIZE_SMALL, UITheme.TEXT_DIM)
	right.add_child(_tray_label)
	right.add_child(UITheme.caption("Workshop storage"))
	_storage_label = UITheme.label("", UITheme.SIZE_SMALL, UITheme.TEXT_DIM)
	right.add_child(_storage_label)
	session.world_changed.connect(func() -> void:
		if visible:
			_rebuild())


func _on_open() -> void:
	_rebuild()


func _rebuild() -> void:
	ModalPanel.clear(_tools_box)
	var list: Array = session.db.tools.values()
	list.sort_custom(func(a: ToolDefinition, b: ToolDefinition) -> bool: return a.hotbar_slot < b.hotbar_slot)
	for t: ToolDefinition in list:
		if not session.inventory.has_tool(t.id):
			continue
		var row := HBoxContainer.new()
		var on := session.tools.equipped == t.id
		var b := UITheme.button(("●  " if on else "    ") + "%d  %s" % [t.hotbar_slot, t.display_name], func() -> void:
			session.equip_tool(t.id)
			_rebuild())
		b.custom_minimum_size = Vector2(420, 0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = t.description
		row.add_child(b)
		_tools_box.add_child(row)
	_tools_box.add_child(UITheme.button("    H  Hands (holster tool)", func() -> void:
		session.equip_tool(&"")
		_rebuild()))
	ModalPanel.clear(_sockets_box)
	for s: int in session.tools.available_sockets():
		var sb := UITheme.button(("[%d mm]" if session.tools.socket_mm == s else "%d mm") % s, func() -> void:
			session.tools.socket_mm = s
			session.tools.changed.emit()
			_rebuild())
		_sockets_box.add_child(sb)
	ModalPanel.clear(_parts_box)
	if session.inventory.parts.is_empty():
		_parts_box.add_child(UITheme.label("No parts carried.", UITheme.SIZE_SMALL, UITheme.TEXT_FAINT))
	for rec: Dictionary in session.inventory.parts:
		var row := HBoxContainer.new()
		var held := session.inventory.held_part_uid == str(rec.get("uid", ""))
		var l := UITheme.label(("●  " if held else "") + session.part_label(rec), UITheme.SIZE_BODY)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var uid := str(rec.get("uid", ""))
		row.add_child(UITheme.button("Put away" if held else "Hold", func() -> void:
			session.hold_part("" if held else uid)
			_rebuild()))
		row.add_child(UITheme.button("Inspect", func() -> void: inspect_part.emit(rec)))
		_parts_box.add_child(row)
	var tray := PackedStringArray()
	for fid: String in session.inventory.fastener_tray:
		var f := session.vehicle.get_fastener(StringName(fid))
		tray.append(f.display_name() if f else fid)
	_tray_label.text = ", ".join(tray) if not tray.is_empty() else "Empty"
	var stored := PackedStringArray()
	for rec: Dictionary in session.inventory.core_bin:
		stored.append(session.part_label(rec) + " (core bin)")
	_storage_label.text = ", ".join(stored) if not stored.is_empty() else "—"
