# UI-Baukasten: Neon-Theme und kleine Helfer zum Bauen von Menüs im Code.
extends RefCounted

const ACCENT := Color(0.35, 0.85, 1.0)
const DIM := Color(0.55, 0.65, 0.8)
const GOLD := Color(1.0, 0.82, 0.3)
const RED := Color(1.0, 0.35, 0.45)
const GREEN := Color(0.45, 1.0, 0.6)

static var _theme: Theme
static var _fonts := {}

static func font(kind: String) -> Font:
	if not _fonts.has(kind):
		var path: String = {"ui": "res://assets/fonts/UIFont.otf", "title": "res://assets/fonts/TitleFont.otf", "mono": "res://assets/fonts/MonoFont.ttf"}[kind]
		_fonts[kind] = load(path)
	return _fonts[kind]

static func _box(bg: Color, border: Color, bw: int = 2, radius: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(border.r, border.g, border.b, 0.25)
	s.shadow_size = 0
	return s

static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font("ui")
	t.default_font_size = 22
	var normal := _box(Color(0.02, 0.04, 0.08, 0.75), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.45))
	var hover := _box(Color(0.05, 0.15, 0.22, 0.9), Color(ACCENT.r * 1.4, ACCENT.g * 1.4, ACCENT.b * 1.4, 1.0))
	hover.shadow_size = 10
	var pressed := _box(Color(0.1, 0.3, 0.4, 0.95), Color(1.6, 1.6, 1.6, 1.0))
	var disabled := _box(Color(0.02, 0.02, 0.04, 0.6), Color(0.3, 0.3, 0.4, 0.4))
	for cls in ["Button", "OptionButton", "CheckButton"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("focus", cls, hover)
		t.set_stylebox("disabled", cls, disabled)
		t.set_stylebox("hover_pressed", cls, pressed)
		t.set_color("font_color", cls, Color(0.85, 0.95, 1.0))
		t.set_color("font_hover_color", cls, Color(1.4, 1.5, 1.6))
		t.set_color("font_focus_color", cls, Color(1.4, 1.5, 1.6))
		t.set_color("font_pressed_color", cls, Color(1.6, 1.6, 1.6))
		t.set_color("font_disabled_color", cls, Color(0.4, 0.45, 0.55))
	var panel := _box(Color(0.01, 0.02, 0.05, 0.92), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.6), 2, 6)
	panel.content_margin_left = 28
	panel.content_margin_right = 28
	panel.content_margin_top = 22
	panel.content_margin_bottom = 22
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_color("font_color", "Label", Color(0.85, 0.95, 1.0))
	# Schieberegler
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.1, 0.2, 0.3, 0.9)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(ACCENT.r * 1.3, ACCENT.g * 1.3, ACCENT.b * 1.3)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var grab := _circle_tex(9, Color(1.5, 1.6, 1.7))
	t.set_icon("grabber", "HSlider", grab)
	t.set_icon("grabber_highlight", "HSlider", grab)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.2, 0.3, 0.5)
	t.set_stylebox("scroll", "VScrollBar", sb)
	var grab_sb := StyleBoxFlat.new()
	grab_sb.bg_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.6)
	t.set_stylebox("grabber", "VScrollBar", grab_sb)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab_sb)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab_sb)
	var pm := _box(Color(0.02, 0.04, 0.08, 0.98), ACCENT)
	t.set_stylebox("panel", "PopupMenu", pm)
	_theme = t
	return t

static func _circle_tex(r: int, c: Color) -> ImageTexture:
	var img := Image.create(r * 2, r * 2, false, Image.FORMAT_RGBAF)
	for y in r * 2:
		for x in r * 2:
			var d := Vector2(x - r + 0.5, y - r + 0.5).length()
			var a := clampf(r - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	return ImageTexture.create_from_image(img)

static func label(text: String, size: int = 22, color: Color = Color(0.85, 0.95, 1.0), kind: String = "ui") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func title(text: String, size: int = 64, color: Color = ACCENT) -> Label:
	var l := label(text, size, Color(color.r * 1.6, color.g * 1.6, color.b * 1.6), "title")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color(color.r, color.g, color.b, 0.35))
	l.add_theme_constant_override("outline_size", 10)
	return l

static func button(text: String, cb: Callable, min_w: float = 320.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 50)
	b.pressed.connect(func():
		Sfx.play("ui_select", -6.0)
		cb.call())
	b.focus_entered.connect(func(): Sfx.play("ui_move", -12.0))
	b.mouse_entered.connect(func():
		if not b.disabled:
			b.grab_focus())
	return b

static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func panel() -> PanelContainer:
	return PanelContainer.new()

static func spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

# Vollbild-Wurzel für ein Menü, mit abgedunkeltem Hintergrund
static func root(dim: float = 0.0) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.theme = theme()
	if dim > 0.0:
		var r := ColorRect.new()
		r.color = Color(0, 0, 0, dim)
		r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		r.mouse_filter = Control.MOUSE_FILTER_STOP
		c.add_child(r)
	return c

static func center(child: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.add_child(child)
	return cc

static func fmt_time(t: float) -> String:
	var m := int(t / 60.0)
	var s := fmod(t, 60.0)
	if m >= 60:
		return "%dh %dm %.1fs" % [m / 60, m % 60, s]
	return "%dm %04.1fs" % [m, s]

static func fmt_num(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	var n := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		n += 1
		if n % 3 == 0 and i > 0:
			out = ("." if L.lang == "de" else ",") + out
	return ("-" if v < 0 else "") + out
