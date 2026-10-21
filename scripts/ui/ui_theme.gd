class_name UITheme
extends RefCounted
## Minimal monochrome theme: black / charcoal panels, thin borders, white text.

const BG := Color(0.035, 0.035, 0.04, 0.92)
const BG_SOLID := Color(0.05, 0.05, 0.055, 0.97)
const CHARCOAL := Color(0.11, 0.11, 0.12, 0.95)
const BORDER := Color(1, 1, 1, 0.16)
const BORDER_STRONG := Color(1, 1, 1, 0.45)
const TEXT := Color(0.93, 0.93, 0.93)
const TEXT_DIM := Color(0.6, 0.6, 0.62)
const TEXT_FAINT := Color(0.4, 0.4, 0.42)
const ACCENT := Color(1, 1, 1)
const SIZE_BODY: int = 16
const SIZE_SMALL: int = 13
const SIZE_TITLE: int = 22
const SIZE_HEADER: int = 30


static func panel_style(bg: Color = BG, border: Color = BORDER, pad: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_content_margin_all(pad)
	s.corner_radius_top_left = 2
	s.corner_radius_top_right = 2
	s.corner_radius_bottom_left = 2
	s.corner_radius_bottom_right = 2
	return s


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = SIZE_BODY
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	t.set_color("font_color", "Label", TEXT)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var b := panel_style(CHARCOAL, BORDER, 8)
		b.content_margin_left = 14
		b.content_margin_right = 14
		match state:
			"hover": b.border_color = BORDER_STRONG
			"pressed": b.bg_color = Color(0.22, 0.22, 0.24)
			"disabled": b.bg_color = Color(0.07, 0.07, 0.075); b.border_color = Color(1, 1, 1, 0.06)
			"focus": b.bg_color = Color(0, 0, 0, 0); b.border_color = BORDER_STRONG
		t.set_stylebox(state, "Button", b)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", TEXT_FAINT)
	t.set_font_size("font_size", "Button", SIZE_BODY)
	var bar_bg := panel_style(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.12), 0)
	var bar_fg := panel_style(Color(0.92, 0.92, 0.92), Color(0, 0, 0, 0), 0)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fg)
	t.set_stylebox("slider", "HSlider", panel_style(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 0))
	t.set_stylebox("grabber_area", "HSlider", panel_style(Color(0.8, 0.8, 0.8), Color(0, 0, 0, 0), 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", panel_style(Color(1, 1, 1), Color(0, 0, 0, 0), 0))
	t.set_stylebox("panel", "TooltipPanel", panel_style(BG_SOLID))
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("panel", "PopupMenu", panel_style(BG_SOLID))
	t.set_stylebox("normal", "OptionButton", panel_style(CHARCOAL, BORDER, 8))
	t.set_stylebox("hover", "OptionButton", panel_style(CHARCOAL, BORDER_STRONG, 8))
	t.set_stylebox("pressed", "OptionButton", panel_style(CHARCOAL, BORDER_STRONG, 8))
	t.set_stylebox("normal", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckBox", StyleBoxEmpty.new())
	var sep := StyleBoxLine.new()
	sep.color = BORDER
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 12)
	return t


static func label(text: String, size: int = SIZE_BODY, color: Color = TEXT, upper: bool = false) -> Label:
	var l := Label.new()
	l.text = text.to_upper() if upper else text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Small caps-style section header.
static func caption(text: String) -> Label:
	var l := label(text, SIZE_SMALL, TEXT_DIM, true)
	return l


static func button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b
