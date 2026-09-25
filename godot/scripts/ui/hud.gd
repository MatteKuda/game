class_name Hud
extends CanvasLayer
## Heads-up display: top bar, dock, panels, inspector, alerts, placement hint, day report.

const ICON_COLOR := {
	"empty": Color("e5484d"), "low": Color("f2a93b"), "noproduct": Color("7b8698"), "price": Color("e0663c"), "cheap": Color("2fae7a"),
	"wait": Color("f2a93b"), "happy": Color("2fae7a"), "angry": Color("d6333a"), "notfound": Color("7a5ae0"), "dirty": Color("8a6a3c"),
	"crowd": Color("d9822b"), "wallet": Color("b0546a"), "queue": Color("e0663c"), "nocashier": Color("d6333a"), "star": Color("f2b33d"), "box": Color("2f5d8a"),
	"alarm": Color("d6333a"), "sneak": Color("4a3a6a"), "slip": Color("2f7fd8"), "tired": Color("8a6ab8"), "wrench": Color("5b6570"),
	"shop": Color("1f8a86"), "food": Color("e0663c"), "fun": Color("7a5ae0"),
	"sun": Color("f2a93b"), "cloud": Color("7b8698"), "rain": Color("2f6fb5"), "snow": Color("5aa0d0"), "moon": Color("5b4a9a"), "people": Color("1f8a86"),
	"rival": Color("d6333a"), "note": Color("7a5ae0"), "bank": Color("2f5d8a"), "chart": Color("e8962c"), "question": Color("7a5ae0"), "trophy": Color("f2b33d"),
	"heart": Color("e0663c"), "book": Color("2f6fb5"), "cart": Color("1f8a86"), "megaphone2": Color("d6333a"), "tag": Color("e0663c"), "flag": Color("e0663c"), "cat": Color("c9803e"),
}
const ICON_GLYPH := {
	"empty": "box", "low": "box", "noproduct": "plus", "price": "tag", "cheap": "tag", "wait": "clock", "happy": "heart", "angry": "alert",
	"notfound": "info", "dirty": "broom", "crowd": "people", "wallet": "coin", "queue": "people", "nocashier": "staff", "star": "star", "box": "box",
	"alarm": "shield", "sneak": "sneak", "slip": "drop", "tired": "tired", "wrench": "wrench", "shop": "shop", "food": "food", "fun": "fun",
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
var menu: Control
var menu_page := "main"
var toast: PanelContainer
var events_box: VBoxContainer
var event_bars := {} # event id -> ColorRect fill
var started := false
var _acc := 0.0
var _press_pos := Vector2.ZERO
var _pressing := false
var build_tab := "Teşhir"
var mall_tab := "Kiracılar"
var picks := {"indirim": [], "ucal": []}
var hire_shift := {} # candidate name -> shift
var hood_tab := "Defter"
var prod_tab := "Fiyatlar"
var cal_lbl: Label
var weather_icon: TextureRect
var quest_card: PanelContainer
var radio: PanelContainer
var radio_lbl: Label
var tutorial := Tutorial.new()
var tut_card: PanelContainer
var _tut_sig := -2
var word_card: PanelContainer
var _word_t := 0.0

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
	events_box = UIKit.vbox(8)
	events_box.anchor_left = 0.5; events_box.anchor_right = 0.5
	events_box.offset_left = -220; events_box.offset_right = 220; events_box.offset_top = 92
	events_box.custom_minimum_size = Vector2(440, 0)
	events_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(events_box)
	game.events_changed.connect(_render_events)
	radio = UIKit.card(Color(0.12, 0.16, 0.27, 0.92), 14, Vector4(12, 7, 14, 7), 8)
	radio.anchor_left = 0.5; radio.anchor_right = 0.5; radio.anchor_top = 1.0; radio.anchor_bottom = 1.0
	radio.offset_top = -150; radio.offset_left = -330; radio.offset_right = 330
	radio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rh := UIKit.hbox(10)
	var rb := PanelContainer.new(); rb.add_theme_stylebox_override("panel", UIKit.sb(Cfg.TERRA, 8, Color(0, 0, 0, 0), 0, 0, Vector4(6, 3, 6, 3)))
	rb.add_child(UIKit.label("RADYO KÖŞEBAŞI", 10, Color.WHITE, "body", 900)); rb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rh.add_child(rb)
	radio_lbl = UIKit.wrap(UIKit.label("", 13, Color.WHITE, "body", 700), 540)
	radio_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rh.add_child(radio_lbl)
	radio.add_child(rh); radio.visible = false
	root.add_child(radio)
	game.announced.connect(_announce)
	game.achievement.connect(_achievement)
	game.scenario_result.connect(_scenario_result)
	game.alert_added.connect(func(_a): _render_alerts())
	game.selection_changed.connect(func(): slot_picker = -1; insp_sig = ""; _render_inspector())
	game.day_ended.connect(_show_day_end)
	game.changed.connect(func(): panel_sig = "")
	game.placing_changed.connect(_render_place_hint)
	game.stage_changed.connect(func(): panel_sig = ""; _render_dock_state())
	game.floor_changed.connect(_render_dock_state)
	game.mall_changed.connect(func(): panel_sig = ""; insp_sig = "")
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
	quest_card = PanelContainer.new()
	quest_card.add_theme_stylebox_override("panel", UIKit.sb(Color(1.0, 0.98, 0.95, 0.94), 16, Color(0, 0, 0, 0), 0, 8, Vector4(12, 10, 12, 10)))
	quest_card.mouse_filter = Control.MOUSE_FILTER_STOP
	quest_card.tooltip_text = Loc.t("Görevler — Mahalle paneli (N)")
	quest_card.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: hood_tab = "Görevler"; toggle_panel("hood"))
	top_left.add_child(quest_card)
	tut_card = PanelContainer.new()
	tut_card.add_theme_stylebox_override("panel", UIKit.sb(Color("fff3d6"), 16, Cfg.MUSTARD, 3, 8, Vector4(12, 10, 12, 10)))
	tut_card.visible = false
	top_left.add_child(tut_card)
	top_left.move_child(tut_card, 1)
	# time
	var tp := _pill(Color("fffaf2"))
	tp.anchor_left = 0.5; tp.anchor_right = 0.5
	tp.offset_left = -270; tp.offset_right = 270; tp.offset_top = 16
	tp.custom_minimum_size = Vector2(540, 0)
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
	cal_lbl = UIKit.label("", 11, Cfg.INK3, "body", 800)
	tv.add_child(cal_lbl)
	th.add_child(tv)
	weather_icon = UIKit.icon("sun", 22, Cfg.MUSTARD)
	weather_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	th.add_child(weather_icon)
	var sp := UIKit.hbox(4)
	for v in [[0.0, "pause", "Duraklat (Boşluk)"], [1.0, "play", "Normal (1)"], [2.0, "fast", "Hızlı (2)"], [4.0, "fast", "Çok hızlı (3)"], [8.0, "fast", "Süper hızlı (4)"], [16.0, "fast", "Işık hızı (5)"]]:
		var b := Button.new()
		b.icon = UIKit.icon_tex(v[1]); b.tooltip_text = Loc.t(v[2]); b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(38, 34)
		b.add_theme_constant_override("icon_max_width", 16)
		if v[0] >= 4.0: b.text = str(int(v[0])); b.add_theme_font_size_override("font_size", 10)
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
		["staff", "staff", "Personel", "H"], ["campaign", "megaphone", "Kampanya", "K"], ["hood", "people", "Mahalle", "N"], ["mall", "mall", "AVM", "V"], ["finance", "chart", "Finans", "F"], ["growth", "arrowUp", "Gelişim", "U"],
		["|", "", "", ""], ["heat", "route", "Akış", "M"], ["security", "shield", "Güvenlik", "G"], ["floor", "floors", "Zemin Kat", "PgUp/PgDn"],
		["|", "", "", ""], ["menu", "settings", "Menü", "Esc"]]
	for it in items:
		if it[0] == "|":
			var s := VSeparator.new(); s.add_theme_constant_override("separation", 10); dock.add_child(s); continue
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(84, 62)
		b.tooltip_text = Loc.t("%s (%s)" % [it[2], it[3]])
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
	if id == "heat" or id == "security":
		game.set_overlay(id)
		_render_dock_state(); return
	if id == "floor":
		game.set_view_floor(1 - game.view_floor)
		_render_dock_state(); return
	if id == "menu":
		open_menu(); return
	toggle_panel(id)

func _render_dock_state() -> void:
	for id in dock_btns:
		var b: Button = dock_btns[id]
		if game != null:
			b.visible = not ((id == "mall" or id == "floor") and game.stage < 3) and not (id == "security" and game.stage < 1)
			if id == "floor": (b.get_meta("lbl") as Label).text = "1. Kat" if game.view_floor == 1 else "Zemin Kat"
		var on: bool = panel_id == id or (game != null and ((id == game.overlay_mode) or (id == "floor" and game.view_floor == 1)))
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
	day_lbl.text = Loc.t("Gün %d" % game.day)
	var sp: Dictionary = game.calendar.special(game.day)
	cal_lbl.text = Loc.t(game.calendar.label(game.day) + ((" · " + sp["name"]) if not sp.is_empty() else ""))
	var wi: Dictionary = game.calendar.weather_info()
	weather_icon.texture = UIKit.icon_tex(wi["icon"])
	weather_icon.modulate = {"sun": Cfg.MUSTARD, "cloud": Cfg.INK3, "rain": Cfg.BLUE, "snow": Color("7fb8e0")}.get(wi["icon"], Cfg.INK2)
	weather_icon.tooltip_text = Loc.t("Bugün: %s\nYarın: %s" % [wi["name"], game.calendar.weather_info(game.calendar.tomorrow)["name"]])
	_render_quests()
	_word_t -= 0.12
	if _word_t <= 0.0 and started:
		var k := Glossary.pop()
		if k != "": _show_word(k)
	if tutorial.check(self):
		GameAudio.play("good", -6.0)
		if not tutorial.active:
			_toast("Rehber tamam! Artık dükkân senin.")
			Settings.tutorial = false; Settings.save_settings()
	_render_tutorial()
	sun_icon.texture = UIKit.icon_tex("moon" if game.sky.night > 0.5 else "sun")
	var prog := clampf((game.clock - Cfg.DAY_OPEN) / float(Cfg.DAY_CLOSE - Cfg.DAY_OPEN), 0, 1)
	(day_prog.get_child(0) as Control).anchor_right = prog
	money_lbl.text = Cfg.fmt_money(game.money)
	# event cards sit top-centre, or just right of an open side panel so they never cover it
	if panel.visible and panel_id != "build":
		events_box.anchor_left = 0.0; events_box.anchor_right = 0.0
		events_box.offset_left = panel.position.x + panel.size.x + 14; events_box.offset_right = events_box.offset_left + 440
	else:
		events_box.anchor_left = 0.5; events_box.anchor_right = 0.5
		events_box.offset_left = -220; events_box.offset_right = 220
	for ev in game.neighbor_events:
		var bar = event_bars.get(ev["id"])
		if bar and is_instance_valid(bar): (bar as Control).anchor_right = clampf((ev["expires"] - game.abs_minutes()) / 60.0, 0.0, 1.0)
	var profit: int = game.stats["revenue"] - game.stats["purchases"] - game.stats["other"]
	money_delta.text = Loc.t("bugün %s%s" % ["+" if profit >= 0 else "", Cfg.fmt_money(profit)])
	rating_lbl.text = "%.1f" % game.rating
	var r := game.rating
	for i in 5: (rating_box.get_child(i) as TextureRect).modulate = Cfg.MUSTARD if r - i > 0.5 else Color(0.12, 0.16, 0.27, 0.18)
	var qn := 0
	for f in game.fixtures: qn += f.queue.size()
	inside_lbl.text = Loc.t("%d%s" % [game.customers_inside(), ("  · kuyruk %d" % qn) if qn > 0 else ""])
	for i in speed_btns.size():
		var on: bool = (game.paused and i == 0) or (not game.paused and [0.0, 1.0, 2.0, 4.0, 8.0, 16.0][i] == game.speed)
		speed_btns[i].add_theme_stylebox_override("normal", UIKit.sb(Cfg.INK if on else Color(1, 1, 1, 0), 10, Color(0, 0, 0, 0), 0, 0, Vector4(6, 4, 6, 4)))
		speed_btns[i].add_theme_color_override("icon_normal_color", Color.WHITE if on else Cfg.INK2)
		speed_btns[i].add_theme_color_override("font_color", Color.WHITE if on else Cfg.INK2)
	(top_left.get_child(0).find_child("StageLbl", true, false) as Label).text = Loc.t("%s · Aşama %d" % [DB.STAGES[game.stage]["name"], game.stage + 1])
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
	var srows := Scenarios.goal_rows(game) if not game.scenario.is_empty() else []
	var sig := str(gs) + str(game.can_expand()) + str(srows)
	if sig == _goal_sig: return
	_goal_sig = sig
	UIKit.clear(goal_card)
	var v := UIKit.vbox(6)
	if not srows.is_empty():
		var sd := Scenarios.get_def(game.scenario["id"])
		var hs := UIKit.hbox(8)
		hs.add_child(UIKit.icon(sd["icon"], 18, Cfg.VIOLET))
		hs.add_child(UIKit.label("%s · %s" % [sd["name"], sd["sub"]], 16, Cfg.INK, "display"))
		v.add_child(hs)
		for r in srows:
			var row := UIKit.hbox(6)
			var l := UIKit.label(r[1], 12, Cfg.INK2, "body", 700); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			var val := ""
			match r[0]:
				"rating": val = "%.1f / %.1f★" % [r[2], r[3]]
				"cash": val = "%s / %s" % [Cfg.fmt_money(r[2]), Cfg.fmt_money(r[3])]
				"days": val = "%d" % int(r[2])
				"rival": val = "%%%d / %%%d" % [int(r[2]), int(r[3])]
				_: val = "%d / %d" % [int(r[2]), int(r[3])]
			row.add_child(UIKit.label(val, 12, Cfg.BAD if r[0] == "days" and r[2] <= 3 else Cfg.INK, "body", 800))
			v.add_child(row)
			if r[0] != "days": v.add_child(UIKit.bar(float(r[2]) / maxf(0.01, float(r[3])), Cfg.VIOLET, 0, 6))
		goal_card.add_child(v); return
	if e == null:
		v.add_child(UIKit.label("Köşebaşı AVM açık!", 16, Cfg.INK, "display"))
		var occ := 0
		if game.mall: occ = game.mall.units.filter(func(u): return not u["tenant"].is_empty()).size()
		v.add_child(UIKit.wrap(UIKit.label("Kiracılar %d / 11 · AVM keyfi %.1f. Birimleri doldur, etkinlik planla, kiracıları mutlu tut." % [occ, game.mall.mood if game.mall else 0.0], 12, Cfg.INK2, "body", 700), 260))
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

