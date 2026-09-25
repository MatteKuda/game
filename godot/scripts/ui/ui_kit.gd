class_name UIKit
## Theme + small widget factory so every panel shares the same look.

static var _icons := {}

static func sb(bg: Color, radius := 14, border := Color(0, 0, 0, 0), bw := 0, shadow := 0, pad := Vector4(12, 10, 12, 10)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	if shadow > 0:
		s.shadow_color = Color(0.12, 0.16, 0.27, 0.18)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * 0.35)
	s.content_margin_left = pad.x; s.content_margin_top = pad.y; s.content_margin_right = pad.z; s.content_margin_bottom = pad.w
	s.anti_aliasing = true
	return s

static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = Art.body_font(500)
	t.default_font_size = 14
	t.set_color("font_color", "Label", Cfg.INK)
	t.set_color("font_color", "Button", Cfg.INK)
	t.set_color("font_hover_color", "Button", Cfg.INK)
	t.set_color("font_pressed_color", "Button", Cfg.INK)
	t.set_color("font_focus_color", "Button", Cfg.INK)
	t.set_color("font_disabled_color", "Button", Cfg.INK3)
	t.set_font("font", "Button", Art.body_font(650))
	t.set_stylebox("normal", "Button", sb(Color.WHITE, 11, Color(0.12, 0.16, 0.27, 0.12), 1, 0, Vector4(12, 7, 12, 7)))
	t.set_stylebox("hover", "Button", sb(Color("fff7ec"), 11, Cfg.TERRA, 1, 3, Vector4(12, 7, 12, 7)))
	t.set_stylebox("pressed", "Button", sb(Color("f6efe3"), 11, Cfg.TERRA, 1, 0, Vector4(12, 7, 12, 7)))
	t.set_stylebox("disabled", "Button", sb(Color(1, 1, 1, 0.5), 11, Color(0.12, 0.16, 0.27, 0.08), 1, 0, Vector4(12, 7, 12, 7)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", sb(Color(1.0, 0.98, 0.95, 0.95), 16, Color(1, 1, 1, 0.7), 1, 10, Vector4(14, 12, 14, 12)))
	t.set_stylebox("panel", "TooltipPanel", sb(Color(0.12, 0.16, 0.27, 0.95), 10, Color(0, 0, 0, 0), 0, 6, Vector4(10, 7, 10, 7)))
	t.set_color("font_color", "TooltipLabel", Color.WHITE)
	var sc := sb(Color(0.12, 0.16, 0.27, 0.15), 6, Color(0, 0, 0, 0), 0, 0, Vector4(0, 0, 0, 0))
	t.set_stylebox("scroll", "VScrollBar", sb(Color(0, 0, 0, 0), 6, Color(0, 0, 0, 0), 0, 0, Vector4(3, 0, 3, 0)))
	t.set_stylebox("grabber", "VScrollBar", sc)
	t.set_stylebox("grabber_highlight", "VScrollBar", sb(Color(0.12, 0.16, 0.27, 0.3), 6))
	t.set_stylebox("grabber_pressed", "VScrollBar", sb(Color(0.12, 0.16, 0.27, 0.4), 6))
	t.set_stylebox("panel", "PopupPanel", sb(Color(1.0, 0.98, 0.95), 14, Color(0, 0, 0, 0.1), 1, 10))
	return t

static func icon_tex(name: String) -> Texture2D:
	if not _icons.has(name):
		var p := "res://assets/icons/ui/%s.svg" % name
		_icons[name] = load(p) if ResourceLoader.exists(p) else load("res://assets/icons/ui/info.svg")
	return _icons[name]

static func icon(name: String, size := 18, col := Cfg.INK2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon_tex(name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.modulate = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func label(text: String, size := 14, col := Cfg.INK, kind := "body", weight := 500) -> Label:
	var l := Label.new()
	l.text = Loc.t(text)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_override("font", Art.font("display") if kind == "display" else (Art.font("display700") if kind == "display700" else Art.body_font(weight)))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func wrap(l: Label, width := 0.0) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if width > 0: l.custom_minimum_size.x = width
	return l

static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", sep); return h
static func vbox(sep := 6) -> VBoxContainer:
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", sep); return v

static func card(bg := Color(1.0, 0.98, 0.95, 0.95), radius := 16, pad := Vector4(14, 12, 14, 12), shadow := 10) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(bg, radius, Color(1, 1, 1, 0.7) if bg.a > 0.5 and bg.v > 0.8 else Color(0, 0, 0, 0), 1, shadow, pad))
	return p

static func button(text: String, ic := "", primary := false, small := false) -> Button:
	var b := Button.new()
	b.text = Loc.t(text)
	b.focus_mode = Control.FOCUS_NONE
	if ic != "": b.icon = icon_tex(ic); b.expand_icon = false; b.add_theme_constant_override("icon_max_width", 16 if small else 18)
	b.add_theme_font_size_override("font_size", 12 if small else 14)
	var pad := Vector4(9, 5, 9, 5) if small else Vector4(14, 8, 14, 8)
	if primary:
		b.add_theme_stylebox_override("normal", sb(Cfg.TERRA, 11, Color(0, 0, 0, 0), 0, 0, pad))
		b.add_theme_stylebox_override("hover", sb(Color("e9744b"), 11, Color(0, 0, 0, 0), 0, 4, pad))
		b.add_theme_stylebox_override("pressed", sb(Cfg.TERRA_DARK, 11, Color(0, 0, 0, 0), 0, 0, pad))
		b.add_theme_stylebox_override("disabled", sb(Color(0.88, 0.4, 0.24, 0.45), 11, Color(0, 0, 0, 0), 0, 0, pad))
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]: b.add_theme_color_override(k, Color.WHITE)
		b.add_theme_color_override("icon_normal_color", Color.WHITE)
		b.add_theme_color_override("icon_hover_color", Color.WHITE)
	else:
		for st in ["normal", "hover", "pressed", "disabled"]:
			var base: StyleBoxFlat = UIKit.theme_cache().get_stylebox(st, "Button").duplicate()
			base.content_margin_left = pad.x; base.content_margin_right = pad.z; base.content_margin_top = pad.y; base.content_margin_bottom = pad.w
			b.add_theme_stylebox_override(st, base)
		b.add_theme_color_override("icon_normal_color", Cfg.INK2)
		b.add_theme_color_override("icon_hover_color", Cfg.TERRA)
	return b

static var _theme: Theme
static func theme_cache() -> Theme:
	if _theme == null: _theme = theme()
	return _theme

static func bar(value: float, col: Color, w := 0.0, h := 7.0) -> Control:
	var bg := Panel.new()
	bg.custom_minimum_size = Vector2(w, h)
	bg.add_theme_stylebox_override("panel", sb(Color(0.12, 0.16, 0.27, 0.09), int(h * 0.5), Color(0, 0, 0, 0), 0, 0, Vector4.ZERO))
	var fill := Panel.new()
	fill.add_theme_stylebox_override("panel", sb(col, int(h * 0.5), Color(0, 0, 0, 0), 0, 0, Vector4.ZERO))
	fill.anchor_bottom = 1.0
	fill.anchor_right = clampf(value, 0.0, 1.0)
	bg.add_child(fill)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bg

static func chip(text: String, bg: Color, fg := Color.WHITE, size := 11) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(bg, 7, Color(0, 0, 0, 0), 0, 0, Vector4(7, 2, 7, 2)))
	p.add_child(label(text, size, fg, "body", 700))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func sep_h() -> HSeparator:
	var s := HSeparator.new()
	var st := StyleBoxLine.new(); st.color = Color(0.12, 0.16, 0.27, 0.1); st.thickness = 1
	s.add_theme_stylebox_override("separator", st)
	return s

static func section(text: String) -> Label:
	var l := label(Loc.t(text).to_upper(), 11, Cfg.INK3, "body", 750)
	l.add_theme_constant_override("line_spacing", 0)
	return l

static func stars(v: float, size := 16) -> HBoxContainer:
	var h := hbox(1)
	for i in 5:
		var f := clampf(v - i, 0.0, 1.0)
		var s := icon("star", size, Cfg.MUSTARD if f > 0.5 else Color(0.12, 0.16, 0.27, 0.18))
		h.add_child(s)
	return h

static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
