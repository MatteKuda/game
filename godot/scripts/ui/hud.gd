class_name Hud
extends CanvasLayer
## Heads-up display: top bar, dock, panels, inspector, alerts, placement hint, day report.

const ICON_COLOR := {
	"empty": Color("e5484d"), "low": Color("f2a93b"), "noproduct": Color("7b8698"), "price": Color("e0663c"), "cheap": Color("2fae7a"),
	"wait": Color("f2a93b"), "happy": Color("2fae7a"), "angry": Color("d6333a"), "notfound": Color("7a5ae0"), "dirty": Color("8a6a3c"),
	"crowd": Color("d9822b"), "wallet": Color("b0546a"), "queue": Color("e0663c"), "nocashier": Color("d6333a"), "star": Color("f2b33d"), "box": Color("2f5d8a"),
}
const ICON_GLYPH := {
	"empty": "box", "low": "box", "noproduct": "plus", "price": "tag", "cheap": "tag", "wait": "clock", "happy": "heart", "angry": "alert",
	"notfound": "info", "dirty": "broom", "crowd": "people", "wallet": "coin", "queue": "people", "nocashier": "staff", "star": "star", "box": "box",
}
const STATUS_TEXT := {"empty": "Raf boş", "low": "Stok azaldı, depoda yok", "noproduct": "Boş bölme var", "nocashier": "Kasiyer yok", "queue": "Kuyruk uzadı", "box": "Depo boşalıyor"}

var game: Game
var thumbs: Thumbs
var root: Control
var top_left: VBoxContainer
var goal_card: PanelContainer
var time_lbl: Label
var day_lbl: Label
var sun_icon: TextureRect
var day_prog: Control
var speed_btns: Array[Button] = []
var money_lbl: Label
var money_delta: Label
var rating_box: HBoxContainer
var rating_lbl: Label
var inside_lbl: Label
var alerts_box: VBoxContainer
var dock: HBoxContainer
var dock_btns := {}
var panel: PanelContainer
var panel_id := ""
var panel_sig := ""
var inspector: PanelContainer
var insp_sig := ""
var slot_picker := -1
var place_hint: PanelContainer
var tooltip: PanelContainer
var tooltip_lbl: RichTextLabel
var modal: Control
var welcome: Control
var started := false
var _acc := 0.0
var _press_pos := Vector2.ZERO
var _pressing := false
var build_tab := "Teşhir"

func setup(g: Game, t: Thumbs) -> void:
	game = g; thumbs = t
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.theme_cache()
	add_child(root)
	_build_top()
	_build_dock()
	alerts_box = UIKit.vbox(8)
	alerts_box.anchor_top = 1.0; alerts_box.anchor_bottom = 1.0
	alerts_box.offset_left = 18; alerts_box.offset_top = -112; alerts_box.offset_bottom = -112
	alerts_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	alerts_box.custom_minimum_size = Vector2(340, 0)
	alerts_box.alignment = BoxContainer.ALIGNMENT_END
	alerts_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(alerts_box)
	panel = PanelContainer.new(); panel.visible = false; root.add_child(panel)
	inspector = PanelContainer.new(); inspector.visible = false; root.add_child(inspector)
	inspector.anchor_left = 1.0; inspector.anchor_right = 1.0
	inspector.offset_left = -368; inspector.offset_right = -18; inspector.offset_top = 96
	inspector.custom_minimum_size = Vector2(350, 0)
	inspector.add_theme_stylebox_override("panel", UIKit.sb(Color(1.0, 0.975, 0.94, 0.97), 18, Color("2d3348"), 0, 14, Vector4(0, 0, 0, 0)))
	place_hint = UIKit.card(Color(0.12, 0.16, 0.27, 0.95), 16, Vector4(14, 10, 14, 10), 14)
	place_hint.visible = false; root.add_child(place_hint)
	tooltip = UIKit.card(Color(0.12, 0.16, 0.27, 0.95), 12, Vector4(11, 8, 11, 8), 8)
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_lbl = RichTextLabel.new(); tooltip_lbl.bbcode_enabled = true; tooltip_lbl.fit_content = true; tooltip_lbl.scroll_active = false
	tooltip_lbl.custom_minimum_size = Vector2(230, 0); tooltip_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_lbl.add_theme_font_override("normal_font", Art.body_font(700)); tooltip_lbl.add_theme_font_override("bold_font", Art.font("display"))
	tooltip_lbl.add_theme_font_size_override("normal_font_size", 13); tooltip_lbl.add_theme_font_size_override("bold_font_size", 17)
	tooltip.add_child(tooltip_lbl); tooltip.visible = false; root.add_child(tooltip)
	modal = Control.new(); modal.set_anchors_preset(Control.PRESET_FULL_RECT); modal.visible = false; root.add_child(modal)
	game.alert_added.connect(func(_a): _render_alerts())
	game.selection_changed.connect(func(): slot_picker = -1; insp_sig = ""; _render_inspector())
	game.day_ended.connect(_show_day_end)
	game.changed.connect(func(): panel_sig = "")
	game.placing_changed.connect(_render_place_hint)
	game.stage_changed.connect(func(): panel_sig = ""; _render_dock_state())
	_show_welcome()

# ================================================================== top bar
func _pill(bg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.sb(bg, 18, Color(0.18, 0.2, 0.3, 0.9), 0, 10, Vector4(12, 8, 16, 8)))
	return p

func _build_top() -> void:
	top_left = UIKit.vbox(10)
	top_left.position = Vector2(18, 16)
	top_left.custom_minimum_size = Vector2(290, 0)
	root.add_child(top_left)
	var brand := _pill(Color("fffaf2"))
	var bh := UIKit.hbox(12)
	var mark := PanelContainer.new()
	mark.add_theme_stylebox_override("panel", UIKit.sb(Cfg.TERRA, 13, Color(0, 0, 0, 0), 0, 0, Vector4(8, 8, 8, 8)))
	mark.add_child(UIKit.icon("store", 26, Color.WHITE))
	bh.add_child(mark)
	var bv := UIKit.vbox(-4)
	bv.add_child(UIKit.label("KÖŞEBAŞI", 26, Cfg.INK, "display"))
	var sub := UIKit.label("Mahalle Büfesi · Aşama 1", 13, Cfg.INK2, "body", 700); sub.name = "StageLbl"
	bv.add_child(sub)
	bh.add_child(bv)
	brand.add_child(bh)
	top_left.add_child(brand)
	goal_card = PanelContainer.new()
	goal_card.add_theme_stylebox_override("panel", UIKit.sb(Color(1.0, 0.98, 0.95, 0.96), 16, Color(0, 0, 0, 0), 0, 10, Vector4(14, 12, 14, 12)))
	goal_card.mouse_filter = Control.MOUSE_FILTER_STOP
	goal_card.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: toggle_panel("growth"))
	top_left.add_child(goal_card)
	# time
	var tp := _pill(Color("fffaf2"))
	tp.anchor_left = 0.5; tp.anchor_right = 0.5
	tp.offset_left = -190; tp.offset_right = 190; tp.offset_top = 16
	tp.custom_minimum_size = Vector2(380, 0)
	var th := UIKit.hbox(10)
	th.alignment = BoxContainer.ALIGNMENT_CENTER
	sun_icon = UIKit.icon("sun", 22, Cfg.MUSTARD)
	th.add_child(sun_icon)
	var tv := UIKit.vbox(0)
	var trow := UIKit.hbox(8)
	day_lbl = UIKit.label("Gün 1", 15, Cfg.INK2, "body", 800); trow.add_child(day_lbl)
	time_lbl = UIKit.label("07:00", 26, Cfg.INK, "display"); trow.add_child(time_lbl)
	tv.add_child(trow)
	day_prog = UIKit.bar(0.0, Cfg.MUSTARD, 120, 5)
	tv.add_child(day_prog)
	th.add_child(tv)
	var sp := UIKit.hbox(4)
	for v in [[0.0, "pause", "Duraklat (Boşluk)"], [1.0, "play", "Normal (1)"], [2.0, "fast", "Hızlı (2)"], [4.0, "fast", "Çok hızlı (3)"]]:
		var b := Button.new()
		b.icon = UIKit.icon_tex(v[1]); b.tooltip_text = v[2]; b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(38, 34)
		b.add_theme_constant_override("icon_max_width", 16)
		if v[0] == 4.0: b.text = "4"; b.add_theme_font_size_override("font_size", 10)
		var val: float = v[0]
		b.pressed.connect(func(): set_speed(val))
		sp.add_child(b); speed_btns.append(b)
	th.add_child(sp)
	tp.add_child(th)
	root.add_child(tp)
	# stats
	var tr := UIKit.hbox(10)
	tr.anchor_left = 1.0; tr.anchor_right = 1.0
	tr.offset_left = -560; tr.offset_right = -18; tr.offset_top = 16
	tr.custom_minimum_size = Vector2(540, 0)
	tr.alignment = BoxContainer.ALIGNMENT_END
	var mp := _pill(Color("2fae7a"))
	var mh := UIKit.hbox(8)
	mh.add_child(UIKit.icon("coin", 24, Color.WHITE))
	var mv := UIKit.vbox(-4)
	money_lbl = UIKit.label("₺0", 26, Color.WHITE, "display"); mv.add_child(money_lbl)
	money_delta = UIKit.label("bugün ₺0", 12, Color(1, 1, 1, 0.85), "body", 800); mv.add_child(money_delta)
	mh.add_child(mv); mp.add_child(mh); tr.add_child(mp)
	var rp := _pill(Color("fffaf2"))
	var rv := UIKit.vbox(0)
	var rh := UIKit.hbox(6)
	rating_box = UIKit.stars(3.0, 18); rh.add_child(rating_box)
	rating_lbl = UIKit.label("3.0", 22, Cfg.INK, "display"); rh.add_child(rating_lbl)
	rv.add_child(rh); rv.add_child(UIKit.label("Mağaza puanı", 12, Cfg.INK2, "body", 800))
	rp.add_child(rv); tr.add_child(rp)
	var ip := _pill(Color("fffaf2"))
	var ih := UIKit.hbox(8)
	ih.add_child(UIKit.icon("people", 22, Cfg.TEAL))
	var iv := UIKit.vbox(-4)
	inside_lbl = UIKit.label("0", 22, Cfg.INK, "display"); iv.add_child(inside_lbl)
	iv.add_child(UIKit.label("içeride", 12, Cfg.INK2, "body", 800))
	ih.add_child(iv); ip.add_child(ih); tr.add_child(ip)
	root.add_child(tr)