## "New word" card: a Turkish word explained the first time an English player meets it
func _show_word(k: String) -> void:
	if word_card: word_card.queue_free()
	word_card = UIKit.card(Color("fff3d6"), 14, Vector4(14, 10, 14, 10), 10)
	var st: StyleBoxFlat = word_card.get_theme_stylebox("panel"); st.border_color = Cfg.MUSTARD; st.border_width_left = 5
	word_card.anchor_left = 1.0; word_card.anchor_right = 1.0; word_card.anchor_top = 1.0; word_card.anchor_bottom = 1.0
	word_card.offset_left = -380; word_card.offset_right = -18; word_card.offset_top = -250; word_card.offset_bottom = -130
	word_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UIKit.vbox(2)
	var h := UIKit.hbox(8)
	h.add_child(UIKit.icon("book", 16, Cfg.TERRA))
	h.add_child(UIKit.label("Yeni kelime", 11, Cfg.TERRA, "body", 900))
	v.add_child(h)
	v.add_child(UIKit.label(k, 22, Cfg.INK, "display"))
	v.add_child(UIKit.wrap(UIKit.label(Glossary.TERMS[k], 13, Cfg.INK2, "body", 700), 330))
	word_card.add_child(v)
	root.add_child(word_card)
	word_card.modulate.a = 0.0
	var tw := word_card.create_tween()
	tw.tween_property(word_card, "modulate:a", 1.0, 0.3); tw.tween_interval(8.0)
	tw.tween_property(word_card, "modulate:a", 0.0, 0.5)
	var wc := word_card
	tw.tween_callback(func(): if is_instance_valid(wc): wc.queue_free())
	_word_t = 9.0

func _announce(text: String) -> void:
	radio_lbl.text = Loc.t(text)
	radio.visible = true
	radio.modulate.a = 0.0
	var tw := radio.create_tween()
	tw.tween_property(radio, "modulate:a", 1.0, 0.3)
	tw.tween_interval(9.0)
	tw.tween_property(radio, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): radio.visible = false)
	GameAudio.play("bell", -12.0, 0.8)

func _achievement(id: String) -> void:
	var a := Progress.ach_def(id)
	if a.is_empty(): return
	game.alert("ach_" + id, "trophy", "Başarım açıldı: %s — %s" % [a["name"], a["desc"]], "good", null, 0.0)

func _render_tutorial() -> void:
	var cur := tutorial.current()
	var sig := tutorial.step if tutorial.active else -1
	if sig == _tut_sig: return
	_tut_sig = sig
	UIKit.clear(tut_card)
	tut_card.visible = not cur.is_empty()
	for id in dock_btns: (dock_btns[id] as Button).modulate = Color.WHITE
	if cur.is_empty(): return
	var v := UIKit.vbox(4)
	var h := UIKit.hbox(6)
	h.add_child(UIKit.icon("book", 16, Cfg.TERRA))
	var tl := UIKit.label("Rehber %d/%d · %s" % [tutorial.step + 1, Tutorial.STEPS.size(), cur["title"]], 14, Cfg.INK, "display"); tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tl)
	var x := Button.new(); x.flat = true; x.icon = UIKit.icon_tex("close"); x.focus_mode = Control.FOCUS_NONE; x.tooltip_text = Loc.t("Rehberi kapat")
	x.add_theme_constant_override("icon_max_width", 12)
	x.pressed.connect(func(): tutorial.active = false; _tut_sig = -2; Settings.tutorial = false; Settings.save_settings())
	h.add_child(x)
	v.add_child(h)
	v.add_child(UIKit.wrap(UIKit.label(cur["text"], 12, Cfg.INK2, "body", 700), 260))
	tut_card.add_child(v)
	if cur["dock"] != "" and dock_btns.has(cur["dock"]):
		var b: Button = dock_btns[cur["dock"]]
		var tw := b.create_tween().set_loops(8)
		tw.tween_property(b, "modulate", Color(1.6, 1.3, 0.8), 0.45)
		tw.tween_property(b, "modulate", Color.WHITE, 0.45)

func _scenario_result(res: String) -> void:
	var id: String = game.scenario.get("id", "")
	var d := Scenarios.get_def(id)
	if res == "win":
		Progress.give_medal(id)
		if Progress.unlock(id): _achievement(id)
	UIKit.clear(modal)
	modal.visible = true
	game.paused = true
	var dim := ColorRect.new(); dim.color = Color(0.12, 0.16, 0.27, 0.5); dim.set_anchors_preset(Control.PRESET_FULL_RECT); modal.add_child(dim)
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", UIKit.sb(Color("fffaf2"), 24, Color(0, 0, 0, 0), 0, 24, Vector4(30, 26, 30, 26)))
	c.custom_minimum_size = Vector2(520, 0)
	var v := UIKit.vbox(12)
	v.add_child(UIKit.icon("trophy" if res == "win" else "alert", 56, Cfg.MUSTARD if res == "win" else Cfg.BAD))
	var t := UIKit.label(("%s kazanıldı!" if res == "win" else "%s kaybedildi") % d["name"], 34, Cfg.INK, "display"); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	v.add_child(UIKit.wrap(UIKit.label("Madalya mahalle haritasına eklendi. Başka bir mahallede şansını dene ya da burada devam et." if res == "win" else "Hedefe ulaşamadın. Yeniden dene ya da haritadan başka bir mahalle seç.", 14, Cfg.INK2, "body", 700), 460))
	var bh := UIKit.hbox(8)
	var b1 := UIKit.button("Burada devam et", "play", res == "win"); b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b1.pressed.connect(func(): modal.visible = false; game.scenario = {}; game.paused = false)
	var b2 := UIKit.button("Mahalle haritası", "map", res != "win"); b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b2.pressed.connect(func(): modal.visible = false; open_menu("map"))
	bh.add_child(b1); bh.add_child(b2); v.add_child(bh)
	c.add_child(v); modal.add_child(c)
	c.reset_size(); c.position = (root.get_viewport_rect().size - c.size) * 0.5

var _quest_sig := ""
func _render_quests() -> void:
	var sig := ""
	for q in game.quests.active: sig += "%d:%d," % [q["id"], int(game.quests.progress(game, q) * 40)]
	if sig == _quest_sig: return
	_quest_sig = sig
	UIKit.clear(quest_card)
	quest_card.visible = not game.quests.active.is_empty()
	var v := UIKit.vbox(2)
	var h := UIKit.hbox(6)
	h.add_child(UIKit.icon("flag", 15, Cfg.TERRA))
	h.add_child(UIKit.label("Görevler", 14, Cfg.INK, "display"))
	v.add_child(h)
	for q in game.quests.active: v.add_child(HudExtra.quest_card(q, game, false))
	quest_card.add_child(v)

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
		chip.add_child(UIKit.icon(ICON_GLYPH.get(a["icon"], a["icon"]), 16, Color.WHITE))
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
	if id != panel_id: GameAudio.play("ui", -6.0)
	if id != "build" and not game.placing.is_empty(): game.cancel_placement()
	panel_id = id
	panel_sig = ""
	panel.visible = id != ""
	_render_dock_state()
	if id != "": _render_panel()

func _sig_panel() -> String:
	match panel_id:
		"build": return "%s|%d|%d|%s|%s" % [build_tab, int(game.money / 100), game.stage, game.placing.is_empty(), str(game.vouchers)]
		"products":
			var s := prod_tab + str(game.product_log.size()) + str(game.cost_mul)
			for p in game.unlocked_products(): s += "%s%d%d%d%d," % [p["id"], game.prices[p["id"]], game.shelf_stock(p["id"]), game.backstock[p["id"]], game.stats["sold"].get(p["id"], 0)]
			return s
		"supply":
			var s2 := "%d|%d" % [game.backstock_total(), game.incoming_total()]
			for p in game.unlocked_products(): s2 += "%d%s" % [game.backstock[p["id"]], game.auto[p["id"]]]
			return s2
		"staff":
			var s3 := str(game.candidates.size())
			for s in game.staff: s3 += s.activity + str(s.get_instance_id()) + s.shift + str(int(s.energy / 10)) + str(s.present)
			return s3 + str(int(game.money / 100)) + str(hire_shift)
		"finance": return "%d|%d|%d|%s|%d" % [game.stats["revenue"], game.stats["purchases"], game.history.size(), str(game.loan), int(game.money / 500)]
		"hood":
			var s5: String = hood_tab + game.neighborhood.mode + str(game.neighborhood.limit) + str(game.neighborhood.total_debt()) + str(game.stats["credit_paid"]) + str(int(game.money / 200))
			for r in game.neighborhood.residents: s5 += str(int(float(r["loyalty"]) / 5)) + str(r["reminded"]) + str(r["request"].size()) + str(r["last"])
			for q in game.quests.active: s5 += str(q["id"]) + str(int(game.quests.progress(game, q) * 20))
			if game.rival.active: s5 += str(game.rival.lost_today) + str(game.rival.prices) + str(game.prices)
			return s5
		"growth": return "%d|%d|%s|%s|%s" % [int(game.money / 100), game.stage, str(game.upgrades.keys()), game.can_expand(), str(game.style)]
		"campaign": return "%s|%s|%s|%d" % [str(game.campaigns.keys()), str(game.discounts + game.multi), str(picks), int(game.money / 100)]
		"mall":
			if game.mall == null: return ""
			var s4: String = mall_tab + str(int(game.money / 100)) + str(game.mall.scheduled) + str(game.mall.event.get("def", {}).get("id", ""))
			for u in game.mall.units: s4 += str(u["tenant"].get("def", {}).get("id", "")) + str(int(u["tenant"].get("sat", 0.0) / 5)) + str(u["offers"].size())
			for c in game.mall.connectors: s4 += str(c["broken"]) + str(c["repair_t"] > 0.0)
			return s4
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
		panel.position = Vector2(18, 92)
		panel.size = Vector2(panel.custom_minimum_size.x, vs.y - 92 - 116)

func _render_panel() -> void:
	match panel_id:
		"build": _p_build()
		"products": _p_products()
		"supply": _p_supply()
		"staff": _p_staff()
		"finance": _p_finance()
		"growth": _p_growth()
		"campaign": _p_campaign()
		"mall": _p_mall()
		"hood":
			var body := _frame("Mahalle", "Komşular, veresiye defteri, görevler ve karşıdaki rakip.", "people", Color("b0546a"), 760)
			HudExtra.hood(self, body)
	_place_panel(panel_id == "build")

