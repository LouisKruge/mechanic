class_name InspectionPanel
extends PanelContainer
## Non-modal right-hand panel showing what the player knows about a component,
## fastener or removed part. Updates live while open.

const REFRESH_SECONDS: float = 0.25

var session: GameSession
var _target: Dictionary = {}
var _part: Dictionary = {}
var _title: Label
var _grid: GridContainer
var _blocker_title: Label
var _blockers: Label
var _timer: float = 0.0


func setup(p_session: GameSession) -> void:
	session = p_session
	add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.BG, UITheme.BORDER, 18))
	HUD._place(self, Vector4(1.0, 0.5, 1.0, 0.5), Vector4(-28, 0, -28, 0))
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(520, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	v.add_child(UITheme.caption("Inspection"))
	_title = UITheme.label("", UITheme.SIZE_TITLE)
	v.add_child(_title)
	v.add_child(HSeparator.new())
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 6)
	v.add_child(_grid)
	_blocker_title = UITheme.caption("")
	v.add_child(_blocker_title)
	_blockers = UITheme.label("", UITheme.SIZE_SMALL, UITheme.TEXT)
	_blockers.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blockers.custom_minimum_size = Vector2(480, 0)
	v.add_child(_blockers)
	v.add_child(UITheme.label("F on empty space to close", UITheme.SIZE_SMALL, UITheme.TEXT_FAINT))
	visible = false


func show_target(target: Dictionary) -> void:
	_target = target
	_part = {}
	visible = true
	refresh()


func show_part(rec: Dictionary) -> void:
	_part = rec
	_target = {}
	visible = true
	refresh()


func hide_panel() -> void:
	visible = false
	_target = {}
	_part = {}


func is_showing(target: Dictionary) -> bool:
	return visible and _target == target


func refresh() -> void:
	var d: Dictionary
	if not _part.is_empty():
		d = session.resolver.part_inspection(_part)
	elif not _target.is_empty():
		d = session.resolver.inspection_data(_target)
	else:
		return
	if str(d.get("title", "")) == "":
		hide_panel()
		return
	_title.text = str(d["title"])
	ModalPanel.clear(_grid)
	for row: Array in d.get("rows", []):
		var k := UITheme.label(str(row[0]), UITheme.SIZE_SMALL, UITheme.TEXT_DIM)
		var val := UITheme.label(str(row[1]), UITheme.SIZE_BODY)
		val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		val.custom_minimum_size = Vector2(320, 0)
		_grid.add_child(k)
		_grid.add_child(val)
	var blockers: PackedStringArray = d.get("blockers", PackedStringArray())
	_blocker_title.visible = not blockers.is_empty()
	_blockers.visible = not blockers.is_empty()
	_blocker_title.text = str(d.get("blocker_title", "Blocked by"))
	var lines := PackedStringArray()
	for b: String in blockers:
		lines.append("—  " + b)
	_blockers.text = "\n".join(lines)


func _process(delta: float) -> void:
	if not visible:
		return
	_timer += delta
	if _timer >= REFRESH_SECONDS:
		_timer = 0.0
		refresh()