# ================================================================== dock
func _build_dock() -> void:
	var d := PanelContainer.new()
	d.add_theme_stylebox_override("panel", UIKit.sb(Color(0.12, 0.16, 0.27, 0.96), 22, Color(0, 0, 0, 0), 0, 16, Vector4(8, 8, 8, 8)))
	d.anchor_left = 0.5; d.anchor_right = 0.5; d.anchor_top = 1.0; d.anchor_bottom = 1.0
	d.grow_horizontal = Control.GROW_DIRECTION_BOTH
	d.grow_vertical = Control.GROW_DIRECTION_BEGIN
	d.offset_top = -16; d.offset_bottom = -16
	dock = UIKit.hbox(4)
	d.add_child(dock)
	var items := [["build", "build", "İnşa", "B"], ["products", "tag", "Ürün & Fiyat", "P"], ["supply", "truck", "Tedarik", "T"],
		["staff", "staff", "Personel", "H"], ["finance", "chart", "Finans", "F"], ["growth", "arrowUp", "Gelişim", "U"], ["|", "", "", ""], ["heat", "route", "Akış", "M"]]
	for it in items:
		if it[0] == "|":
			var s := VSeparator.new(); s.add_theme_constant_override("separation", 10); dock.add_child(s); continue
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(84, 62)
		b.tooltip_text = "%s (%s)" % [it[2], it[3]]
		var v := UIKit.vbox(2); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		var ic := UIKit.icon(it[1], 24, Color(1, 1, 1, 0.85)); ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var l := UIKit.label(it[2], 12, Color(1, 1, 1, 0.85), "body", 800); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		b.add_child(v)
		b.set_meta("icon", ic); b.set_meta("lbl", l)
		var id: String = it[0]
		b.pressed.connect(func(): _dock_pressed(id))
		dock.add_child(b)
		dock_btns[id] = b
	root.add_child(d)
	_render_dock_state()

func _dock_pressed(id: String) -> void:
	if not started: return
	if id == "heat":
		game.heat_on = not game.heat_on; game.overlays.heat.visible = game.heat_on
		if game.heat_on: game.overlays.update_heat(game.grid)
		_render_dock_state(); return
	toggle_panel(id)

func _render_dock_state() -> void:
	for id in dock_btns:
		var b: Button = dock_btns[id]
		var on: bool = panel_id == id or (id == "heat" and game != null and game.heat_on)
		var col := Cfg.TERRA if on else Color(1, 1, 1, 0.0)
		b.add_theme_stylebox_override("normal", UIKit.sb(col, 16, Color(0, 0, 0, 0), 0, 0, Vector4(4, 4, 4, 4)))
		b.add_theme_stylebox_override("hover", UIKit.sb(Cfg.TERRA if on else Color(1, 1, 1, 0.1), 16, Color(0, 0, 0, 0), 0, 0, Vector4(4, 4, 4, 4)))
		b.add_theme_stylebox_override("pressed", UIKit.sb(Cfg.TERRA_DARK, 16, Color(0, 0, 0, 0), 0, 0, Vector4(4, 4, 4, 4)))
		(b.get_meta("icon") as TextureRect).modulate = Color.WHITE if on else Color(1, 1, 1, 0.8)
		(b.get_meta("lbl") as Label).add_theme_color_override("font_color", Color.WHITE if on else Color(1, 1, 1, 0.78))

# ================================================================== per-frame
func _process(dt: float) -> void:
	if game == null: return
	_acc += dt
	_update_tooltip_pos()
	if _acc < 0.12: return
	_acc = 0.0
	time_lbl.text = Cfg.clock_str(game.clock)
	day_lbl.text = "Gün %d" % game.day
	sun_icon.texture = UIKit.icon_tex("moon" if game.sky.night > 0.5 else "sun")
	var prog := clampf((game.clock - Cfg.DAY_OPEN) / float(Cfg.DAY_CLOSE - Cfg.DAY_OPEN), 0, 1)
	(day_prog.get_child(0) as Control).anchor_right = prog
	money_lbl.text = Cfg.fmt_money(game.money)
	var profit: int = game.stats["revenue"] - game.stats["purchases"] - game.stats["other"]
	money_delta.text = "bugün %s%s" % ["+" if profit >= 0 else "", Cfg.fmt_money(profit)]
	rating_lbl.text = "%.1f" % game.rating
	var r := game.rating
	for i in 5: (rating_box.get_child(i) as TextureRect).modulate = Cfg.MUSTARD if r - i > 0.5 else Color(0.12, 0.16, 0.27, 0.18)
	var qn := 0
	for f in game.fixtures: qn += f.queue.size()
	inside_lbl.text = "%d%s" % [game.customers_inside(), ("  · kuyruk %d" % qn) if qn > 0 else ""]
	for i in speed_btns.size():
		var on: bool = (game.paused and i == 0) or (not game.paused and [0.0, 1.0, 2.0, 4.0][i] == game.speed)
		speed_btns[i].add_theme_stylebox_override("normal", UIKit.sb(Cfg.INK if on else Color(1, 1, 1, 0), 10, Color(0, 0, 0, 0), 0, 0, Vector4(6, 4, 6, 4)))
		speed_btns[i].add_theme_color_override("icon_normal_color", Color.WHITE if on else Cfg.INK2)
		speed_btns[i].add_theme_color_override("font_color", Color.WHITE if on else Cfg.INK2)
	(top_left.get_child(0).find_child("StageLbl", true, false) as Label).text = "%s · Aşama %d" % [DB.STAGES[game.stage]["name"], game.stage + 1]
	_render_goal()
	if panel_id != "":
		var sig := _sig_panel()
		if sig != panel_sig: panel_sig = sig; _render_panel()
	if not game.selection.is_empty():
		var s2 := _sig_insp()
		if s2 != insp_sig: insp_sig = s2; _render_inspector()

func set_speed(v: float) -> void:
	if not started: return
	if v == 0.0: game.paused = true
	else: game.paused = false; game.speed = v

