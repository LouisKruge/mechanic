class_name PauseMenu
extends ModalPanel
## Esc: resume, save, load, settings, controls and quit.

signal save_requested
signal load_requested
signal settings_changed(settings: Dictionary)
signal job_selected(job_id: StringName)

const QUALITY_NAMES: PackedStringArray = ["Low", "Medium", "High"]

var settings: Dictionary = {"mouse_sensitivity": 1.0, "quality": 2, "fullscreen": false}
var _status: Label
var _sens_label: Label
var _sens: HSlider
var _quality: OptionButton
var _fullscreen: CheckBox


## [param jobs]: Array of {"job_id", "label", "playable": bool, "current": bool}.
func setup(initial: Dictionary, jobs: Array = []) -> void:
	settings.merge(initial, true)
	title_label.text = "GARAGE — Paused"
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 32)
	body.add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.add_theme_constant_override("separation", 8)
	cols.add_child(left)
	left.add_child(UITheme.button("Resume", close))
	left.add_child(UITheme.button("Save game  (F5)", func() -> void: save_requested.emit()))
	left.add_child(UITheme.button("Load game  (F9)", func() -> void: load_requested.emit()))
	left.add_child(UITheme.button("Quit to desktop", func() -> void: get_tree().quit()))
	_status = UITheme.label("", UITheme.SIZE_SMALL, UITheme.TEXT_DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(300, 0)
	left.add_child(_status)
	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(320, 0)
	mid.add_theme_constant_override("separation", 8)
	cols.add_child(mid)
	mid.add_child(UITheme.caption("Settings"))
	_sens_label = UITheme.label("", UITheme.SIZE_BODY)
	mid.add_child(_sens_label)
	_sens = HSlider.new()
	_sens.min_value = 0.2
	_sens.max_value = 3.0
	_sens.step = 0.05
	_sens.value = float(settings["mouse_sensitivity"])
	_sens.custom_minimum_size = Vector2(300, 24)
	_sens.value_changed.connect(func(v: float) -> void:
		settings["mouse_sensitivity"] = v
		_update_labels()
		settings_changed.emit(settings))
	mid.add_child(_sens)
	mid.add_child(UITheme.label("Graphics quality", UITheme.SIZE_BODY))
	_quality = OptionButton.new()
	for q: String in QUALITY_NAMES:
		_quality.add_item(q)
	_quality.select(int(settings["quality"]))
	_quality.focus_mode = Control.FOCUS_NONE
	_quality.item_selected.connect(func(i: int) -> void:
		settings["quality"] = i
		settings_changed.emit(settings))
	mid.add_child(_quality)
	_fullscreen = CheckBox.new()
	_fullscreen.text = "Fullscreen"
	_fullscreen.button_pressed = bool(settings["fullscreen"])
	_fullscreen.focus_mode = Control.FOCUS_NONE
	_fullscreen.toggled.connect(func(on: bool) -> void:
		settings["fullscreen"] = on
		settings_changed.emit(settings))
	mid.add_child(_fullscreen)
	var right := VBoxContainer.new()
	cols.add_child(right)
	right.add_child(UITheme.caption("Workshop jobs"))
	for j: Dictionary in jobs:
		var label := ("●  " if j.get("current", false) else "    ") + str(j["label"])
		var b := UITheme.button(label, func() -> void: job_selected.emit(StringName(str(j["job_id"]))))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not bool(j.get("playable", false)) or bool(j.get("current", false))
		right.add_child(b)
	right.add_child(HSeparator.new())
	right.add_child(UITheme.caption("Controls"))
	right.add_child(UITheme.label(
		"WASD  move      Shift  sprint      Ctrl  crouch      Space  jump\n" +
		"E  interact      F  inspect      Tab  inventory      J  work order\n" +
		"LMB  tool action / tighten      RMB  alternate / loosen\n" +
		"1–7  tools      H  hands      [ ]  change socket\n" +
		"Mouse wheel  torque setting / socket      Esc  menu", UITheme.SIZE_SMALL, UITheme.TEXT_DIM))
	_update_labels()


func _update_labels() -> void:
	_sens_label.text = "Mouse sensitivity  %.2f" % float(settings["mouse_sensitivity"])


func _on_open() -> void:
	_status.text = ""


func set_status(text: String) -> void:
	_status.text = text