# ---------------------------------------------------------------- build
func _p_build() -> void:
	var sub := "Bir eşya seç, dükkânda yerine tıkla. R: döndür · Shift+tık: arka arkaya · Esc: iptal"
	if game.stage >= 3: sub = "Şu an %s görünüyor, eşya bu kata yerleşir. AVM eşyaları koridora ve yemek katına, market eşyaları süpermarkete. PgUp/PgDn: kat değiştir." % ("1. kat" if game.view_floor == 1 else "zemin kat")
	var body := _frame("İnşa", sub, "build", Cfg.TERRA, 940)
	var tabs := UIKit.hbox(6)
	var tab_list := ["Teşhir", "Kasa & Depo", "Ortam", "Güvenlik & Personel"]
	if game.stage >= 2: tab_list.insert(2, "Odalar")
	if game.stage >= 3: tab_list.append("AVM")
	for t in tab_list:
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
		card.tooltip_text = Loc.t(d["desc"])
		var v := UIKit.vbox(2); v.set_anchors_preset(Control.PRESET_FULL_RECT); v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.offset_left = 8; v.offset_top = 8; v.offset_right = -8; v.offset_bottom = -8
		var img := TextureRect.new(); img.custom_minimum_size = Vector2(124, 96); img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.texture = thumbs.fixtures.get(d["id"])
		var imgbg := PanelContainer.new(); imgbg.add_theme_stylebox_override("panel", UIKit.sb(Color("f6ecde"), 12, Color(0, 0, 0, 0), 0, 0, Vector4(0, 0, 0, 0))); imgbg.add_child(img); imgbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(imgbg)
		v.add_child(UIKit.label(d["name"], 14, Cfg.INK, "body", 800))
		v.add_child(UIKit.label("%d×%d m%s" % [d["w"], d["d"], (" · %d bölme" % d["slots"]) if d.has("slots") else ""], 11, Cfg.INK3, "body", 700))
		var vch := int(game.vouchers.get(d["id"], 0))
		if vch > 0: poor = false
		var pr := UIKit.label(("Bedava ×%d" % vch) if vch > 0 and not locked else (Cfg.fmt_money(d["cost"]) if not locked else "%s aşamasında" % DB.STAGES[d["stage"]]["name"]), 18 if not locked else 12, Cfg.GOOD if vch > 0 else (Cfg.BAD if poor else Cfg.TERRA), "display" if not locked else "body", 800)
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
	var body := _frame("Ürün & Fiyat", "Her arketip farklı fiyat toleransına sahip. Pahalı ürün satılmaz, ucuz ürün kâr bırakmaz.", "tag", Cfg.TEAL, 880)
	body.add_child(HudExtra._tabs(self, prod_tab, ["Fiyatlar", "Analiz"], func(t): prod_tab = t; panel_sig = ""))
	if prod_tab == "Analiz":
		HudExtra.analysis(self, body); return
	var infl: float = game.pending_inflation()
	if infl > 0.005:
		var ib := UIKit.hbox(10)
		ib.add_child(UIKit.icon("chart", 18, Cfg.WARN))
		var il := UIKit.wrap(UIKit.label("Son fiyat güncellemesinden beri toptancı fiyatları %%%.1f arttı; müşteriler de buna alıştı." % (infl * 100.0), 12, Cfg.INK, "body", 800), 520)
		il.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ib.add_child(il)
		var ub := UIKit.button("Tüm fiyatları %%%.0f artır" % ceilf(infl * 100.0), "arrowUp", true, true)
		ub.pressed.connect(func(): game.apply_inflation_to_prices())
		ib.add_child(ub)
		body.add_child(ib)
	var head := UIKit.hbox(8)
	for c in [["", 44], ["ÜRÜN", 150], ["FİYAT", 150], ["KİM ALIR?", 190], ["RAF", 56], ["DEPO", 56], ["SATIŞ", 56]]:
		var l := UIKit.label(c[0], 11, Cfg.INK3, "body", 800); l.custom_minimum_size.x = c[1]; head.add_child(l)
	body.add_child(head)
	for p in game.unlocked_products():
		var pid: String = p["id"]
		var row := UIKit.hbox(8)
		var img := TextureRect.new(); img.custom_minimum_size = Vector2(44, 44); img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.texture = thumbs.products.get(pid); row.add_child(img)
		var gl := Glossary.note(Loc.t(p["name"]))
		if gl != "": img.tooltip_text = gl; img.mouse_filter = Control.MOUSE_FILTER_PASS
		var nv := UIKit.vbox(-2); nv.custom_minimum_size.x = 150
		nv.add_child(UIKit.label(p["name"], 15, Cfg.INK, "body", 800))
		nv.add_child(UIKit.label("%s · maliyet ₺%d" % [DB.DISPLAY_LABEL[p["display"]], game.cost_of(pid)], 11, Cfg.INK3, "body", 700))
		row.add_child(nv)
		var ph := UIKit.hbox(4); ph.custom_minimum_size.x = 150
		var minus := UIKit.button("", "minus", false, true); minus.pressed.connect(func(): game.set_price(pid, game.prices[pid] - 1))
		var plus := UIKit.button("", "plus", false, true); plus.pressed.connect(func(): game.set_price(pid, game.prices[pid] + 1))
		ph.add_child(minus)
		var pv := UIKit.vbox(-4); pv.custom_minimum_size.x = 58
		var price: int = game.prices[pid]
		var pl := UIKit.label("₺%d" % price, 20, Cfg.INK, "display"); pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; pv.add_child(pl)
		var margin := int(round((price - game.cost_of(pid)) * 100.0 / price))
		var ml := UIKit.label("%%%d kâr" % margin, 10, Cfg.GOOD if margin > 30 else Cfg.WARN, "body", 800); ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; pv.add_child(ml)
		ph.add_child(pv); ph.add_child(plus)
		row.add_child(ph)
		var acc := HFlowContainer.new(); acc.custom_minimum_size.x = 190
		acc.add_theme_constant_override("h_separation", 3); acc.add_theme_constant_override("v_separation", 3)
		for a in DB.ARCHETYPES:
			if a["stage"] > game.stage or not a["wants"].has(pid): continue
			var ok: bool = price <= game.ref_price(pid) * (1.0 + a["tol"] + game.tolerance_bonus())
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
	var body := _frame("Tedarik", "Depo: %d / %d birim · yolda %d. Toptancı her sabah açılışta bir kez gelir; verdiğin siparişler ertesi sabah teslim edilir. Oto: her akşam 18:00'de yarının ihtiyacını sipariş eder. Acil sipariş 1 saatte gelir ama %%25 pahalıdır." % [game.backstock_total(), cap, game.incoming_total()], "truck", Cfg.BLUE, 720)
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
		for q in [12, 24, 48]:
			var b := UIKit.button("+%d" % q, "", false, true)
			b.tooltip_text = Loc.t("₺%d · yarın sabahki teslimatla gelir" % (q * game.cost_of(pid)))
			var qq: int = q
			b.pressed.connect(func(): game.order(pid, qq))
			row.add_child(b)
		var ub := UIKit.button("Acil +12", "", false, true)
		ub.tooltip_text = Loc.t("₺%d · 1 saat içinde ayrı minibüsle gelir (%%25 pahalı)" % int(round(12 * game.cost_of(pid) * 1.25)))
		ub.add_theme_color_override("font_color", Cfg.TERRA)
		ub.pressed.connect(func(): game.order(pid, 12, false, true))
		row.add_child(ub)
		var tg := CheckButton.new(); tg.text = Loc.t("Oto"); tg.button_pressed = game.auto[pid]; tg.focus_mode = Control.FOCUS_NONE
		tg.add_theme_font_size_override("font_size", 12)
		tg.toggled.connect(func(on): game.auto[pid] = on)
		row.add_child(tg)
		body.add_child(row)
		body.add_child(UIKit.sep_h())

