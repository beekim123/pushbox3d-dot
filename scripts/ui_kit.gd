class_name AtelierUI
extends RefCounted

const INK = Color("17253b")
const PAPER = Color("fff5dc")
const MUTED = Color("aab8c7")

static func style(color: Color, border: Color, radius: int = 16, width: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	s.shadow_color = Color(0.015, 0.025, 0.05, 0.28)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 4)
	return s

static func theme(accent: Color) -> Theme:
	var t := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK SC", "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", "Noto Sans", "Arial"])
	font.allow_system_fallback = true
	t.default_font = font
	t.default_font_size = 19
	t.set_color("font_color", "Label", PAPER)
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color("677386"))
	t.set_stylebox("normal", "Button", style(Color("24364c"), Color("4c6175"), 12))
	t.set_stylebox("hover", "Button", style(accent, PAPER, 12))
	t.set_stylebox("pressed", "Button", style(accent.darkened(0.12), accent.lightened(0.25), 12))
	t.set_stylebox("disabled", "Button", style(Color("1b293a"), Color("354254"), 12))
	t.set_stylebox("focus", "Button", style(Color(0,0,0,0), accent, 12, 3))
	t.set_stylebox("panel", "PanelContainer", style(Color(0.055,0.085,0.13,0.94), Color("45576a")))
	t.set_constant("separation", "HBoxContainer", 12)
	t.set_constant("separation", "VBoxContainer", 12)
	return t

static func label(text: String, size: int = 20, color: Color = PAPER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func button(text: String, action: Callable, min_size: Vector2 = Vector2(130, 48)) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.pressed.connect(action)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b