# ================================================================== goal card
var _goal_sig := ""
func _render_goal() -> void:
	var e = game.expansion()
	var gs := game.goals()
	var sig := str(gs) + str(game.can_expand())
	if sig == _goal_sig: return
	_goal_sig = sig
	UIKit.clear(goal_card)
	var v := UIKit.vbox(6)
	if e == null:
		v.add_child(UIKit.label("Mahalle Marketi açık!", 16, Cfg.INK, "display"))
		v.add_child(UIKit.wrap(UIKit.label("Rafları dolu, kuyruğu kısa, puanı yüksek tut. Sıradaki büyük adım: Süpermarket.", 12, Cfg.INK2, "body", 700), 260))
		goal_card.add_child(v); return
	var h := UIKit.hbox(8)
	h.add_child(UIKit.icon("arrowUp", 18, Cfg.TERRA))
	h.add_child(UIKit.label("Genişlemeye hazır!" if game.can_expand() else "Hedef: " + e["title"], 16, Cfg.INK, "display"))
	v.add_child(h)
	for g in gs:
		var row := UIKit.hbox(6)
		var l := UIKit.label(g["label"], 12, Cfg.INK2, "body", 700); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var val := ""
		if g["id"] == "rating": val = "%.1f / %.1f★" % [g["value"], g["target"]]
		elif g["id"] == "cash": val = "%s / %s" % [Cfg.fmt_money(g["value"]), Cfg.fmt_money(g["target"])]
		else: val = "%d / %d" % [g["value"], g["target"]]
		row.add_child(UIKit.label(val, 12, Cfg.GOOD if g["done"] else Cfg.INK, "body", 800))
		v.add_child(row)
		v.add_child(UIKit.bar(float(g["value"]) / float(g["target"]), Cfg.GOOD if g["done"] else Cfg.MUSTARD, 0, 6))
	goal_card.add_child(v)
	var st: StyleBoxFlat = goal_card.get_theme_stylebox("panel")
	st.border_color = Cfg.MUSTARD; st.set_border_width_all(3 if game.can_expand() else 0)

# ================================================================== alerts
func _render_alerts() -> void:
	UIKit.clear(alerts_box)
	for a in game.alerts.slice(0, 4):
		var c := PanelContainer.new()
		var sev: String = a["severity"]
		var edge: Color = {"bad": Cfg.BAD, "good": Cfg.GOOD, "info": Cfg.BLUE}.get(sev, Cfg.WARN)
		var st := UIKit.sb(Color(1.0, 0.98, 0.95, 0.97), 14, edge, 0, 8, Vector4(10, 9, 10, 9))
		st.border_width_left = 5; st.border_color = edge
		c.add_theme_stylebox_override("panel", st)
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		var h := UIKit.hbox(10)
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UIKit.sb(ICON_COLOR.get(a["icon"], Cfg.TERRA), 9, Color(0, 0, 0, 0), 0, 0, Vector4(5, 5, 5, 5)))
		chip.add_child(UIKit.icon(ICON_GLYPH.get(a["icon"], "info"), 16, Color.WHITE))
		chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(chip)
		var l := UIKit.wrap(UIKit.label(a["text"], 13, Cfg.INK, "body", 700), 250)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var x := Button.new(); x.flat = true; x.icon = UIKit.icon_tex("close"); x.focus_mode = Control.FOCUS_NONE
		x.add_theme_constant_override("icon_max_width", 12); x.add_theme_color_override("icon_normal_color", Cfg.INK3)
		var aid: int = a["id"]
		x.pressed.connect(func(): game.alerts = game.alerts.filter(func(q): return q["id"] != aid); _render_alerts())
		x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(x)
		c.add_child(h)
		var focus = a["focus"]
		c.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and focus != null: game.rig.focus(focus.x, focus.z))
		alerts_box.add_child(c)
		c.modulate.a = 0.0
		c.create_tween().tween_property(c, "modulate:a", 1.0, 0.25)

# ================================================================== panels
func toggle_panel(id: String) -> void:
	open_panel("" if panel_id == id else id)

func open_panel(id: String) -> void:
	if id != "build" and not game.placing.is_empty(): game.cancel_placement()
	panel_id = id
	panel_sig = ""
	panel.visible = id != ""
	_render_dock_state()
	if id != "": _render_panel()

func _sig_panel() -> String:
	match panel_id:
		"build": return "%s|%d|%d|%s" % [build_tab, int(game.money / 100), game.stage, game.placing.is_empty()]
		"products":
			var s := ""
			for p in game.unlocked_products(): s += "%s%d%d%d%d," % [p["id"], game.prices[p["id"]], game.shelf_stock(p["id"]), game.backstock[p["id"]], game.stats["sold"].get(p["id"], 0)]
			return s
		"supply":
			var s2 := "%d|%d" % [game.backstock_total(), game.incoming_total()]
			for p in game.unlocked_products(): s2 += "%d%s" % [game.backstock[p["id"]], game.auto[p["id"]]]
			return s2
		"staff":
			var s3 := str(game.candidates.size())
			for s in game.staff: s3 += s.activity + str(s.id)
			return s3 + str(int(game.money / 100))
		"finance": return "%d|%d|%d" % [game.stats["revenue"], game.stats["purchases"], game.history.size()]
		"growth": return "%d|%d|%s|%s" % [int(game.money / 100), game.stage, str(game.upgrades.keys()), game.can_expand()]
	return ""