# ---------------------------------------------------------------- staff
func _p_staff() -> void:
	var body := _frame("Personel", "Günlük maaş toplamı %s, gün sonunda ödenir. Yarım vardiya %%60 maaş alır; yorgun personel yavaşlar." % Cfg.fmt_money(game.wages_per_day()), "staff", Cfg.VIOLET, 700)
	body.add_child(UIKit.section("Ekip"))
	for s in game.staff:
		var row := UIKit.hbox(10)
		var chip := PanelContainer.new(); chip.add_theme_stylebox_override("panel", UIKit.sb(s.view.mat.get_shader_parameter("c_top"), 22, Color(0, 0, 0, 0), 0, 0, Vector4(9, 9, 9, 9)))
		chip.add_child(UIKit.icon("staff", 22, Color.WHITE)); row.add_child(chip)
		var nv := UIKit.vbox(-2); nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nv.add_child(UIKit.label(s.person_name, 16, Cfg.INK, "body", 800))
		nv.add_child(UIKit.label("%s · %s" % [DB.ROLE_LABEL[s.role], s.activity if s.present else "vardiya dışında"], 12, Cfg.INK2, "body", 700))
		if s.role != "owner":
			var th := UIKit.hbox(6)
			if s.persona != "":
				var tc := UIKit.chip(s.trait_name(), Cfg.TEAL if DB.TRAITS[s.persona]["good"] else Cfg.WARN, Color.WHITE, 10); tc.tooltip_text = Loc.t(DB.TRAITS[s.persona]["desc"])
				th.add_child(tc)
			th.add_child(UIKit.label("beceri %d%% · moral %d · %d gün" % [int(s.skill * 100), int(s.morale), s.days_worked], 11, Cfg.BAD if s.morale < 35 else Cfg.INK3, "body", 800))
			if s.quit_day >= 0: th.add_child(UIKit.chip("istifa etti", Cfg.BAD, Color.WHITE, 10))
			nv.add_child(th)
		var eh := UIKit.hbox(6)
		eh.add_child(UIKit.icon("tired" if s.tired() else "sun", 12, Cfg.BAD if s.tired() else Cfg.MUSTARD))
		var eb := UIKit.bar(s.energy / 100.0, Cfg.BAD if s.tired() else (Cfg.WARN if s.energy < 55 else Cfg.GOOD), 110, 6); eb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		eh.add_child(eb)
		eh.add_child(UIKit.label("enerji %d" % int(s.energy), 11, Cfg.INK3, "body", 800))
		nv.add_child(eh)
		row.add_child(nv)
		var sref: Staff = s
		if s.role != "owner": row.add_child(_shift_seg(s.shift, func(sh): game.set_shift(sref, sh)))
		row.add_child(UIKit.label(Cfg.fmt_money(s.wage) if s.wage > 0 else "sahip", 15, Cfg.INK2, "display"))
		if s.role != "owner":
			var tb := UIKit.button("Eğit", "book", false, true)
			tb.tooltip_text = Loc.t("Kurs ve usta yanında pratik: beceri +8, moral +8. %s · 3 günde bir." % Cfg.fmt_money(300 * (game.stage + 1)))
			tb.disabled = game.money < 300 * (game.stage + 1) or game.day - s.trained_day < 3 or s.skill >= 1.45
			var sref2: Staff = s
			tb.pressed.connect(func(): game.train(sref2))
			row.add_child(tb)
			var f := UIKit.button("", "close", false, true); f.tooltip_text = Loc.t("İşten çıkar")
			var ss: Staff = s
			f.pressed.connect(func(): game.fire(ss))
			row.add_child(f)
		body.add_child(row)
	body.add_child(UIKit.sep_h())
	var tired_n := game.staff.filter(func(x): return x.tired()).size()
	if tired_n > 0 and not game.fixtures.any(func(f): return f.def["kind"] == "break"):
		body.add_child(UIKit.wrap(UIKit.label("%d kişi yorgun ve yavaşladı. Bir Çay Ocağı kur ya da vardiyaları böl (Sabah + Akşam)." % tired_n, 12, Cfg.BAD, "body", 800), 600))
	body.add_child(UIKit.section("Adaylar (her sabah yenilenir)"))
	for c in game.candidates:
		var row := UIKit.hbox(10)
		var nv := UIKit.vbox(-2); nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nv.add_child(UIKit.label("%s — %s" % [c["name"], DB.ROLE_LABEL[c["role"]]], 15, Cfg.INK, "body", 800))
		nv.add_child(UIKit.wrap(UIKit.label(DB.ROLE_DESC[c["role"]], 11, Cfg.INK3, "body", 700), 330))
		var ch := UIKit.hbox(6)
		ch.add_child(UIKit.label("Beceri %d%%" % int(c["skill"] * 100), 11, Cfg.TEAL, "body", 800))
		var ctr: String = c.get("trait", "")
		if ctr != "":
			var tc2 := UIKit.chip(DB.TRAITS[ctr]["name"], Cfg.TEAL if DB.TRAITS[ctr]["good"] else Cfg.WARN, Color.WHITE, 10)
			ch.add_child(tc2)
			ch.add_child(UIKit.label(DB.TRAITS[ctr]["desc"], 10, Cfg.INK3, "body", 700))
		nv.add_child(ch)
		row.add_child(nv)
		var cc: Dictionary = c
		var key: String = c["name"]
		var sh: String = hire_shift.get(key, "full")
		row.add_child(_shift_seg(sh, func(x): hire_shift[key] = x; panel_sig = ""))
		var b := UIKit.button("İşe al · " + Cfg.fmt_money(int(round(c["wage"] * DB.SHIFT_WAGE[sh]))), "plus", true, true)
		b.pressed.connect(func(): game.hire(cc, false, sh))
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
	body.add_child(UIKit.section("Faturalar (gün sonunda)"))
	var ut := UIKit.hbox(10)
	ut.add_child(UIKit.icon("bolt", 18, Cfg.MUSTARD))
	var pb: Array = game.power_breakdown()
	var ptxt := "Elektrik, su, doğalgaz: %s/gün." % Cfg.fmt_money(game.utilities())
	if not pb.is_empty(): ptxt += " En çok yakan: " + ", ".join(pb.slice(0, 3).map(func(x): return "%s ₺%d" % [x[0], x[1]]))
	if not game.upgrades.has("gunes") and game.stage >= 1: ptxt += ". Çatıya güneş paneli faturayı %40 düşürür (Gelişim)."
	ut.add_child(UIKit.wrap(UIKit.label(ptxt, 12, Cfg.INK2, "body", 800), 400))
	body.add_child(ut)
	if game.cost_mul > 1.001:
		body.add_child(UIKit.label("Toptancı fiyat endeksi: %d (başlangıç 100)" % int(round(game.cost_mul * 100.0)), 12, Cfg.WARN, "body", 800))
	body.add_child(UIKit.section("Mahalle Bankası"))
	if game.loan.is_empty():
		body.add_child(UIKit.wrap(UIKit.label("Büyümek için nakit mi lazım? Kredi hemen gelir, taksitler her gün sonunda düşülür.", 12, Cfg.INK2, "body", 700), 440))
		for i in DB.LOANS.size():
			var l: Dictionary = DB.LOANS[i]
			var row := UIKit.hbox(8)
			var lt := UIKit.label("%s · %d gün · faiz %%%d · günlük %s" % [Cfg.fmt_money(l["amount"]), l["days"], int(l["rate"] * 100), Cfg.fmt_money(ceilf(l["amount"] * (1.0 + l["rate"]) / l["days"]))], 13, Cfg.INK if l["stage"] <= game.stage else Cfg.INK3, "body", 800)
			lt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(lt)
			var b := UIKit.button("Çek" if l["stage"] <= game.stage else DB.STAGES[l["stage"]]["short"] + "'te", "bank", l["stage"] <= game.stage, true)
			b.disabled = l["stage"] > game.stage
			var ii: int = i
			b.pressed.connect(func(): game.take_loan(ii))
			row.add_child(b)
			body.add_child(row)
	else:
		var row2 := UIKit.hbox(8)
		var lt2 := UIKit.label("Kalan borç %s · günlük taksit %s" % [Cfg.fmt_money(game.loan["left"]), Cfg.fmt_money(game.loan["daily"])], 14, Cfg.VIOLET, "body", 900)
		lt2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(lt2)
		var rb := UIKit.button("Erken kapat", "check", true, true)
		rb.disabled = game.money < game.loan["left"]
		rb.pressed.connect(func(): game.repay_loan())
		row2.add_child(rb)
		body.add_child(row2)
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
	body.add_child(UIKit.section("Dükkânın rengi (ücretsiz)"))
	for row in [["wall", "Duvar", ShopShell.WALLS], ["floor", "Zemin", ShopShell.FLOORS], ["awning", "Tente", ShopShell.AWNINGS]]:
		var h := UIKit.hbox(6)
		var rl := UIKit.label(row[1], 13, Cfg.INK, "body", 800); rl.custom_minimum_size.x = 60; h.add_child(rl)
		var key: String = row[0]
		var pal: Array = row[2]
		for i in pal.size():
			var sw := Button.new(); sw.focus_mode = Control.FOCUS_NONE; sw.custom_minimum_size = Vector2(34, 28)
			sw.tooltip_text = Loc.t(pal[i][0])
			var on: bool = int(game.style.get(key, 0)) == i
			var c1: Color = pal[i][1]
			sw.add_theme_stylebox_override("normal", UIKit.sb(c1, 8, Cfg.INK if on else Color(0, 0, 0, 0.1), 3 if on else 1, 0, Vector4(0, 0, 0, 0)))
			sw.add_theme_stylebox_override("hover", UIKit.sb(c1.lightened(0.1), 8, Cfg.TERRA, 2, 0, Vector4(0, 0, 0, 0)))
			if pal[i].size() > 2:
				var inner := ColorRect.new(); inner.color = pal[i][2]; inner.custom_minimum_size = Vector2(12, 12)
				inner.position = Vector2(11, 8); inner.mouse_filter = Control.MOUSE_FILTER_IGNORE; sw.add_child(inner)
			var ii: int = i
			sw.pressed.connect(func(): game.set_style(key, ii); panel_sig = "")
			h.add_child(sw)
		body.add_child(h)
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
	var kind: String = game.selection.get("kind", "")
	var o = game.selection.get("obj")
	if kind == "unit": return "u%s|%d|%d|%d|%s" % [str(o["tenant"].get("def", {}).get("id", "")), int(o["tenant"].get("sat", 0.0)), int(o["tenant"].get("sales", 0)), o["offers"].size(), str(o["tenant"].get("reasons", []).size())]
	if kind == "connector": return "c%s|%s" % [o["broken"], o["repair_t"] > 0.0]
	if kind == "puddle": return "p%s|%s|%s" % [o["dry"] > 0.0, o.get("sign") != null, int(o["claimed"]) != 0]
	if o == null or not is_instance_valid(o): return "none"
	if o is Visitor: return "%s|%d|%d|%d" % [o.state, int(o.mood / 3), o.spent, o.thoughts.size()]
	if o is Fixture:
		var s := "%d|%d|%s" % [slot_picker, o.queue.size(), o.status_kind]
		for sl in o.slots: s += "%s%d" % [sl["pid"], sl["stock"]]
		return s
	if o is Customer: return "%s|%d|%d|%d|%d" % [o.state, int(o.mood / 3), o.basket.size(), o.thoughts.size(), o.queue_idx]
	if o is Staff: return "%s|%s" % [o.activity, str(o.task != null)]
	return ""

func _render_inspector() -> void:
	var o = game.selection.get("obj")
	var kind: String = game.selection.get("kind", "")
	UIKit.clear(inspector)
	var dict_sel := kind in ["unit", "connector", "puddle"]
	if o == null or (not dict_sel and not is_instance_valid(o)):
		inspector.visible = false; return
	inspector.visible = true
	var v := UIKit.vbox(0)
	inspector.add_child(v)
	if kind == "unit": _insp_unit(v, o)
	elif kind == "connector": _insp_connector(v, o)
	elif kind == "puddle": _insp_puddle(v, o)
	elif o is Visitor: _insp_visitor(v, o)
	elif o is Fixture: _insp_fixture(v, o)
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
				if DB.BAKERY.has(s["pid"]) and int(s["stock"]) > 0:
					var fr: float = game.slot_fresh(s)
					top.add_child(UIKit.chip("sıcacık" if fr >= 0.75 else ("taze" if fr >= 0.3 else "bayat"), Cfg.GOOD if fr >= 0.75 else (Cfg.MUSTARD if fr >= 0.3 else Cfg.BAD), Color.WHITE, 10))
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
					var pb := Button.new(); pb.focus_mode = Control.FOCUS_NONE; pb.tooltip_text = Loc.t("%s · ₺%d" % [p["name"], game.prices[p["id"]]])
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
	elif d["kind"] == "oven":
		b.add_child(UIKit.section("Fırın"))
		b.add_child(UIKit.label("Fırıncı: " + ("var" if game.has_role("baker") else "yok, Personel panelinden al"), 14, Cfg.INK if game.has_role("baker") else Cfg.BAD, "body", 800))
		b.add_child(UIKit.label("Durum: " + ("pişiyor" if f.baking else "bekliyor"), 14, Cfg.INK, "body", 800))
		if not (game.is_stocked("simit") or game.is_stocked("ekmek")):
			b.add_child(UIKit.wrap(UIKit.label("Pişen simit ve ekmek depoya gider. Satmak için bir Fırın Sepeti kurup bölmesine simit ya da ekmek ata.", 12, Cfg.BAD, "body", 800), 310))
		else:
			b.add_child(UIKit.wrap(UIKit.label("Fırıncı depoda simit/ekmek azalınca pişirir; toptancıdan almaktan ucuzdur ve müşteriye \"sıcacık\" keyfi verir. Gece fırıncı sabahın ekmeğini pişirir.", 12, Cfg.INK2, "body", 700), 310))
		_evening_toggle(b)
	elif d["kind"] == "depot":
		b.add_child(UIKit.section("Depo"))
		if d.get("cold", false): b.add_child(UIKit.wrap(UIKit.label("Soğuk oda var: depodaki süt, ayran, peynir ve içecekler gece bozulmaz.", 12, Cfg.TEAL, "body", 800), 310))
		elif game.stage >= 1 and not game.has_cold_room(): b.add_child(UIKit.wrap(UIKit.label("Soğuk oda yok: depodaki soğuk ürünlerin %30'u her gece bozulur.", 12, Cfg.WARN, "body", 800), 310))
		b.add_child(UIKit.label("%d / %d birim dolu" % [game.backstock_total(), game.depot_capacity()], 16, Cfg.INK, "display"))
		b.add_child(UIKit.bar(float(game.backstock_total()) / maxf(1, game.depot_capacity()), Cfg.BLUE, 0, 8))
	var acts := UIKit.hbox(6)
	var mv := UIKit.button("Taşı", "move", false, true); mv.pressed.connect(func(): game.start_placement(d["id"], f); open_panel("build"))
	if d.get("display", "") == "basket": _evening_toggle(b)
	var sl := UIKit.button("Sat · " + Cfg.fmt_money(int(d["cost"] * 0.5)), "trash", false, true); sl.pressed.connect(func(): game.sell_fixture(f))
	var cp := UIKit.button("Kopyala", "copy", false, true); cp.tooltip_text = Loc.t("Aynısından bir tane daha: yön ve ürünler kopyalanır (Ctrl+D)")
	cp.pressed.connect(func(): game.copy_fixture(f); open_panel("build"))
	acts.add_child(mv); acts.add_child(cp); acts.add_child(sl)
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
	if not c.resident.is_empty():
		var r: Dictionary = c.resident
		var rc := UIKit.card(Color(0.69, 0.33, 0.42, 0.1), 12, Vector4(10, 8, 10, 8), 0)
		var rv := UIKit.vbox(2)
		rv.add_child(UIKit.label("Müdavim · sadakat %d%s" % [int(r["loyalty"]), (" · borç " + Cfg.fmt_money(r["debt"])) if int(r["debt"]) > 0 else ""], 13, Color("8a3b50"), "body", 900))
		rv.add_child(UIKit.wrap(UIKit.label(r["quirk"], 12, Cfg.INK2, "body", 700), 290))
		if not r["request"].is_empty(): rv.add_child(UIKit.label("İstediği: " + DB.product(r["request"]["pid"])["name"], 12, Cfg.VIOLET, "body", 800))
		rc.add_child(rv); b.add_child(rc)
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
	if s.persona != "": b.add_child(UIKit.wrap(UIKit.label("%s: %s" % [s.trait_name(), DB.TRAITS[s.persona]["desc"]], 12, Cfg.TEAL, "body", 800), 310))
	if s.role != "owner": b.add_child(UIKit.label("Moral %d · %d gündür burada" % [int(s.morale), s.days_worked], 12, Cfg.INK2, "body", 800))
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
	var keys := UIKit.label("Sol tık: yerleştir · R: döndür · Sağ tık/Esc: iptal · Ctrl+Z: geri al", 12, Color(1, 1, 1, 0.8), "body", 700)
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(keys)
	place_hint.add_child(h)
	place_hint.reset_size()
	var vs := root.get_viewport_rect().size
	place_hint.position = Vector2((vs.x - place_hint.size.x) * 0.5, vs.y - 180)

