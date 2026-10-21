class_name ModalPanel
extends Control
## Base for centred, mouse-driven panels (inventory, work order, scanner, menu).
## While any modal panel is open the player cannot move or use tools.

signal opened
signal closed

var frame: PanelContainer
var body: VBoxContainer
var title_label: Label
var _dim: ColorRect
var _center: CenterContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_center = CenterContainer.new()
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	var center := _center
	frame = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.BG_SOLID, UITheme.BORDER, 26))
	center.add_child(frame)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	frame.add_child(body)
	var head := HBoxContainer.new()
	body.add_child(head)
	title_label = UITheme.label("", UITheme.SIZE_TITLE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	head.add_child(UITheme.button("Close  (Esc)", close))
	body.add_child(HSeparator.new())


func _enter_tree() -> void:
	# Full-screen anchoring is only reliable once the parent rect is known.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func open() -> void:
	if visible:
		return
	visible = true
	_on_open()
	opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## Override to rebuild content when shown.
func _on_open() -> void:
	pass


static func clear(container: Node) -> void:
	for c: Node in container.get_children():
		container.remove_child(c)
		c.queue_free()