func _frame(title: String, subtitle: String, ic: String, col: Color, width: float, wide_top := true) -> VBoxContainer:
	UIKit.clear(panel)
	panel.add_theme_stylebox_override("panel", UIKit.sb(Color(1.0, 0.975, 0.94, 0.98), 20, Color(0, 0, 0, 0), 0, 16, Vector4(0, 0, 0, 0)))
	panel.custom_minimum_size = Vector2(width, 0)
	var outer := UIKit.vbox(0)
	var head := PanelContainer.new()
	var hs := UIKit.sb(col, 20, Color(0, 0, 0, 0), 0, 0, Vector4(16, 12, 12, 12))
	hs.corner_radius_bottom_left = 0; hs.corner_radius_bottom_right = 0
	head.add_theme_stylebox_override("panel", hs)
	var hh := UIKit.hbox(12)
	var ib := PanelContainer.new(); ib.add_theme_stylebox_override("panel", UIKit.sb(Color(1, 1, 1, 0.2), 12, Color(0, 0, 0, 0), 0, 0, Vector4(7, 7, 7, 7)))
	ib.add_child(UIKit.icon(ic, 22, Color.WHITE)); hh.add_child(ib)
	var tv := UIKit.vbox(-2); tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UIKit.label(title, 24, Color.WHITE, "display"))
	if subtitle != "": tv.add_child(UIKit.wrap(UIKit.label(subtitle, 12, Color(1, 1, 1, 0.88), "body", 700), width - 120))
	hh.add_child(tv)
	var x := Button.new(); x.flat = true; x.icon = UIKit.icon_tex("close"); x.focus_mode = Control.FOCUS_NONE
	x.add_theme_constant_override("icon_max_width", 16); x.add_theme_color_override("icon_normal_color", Color.WHITE)
	x.pressed.connect(func(): open_panel(""))
	x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hh.add_child(x)
	head.add_child(hh)
	outer.add_child(head)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var m := MarginContainer.new()
	for k in ["margin_left", "margin_right"]: m.add_theme_constant_override(k, 16)
	m.add_theme_constant_override("margin_top", 10); m.add_theme_constant_override("margin_bottom", 14)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := UIKit.vbox(8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(body); sc.add_child(m); outer.add_child(sc)
	panel.add_child(outer)
	return body

func _place_panel(build := false) -> void:
	var vs := root.get_viewport_rect().size
	if build:
		panel.position = Vector2((vs.x - panel.custom_minimum_size.x) * 0.5, vs.y - 110 - 300)
		panel.size = Vector2(panel.custom_minimum_size.x, 300)
	else:
		panel.position = Vector2(18, 16)
		panel.size = Vector2(panel.custom_minimum_size.x, vs.y - 16 - 120)

func _render_panel() -> void:
	match panel_id:
		"build": _p_build()
		"products": _p_products()
		"supply": _p_supply()
		"staff": _p_staff()
		"finance": _p_finance()
		"growth": _p_growth()
	_place_panel(panel_id == "build")

# ---------------------------------------------------------------- build
func _p_build() -> void:
	var body := _frame("İnşa", "Bir eşya seç, dükkânda yerine tıkla. R: döndür · Shift+tık: arka arkaya · Esc: iptal", "build", Cfg.TERRA, 940)
	var tabs := UIKit.hbox(6)
	for t in ["Teşhir", "Kasa & Depo", "Ortam"]:
		var b := UIKit.button(t, "", false, true)
		if t == build_tab:
			b.add_theme_stylebox_override("normal", UIKit.sb(Cfg.INK, 10, Color(0, 0, 0, 0), 0, 0, Vector4(12, 6, 12, 6)))
			b.add_theme_color_override("font_color", Color.WHITE)
		var tt: String = t
		b.pressed.connect(func(): build_tab = tt; panel_sig = "")
		tabs.add_child(b)
	body.add_child(tabs)
	var grid := HBoxContainer.new(); grid.add_theme_constant_override("separation", 10)
	for d in DB.FIXTURES:
		if d["cat"] != build_tab: continue
		var locked: bool = d["stage"] > game.stage
		var poor: bool = game.money < d["cost"]
		var card := Button.new()
		card.focus_mode = Control.FOCUS_NONE
		card.custom_minimum_size = Vector2(140, 188)
		card.add_theme_stylebox_override("normal", UIKit.sb(Color.WHITE, 16, Color(0.12, 0.16, 0.27, 0.1), 2, 0, Vector4(8, 8, 8, 8)))
		card.add_theme_stylebox_override("hover", UIKit.sb(Color("fffaf2"), 16, Cfg.TERRA, 3, 6, Vector4(8, 8, 8, 8)))
		card.add_theme_stylebox_override("pressed", UIKit.sb(Color("fff1e0"), 16, Cfg.TERRA, 3, 0, Vector4(8, 8, 8, 8)))
		card.add_theme_stylebox_override("disabled", UIKit.sb(Color(1, 1, 1, 0.5), 16, Color(0.12, 0.16, 0.27, 0.08), 2, 0, Vector4(8, 8, 8, 8)))
		card.disabled = locked
		card.tooltip_text = d["desc"]
		var v := UIKit.vbox(2); v.set_anchors_preset(Control.PRESET_FULL_RECT); v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.offset_left = 8; v.offset_top = 8; v.offset_right = -8; v.offset_bottom = -8
		var img := TextureRect.new(); img.custom_minimum_size = Vector2(124, 96); img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.texture = thumbs.fixtures.get(d["id"])
		var imgbg := PanelContainer.new(); imgbg.add_theme_stylebox_override("panel", UIKit.sb(Color("f6ecde"), 12, Color(0, 0, 0, 0), 0, 0, Vector4(0, 0, 0, 0))); imgbg.add_child(img); imgbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(imgbg)
		v.add_child(UIKit.label(d["name"], 14, Cfg.INK, "body", 800))
		v.add_child(UIKit.label("%d×%d m%s" % [d["w"], d["d"], (" · %d bölme" % d["slots"]) if d.has("slots") else ""], 11, Cfg.INK3, "body", 700))
		var pr := UIKit.label(Cfg.fmt_money(d["cost"]) if not locked else "Market'te açılır", 18 if not locked else 12, Cfg.BAD if poor else Cfg.TERRA, "display" if not locked else "body", 800)
		v.add_child(pr)
		card.add_child(v)
		if locked: card.modulate = Color(1, 1, 1, 0.55)
		var fid: String = d["id"]
		card.pressed.connect(func(): game.start_placement(fid))
		grid.add_child(card)
	var sc := ScrollContainer.new(); sc.custom_minimum_size = Vector2(900, 200); sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(grid)
	body.add_child(sc)

# ---------------------------------------------------------------- products & prices
func _p_products() -> void:
	var body := _frame("Ürün & Fiyat", "Her arketip farklı fiyat toleransına sahip. Pahalı ürün satılmaz, ucuz ürün kâr bırakmaz.", "tag", Cfg.TEAL, 760)
	var head := UIKit.hbox(8)
	for c in [["", 44], ["ÜRÜN", 150], ["FİYAT", 150], ["KİM ALIR?", 190], ["RAF", 56], ["DEPO", 56], ["SATIŞ", 56]]:
		var l := UIKit.label(c[0], 11, Cfg.INK3, "body", 800); l.custom_minimum_size.x = c[1]; head.add_child(l)
	body.add_child(head)
	for p in game.unlocked_products():
		var pid: String = p["id"]
		var row := UIKit.hbox(8)
		var img := TextureRect.new(); img.custom_minimum_size = Vector2(44, 44); img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.texture = thumbs.products.get(pid); row.add_child(img)
		var nv := UIKit.vbox(-2); nv.custom_minimum_size.x = 150
		nv.add_child(UIKit.label(p["name"], 15, Cfg.INK, "body", 800))
		nv.add_child(UIKit.label("%s · maliyet ₺%d" % [DB.DISPLAY_LABEL[p["display"]], p["cost"]], 11, Cfg.INK3, "body", 700))
		row.add_child(nv)
		var ph := UIKit.hbox(4); ph.custom_minimum_size.x = 150
		var minus := UIKit.button("", "minus", false, true); minus.pressed.connect(func(): game.set_price(pid, game.prices[pid] - 1))
		var plus := UIKit.button("", "plus", false, true); plus.pressed.connect(func(): game.set_price(pid, game.prices[pid] + 1))
		ph.add_child(minus)
		var pv := UIKit.vbox(-4); pv.custom_minimum_size.x = 58
		var price: int = game.prices[pid]
		var pl := UIKit.label("₺%d" % price, 20, Cfg.INK, "display"); pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; pv.add_child(pl)
		var margin := int(round((price - p["cost"]) * 100.0 / price))
		var ml := UIKit.label("%%%d kâr" % margin, 10, Cfg.GOOD if margin > 30 else Cfg.WARN, "body", 800); ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; pv.add_child(ml)
		ph.add_child(pv); ph.add_child(plus)
		row.add_child(ph)
		var acc := HFlowContainer.new(); acc.custom_minimum_size.x = 190
		acc.add_theme_constant_override("h_separation", 3); acc.add_theme_constant_override("v_separation", 3)
		for a in DB.ARCHETYPES:
			if a["stage"] > game.stage or not a["wants"].has(pid): continue
			var ok: bool = price <= p["base"] * (1.0 + a["tol"] + game.tolerance_bonus())
			acc.add_child(UIKit.chip(a["name"].split(" ")[0], Cfg.GOOD if ok else Cfg.BAD, Color.WHITE, 10))
		row.add_child(acc)
		for v in [game.shelf_stock(pid), game.backstock[pid], game.stats["sold"].get(pid, 0)]:
			var l2 := UIKit.label(str(v), 16, Cfg.INK, "display"); l2.custom_minimum_size.x = 56; l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(l2)
		body.add_child(row)
		body.add_child(UIKit.sep_h())

# ---------------------------------------------------------------- supply
func _p_supply() -> void:
	var cap := game.depot_capacity()
	var body := _frame("Tedarik", "Depo: %d / %d birim · yolda %d. Toptancı minibüsü ~50 oyun dakikasında gelir." % [game.backstock_total(), cap, game.incoming_total()], "truck", Cfg.BLUE, 640)
	body.add_child(UIKit.bar(float(game.backstock_total() + game.incoming_total()) / maxf(1, cap), Cfg.BLUE, 0, 8))
	for p in game.unlocked_products():
		var pid: String = p["id"]
		var row := UIKit.hbox(10)
		var img := TextureRect.new(); img.custom_minimum_size = Vector2(40, 40); img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.texture = thumbs.products.get(pid); row.add_child(img)
		var nv := UIKit.vbox(-2); nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nv.add_child(UIKit.label(p["name"], 15, Cfg.INK, "body", 800))
		nv.add_child(UIKit.label("depoda %d · rafta %d · yolda %d" % [game.backstock[pid], game.shelf_stock(pid), game.incoming(pid)], 11, Cfg.INK3, "body", 700))
		row.add_child(nv)
		for q in [6, 12, 24]:
			var b := UIKit.button("+%d" % q, "", false, true)
			b.tooltip_text = "₺%d" % (q * p["cost"])
			var qq: int = q
			b.pressed.connect(func(): game.order(pid, qq))
			row.add_child(b)
		var tg := CheckButton.new(); tg.text = "Oto"; tg.button_pressed = game.auto[pid]; tg.focus_mode = Control.FOCUS_NONE
		tg.add_theme_font_size_override("font_size", 12)
		tg.toggled.connect(func(on): game.auto[pid] = on)
		row.add_child(tg)
		body.add_child(row)
		body.add_child(UIKit.sep_h())

# ---------------------------------------------------------------- staff
func _p_staff() -> void:
	var body := _frame("Personel", "Günlük maaş toplamı %s — gün sonunda ödenir." % Cfg.fmt_money(game.wages_per_day()), "staff", Cfg.VIOLET, 560)
	body.add_child(UIKit.section("Ekip"))
	for s in game.staff:
		var row := UIKit.hbox(10)
		var chip := PanelContainer.new(); chip.add_theme_stylebox_override("panel", UIKit.sb(s.view.mat.get_shader_parameter("c_top"), 22, Color(0, 0, 0, 0), 0, 0, Vector4(9, 9, 9, 9)))
		chip.add_child(UIKit.icon("staff", 22, Color.WHITE)); row.add_child(chip)
		var nv := UIKit.vbox(-2); nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nv.add_child(UIKit.label(s.person_name, 16, Cfg.INK, "body", 800))
		nv.add_child(UIKit.label("%s · %s" % [DB.ROLE_LABEL[s.role], s.activity], 12, Cfg.INK2, "body", 700))
		row.add_child(nv)
		row.add_child(UIKit.label(Cfg.fmt_money(s.wage) if s.wage > 0 else "sahip", 15, Cfg.INK2, "display"))
		if s.role != "owner":
			var f := UIKit.button("", "close", false, true); f.tooltip_text = "İşten çıkar"
			var ss: Staff = s
			f.pressed.connect(func(): game.fire(ss))
			row.add_child(f)
		body.add_child(row)
	body.add_child(UIKit.sep_h())
	body.add_child(UIKit.section("Adaylar (her sabah yenilenir)"))
	for c in game.candidates:
		var row := UIKit.hbox(10)
		var nv := UIKit.vbox(-2); nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nv.add_child(UIKit.label("%s — %s" % [c["name"], DB.ROLE_LABEL[c["role"]]], 15, Cfg.INK, "body", 800))
		nv.add_child(UIKit.wrap(UIKit.label(DB.ROLE_DESC[c["role"]], 11, Cfg.INK3, "body", 700), 330))
		nv.add_child(UIKit.label("Beceri %d%%" % int(c["skill"] * 100), 11, Cfg.TEAL, "body", 800))
		row.add_child(nv)
		var b := UIKit.button("İşe al · " + Cfg.fmt_money(c["wage"]), "plus", true, true)
		var cc: Dictionary = c
		b.pressed.connect(func(): game.hire(cc))
		row.add_child(b)
		body.add_child(row)

# ---------------------------------------------------------------- finance
func _p_finance() -> void:
	var st: Dictionary = game.stats
	var body := _frame("Finans", "Bugünün tabloları ve son günlerin kârı.", "chart", Cfg.GOOD, 480)
	var grid := GridContainer.new(); grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10); grid.add_theme_constant_override("v_separation", 10)
	for kv in [["Satış", st["revenue"], Cfg.GOOD], ["Mal alımı", st["purchases"], Cfg.INK], ["Diğer (eşya, yükseltme)", st["other"], Cfg.INK],
		["Maaş / gün", game.wages_per_day(), Cfg.INK], ["Kira / gün", game.rent(), Cfg.INK], ["Ödeyen müşteri", st["served"], Cfg.INK]]:
		var c := UIKit.card(Color.WHITE, 14, Vector4(12, 10, 12, 10), 0)
		var v := UIKit.vbox(0)
		v.add_child(UIKit.label(kv[0], 12, Cfg.INK3, "body", 800))
		v.add_child(UIKit.label(Cfg.fmt_money(kv[1]) if kv[0] != "Ödeyen müşteri" else str(kv[1]), 22, kv[2], "display"))
		c.add_child(v); c.custom_minimum_size.x = 210
		grid.add_child(c)
	body.add_child(grid)
	body.add_child(UIKit.section("Son günler"))
	if game.history.is_empty():
		body.add_child(UIKit.label("İlk gün sonunda burada kâr grafiği çıkacak.", 13, Cfg.INK2, "body", 700))
	var mx := 1.0
	for h in game.history: mx = maxf(mx, absf(h["profit"]))
	for h in game.history.slice(-7):
		var row := UIKit.hbox(8)
		row.add_child(UIKit.label("Gün %d" % h["day"], 13, Cfg.INK2, "body", 800))
		var b := UIKit.bar(absf(h["profit"]) / mx, Cfg.GOOD if h["profit"] >= 0 else Cfg.BAD, 220, 10); b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
		row.add_child(UIKit.label(Cfg.fmt_money(h["profit"]), 14, Cfg.GOOD if h["profit"] >= 0 else Cfg.BAD, "display"))
		body.add_child(row)