# ================================================================== world input
func _unhandled_input(e: InputEvent) -> void:
	if not started: return
	if menu != null and menu.visible:
		if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE: close_menu()
		return
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
			elif not game.selection.is_empty(): game.select({})
			else: open_menu()
		KEY_SPACE: set_speed(game.speed if game.paused else 0.0)
		KEY_1: set_speed(1.0)
		KEY_2: set_speed(2.0)
		KEY_3: set_speed(4.0)
		KEY_4: set_speed(8.0)
		KEY_5: set_speed(16.0)
		KEY_B: toggle_panel("build")
		KEY_P: toggle_panel("products")
		KEY_T: toggle_panel("supply")
		KEY_H: toggle_panel("staff")
		KEY_F: toggle_panel("finance")
		KEY_U: toggle_panel("growth")
		KEY_M: _dock_pressed("heat")
		KEY_G: if game.stage >= 1: _dock_pressed("security")
		KEY_K: toggle_panel("campaign")
		KEY_N: toggle_panel("hood")
		KEY_V: if game.stage >= 3: toggle_panel("mall")
		KEY_PAGEUP, KEY_BRACKETRIGHT: game.set_view_floor(game.view_floor + 1)
		KEY_PAGEDOWN, KEY_BRACKETLEFT: game.set_view_floor(game.view_floor - 1)
		KEY_R: game.rotate_placement()
		KEY_Z:
			if k.ctrl_pressed or k.meta_pressed:
				if game.undo(): _toast("Geri alındı")
		KEY_D:
			if (k.ctrl_pressed or k.meta_pressed) and game.selection.get("obj") is Fixture:
				game.copy_fixture(game.selection["obj"]); open_panel("build")
		KEY_C: game.shop.cutaway = not game.shop.cutaway

func _click(pos: Vector2, shift: bool) -> void:
	if not game.placing.is_empty():
		game.confirm_placement(shift); return
	var hit := game.pick(pos)
	if hit.has("litter"):
		game.remove_litter(hit["litter"]); game.float_text(Vector3(hit["ground"].x, 1.0, hit["ground"].z), "Temizlendi", Cfg.TEAL); return
	if hit.has("agent"): game.select({"kind": "agent", "obj": hit["agent"]}); return
	if hit.has("fixture"): game.select({"kind": "fixture", "obj": hit["fixture"]}); return
	if hit.has("puddle"): game.select({"kind": "puddle", "obj": hit["puddle"]}); return
	if hit.has("connector"): game.select({"kind": "connector", "obj": hit["connector"]}); return
	if hit.has("unit"): game.select({"kind": "unit", "obj": hit["unit"]}); return
	game.select({})

func _hover(pos: Vector2) -> void:
	var hit := game.pick(pos)
	var txt := ""
	game.overlays.hover_ring.visible = false
	if hit.has("agent"):
		var a = hit["agent"]
		game.overlays.hover_ring.visible = true
		game.overlays.hover_ring.position = a.position + Vector3(0, 0.05, 0)
		if a is Visitor:
			txt = "[b]%s[/b]\nAVM ziyaretçisi · %s · %s" % [a.person_name, a.arch["name"], a.status_label()]
		elif a is Customer:
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
	elif hit.has("puddle"):
		txt = "[b]Islak zemin[/b]\nKayma riski! Temizlik görevlisi paspaslar."
	elif hit.has("connector"):
		var c: Dictionary = hit["connector"]
		txt = "[b]%s[/b]\n%s" % [c["def"]["name"], ("[color=#ffb3a0]Arızalı, tıkla: tamir[/color]" if c["repair_t"] <= 0.0 else "Tamir ediliyor") if c["broken"] else "Çalışıyor"]
	elif hit.has("unit"):
		var u: Dictionary = hit["unit"]
		if u["tenant"].is_empty(): txt = "[b]Birim %s · KİRALIK[/b]\n%d teklif var, tıkla" % [u["def"]["id"], u["offers"].size()]
		else: txt = "[b]%s[/b]\n%s · memnuniyet %d" % [u["tenant"]["def"]["brand"], u["tenant"]["def"]["name"], int(u["tenant"]["sat"])]
	tooltip.visible = txt != ""
	tooltip_lbl.text = Loc.t(txt)
	var gnote := Glossary.note(tooltip_lbl.text)
	if gnote != "": tooltip_lbl.text += "\n[color=#f2d38a]" + gnote + "[/color]"
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
	var ms: Dictionary = r.get("mall", {})
	if not ms.is_empty():
		var g2 := GridContainer.new(); g2.columns = 3
		g2.add_theme_constant_override("h_separation", 8); g2.add_theme_constant_override("v_separation", 8)
		for kv in [["AVM kira + ciro payı", Cfg.fmt_money(ms["rent"] + ms["share"]), Cfg.GOOD], ["AVM ziyaretçisi", str(ms["visitors"]), Cfg.INK], ["AVM keyfi", "%.1f" % ms["mood"], Cfg.VIOLET]]:
			var cc2 := UIKit.card(Color(0.48, 0.35, 0.88, 0.08), 14, Vector4(12, 8, 12, 8), 0)
			var vv2 := UIKit.vbox(0)
			vv2.add_child(UIKit.label(kv[0], 12, Cfg.INK3, "body", 800))
			vv2.add_child(UIKit.label(kv[1], 20, kv[2], "display"))
			cc2.add_child(vv2); cc2.custom_minimum_size.x = 150
			g2.add_child(cc2)
		v.add_child(g2)
	var rh := UIKit.hbox(8); rh.alignment = BoxContainer.ALIGNMENT_CENTER
	rh.add_child(UIKit.stars(r["rating"], 22)); rh.add_child(UIKit.label("%.2f" % r["rating"], 20, Cfg.INK, "display"))
	v.add_child(rh)
	for tip in _insights(st, ms):
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

func _insights(st: Dictionary, ms := {}) -> Array:
	var out := []
	if st.get("theft_count", 0) > 0:
		out.append(["sneak", "%d hırsızlık oldu (₺%d kayıp). Kör noktalara kamera, kapıya alarm, içeriye güvenlik görevlisi. G tuşu kör noktaları gösterir." % [st["theft_count"], st["theft"]]])
	if st.get("slips", 0) > 0:
		out.append(["drop", "%d müşteri ıslak zeminde kaydı. Temizlik görevlisi paspaslar ve uyarı levhası koyar." % st["slips"]])
	if st.get("stale", 0) > 0:
		out.append(["box", "%d simit/ekmek satılamadan bayatladı (₺%d zarar). Fırın kartından akşam indirimini aç ya da daha az stokla." % [st["stale"], st["stale_cost"]]])
	if st.get("spoiled", 0) > 0:
		out.append(["snow", "Depodaki %d soğuk ürün bozuldu (₺%d). Bir Soğuk Oda kur." % [st["spoiled"], st["spoiled_cost"]]])
	if st.get("caught", 0) > 0:
		out.append(["shield", "%d hırsız yakalandı. Güvenlik yatırımı işe yarıyor." % st["caught"]])
	if not ms.is_empty() and ms.get("incidents", 0) > 0:
		out.append(["people", "Etkinlik kalabalığında %d arbede çıktı. Büyük etkinlikte güvenlik görevlisi şart." % ms["incidents"]])
	var tired := game.staff.filter(func(x): return x.tired()).size()
	if tired > 0: out.append(["tired", "%d personel gün sonunda bitkindi. Çay ocağı kur ya da vardiyaları böl." % tired])
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
	if st.get("rival_lost", 0) >= 5:
		out.append(["rival", "%d kişi bugün alışverişi karşıdaki UCUZA'da yaptı. Mahalle panelinden (N) fiyatları karşılaştır." % st["rival_lost"]])
	if st.get("credit", 0) > 0 or st.get("credit_paid", 0) > 0:
		out.append(["note", "Veresiye: bugün %s deftere yazıldı, %s tahsil edildi. Defterde toplam %s alacak var." % [Cfg.fmt_money(st["credit"]), Cfg.fmt_money(st["credit_paid"]), Cfg.fmt_money(game.neighborhood.total_debt())]])
	if out.is_empty(): out.append(["heart", "Sakin bir gün. Müşteriler aradığını buldu."])
	var tw: Dictionary = game.calendar.weather_info(game.calendar.tomorrow)
	var tsp: Dictionary = game.calendar.special(game.day + 1)
	var fc := "Yarın: %s, %s." % [game.calendar.label(game.day + 1), (tw["name"] as String).to_lower()]
	if not tsp.is_empty(): fc += " " + tsp["name"] + "!"
	match game.calendar.tomorrow:
		"sicak": fc += " Dondurma ve soğuk içecek stokla."
		"yagmur": fc += " Şemsiye satılır, müşteri biraz azalır."
		"kar": fc += " Salep aranır, sokak sakin olur."
	var res := out.slice(0, 3)
	res.append([tw["icon"], fc])
	return res

# ================================================================== welcome
func _show_welcome() -> void:
	welcome = Control.new(); welcome.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(welcome)
	var dim := ColorRect.new(); dim.color = Color(0.12, 0.16, 0.27, 0.35); dim.set_anchors_preset(Control.PRESET_FULL_RECT); welcome.add_child(dim)
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", UIKit.sb(Color("fffaf2"), 28, Color(0, 0, 0, 0), 0, 30, Vector4(36, 30, 36, 30)))
	c.custom_minimum_size = Vector2(700, 0)
	var v := UIKit.vbox(12)
	var top := UIKit.hbox(8)
	var kick := UIKit.label("PERAKENDE YÖNETİM OYUNU", 13, Cfg.TEAL, "body", 900); kick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(kick)
	top.add_child(UIKit.icon("globe", 18, Cfg.INK3))
	top.add_child(_seg(["Türkçe", "English"], 1 if Loc.lang == "en" else 0, func(i):
		Settings.lang = "en" if i == 1 else "tr"; Loc.set_lang(Settings.lang); Settings.save_settings(); get_tree().reload_current_scene()))
	v.add_child(top)
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
	var saves := UIKit.hbox(8)
	if SaveGame.exists(0):
		var inf := SaveGame.info(0)
		var cb := UIKit.button("Devam et · %s, Gün %d" % [DB.STAGES[int(inf["stage"])]["name"], int(inf["day"])], "play", false)
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.pressed.connect(func(): SaveGame.load_slot(get_tree(), 0))
		saves.add_child(cb)
	var lb := UIKit.button("Kayıtlı oyun yükle", "save", false)
	lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lb.pressed.connect(func(): open_menu("load"))
	saves.add_child(lb)
	var mp := UIKit.button("Mahalleler", "map", false)
	mp.pressed.connect(func(): open_menu("map"))
	saves.add_child(mp)
	var sb2 := UIKit.button("Ayarlar", "settings", false)
	sb2.pressed.connect(func(): open_menu("settings"))
	saves.add_child(sb2)
	v.add_child(saves)
	c.add_child(v)
	welcome.add_child(c)
	await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(c): return
	c.reset_size()
	c.position = (root.get_viewport_rect().size - c.size) * 0.5

func start(loaded := false) -> void:
	if started: return
	started = true
	var tw := create_tween(); tw.tween_property(welcome, "modulate:a", 0.0, 0.35); tw.tween_callback(welcome.queue_free)
	game.paused = false
	game.speed = 1.0
	if loaded:
		game.alert("loaded", "star", "Kayıt yüklendi: %s, Gün %d. Gün sabah 07:00'den başlıyor." % [DB.STAGES[game.stage]["name"], game.day], "good", null, 0.0)
	else:
		game.alert("hello", "star", "Hoş geldin! Boş bölmeye tıklayıp ürün ata, rafları dolu tut. Sorunlar önce dükkânın içinde görünür.", "good", null, 0.0)
		if game.scenario.is_empty() and Settings.tutorial: tutorial.start(game)

# ================================================================== shifts
func _shift_seg(cur: String, cb: Callable) -> HBoxContainer:
	var h := UIKit.hbox(2)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for sh in ["full", "morning", "evening"]:
		var b := Button.new(); b.focus_mode = Control.FOCUS_NONE
		b.text = DB.SHIFT_SHORT[sh]; b.tooltip_text = Loc.t(DB.SHIFT_LABEL[sh])
		b.add_theme_font_override("font", Art.body_font(800)); b.add_theme_font_size_override("font_size", 11)
		var on: bool = sh == cur
		b.add_theme_stylebox_override("normal", UIKit.sb(Cfg.VIOLET if on else Color(0.12, 0.16, 0.27, 0.07), 8, Color(0, 0, 0, 0), 0, 0, Vector4(8, 4, 8, 4)))
		b.add_theme_stylebox_override("hover", UIKit.sb(Cfg.VIOLET if on else Color(0.48, 0.35, 0.88, 0.2), 8, Color(0, 0, 0, 0), 0, 0, Vector4(8, 4, 8, 4)))
		b.add_theme_color_override("font_color", Color.WHITE if on else Cfg.INK2)
		b.add_theme_color_override("font_hover_color", Color.WHITE if on else Cfg.INK)
		var x: String = sh
		b.pressed.connect(func(): cb.call(x))
		h.add_child(b)
	return h

# ================================================================== campaigns
func _p_campaign() -> void:
	var body := _frame("Kampanyalar", "Kampanyalar bugün için geçerlidir, gün sonunda biter. Aynı anda birden fazla çalışabilir.", "megaphone", Color("d6333a"), 560)
	for c in DB.CAMPAIGNS:
		var locked: bool = c["stage"] > game.stage
		var card := UIKit.card(Color.WHITE, 16, Vector4(14, 12, 14, 12), 0)
		var v := UIKit.vbox(6)
		var h := UIKit.hbox(10)
		var ib := PanelContainer.new(); ib.add_theme_stylebox_override("panel", UIKit.sb(Color(0.84, 0.2, 0.23, 0.12), 12, Color(0, 0, 0, 0), 0, 0, Vector4(8, 8, 8, 8)))
		ib.add_child(UIKit.icon(c["icon"], 22, Color("d6333a"))); ib.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(ib)
		var tv := UIKit.vbox(0); tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UIKit.label(c["name"], 17, Cfg.INK, "body", 900))
		tv.add_child(UIKit.wrap(UIKit.label(c["desc"], 12, Cfg.INK2, "body", 700), 330))
		tv.add_child(UIKit.label(c["effect"], 12, Cfg.TEAL, "body", 800))
		h.add_child(tv)
		var cid: String = c["id"]
		if game.campaigns.has(cid):
			var ok := UIKit.hbox(4); ok.add_child(UIKit.icon("check", 16, Cfg.GOOD)); ok.add_child(UIKit.label("Bugün aktif", 13, Cfg.GOOD, "body", 800))
			ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(ok)
		elif locked:
			h.add_child(UIKit.chip("%s aşamasında" % DB.STAGES[c["stage"]]["name"], Color(0.12, 0.16, 0.27, 0.08), Cfg.INK3, 11))
		elif cid != "indirim" and cid != "ucal":
			var b := UIKit.button("Başlat · " + Cfg.fmt_money(c["cost"]), "", true, true)
			b.disabled = game.money < c["cost"]
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.pressed.connect(func(): game.start_campaign(cid))
			h.add_child(b)
		v.add_child(h)
		if (cid == "indirim" or cid == "ucal") and not game.campaigns.has(cid) and not locked:
			var disc_pick: Array = picks[cid]
			v.add_child(UIKit.label("En fazla 3 ürün seç (%d/3):" % disc_pick.size(), 12, Cfg.INK3, "body", 800))
			var flow := HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 5); flow.add_theme_constant_override("v_separation", 5)
			for p in game.unlocked_products():
				var pid: String = p["id"]
				var on: bool = disc_pick.has(pid)
				var pb := Button.new(); pb.focus_mode = Control.FOCUS_NONE; pb.tooltip_text = Loc.t("%s · ₺%d → ₺%d" % [p["name"], game.prices[pid], int(round(game.prices[pid] * 0.85))])
				pb.icon = thumbs.products.get(pid); pb.expand_icon = true; pb.custom_minimum_size = Vector2(50, 50)
				pb.add_theme_stylebox_override("normal", UIKit.sb(Color("ffe3df") if on else Color("f6ecde"), 12, Color("d6333a") if on else Color(0, 0, 0, 0), 3 if on else 0, 0, Vector4(4, 4, 4, 4)))
				pb.add_theme_stylebox_override("hover", UIKit.sb(Color("fff1e0"), 12, Color("d6333a"), 2, 0, Vector4(4, 4, 4, 4)))
				pb.pressed.connect(func():
					if disc_pick.has(pid): disc_pick.erase(pid)
					elif disc_pick.size() < 3: disc_pick.append(pid)
					panel_sig = "")
				flow.add_child(pb)
			v.add_child(flow)
			var b2 := UIKit.button(("Başlat · " + Cfg.fmt_money(c["cost"])) if c["cost"] > 0 else "İndirimi başlat", "tag", true, true)
			b2.disabled = disc_pick.is_empty() or game.money < c["cost"]
			b2.pressed.connect(func():
				if game.start_campaign(cid, disc_pick.duplicate()): picks[cid] = [])
			v.add_child(b2)
		elif (cid == "indirim" or cid == "ucal") and game.campaigns.has(cid):
			var names := []
			for pid in (game.discounts if cid == "indirim" else game.multi): names.append(DB.product(pid)["name"])
			v.add_child(UIKit.label(("İndirimde: " if cid == "indirim" else "3 al 2 öde: ") + ", ".join(names), 12, Color("d6333a"), "body", 800))
		card.add_child(v)
		if locked: card.modulate = Color(1, 1, 1, 0.55)
		body.add_child(card)

# ================================================================== AVM
func _p_mall() -> void:
	var m = game.mall
	if m == null: open_panel(""); return
	var occ: int = m.units.filter(func(u): return not u["tenant"].is_empty()).size()
	var rent_sum := 0
	for u in m.units: if not u["tenant"].is_empty(): rent_sum += int(u["tenant"]["rent"])
	var body := _frame("Köşebaşı AVM", "Kiracı %d / %d · günlük kira %s + ciro payı · AVM keyfi %.1f★" % [occ, m.units.size(), Cfg.fmt_money(rent_sum), m.mood], "mall", Cfg.TEAL_DARK, 640)
	var tabs := UIKit.hbox(6)
	for t in ["Kiracılar", "Etkinlikler", "Tesis"]:
		var b := UIKit.button(t, "", false, true)
		if t == mall_tab:
			b.add_theme_stylebox_override("normal", UIKit.sb(Cfg.INK, 10, Color(0, 0, 0, 0), 0, 0, Vector4(12, 6, 12, 6)))
			b.add_theme_color_override("font_color", Color.WHITE)
		var tt: String = t
		b.pressed.connect(func(): mall_tab = tt; panel_sig = "")
		tabs.add_child(b)
	body.add_child(tabs)
	match mall_tab:
		"Kiracılar": _mall_tenants(body, m)
		"Etkinlikler": _mall_events(body, m)
		"Tesis": _mall_facility(body, m)

func _unit_label(u: Dictionary) -> String:
	var d: Dictionary = u["def"]
	var r: Rect2i = d["rect"]
	return "Birim %s · %s · %d m²%s" % [d["id"], "Zemin kat" if d["floor"] == 0 else "1. kat", r.size.x * r.size.y, " · yemek" if d.get("food", false) else ""]

func _tenant_chip(t: Dictionary) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UIKit.sb(t["color"], 10, t["accent"], 2, 0, Vector4(8, 4, 8, 4)))
	chip.add_child(UIKit.label(t["brand"], 14, Color.WHITE, "display"))
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return chip

func _offer_row(u: Dictionary, i: int) -> HBoxContainer:
	var o: Dictionary = u["offers"][i]
	var t: Dictionary = o["def"]
	var row := UIKit.hbox(8)
	row.add_child(_tenant_chip(t))
	var tv := UIKit.vbox(-2); tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UIKit.label("%s · %s/gün + %%%d ciro" % [t["name"], Cfg.fmt_money(o["rent"]), int(t["share"] * 100)], 13, Cfg.INK, "body", 800))
	tv.add_child(UIKit.wrap(UIKit.label(t["rule"], 11, Cfg.INK3, "body", 700), 300))
	row.add_child(tv)
	var b := UIKit.button("Kirala", "check", true, true)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): game.mall.lease(u, i))
	row.add_child(b)
	return row

func _mall_tenants(body: VBoxContainer, m) -> void:
	for u in m.units:
		var card := UIKit.card(Color.WHITE, 14, Vector4(12, 10, 12, 10), 0)
		var v := UIKit.vbox(6)
		var head := UIKit.hbox(8)
		var hl := UIKit.label(_unit_label(u), 12, Cfg.INK3, "body", 900); hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(hl)
		var uu: Dictionary = u
		var fb := UIKit.button("Göster", "eye", false, true)
		fb.pressed.connect(func():
			var r: Rect2i = uu["def"]["rect"]
			game.set_view_floor(uu["def"]["floor"])
			game.rig.focus(Cfg.rc(r).x, Cfg.rc(r).y)
			game.select({"kind": "unit", "obj": uu}))
		head.add_child(fb)
		v.add_child(head)
		if u["tenant"].is_empty():
			if u["offers"].is_empty(): v.add_child(UIKit.label("Bugün teklif yok, yarın yenilenir.", 12, Cfg.INK3, "body", 700))
			for i in u["offers"].size(): v.add_child(_offer_row(u, i))
		else:
			var t: Dictionary = u["tenant"]
			var row := UIKit.hbox(10)
			row.add_child(_tenant_chip(t["def"]))
			var tv := UIKit.vbox(0); tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tv.add_child(UIKit.label("%s · kira %s · bugün %s satış, %d ziyaret" % [t["def"]["name"], Cfg.fmt_money(t["rent"]), Cfg.fmt_money(t["sales"]), t["visitors"]], 12, Cfg.INK2, "body", 800))
			var sh := UIKit.hbox(6)
			var sat: float = t["sat"]
			var col := Cfg.GOOD if sat >= 60 else (Cfg.WARN if sat >= 35 else Cfg.BAD)
			var sb := UIKit.bar(sat / 100.0, col, 200, 8); sb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			sh.add_child(sb); sh.add_child(UIKit.label("memnuniyet %d" % int(sat), 12, col, "body", 900))
			tv.add_child(sh)
			row.add_child(tv)
			v.add_child(row)
		card.add_child(v)
		body.add_child(card)

func _mall_events(body: VBoxContainer, m) -> void:
	if not m.event.is_empty():
		var c := UIKit.card(Color(0.48, 0.35, 0.88, 0.1), 14, Vector4(12, 10, 12, 10), 0)
		c.add_child(UIKit.label("Bugün: %s" % m.event["def"]["name"], 16, Cfg.VIOLET, "display"))
		body.add_child(c)
	for sc in m.scheduled:
		body.add_child(UIKit.label("Planlandı: Gün %d · %s" % [sc["day"], MallDB.event(sc["id"])["name"]], 13, Cfg.TEAL, "body", 800))
	if not game.has_role("security"):
		body.add_child(UIKit.wrap(UIKit.label("Güvenlik görevlisi yok: kalabalık etkinliklerde arbede çıkabilir.", 12, Cfg.BAD, "body", 800), 580))
	for e in MallDB.EVENTS:
		var card := UIKit.card(Color.WHITE, 14, Vector4(12, 10, 12, 10), 0)
		var h := UIKit.hbox(10)
		var ib := PanelContainer.new(); ib.add_theme_stylebox_override("panel", UIKit.sb(Color(0.48, 0.35, 0.88, 0.14), 12, Color(0, 0, 0, 0), 0, 0, Vector4(8, 8, 8, 8)))
		ib.add_child(UIKit.icon("sparkle", 20, Cfg.VIOLET)); ib.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(ib)
		var tv := UIKit.vbox(0); tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UIKit.label("%s · %s" % [e["name"], Cfg.fmt_money(e["cost"])], 16, Cfg.INK, "body", 900))
		tv.add_child(UIKit.wrap(UIKit.label(e["desc"], 12, Cfg.INK2, "body", 700), 330))
		tv.add_child(UIKit.label("Ziyaretçi ×%.2f · kiracı satışı ×%.2f · süpermarket ×%.2f" % [e["visitors"], e["tenants"], e["store"]], 11, Cfg.TEAL, "body", 800))
		h.add_child(tv)
		var bv := UIKit.vbox(4)
		var eid: String = e["id"]
		for w in [["today", "Bugün"], ["tomorrow", "Yarın"]]:
			var b := UIKit.button(w[1], "", w[0] == "tomorrow", true)
			b.disabled = game.money < e["cost"]
			var ww: String = w[0]
			b.pressed.connect(func(): m.schedule(eid, ww))
			bv.add_child(b)
		h.add_child(bv)
		card.add_child(h)
		body.add_child(card)

func _mall_facility(body: VBoxContainer, m) -> void:
	var st: Dictionary = m.stats
	var grid := GridContainer.new(); grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8)
	for kv in [["Bugün ziyaretçi", str(st["visitors"])], ["Kiracı satışı", Cfg.fmt_money(st["tenant_sales"])], ["Şu an içeride", str(m.visitors.size())], ["Arbede", str(st["incidents"])], ["Koltuk bulamayan", str(st["no_seat"])], ["AVM keyfi", "%.1f" % m.mood]]:
		var c := UIKit.card(Color.WHITE, 14, Vector4(12, 8, 12, 8), 0)
		var vv := UIKit.vbox(0)
		vv.add_child(UIKit.label(kv[0], 12, Cfg.INK3, "body", 800))
		vv.add_child(UIKit.label(kv[1], 20, Cfg.INK, "display"))
		c.add_child(vv); c.custom_minimum_size.x = 185
		grid.add_child(c)
	body.add_child(grid)
	body.add_child(UIKit.section("Yürüyen merdiven ve asansör"))
	for c in m.connectors: body.add_child(_connector_row(c))
	body.add_child(UIKit.wrap(UIKit.label("Arızalar rastgele çıkar. Arızalı yürüyen merdivende ziyaretçiler asansöre ya da merdivene yönelir, 1. kat kiracıları memnuniyetsizleşir. Teknisyen ücretsiz tamir eder ve arızaları yarıya indirir.", 12, Cfg.INK2, "body", 700), 580))
	body.add_child(UIKit.section("Tuvaletler"))
	var wcs: Array = game.fixtures.filter(func(f): return f.def["kind"] == "wc")
	if wcs.is_empty(): body.add_child(UIKit.wrap(UIKit.label("AVM'de tuvalet yok! Ziyaretçiler ve kiracılar söyleniyor. İnşa > AVM > Tuvalet.", 12, Cfg.BAD, "body", 800), 580))
	for w in wcs: body.add_child(UIKit.label("Tuvalet (%s) · %s" % ["1. kat" if w.lvl == 1 else "zemin kat", "kirli, temizlik bekliyor" if w.dirty else "temiz"], 13, Cfg.BAD if w.dirty else Cfg.INK, "body", 800))