# ---------------------------------------------------------------- growth
func _p_growth() -> void:
	var body := _frame("Gelişim", "Hedefleri tamamla, dükkânı büyüt; yükseltmelerle çekimi ve hızı artır.", "arrowUp", Cfg.MUSTARD.darkened(0.15), 520)
	var e = game.expansion()
	if e != null:
		var c := UIKit.card(Color.WHITE, 16, Vector4(14, 12, 14, 12), 0)
		var v := UIKit.vbox(6)
		v.add_child(UIKit.label(e["title"], 22, Cfg.INK, "display"))
		v.add_child(UIKit.wrap(UIKit.label(e["pitch"], 13, Cfg.INK2, "body", 700), 440))
		for g in game.goals():
			var row := UIKit.hbox(6)
			row.add_child(UIKit.icon("check" if g["done"] else "clock", 16, Cfg.GOOD if g["done"] else Cfg.INK3))
			var l := UIKit.label(g["label"], 13, Cfg.INK, "body", 800); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(l)
			v.add_child(row)
			v.add_child(UIKit.bar(float(g["value"]) / float(g["target"]), Cfg.GOOD if g["done"] else Cfg.MUSTARD, 0, 6))
		v.add_child(UIKit.wrap(UIKit.label("Açılanlar: " + e["unlocks"], 12, Cfg.TEAL, "body", 800), 440))
		var b := UIKit.button("Genişlet · " + Cfg.fmt_money(e["cost"]), "arrowUp", true)
		b.disabled = not game.can_expand()
		b.pressed.connect(func(): if game.expand(): open_panel(""))
		v.add_child(b)
		c.add_child(v); body.add_child(c)
	body.add_child(UIKit.section("Yükseltmeler"))
	for u in DB.UPGRADES:
		if u["stage"] > game.stage: continue
		var row := UIKit.hbox(10)
		var ib := PanelContainer.new(); ib.add_theme_stylebox_override("panel", UIKit.sb(Color(0.48, 0.35, 0.88, 0.14), 12, Color(0, 0, 0, 0), 0, 0, Vector4(8, 8, 8, 8)))
		ib.add_child(UIKit.icon("sparkle", 20, Cfg.VIOLET)); ib.size_flags_vertical = Control.SIZE_SHRINK_BEGIN; row.add_child(ib)
		var v2 := UIKit.vbox(0); v2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v2.add_child(UIKit.label(u["name"], 15, Cfg.INK, "body", 800))
		v2.add_child(UIKit.wrap(UIKit.label(u["desc"], 12, Cfg.INK2, "body", 700), 300))
		v2.add_child(UIKit.label(u["effect"], 12, Cfg.TEAL, "body", 800))
		row.add_child(v2)
		if game.upgrades.has(u["id"]):
			var ok := UIKit.hbox(4); ok.add_child(UIKit.icon("check", 16, Cfg.GOOD)); ok.add_child(UIKit.label("Alındı", 13, Cfg.GOOD, "body", 800)); row.add_child(ok)
		else:
			var b2 := UIKit.button(Cfg.fmt_money(u["cost"]), "", true, true)
			b2.disabled = game.money < u["cost"]
			var uid: String = u["id"]
			b2.pressed.connect(func(): game.buy_upgrade(uid))
			b2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(b2)
		body.add_child(row)

# ================================================================== inspector
func _sig_insp() -> String:
	var o = game.selection.get("obj")
	if o == null or not is_instance_valid(o): return "none"
	if o is Fixture:
		var s := "%d|%d|%s" % [slot_picker, o.queue.size(), o.status_kind]
		for sl in o.slots: s += "%s%d" % [sl["pid"], sl["stock"]]
		return s
	if o is Customer: return "%s|%d|%d|%d|%d" % [o.state, int(o.mood / 3), o.basket.size(), o.thoughts.size(), o.queue_idx]
	if o is Staff: return "%s|%s" % [o.activity, str(o.task != null)]
	return ""

func _render_inspector() -> void:
	var o = game.selection.get("obj")
	UIKit.clear(inspector)
	if o == null or not is_instance_valid(o):
		inspector.visible = false; return
	inspector.visible = true
	var v := UIKit.vbox(0)
	inspector.add_child(v)
	if o is Fixture: _insp_fixture(v, o)
	elif o is Customer: _insp_customer(v, o)
	elif o is Staff: _insp_staff(v, o)
	inspector.reset_size()