func _connector_row(c: Dictionary) -> HBoxContainer:
	var row := UIKit.hbox(10)
	row.add_child(UIKit.icon("wrench" if c["broken"] else "check", 18, Cfg.BAD if c["broken"] else Cfg.GOOD))
	var l := UIKit.label(c["def"]["name"], 14, Cfg.INK, "body", 800); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	if c["def"]["kind"] == "stairs":
		row.add_child(UIKit.chip("Arızalanmaz", Cfg.GOOD, Color.WHITE, 11))
	elif c["broken"] and int(c.get("claimed", 0)) != 0:
		row.add_child(UIKit.chip("Teknisyen tamir ediyor", Cfg.WARN, Color.WHITE, 11))
	elif c["broken"] and c["repair_t"] > 0.0:
		row.add_child(UIKit.chip("Tamir ediliyor", Cfg.WARN, Color.WHITE, 11))
	elif c["broken"]:
		var b := UIKit.button("Tamir · ₺600", "wrench", true, true)
		b.disabled = game.money < 600
		b.pressed.connect(func(): game.mall.repair(c))
		row.add_child(b)
	else:
		row.add_child(UIKit.chip("Çalışıyor", Cfg.GOOD, Color.WHITE, 11))
	return row

# ---------------------------------------------------------------- AVM inspectors
func _insp_unit(v: VBoxContainer, u: Dictionary) -> void:
	if u["tenant"].is_empty():
		_insp_head(v, "Birim %s · KİRALIK" % u["def"]["id"], _unit_label(u), Cfg.TEAL, null, "shop")
		var b := _body(v)
		b.add_child(UIKit.section("Bugünkü teklifler"))
		if u["offers"].is_empty(): b.add_child(UIKit.label("Teklif yok, yarın sabah yenilenir.", 12, Cfg.INK3, "body", 700))
		for i in u["offers"].size(): b.add_child(_offer_row(u, i))
		return
	var t: Dictionary = u["tenant"]
	var d: Dictionary = t["def"]
	_insp_head(v, d["brand"], "%s · %s" % [d["name"], _unit_label(u)], d["color"], null, "shop")
	var b2 := _body(v)
	var sat: float = t["sat"]
	var col := Cfg.GOOD if sat >= 60 else (Cfg.WARN if sat >= 35 else Cfg.BAD)
	var sh := UIKit.hbox(8)
	sh.add_child(UIKit.label("Memnuniyet", 13, Cfg.INK, "body", 800))
	var sb := UIKit.bar(sat / 100.0, col, 150, 9); sb.size_flags_vertical = Control.SIZE_SHRINK_CENTER; sh.add_child(sb)
	sh.add_child(UIKit.label("%d" % int(sat), 16, col, "display"))
	b2.add_child(sh)
	b2.add_child(UIKit.label("Kira %s/gün · ciro payı %%%d · bugün %s satış · %d ziyaret" % [Cfg.fmt_money(t["rent"]), int(d["share"] * 100), Cfg.fmt_money(t["sales"]), t["visitors"]], 12, Cfg.INK2, "body", 800))
	b2.add_child(UIKit.wrap(UIKit.label("İstediği: " + d["rule"], 12, Cfg.TEAL, "body", 800), 310))
	b2.add_child(UIKit.section("Neden böyle hissediyor?"))
	for rr in t["reasons"]:
		var row := UIKit.hbox(8)
		var l := UIKit.wrap(UIKit.label(rr["text"], 12, Cfg.INK, "body", 700), 240); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var vv: int = rr["v"]
		row.add_child(UIKit.label(("+%d" % vv) if vv > 0 else str(vv), 13, Cfg.GOOD if vv > 0 else Cfg.BAD, "body", 900))
		b2.add_child(row)
	if t["low_days"] > 0: b2.add_child(UIKit.label("Uyarı: yarın da mutsuz kalırsa ayrılacak.", 12, Cfg.BAD, "body", 900))
	var ev := UIKit.button("Sözleşmeyi feshet", "close", false, true)
	ev.pressed.connect(func(): game.mall.evict(u, "sözleşme feshedildi"); game.select({}))
	b2.add_child(UIKit.sep_h()); b2.add_child(ev)

func _insp_connector(v: VBoxContainer, c: Dictionary) -> void:
	_insp_head(v, c["def"]["name"], "Arızalı" if c["broken"] else "Çalışıyor", Cfg.BAD if c["broken"] else Cfg.TEAL, null, "wrench" if c["broken"] else "floors")
	var b := _body(v)
	b.add_child(_connector_row(c))
	b.add_child(UIKit.wrap(UIKit.label("Katlar arası yolculuk %.1f sn sürer. Emekliler ve bebek arabalı aileler asansörü tercih eder." % c["def"]["time"], 12, Cfg.INK2, "body", 700), 310))

func _insp_puddle(v: VBoxContainer, P: Dictionary) -> void:
	_insp_head(v, "Islak zemin", "Üstünden geçen kayabilir, müşteri keyfi düşer.", Color("2f7fd8"), null, "drop")
	var b := _body(v)
	if P["dry"] > 0.0: b.add_child(UIKit.label("Paspaslandı, kuruyor.", 13, Cfg.GOOD, "body", 800))
	elif int(P["claimed"]) != 0: b.add_child(UIKit.label("Temizlik görevlisi yolda.", 13, Cfg.TEAL, "body", 800))
	elif not game.has_role("cleaner"): b.add_child(UIKit.wrap(UIKit.label("Temizlik görevlisi yok! Personel panelinden (H) bir tane al.", 13, Cfg.BAD, "body", 800), 310))
	else: b.add_child(UIKit.label("Sırada: temizlik görevlisi birazdan gelir.", 13, Cfg.INK2, "body", 800))
	if P.get("sign") == null and P["dry"] <= 0.0:
		var sb := UIKit.button("Uyarı levhası koy", "alert", true, true)
		sb.pressed.connect(func(): game.place_wet_sign(P); insp_sig = "")
		b.add_child(sb)

func _insp_visitor(v: VBoxContainer, c: Visitor) -> void:
	var col := Cfg.GOOD if c.mood >= 60 else (Cfg.WARN if c.mood >= 35 else Cfg.BAD)
	_insp_head(v, c.person_name, "AVM ziyaretçisi · %s · %s" % [c.arch["name"], c.status_label()], col, null, "people")
	var b := _body(v)
	var mh := UIKit.hbox(8)
	mh.add_child(UIKit.label("Keyif", 13, Cfg.INK, "body", 800))
	var mb := UIKit.bar(c.mood / 100.0, col, 180, 9); mb.size_flags_vertical = Control.SIZE_SHRINK_CENTER; mh.add_child(mb)
	mh.add_child(UIKit.label("%d" % int(c.mood), 14, col, "display"))
	b.add_child(mh)
	b.add_child(UIKit.label("Harcadı %s%s" % [Cfg.fmt_money(c.spent), " · çocuğuyla" if c.child != null else ""], 12, Cfg.INK2, "body", 800))
	b.add_child(UIKit.section("Aklından geçenler"))
	if c.thoughts.is_empty(): b.add_child(UIKit.label("Henüz bir şey düşünmedi.", 12, Cfg.INK3, "body", 700))
	for t in c.thoughts:
		var row2 := UIKit.hbox(8)
		var chip := PanelContainer.new(); chip.add_theme_stylebox_override("panel", UIKit.sb(ICON_COLOR.get(t["icon"], Cfg.TERRA), 8, Color(0, 0, 0, 0), 0, 0, Vector4(4, 4, 4, 4)))
		chip.add_child(UIKit.icon(ICON_GLYPH.get(t["icon"], "info"), 13, Color.WHITE)); chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row2.add_child(chip)
		row2.add_child(UIKit.wrap(UIKit.label("“%s”" % t["text"], 13, Cfg.INK, "body", 700), 270))
		b.add_child(row2)

func _evening_toggle(b: VBoxContainer) -> void:
	var tg := CheckButton.new(); tg.text = Loc.t("Akşam indirimi: 19:00'dan sonra simit ve ekmek %40 ucuz")
	tg.button_pressed = game.evening_bakery; tg.focus_mode = Control.FOCUS_NONE
	tg.add_theme_font_size_override("font_size", 12); tg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tg.custom_minimum_size.x = 310
	tg.toggled.connect(func(on): game.evening_bakery = on; game.refresh_all())
	b.add_child(tg)

# ================================================================== pause menu: save / load / settings
func open_menu(page := "main") -> void:
	menu_page = page
	if menu == null:
		menu = Control.new(); menu.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(menu)
	menu.visible = true
	if started: game.paused = true
	_render_menu()

func close_menu() -> void:
	if menu == null: return
	menu.visible = false
	if started: game.paused = false

func _render_menu() -> void:
	UIKit.clear(menu)
	var dim := ColorRect.new(); dim.color = Color(0.12, 0.16, 0.27, 0.5); dim.set_anchors_preset(Control.PRESET_FULL_RECT); menu.add_child(dim)
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", UIKit.sb(Color("fffaf2"), 24, Color(0, 0, 0, 0), 0, 24, Vector4(26, 22, 26, 22)))
	c.custom_minimum_size = Vector2(520, 0)
	var v := UIKit.vbox(10)
	var head := UIKit.hbox(10)
	var title: String = {"main": "Menü", "save": "Oyunu Kaydet", "load": "Kayıt Yükle", "settings": "Ayarlar", "map": "Mahalle Haritası", "ach": "Başarımlar", "words": "Sözlük"}[menu_page]
	var tl := UIKit.label(title, 30, Cfg.INK, "display"); tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	if menu_page != "main" and started:
		var bk := UIKit.button("Geri", "", false, true); bk.pressed.connect(func(): menu_page = "main"; _render_menu())
		head.add_child(bk)
	var x := Button.new(); x.flat = true; x.icon = UIKit.icon_tex("close"); x.focus_mode = Control.FOCUS_NONE
	x.add_theme_constant_override("icon_max_width", 16); x.add_theme_color_override("icon_normal_color", Cfg.INK2)
	x.pressed.connect(close_menu)
	head.add_child(x)
	v.add_child(head)
	match menu_page:
		"main": _menu_main(v)
		"save": _menu_slots(v, true)
		"load": _menu_slots(v, false)
		"settings": _menu_settings(v)
		"map": _menu_map(v)
		"ach": _menu_ach(v)
		"words": _menu_words(v)
	c.add_child(v)
	menu.add_child(c)
	c.reset_size()
	c.position = (root.get_viewport_rect().size / root.get_viewport().get_final_transform().get_scale() - c.size) * 0.5

func _menu_main(v: VBoxContainer) -> void:
	v.add_child(UIKit.label("Oyun duraklatıldı. Gün %d, %s" % [game.day, Cfg.clock_str(game.clock)], 13, Cfg.INK3, "body", 800))
	for it in [["Devam et", "play", func(): close_menu(), true], ["Kaydet", "save", func(): menu_page = "save"; _render_menu(), false],
		["Yükle", "box", func(): menu_page = "load"; _render_menu(), false], ["Mahalle haritası", "map", func(): menu_page = "map"; _render_menu(), false],
		["Başarımlar", "trophy", func(): menu_page = "ach"; _render_menu(), false], ["Sözlük", "book", func(): menu_page = "words"; _render_menu(), false], ["Ayarlar", "settings", func(): menu_page = "settings"; _render_menu(), false],
		["Oyundan çık", "close", func(): get_tree().quit(), false]]:
		var b := UIKit.button(it[0], it[1], it[3])
		b.custom_minimum_size = Vector2(0, 46)
		b.pressed.connect(it[2])
		v.add_child(b)
	v.add_child(UIKit.wrap(UIKit.label("Oyun her sabah otomatik kaydedilir. Kayıt yüklenince gün 07:00'den yeniden başlar.", 12, Cfg.INK3, "body", 700), 460))

func _menu_slots(v: VBoxContainer, saving: bool) -> void:
	var slots := [1, 2, 3] if saving else [0, 1, 2, 3]
	for sl in slots:
		var inf := SaveGame.info(sl)
		var row := UIKit.card(Color.WHITE, 14, Vector4(12, 10, 12, 10), 0)
		var h := UIKit.hbox(10)
		var tv := UIKit.vbox(0); tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UIKit.label("Otomatik kayıt (her sabah)" if sl == 0 else "Kayıt %d" % sl, 15, Cfg.INK, "body", 900))
		if inf.is_empty(): tv.add_child(UIKit.label("Boş", 12, Cfg.INK3, "body", 700))
		else: tv.add_child(UIKit.label("%s · Gün %d · %s · %s" % [DB.STAGES[int(inf["stage"])]["name"], int(inf["day"]), Cfg.fmt_money(int(inf["money"])), String(inf["saved_at"]).replace("T", " ").left(16)], 12, Cfg.INK2, "body", 700))
		h.add_child(tv)
		var ss: int = sl
		if saving:
			var b := UIKit.button("Üzerine kaydet" if not inf.is_empty() else "Kaydet", "save", true, true)
			b.pressed.connect(func():
				if SaveGame.save(game, ss): _toast("Kaydedildi: Kayıt %d" % ss)
				else: _toast("Kaydedilemedi!")
				_render_menu())
			h.add_child(b)
		else:
			var b2 := UIKit.button("Yükle", "play", true, true)
			b2.disabled = inf.is_empty()
			b2.pressed.connect(func(): SaveGame.load_slot(get_tree(), ss))
			h.add_child(b2)
		row.add_child(h); v.add_child(row)
	v.add_child(UIKit.wrap(UIKit.label("Kayıt klasörü: " + ProjectSettings.globalize_path("user://"), 11, Cfg.INK3, "body", 700), 460))

func _seg(opts: Array, cur: int, cb: Callable) -> HBoxContainer:
	var h := UIKit.hbox(3)
	for i in opts.size():
		var b := Button.new(); b.focus_mode = Control.FOCUS_NONE; b.text = str(opts[i])
		b.add_theme_font_override("font", Art.body_font(800)); b.add_theme_font_size_override("font_size", 13)
		var on := i == cur
		b.add_theme_stylebox_override("normal", UIKit.sb(Cfg.TERRA if on else Color(0.12, 0.16, 0.27, 0.07), 9, Color(0, 0, 0, 0), 0, 0, Vector4(12, 6, 12, 6)))
		b.add_theme_stylebox_override("hover", UIKit.sb(Cfg.TERRA if on else Color(0.88, 0.4, 0.24, 0.2), 9, Color(0, 0, 0, 0), 0, 0, Vector4(12, 6, 12, 6)))
		b.add_theme_color_override("font_color", Color.WHITE if on else Cfg.INK2)
		b.add_theme_color_override("font_hover_color", Color.WHITE if on else Cfg.INK)
		var ii: int = i
		b.pressed.connect(func(): cb.call(ii))
		h.add_child(b)
	return h

func _set_row(v: VBoxContainer, label: String, ctl: Control) -> void:
	var h := UIKit.hbox(10)
	var l := UIKit.label(label, 14, Cfg.INK, "body", 800); l.custom_minimum_size.x = 170
	h.add_child(l); ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(ctl)
	v.add_child(h)

func _menu_settings(v: VBoxContainer) -> void:
	var changed := func():
		Settings.save_settings(); Settings.apply(game, get_tree()); _render_menu()
	v.add_child(UIKit.section("Görüntü"))
	_set_row(v, "Grafik kalitesi", _seg(Settings.QUALITY, Settings.quality, func(i): Settings.quality = i; changed.call()))
	_set_row(v, "Dil / Language", _seg(["Türkçe", "English"], 1 if Settings.lang == "en" else 0, func(i): Settings.lang = "en" if i == 1 else "tr"; Loc.set_lang(Settings.lang); Settings.save_settings(); get_tree().reload_current_scene()))
	_set_row(v, "Arayüz boyutu", _seg(["%90", "%100", "%115", "%130"], Settings.UI_SCALES.find(Settings.ui_scale), func(i): Settings.ui_scale = Settings.UI_SCALES[i]; changed.call()))
	var fs := CheckButton.new(); fs.text = Loc.t("Tam ekran"); fs.button_pressed = Settings.fullscreen; fs.focus_mode = Control.FOCUS_NONE
	fs.toggled.connect(func(on): Settings.fullscreen = on; changed.call())
	v.add_child(fs)
	var cw := CheckButton.new(); cw.text = Loc.t("Yakınlaşınca kameraya bakan duvarları indir (C)"); cw.button_pressed = Settings.cutaway; cw.focus_mode = Control.FOCUS_NONE
	cw.toggled.connect(func(on): Settings.cutaway = on; changed.call())
	v.add_child(cw)
	v.add_child(UIKit.section("Ses"))
	for k in [["Master", "Ana ses"], ["Music", "Müzik"], ["SFX", "Efektler"], ["Ambience", "Ortam sesi"]]:
		var sl := HSlider.new(); sl.min_value = 0.0; sl.max_value = 1.0; sl.step = 0.05; sl.value = Settings.vol[k[0]]
		sl.custom_minimum_size = Vector2(240, 24); sl.focus_mode = Control.FOCUS_NONE
		var key: String = k[0]
		sl.value_changed.connect(func(val): Settings.vol[key] = val; Settings.apply_audio())
		sl.drag_ended.connect(func(_c): Settings.save_settings())
		_set_row(v, k[1], sl)
	v.add_child(UIKit.label("Düşük kalite: gölge ve ortam ışığı sadeleşir, eski ekran kartlarında akıcı çalışır.", 11, Cfg.INK3, "body", 700))

func _menu_map(v: VBoxContainer) -> void:
	v.add_child(UIKit.wrap(UIKit.label("Her mahalle ayrı bir oyun başlatır. Kazandığın mahallelere madalya işlenir.", 12, Cfg.INK3, "body", 700), 560))
	for sd in Scenarios.LIST:
		var row := UIKit.card(Color.WHITE, 14, Vector4(12, 10, 12, 10), 0)
		var h := UIKit.hbox(10)
		var ib := PanelContainer.new(); ib.add_theme_stylebox_override("panel", UIKit.sb(Cfg.VIOLET if Progress.medal(sd["id"]) else Color(0.12, 0.16, 0.27, 0.08), 12, Color(0, 0, 0, 0), 0, 0, Vector4(8, 8, 8, 8)))
		ib.add_child(UIKit.icon("medal" if Progress.medal(sd["id"]) else sd["icon"], 22, Color.WHITE if Progress.medal(sd["id"]) else Cfg.INK2)); ib.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(ib)
		var tv := UIKit.vbox(0); tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UIKit.label("%s · %s" % [sd["name"], sd["sub"]], 16, Cfg.INK, "body", 900))
		tv.add_child(UIKit.wrap(UIKit.label(sd["desc"], 12, Cfg.INK2, "body", 700), 380))
		tv.add_child(UIKit.wrap(UIKit.label("Hedef: " + sd["goal"], 12, Cfg.TEAL, "body", 800), 380))
		h.add_child(tv)
		var sid: String = sd["id"]
		var b := UIKit.button("Başla", "play", true, true); b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func(): SaveGame.pending_scenario = sid; SaveGame.pending = {}; get_tree().reload_current_scene())
		h.add_child(b)
		row.add_child(h); v.add_child(row)

func _menu_ach(v: VBoxContainer) -> void:
	Progress.load_data()
	var got := 0
	for a in Progress.ACHIEVEMENTS: if Progress.has(a["id"]): got += 1
	v.add_child(UIKit.label("%d / %d açıldı" % [got, Progress.ACHIEVEMENTS.size()], 13, Cfg.INK3, "body", 800))
	var sc := ScrollContainer.new(); sc.custom_minimum_size = Vector2(560, 420); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := UIKit.vbox(6); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for a in Progress.ACHIEVEMENTS:
		var on := Progress.has(a["id"])
		var h := UIKit.hbox(10)
		h.add_child(UIKit.icon("trophy" if on else "lock", 20, Cfg.MUSTARD if on else Cfg.INK3))
		var tv := UIKit.vbox(-2); tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UIKit.label(a["name"], 14, Cfg.INK if on else Cfg.INK3, "body", 900))
		tv.add_child(UIKit.label(a["desc"], 12, Cfg.INK2 if on else Cfg.INK3, "body", 700))
		h.add_child(tv)
		list.add_child(h)
	sc.add_child(list); v.add_child(sc)

func _menu_words(v: VBoxContainer) -> void:
	v.add_child(UIKit.label("Oyunda bilerek Türkçe bırakılan kelimeler.", 13, Cfg.INK3, "body", 800))
	var sc := ScrollContainer.new(); sc.custom_minimum_size = Vector2(560, 420); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := UIKit.vbox(8); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var keys := Glossary.TERMS.keys(); keys.sort()
	for k in keys:
		if k == "Ramadan": continue
		var tv := UIKit.vbox(0)
		var l := Label.new(); l.text = k; l.add_theme_font_override("font", Art.font("display")); l.add_theme_font_size_override("font_size", 17); l.add_theme_color_override("font_color", Cfg.TERRA)
		tv.add_child(l)
		var d := Label.new(); d.text = Glossary.TERMS[k]; d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; d.custom_minimum_size.x = 520
		d.add_theme_font_override("font", Art.body_font(700)); d.add_theme_font_size_override("font_size", 13); d.add_theme_color_override("font_color", Cfg.INK2)
		tv.add_child(d)
		list.add_child(tv)
	sc.add_child(list); v.add_child(sc)

func _toast(text: String) -> void:
	if toast: toast.queue_free()
	toast = UIKit.card(Color(0.12, 0.16, 0.27, 0.95), 14, Vector4(16, 10, 16, 10), 10)
	toast.add_child(UIKit.label(text, 15, Color.WHITE, "body", 800))
	root.add_child(toast)
	toast.reset_size()
	var vs := root.get_viewport_rect().size / root.get_viewport().get_final_transform().get_scale()
	toast.position = Vector2((vs.x - toast.size.x) * 0.5, 110)
	var tw := toast.create_tween(); tw.tween_interval(1.8); tw.tween_property(toast, "modulate:a", 0.0, 0.4); tw.tween_callback(toast.queue_free)

# ================================================================== mahalle olayları
func _render_events() -> void:
	UIKit.clear(events_box)
	event_bars.clear()
	for ev in game.neighbor_events:
		var c := PanelContainer.new()
		var st := UIKit.sb(Color(1.0, 0.98, 0.95, 0.97), 16, Cfg.MUSTARD, 0, 12, Vector4(14, 12, 14, 12))
		st.border_width_top = 5; st.border_color = Cfg.MUSTARD
		c.add_theme_stylebox_override("panel", st)
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		var v := UIKit.vbox(6)
		var h := UIKit.hbox(8)
		var ib := PanelContainer.new(); ib.add_theme_stylebox_override("panel", UIKit.sb(Cfg.MUSTARD, 10, Color(0, 0, 0, 0), 0, 0, Vector4(6, 6, 6, 6)))
		ib.add_child(UIKit.icon(ev["icon"], 18, Color.WHITE)); h.add_child(ib)
		var tl := UIKit.label(ev["title"], 18, Cfg.INK, "display"); tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(tl)
		var tag := UIKit.label("MAHALLE", 11, Cfg.TEAL, "body", 900); tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(tag)
		v.add_child(h)
		v.add_child(UIKit.wrap(UIKit.label(ev["text"], 13, Cfg.INK2, "body", 700), 410))
		var track := ColorRect.new(); track.color = Color(0.12, 0.16, 0.27, 0.08); track.custom_minimum_size = Vector2(0, 4)
		var fill := ColorRect.new(); fill.color = Cfg.TERRA; fill.anchor_bottom = 1.0; fill.anchor_right = 1.0
		track.add_child(fill); v.add_child(track)
		event_bars[ev["id"]] = fill
		var bh := UIKit.hbox(6)
		var eid: int = ev["id"]
		for i in ev["choices"].size():
			var ch: Dictionary = ev["choices"][i]
			var txt: String = ch["label"] + ((" · " + ch["hint"]) if ch.get("hint", "") != "" else "")
			var b := UIKit.button(txt, "", ch.get("primary", false), true)
			b.disabled = ch.get("disabled", false)
			var ii: int = i
			b.pressed.connect(func(): game.answer_event(eid, ii))
			bh.add_child(b)
		v.add_child(bh)
		c.add_child(v)
		events_box.add_child(c)
		c.modulate.a = 0.0
		c.create_tween().tween_property(c, "modulate:a", 1.0, 0.25)