func _insp_head(v: VBoxContainer, title: String, sub: String, col: Color, tex: Texture2D = null, glyph := "") -> void:
	var head := PanelContainer.new()
	var hs := UIKit.sb(col, 18, Color(0, 0, 0, 0), 0, 0, Vector4(12, 10, 10, 10))
	hs.corner_radius_bottom_left = 0; hs.corner_radius_bottom_right = 0
	head.add_theme_stylebox_override("panel", hs)
	var h := UIKit.hbox(10)
	var ib := PanelContainer.new(); ib.add_theme_stylebox_override("panel", UIKit.sb(Color(1, 1, 1, 0.92), 14, Color(0, 0, 0, 0), 0, 0, Vector4(4, 4, 4, 4)))
	if tex:
		var img := TextureRect.new(); img.texture = tex; img.custom_minimum_size = Vector2(56, 56); img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ib.add_child(img)
	else: ib.add_child(UIKit.icon(glyph, 40, col))
	h.add_child(ib)
	var tv := UIKit.vbox(-2); tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UIKit.label(title, 22, Color.WHITE, "display"))
	tv.add_child(UIKit.wrap(UIKit.label(sub, 12, Color(1, 1, 1, 0.9), "body", 700), 200))
	h.add_child(tv)
	var x := Button.new(); x.flat = true; x.icon = UIKit.icon_tex("close"); x.focus_mode = Control.FOCUS_NONE
	x.add_theme_constant_override("icon_max_width", 14); x.add_theme_color_override("icon_normal_color", Color.WHITE)
	x.pressed.connect(func(): game.select({})); x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(x)
	head.add_child(h)
	v.add_child(head)

func _body(v: VBoxContainer) -> VBoxContainer:
	var m := MarginContainer.new()
	for k in ["margin_left", "margin_right"]: m.add_theme_constant_override(k, 14)
	m.add_theme_constant_override("margin_top", 10); m.add_theme_constant_override("margin_bottom", 14)
	var b := UIKit.vbox(8)
	m.add_child(b); v.add_child(m)
	return b

func _insp_fixture(v: VBoxContainer, f: Fixture) -> void:
	var d := f.def
	var sub: String = d["desc"]
	if f.status_kind != "": sub = STATUS_TEXT.get(f.status_kind, sub)
	_insp_head(v, d["name"], sub, Cfg.TERRA if f.status_kind in ["empty", "nocashier"] else Cfg.TEAL, thumbs.fixtures.get(d["id"]))
	var b := _body(v)
	if f.is_display():
		b.add_child(UIKit.section("Bölmeler — tıkla, ürün ata"))
		for i in f.slots.size():
			var s: Dictionary = f.slots[i]
			var btn := Button.new(); btn.focus_mode = Control.FOCUS_NONE
			btn.custom_minimum_size = Vector2(0, 58)
			btn.add_theme_stylebox_override("normal", UIKit.sb(Color.WHITE, 12, Color(0.12, 0.16, 0.27, 0.1), 2, 0, Vector4(8, 6, 8, 6)))
			btn.add_theme_stylebox_override("hover", UIKit.sb(Color("fffaf2"), 12, Cfg.TERRA, 2, 3, Vector4(8, 6, 8, 6)))
			var h := UIKit.hbox(10); h.set_anchors_preset(Control.PRESET_FULL_RECT); h.offset_left = 8; h.offset_right = -8; h.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var img := TextureRect.new(); img.custom_minimum_size = Vector2(46, 46); img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if s["pid"] != "": img.texture = thumbs.products.get(s["pid"])
			else: img.texture = UIKit.icon_tex("plus"); img.modulate = Cfg.INK3
			h.add_child(img)
			var tv := UIKit.vbox(2); tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tv.alignment = BoxContainer.ALIGNMENT_CENTER
			if s["pid"] != "":
				var p := DB.product(s["pid"])
				var top := UIKit.hbox(6)
				var nl := UIKit.label(p["name"], 15, Cfg.INK, "body", 800); nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(nl)
				top.add_child(UIKit.label("%d/%d" % [s["stock"], f.cap()], 13, Cfg.INK2, "body", 800))
				tv.add_child(top)
				var ratio := float(s["stock"]) / f.cap()
				tv.add_child(UIKit.bar(ratio, Cfg.BAD if ratio < 0.01 else (Cfg.WARN if ratio < 0.34 else Cfg.GOOD), 0, 6))
			else:
				tv.add_child(UIKit.label("Boş bölme — ürün seç", 14, Cfg.INK3, "body", 800))
			h.add_child(tv)
			btn.add_child(h)
			var ii: int = i
			btn.pressed.connect(func(): slot_picker = -1 if slot_picker == ii else ii; insp_sig = ""; _render_inspector())
			b.add_child(btn)
			if slot_picker == i:
				var flow := HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 6); flow.add_theme_constant_override("v_separation", 6)
				for p in game.unlocked_products():
					if p["display"] != d["display"]: continue
					var pb := Button.new(); pb.focus_mode = Control.FOCUS_NONE; pb.tooltip_text = "%s · ₺%d" % [p["name"], game.prices[p["id"]]]
					pb.icon = thumbs.products.get(p["id"]); pb.expand_icon = true; pb.custom_minimum_size = Vector2(58, 58)
					pb.add_theme_stylebox_override("normal", UIKit.sb(Color("f6ecde"), 12, Color(0, 0, 0, 0), 0, 0, Vector4(4, 4, 4, 4)))
					pb.add_theme_stylebox_override("hover", UIKit.sb(Color("fff1e0"), 12, Cfg.TERRA, 2, 0, Vector4(4, 4, 4, 4)))
					var pid: String = p["id"]
					pb.pressed.connect(func(): game.assign_slot(f, ii, pid); slot_picker = -1; insp_sig = ""; _render_inspector())
					flow.add_child(pb)
				if s["pid"] != "":
					var rb := UIKit.button("Boşalt", "trash", false, true)
					rb.pressed.connect(func(): game.assign_slot(f, ii, ""); slot_picker = -1; insp_sig = ""; _render_inspector())
					flow.add_child(rb)
				b.add_child(flow)
	elif d["kind"] == "register":
		b.add_child(UIKit.section("Kasa"))
		var cn: String = f.cashier.person_name if f.cashier else "Yok — kasiyer al!"
		b.add_child(UIKit.label("Kasiyer: " + cn, 14, Cfg.INK if f.cashier else Cfg.BAD, "body", 800))
		b.add_child(UIKit.label("Kuyrukta: %d kişi" % f.queue.size(), 14, Cfg.INK, "body", 800))
		b.add_child(UIKit.wrap(UIKit.label("Sarı noktalar kuyruğun izleyeceği yolu gösterir. Kasayı kapıdan uzağa koymak kuyruğu içeride tutar.", 12, Cfg.INK2, "body", 700), 310))
	elif d["kind"] == "depot":
		b.add_child(UIKit.section("Depo"))
		b.add_child(UIKit.label("%d / %d birim dolu" % [game.backstock_total(), game.depot_capacity()], 16, Cfg.INK, "display"))
		b.add_child(UIKit.bar(float(game.backstock_total()) / maxf(1, game.depot_capacity()), Cfg.BLUE, 0, 8))
	var acts := UIKit.hbox(6)
	var mv := UIKit.button("Taşı", "move", false, true); mv.pressed.connect(func(): game.start_placement(d["id"], f); open_panel("build"))
	var sl := UIKit.button("Sat · " + Cfg.fmt_money(int(d["cost"] * 0.5)), "trash", false, true); sl.pressed.connect(func(): game.sell_fixture(f))
	acts.add_child(mv); acts.add_child(sl)
	b.add_child(UIKit.sep_h()); b.add_child(acts)

func _insp_customer(v: VBoxContainer, c: Customer) -> void:
	var a = c.arch
	var title: String = c.person_name
	var sub: String = ("%s · %s" % [a["name"], c.status_label()]) if a != null else "Yoldan geçen"
	var col := Cfg.GOOD if c.mood >= 60 else (Cfg.WARN if c.mood >= 35 else Cfg.BAD)
	_insp_head(v, title, sub, col, null, "people")
	var b := _body(v)
	if a == null:
		b.add_child(UIKit.label("Sadece geçip gidiyor. Vitrin ve tabela onu içeri çekebilir.", 13, Cfg.INK2, "body", 700)); return
	b.add_child(UIKit.wrap(UIKit.label(a["blurb"], 12, Cfg.INK2, "body", 700), 310))
	var mh := UIKit.hbox(8)
	mh.add_child(UIKit.label("Keyif", 13, Cfg.INK, "body", 800))
	var mb := UIKit.bar(c.mood / 100.0, col, 180, 9); mb.size_flags_vertical = Control.SIZE_SHRINK_CENTER; mh.add_child(mb)
	mh.add_child(UIKit.label("%d" % int(c.mood), 14, col, "display"))
	b.add_child(mh)
	b.add_child(UIKit.label("Bütçe %s · harcadı %s" % [Cfg.fmt_money(c.budget), Cfg.fmt_money(c.spent())], 12, Cfg.INK2, "body", 800))
	b.add_child(UIKit.section("Alışveriş listesi"))
	var st_txt := {"pending": ["Arıyor", Cfg.INK3], "got": ["Aldı", Cfg.GOOD], "oos": ["Bitmiş", Cfg.BAD], "notfound": ["Bulamadı", Cfg.VIOLET], "expensive": ["Pahalı", Cfg.TERRA], "budget": ["Parası yetmedi", Color("b0546a")]}
	for w in c.wants:
		var row := UIKit.hbox(8)
		var img := TextureRect.new(); img.custom_minimum_size = Vector2(30, 30); img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.texture = thumbs.products.get(w["pid"]); row.add_child(img)
		var nl := UIKit.label(DB.product(w["pid"])["name"] + (" ×%d" % w["qty"] if w["qty"] > 1 else ""), 14, Cfg.INK, "body", 800); nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nl)
		var sx: Array = st_txt.get(w["status"], ["", Cfg.INK3])
		row.add_child(UIKit.chip(sx[0], sx[1], Color.WHITE, 11))
		b.add_child(row)
	b.add_child(UIKit.section("Aklından geçenler"))
	if c.thoughts.is_empty(): b.add_child(UIKit.label("Henüz bir şey düşünmedi.", 12, Cfg.INK3, "body", 700))
	for t in c.thoughts:
		var row2 := UIKit.hbox(8)
		var chip := PanelContainer.new(); chip.add_theme_stylebox_override("panel", UIKit.sb(ICON_COLOR.get(t["icon"], Cfg.TERRA), 8, Color(0, 0, 0, 0), 0, 0, Vector4(4, 4, 4, 4)))
		chip.add_child(UIKit.icon(ICON_GLYPH.get(t["icon"], "info"), 13, Color.WHITE)); chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row2.add_child(chip)
		row2.add_child(UIKit.wrap(UIKit.label("“%s”" % t["text"], 13, Cfg.INK, "body", 700), 270))
		b.add_child(row2)

func _insp_staff(v: VBoxContainer, s: Staff) -> void:
	_insp_head(v, s.person_name, "%s · %s" % [DB.ROLE_LABEL[s.role], s.activity], Cfg.VIOLET, null, "staff")
	var b := _body(v)
	b.add_child(UIKit.wrap(UIKit.label(DB.ROLE_DESC[s.role], 13, Cfg.INK2, "body", 700), 310))
	b.add_child(UIKit.label("Beceri %d%% · maaş %s/gün" % [int(s.skill * 100), Cfg.fmt_money(s.wage)], 13, Cfg.INK, "body", 800))
	if s.role != "owner":
		var f := UIKit.button("İşten çıkar", "close", false, true)
		f.pressed.connect(func(): game.fire(s))
		b.add_child(f)

# ================================================================== placement hint
func _render_place_hint() -> void:
	var p := game.placing
	UIKit.clear(place_hint)
	panel.visible = panel_id != "" and p.is_empty()
	if p.is_empty():
		place_hint.visible = false; return
	place_hint.visible = true
	var h := UIKit.hbox(14)
	var img := TextureRect.new(); img.custom_minimum_size = Vector2(44, 44); img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.texture = thumbs.fixtures.get(p["def"]["id"]); h.add_child(img)
	var tv := UIKit.vbox(-2)
	tv.add_child(UIKit.label(p["def"]["name"], 16, Color.WHITE, "display"))
	tv.add_child(UIKit.label("Taşınıyor" if p["moving"] else Cfg.fmt_money(p["def"]["cost"]), 12, Color(1, 1, 1, 0.75), "body", 800))
	h.add_child(tv)
	var ok: bool = p["ok"]
	var chip := UIKit.chip(("Yerleştirilebilir" if ok else String(p["reason"])), Color(0.35, 0.82, 0.6, 0.3) if ok else Color(0.9, 0.3, 0.3, 0.35), Color("a7f3cf") if ok else Color("ffc2c4"), 13)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(chip)
	var keys := UIKit.label("Sol tık: yerleştir · R: döndür · Sağ tık/Esc: iptal", 12, Color(1, 1, 1, 0.8), "body", 700)
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(keys)
	place_hint.add_child(h)
	place_hint.reset_size()
	var vs := root.get_viewport_rect().size
	place_hint.position = Vector2((vs.x - place_hint.size.x) * 0.5, vs.y - 180)

# ================================================================== world input
func _unhandled_input(e: InputEvent) -> void:
	if not started: return
	if e is InputEventKey and e.pressed and not e.echo:
		_key(e as InputEventKey); return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed: _press_pos = mb.position; _pressing = true
			elif _pressing:
				_pressing = false
				if mb.position.distance_to(_press_pos) < 6.0 and not mb.alt_pressed: _click(mb.position, mb.shift_pressed)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed and not game.placing.is_empty():
			game.cancel_placement()
	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if not game.placing.is_empty():
			var g = game.ground_at(mm.position)
			if g != null: game.update_placement(floori(g.x), floori(g.z))
			tooltip.visible = false
		elif not game.rig.is_dragging():
			_hover(mm.position)

func _key(k: InputEventKey) -> void:
	match k.keycode:
		KEY_ESCAPE:
			if not game.placing.is_empty(): game.cancel_placement()
			elif slot_picker >= 0: slot_picker = -1; insp_sig = ""
			elif panel_id != "": open_panel("")
			else: game.select({})
		KEY_SPACE: set_speed(game.speed if game.paused else 0.0)
		KEY_1: set_speed(1.0)
		KEY_2: set_speed(2.0)
		KEY_3: set_speed(4.0)
		KEY_B: toggle_panel("build")
		KEY_P: toggle_panel("products")
		KEY_T: toggle_panel("supply")
		KEY_H: toggle_panel("staff")
		KEY_F: toggle_panel("finance")
		KEY_U: toggle_panel("growth")
		KEY_M: _dock_pressed("heat")
		KEY_R: game.rotate_placement()
		KEY_C: game.shop.cutaway = not game.shop.cutaway

func _click(pos: Vector2, shift: bool) -> void:
	if not game.placing.is_empty():
		game.confirm_placement(shift); return
	var hit := game.pick(pos)
	if hit.has("litter"):
		game.remove_litter(hit["litter"]); game.float_text(Vector3(hit["ground"].x, 1.0, hit["ground"].z), "Temizlendi", Cfg.TEAL); return
	if hit.has("agent"): game.select({"kind": "agent", "obj": hit["agent"]}); return
	if hit.has("fixture"): game.select({"kind": "fixture", "obj": hit["fixture"]}); return
	game.select({})

func _hover(pos: Vector2) -> void:
	var hit := game.pick(pos)
	var txt := ""
	game.overlays.hover_ring.visible = false
	if hit.has("agent"):
		var a = hit["agent"]
		game.overlays.hover_ring.visible = true
		game.overlays.hover_ring.position = a.position + Vector3(0, 0.05, 0)
		if a is Customer:
			txt = "[b]%s[/b]\n%s · %s" % [a.person_name, a.arch["name"] if a.arch != null else "Yoldan geçen", a.status_label() if a.shopper else "yürüyor"]
		else:
			txt = "[b]%s[/b]\n%s · %s" % [a.person_name, DB.ROLE_LABEL[a.role], a.activity]
	elif hit.has("fixture"):
		var f: Fixture = hit["fixture"]
		txt = "[b]%s[/b]" % f.def["name"]
		for s in f.slots:
			if s["pid"] != "": txt += "\n%s  %d/%d  ₺%d" % [DB.product(s["pid"])["name"], s["stock"], f.cap(), game.prices[s["pid"]]]
		if f.status_kind != "": txt += "\n[color=#ffb3a0]%s[/color]" % STATUS_TEXT.get(f.status_kind, "")
	elif hit.has("litter"):
		txt = "[b]Çöp[/b]\nTıkla: temizle"
	tooltip.visible = txt != ""
	tooltip_lbl.text = txt
	tooltip.reset_size()

func _update_tooltip_pos() -> void:
	if tooltip.visible: tooltip.position = root.get_local_mouse_position() + Vector2(18, 16)

# ================================================================== day end
func _show_day_end(r: Dictionary) -> void:
	UIKit.clear(modal)
	modal.visible = true
	var dim := ColorRect.new(); dim.color = Color(0.12, 0.16, 0.27, 0.45); dim.set_anchors_preset(Control.PRESET_FULL_RECT); modal.add_child(dim)
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", UIKit.sb(Color("fffaf2"), 24, Color(0, 0, 0, 0), 0, 24, Vector4(28, 24, 28, 24)))
	c.custom_minimum_size = Vector2(520, 0)
	c.set_anchors_preset(Control.PRESET_CENTER)
	var v := UIKit.vbox(10)
	var st: Dictionary = r["stats"]
	var profit: int = st["revenue"] - int(r["costs"])
	var k := UIKit.label("GÜN %d KAPANDI" % r["day"], 13, Cfg.VIOLET, "body", 900); k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(k)
	var big := UIKit.label(("+" if profit >= 0 else "") + Cfg.fmt_money(profit), 56, Cfg.GOOD if profit >= 0 else Cfg.BAD, "display"); big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(big)
	var s2 := UIKit.label("günlük net kâr · kasada %s" % Cfg.fmt_money(r["money"]), 13, Cfg.INK3, "body", 800); s2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(s2)
	var grid := GridContainer.new(); grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8)
	for kv in [["Satış", Cfg.fmt_money(st["revenue"]), Cfg.GOOD], ["Mal alımı", Cfg.fmt_money(st["purchases"]), Cfg.INK], ["Maaş + kira", Cfg.fmt_money(st["wages"] + st["rent"] + st["utilities"]), Cfg.INK],
		["Ödeyen", str(st["served"]), Cfg.INK], ["Mutlu ayrılan", str(st["happy"]), Cfg.GOOD], ["Kaybedilen", str(st["lost"]), Cfg.BAD]]:
		var cc := UIKit.card(Color.WHITE, 14, Vector4(12, 8, 12, 8), 0)
		var vv := UIKit.vbox(0)
		vv.add_child(UIKit.label(kv[0], 12, Cfg.INK3, "body", 800))
		vv.add_child(UIKit.label(kv[1], 20, kv[2], "display"))
		cc.add_child(vv); cc.custom_minimum_size.x = 150
		grid.add_child(cc)
	v.add_child(grid)
	var rh := UIKit.hbox(8); rh.alignment = BoxContainer.ALIGNMENT_CENTER
	rh.add_child(UIKit.stars(r["rating"], 22)); rh.add_child(UIKit.label("%.2f" % r["rating"], 20, Cfg.INK, "display"))
	v.add_child(rh)
	for tip in _insights(st):
		var row := UIKit.card(Color(0.12, 0.16, 0.27, 0.05), 12, Vector4(10, 8, 10, 8), 0)
		var h := UIKit.hbox(8)
		h.add_child(UIKit.icon(tip[0], 16, Cfg.TERRA))
		h.add_child(UIKit.wrap(UIKit.label(tip[1], 13, Cfg.INK, "body", 700), 430))
		row.add_child(h); v.add_child(row)
	var b := UIKit.button("Yeni güne başla", "sun", true)
	b.add_theme_font_override("font", Art.font("display")); b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(func(): modal.visible = false; game.start_next_day())
	v.add_child(b)
	c.add_child(v)
	modal.add_child(c)
	c.reset_size()
	c.position = (root.get_viewport_rect().size - c.size) * 0.5

func _insights(st: Dictionary) -> Array:
	var out := []
	var missed: Dictionary = st["missed"]
	var worst := ""
	for pid in missed: if worst == "" or missed[pid] > missed[worst]: worst = pid
	if worst != "" and missed[worst] >= 3:
		out.append(["box", "%s %d kez bulunamadı. Rafa ata, stoğu ve reyon görevlisini kontrol et." % [DB.product(worst)["name"], missed[worst]]])
	if st["lost_queue"] >= 2: out.append(["clock", "%d müşteri kuyrukta beklemekten sıkılıp sepeti bıraktı. Temassız POS ya da ek kasa düşün." % st["lost_queue"]])
	if st["lost_crowd"] >= 3: out.append(["people", "%d kişi dükkân çok kalabalık diye girmedi. Büyümenin zamanı yaklaşıyor." % st["lost_crowd"]])
	var exp: Dictionary = st["expensive"]
	for pid in exp:
		if exp[pid] >= 3: out.append(["tag", "%s %d kişiye pahalı geldi." % [DB.product(pid)["name"], exp[pid]]]); break
	if out.is_empty(): out.append(["heart", "Sakin bir gün. Müşteriler aradığını buldu."])
	return out.slice(0, 3)

# ================================================================== welcome
func _show_welcome() -> void:
	welcome = Control.new(); welcome.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(welcome)
	var dim := ColorRect.new(); dim.color = Color(0.12, 0.16, 0.27, 0.35); dim.set_anchors_preset(Control.PRESET_FULL_RECT); welcome.add_child(dim)
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", UIKit.sb(Color("fffaf2"), 28, Color(0, 0, 0, 0), 0, 30, Vector4(36, 30, 36, 30)))
	c.custom_minimum_size = Vector2(700, 0)
	var v := UIKit.vbox(12)
	v.add_child(UIKit.label("PERAKENDE YÖNETİM OYUNU", 13, Cfg.TEAL, "body", 900))
	var t := UIKit.hbox(0)
	t.add_child(UIKit.label("Tezgâh", 84, Cfg.INK, "display"))
	t.add_child(UIKit.label(".", 84, Cfg.TERRA, "display"))
	v.add_child(t)
	v.add_child(UIKit.wrap(UIKit.label("Köşedeki küçük büfeden mahallenin marketine. Rafları diz, fiyatı ayarla, kuyruğu erit, müşteriyi mutlu gönder.", 17, Cfg.INK2, "body", 700), 620))
	var cards := UIKit.hbox(10)
	for it in [["eye", "Önce dünyaya bak", "Boş raflar, uzayan kuyruk, çöp ve baloncuklar sorunu gösterir."], ["build", "Yerleşim önemli", "Rafın yeri müşterinin yolunu, kuyruğu ve anlık alımları değiştirir."], ["arrowUp", "Büyü", "Hedefleri tut, yan dükkânı devral, Mahalle Marketi'ne dönüş."]]:
		var cc := UIKit.card(Color.WHITE, 16, Vector4(12, 12, 12, 12), 0)
		var vv := UIKit.vbox(4)
		vv.add_child(UIKit.icon(it[0], 22, Cfg.TERRA))
		vv.add_child(UIKit.label(it[1], 15, Cfg.INK, "body", 900))
		vv.add_child(UIKit.wrap(UIKit.label(it[2], 12, Cfg.INK2, "body", 700), 180))
		cc.add_child(vv); cards.add_child(cc)
	v.add_child(cards)
	v.add_child(UIKit.label("Sağ tık sürükle: kaydır · Q/E: döndür · Tekerlek: yakınlaş · B: inşa · Boşluk: duraklat", 12, Cfg.INK3, "body", 800))
	var b := UIKit.button("Dükkânı Aç", "", true)
	b.name = "Start"
	b.add_theme_font_override("font", Art.font("display")); b.add_theme_font_size_override("font_size", 24)
	b.custom_minimum_size = Vector2(0, 58)
	b.pressed.connect(start)
	v.add_child(b)
	c.add_child(v)
	welcome.add_child(c)
	await get_tree().process_frame
	c.reset_size()
	c.position = (root.get_viewport_rect().size - c.size) * 0.5

func start() -> void:
	if started: return
	started = true
	var tw := create_tween(); tw.tween_property(welcome, "modulate:a", 0.0, 0.35); tw.tween_callback(welcome.queue_free)
	game.paused = false
	game.speed = 1.0
	game.alert("hello", "star", "Hoş geldin! Boş bölmeye tıklayıp ürün ata, rafları dolu tut. Sorunlar önce dükkânın içinde görünür.", "good", null, 0.0)
