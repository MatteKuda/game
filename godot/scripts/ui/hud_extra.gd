class_name HudExtra
## Panels for the neighbourhood (veresiye defteri, regulars, quests, the rival) and the product analysis.
## Static helpers that draw into a body VBox built by Hud._frame(); `h` is the Hud.

const ARCH_SHORT := {"ogrenci": "Öğrenci", "emekli": "Emekli", "calisan": "Beyaz yaka", "aile": "Aile", "haftalik": "Haftalık", "firsatci": "Fırsatçı"}

static func _tabs(h, cur: String, list: Array, cb: Callable) -> HBoxContainer:
	var tabs := UIKit.hbox(6)
	for t in list:
		var b := UIKit.button(t, "", false, true)
		if t == cur:
			b.add_theme_stylebox_override("normal", UIKit.sb(Cfg.INK, 10, Color(0, 0, 0, 0), 0, 0, Vector4(12, 6, 12, 6)))
			b.add_theme_color_override("font_color", Color.WHITE)
		var tt: String = t
		b.pressed.connect(func(): cb.call(tt))
		tabs.add_child(b)
	return tabs

static func _thumb(h, pid: String, size := 34) -> TextureRect:
	var img := TextureRect.new(); img.custom_minimum_size = Vector2(size, size); img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; img.texture = h.thumbs.products.get(pid)
	var nm := Loc.t(DB.product(pid)["name"])
	var gl := Glossary.note(nm)
	img.tooltip_text = nm + ("\n" + gl if gl != "" else ""); img.mouse_filter = Control.MOUSE_FILTER_PASS
	return img

static func _stat_card(title: String, value: String, col: Color, w := 150.0) -> PanelContainer:
	var c := UIKit.card(Color.WHITE, 14, Vector4(12, 8, 12, 8), 0)
	var v := UIKit.vbox(0)
	v.add_child(UIKit.label(title, 12, Cfg.INK3, "body", 800))
	v.add_child(UIKit.label(value, 20, col, "display"))
	c.add_child(v); c.custom_minimum_size.x = w
	return c

# ================================================================== Mahalle panel
static func hood(h, body: VBoxContainer) -> void:
	var g: Game = h.game
	var list := ["Defter", "Müdavimler", "Görevler"]
	if g.rival != null and g.rival.active: list.append("Rakip")
	if not list.has(h.hood_tab): h.hood_tab = "Defter"
	body.add_child(_tabs(h, h.hood_tab, list, func(t): h.hood_tab = t; h.panel_sig = ""))
	match h.hood_tab:
		"Defter": _ledger(h, body)
		"Müdavimler": _regulars(h, body)
		"Görevler": _quests(h, body)
		"Rakip": _rival(h, body)

static func _ledger(h, body: VBoxContainer) -> void:
	var g: Game = h.game
	var nb: Neighborhood = g.neighborhood
	body.add_child(UIKit.wrap(UIKit.label("Veresiye defteri: tanıdık komşular \"yazarsın\" der. Deftere yazmak sadakati ve satışı artırır ama bazıları geç öder, bazıları hiç ödemez. Hatırlatmak parayı getirir ama biraz kırar; borcu silmek mahallede adını büyütür.", 12, Cfg.INK2, "body", 700), 600))
	var row := UIKit.hbox(10)
	row.add_child(UIKit.label("Kime yazılır?", 13, Cfg.INK, "body", 800))
	var modes := ["off", "regulars", "all"]
	row.add_child(h._seg(["Kimseye", "Sadık müdavimlere", "Bütün mahalleye"], modes.find(nb.mode), func(i): nb.mode = modes[i]; h.panel_sig = ""))
	body.add_child(row)
	var row2 := UIKit.hbox(10)
	row2.add_child(UIKit.label("Kişi başı sınır", 13, Cfg.INK, "body", 800))
	var lims := [150, 300, 600, 1200]
	row2.add_child(h._seg(lims.map(func(x): return Cfg.fmt_money(x)), lims.find(nb.limit), func(i): nb.limit = lims[i]; h.panel_sig = ""))
	body.add_child(row2)
	var grid := GridContainer.new(); grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8)
	grid.add_child(_stat_card("Toplam alacak", Cfg.fmt_money(nb.total_debt()), Cfg.VIOLET, 140))
	grid.add_child(_stat_card("Bugün yazılan", Cfg.fmt_money(g.stats["credit"]), Cfg.INK, 140))
	grid.add_child(_stat_card("Bugün tahsil", Cfg.fmt_money(g.stats["credit_paid"]), Cfg.GOOD, 140))
	grid.add_child(_stat_card("Silinen", Cfg.fmt_money(g.stats["credit_lost"]), Cfg.BAD, 140))
	body.add_child(grid)
	body.add_child(UIKit.section("Borçlular"))
	var ds := nb.debtors()
	if ds.is_empty():
		body.add_child(UIKit.label("Defter temiz, kimsenin borcu yok." if nb.mode != "off" else "Veresiye kapalı. Açarsan tanıdık müşteriler parası yetmeyince deftere yazdırır.", 13, Cfg.INK3, "body", 700))
	ds.sort_custom(func(a, b): return int(a["debt"]) > int(b["debt"]))
	for r in ds:
		var card := UIKit.card(Color.WHITE, 14, Vector4(12, 8, 12, 8), 0)
		var hb := UIKit.hbox(10)
		var tv := UIKit.vbox(-2); tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UIKit.label(r["name"], 15, Cfg.INK, "body", 900))
		var days: int = g.day - int(r["debt_day"])
		var trust_txt := "sözünün eri" if float(r["trust"]) > 0.75 else ("ödemeyi unutabilir" if float(r["trust"]) > 0.45 else "ödeyeceği şüpheli")
		if int(r["visits"]) < 3: trust_txt = "henüz tanımıyorsun"
		tv.add_child(UIKit.label("%s · %d gündür · %s%s" % [ARCH_SHORT.get(r["arch"], ""), days, trust_txt, " · hatırlatıldı" if r["reminded"] else ""], 11, Cfg.BAD if days >= 7 else Cfg.INK3, "body", 800))
		hb.add_child(tv)
		hb.add_child(UIKit.label(Cfg.fmt_money(r["debt"]), 20, Cfg.VIOLET, "display"))
		var rr: Dictionary = r
		var rb := UIKit.button("Hatırlat", "megaphone2", false, true)
		rb.disabled = r["reminded"]
		rb.tooltip_text = Loc.t("Borcunu nazikçe hatırlat: büyük ihtimalle yakında gelip öder, sadakati biraz düşer.")
		rb.pressed.connect(func(): nb.remind(g, rr); h.panel_sig = "")
		hb.add_child(rb)
		var fb := UIKit.button("Sil", "heart", false, true)
		fb.tooltip_text = Loc.t("Borcu sil: para gider ama sadakat ve mağaza puanı artar.")
		fb.pressed.connect(func(): nb.forgive(g, rr); h.panel_sig = "")
		hb.add_child(fb)
		card.add_child(hb)
		body.add_child(card)

static func _regulars(h, body: VBoxContainer) -> void:
	var g: Game = h.game
	var nb: Neighborhood = g.neighborhood
	var rs: Array = nb.residents.filter(func(r): return Neighborhood._arch(r["arch"])["stage"] <= g.stage)
	rs.sort_custom(func(a, b): return float(a["loyalty"]) > float(b["loyalty"]))
	var loyal := rs.filter(func(r): return float(r["loyalty"]) >= 70.0).size()
	var sulky := rs.filter(func(r): return float(r["loyalty"]) < 25.0).size()
	body.add_child(UIKit.wrap(UIKit.label("Mahallenin %d tanıdık yüzü. %d kişi dükkâna bağlı, %d kişi küs. Mutlu ayrılan müdavimin sadakati artar; sevdiği ürün yoksa ya da kuyrukta bekletilirse düşer. İstekleri 3 gün içinde karşılarsan çok sevinirler." % [rs.size(), loyal, sulky], 12, Cfg.INK2, "body", 700), 600))
	var reqs := rs.filter(func(r): return not r["request"].is_empty())
	if not reqs.is_empty():
		body.add_child(UIKit.section("İstekler"))
		for r in reqs:
			var hb := UIKit.hbox(8)
			var pid: String = r["request"]["pid"]
			hb.add_child(_thumb(h, pid, 34))
			var left: int = int(r["request"]["until"]) - g.day
			var l := UIKit.label("%s: \"%s getirir misin?\" · %s%s" % [r["name"], DB.product(pid)["name"], ("%d gün kaldı" % left) if left > 0 else "bugün son gün", " · rafta var" if g.is_stocked(pid) else ""], 13, Cfg.GOOD if g.is_stocked(pid) else Cfg.INK, "body", 800)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hb.add_child(l)
			body.add_child(hb)
	body.add_child(UIKit.section("Müdavimler"))
	for r in rs:
		var card := UIKit.card(Color.WHITE, 14, Vector4(12, 8, 12, 8), 0)
		var hb := UIKit.hbox(10)
		var chip := PanelContainer.new(); chip.add_theme_stylebox_override("panel", UIKit.sb(r["look"]["top"], 18, Color(0, 0, 0, 0), 0, 0, Vector4(7, 7, 7, 7)))
		chip.add_child(UIKit.icon("people", 18, Color.WHITE)); chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		hb.add_child(chip)
		var tv := UIKit.vbox(0); tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := UIKit.hbox(6)
		nm.add_child(UIKit.label(r["name"], 15, Cfg.INK, "body", 900))
		nm.add_child(UIKit.chip(ARCH_SHORT.get(r["arch"], ""), Color(0.12, 0.16, 0.27, 0.08), Cfg.INK2, 10))
		if int(r["debt"]) > 0: nm.add_child(UIKit.chip("borç " + Cfg.fmt_money(r["debt"]), Cfg.VIOLET, Color.WHITE, 10))
		tv.add_child(nm)
		tv.add_child(UIKit.wrap(UIKit.label(r["quirk"], 11, Cfg.INK3, "body", 700), 330))
		var last: int = r["last"]
		tv.add_child(UIKit.label("%d ziyaret · %s harcadı · %s" % [r["visits"], Cfg.fmt_money(r["spent"]), "hiç gelmedi" if last == 0 else ("bugün geldi" if last == g.day else ("dün geldi" if last == g.day - 1 else "%d gün önce geldi" % (g.day - last)))], 11, Cfg.INK2, "body", 800))
		hb.add_child(tv)
		var fav := UIKit.hbox(2)
		for pid in r["favs"]: fav.add_child(_thumb(h, pid, 30))
		hb.add_child(fav)
		var lv := UIKit.vbox(2); lv.custom_minimum_size.x = 96
		var loy: float = r["loyalty"]
		var col := Cfg.GOOD if loy >= 70 else (Cfg.MUSTARD if loy >= 40 else Cfg.BAD)
		lv.add_child(UIKit.label("sadakat %d" % int(loy), 11, col, "body", 900))
		lv.add_child(UIKit.bar(loy / 100.0, col, 90, 7))
		hb.add_child(lv)
		card.add_child(hb)
		body.add_child(card)

# ================================================================== quests
static func _quests(h, body: VBoxContainer) -> void:
	var g: Game = h.game
	if g.quests == null:
		body.add_child(UIKit.label("Görevler yakında.", 13, Cfg.INK3, "body", 700)); return
	body.add_child(UIKit.wrap(UIKit.label("Mahallenin küçük meydan okumaları. Aynı anda üç görev açık; biri bitince yenisi gelir. Ödüller nakit, puan ve bazen bedava eşya.", 12, Cfg.INK2, "body", 700), 600))
	for q in g.quests.active:
		body.add_child(quest_card(q, g, true))
	if not g.quests.done.is_empty():
		body.add_child(UIKit.section("Tamamlananlar (%d)" % g.quests.done.size()))
		for q in g.quests.done.slice(-6):
			body.add_child(UIKit.label("✓ %s · %s" % [q["title"], q["reward_text"]], 12, Cfg.GOOD, "body", 800))

static func quest_card(q: Dictionary, g: Game, big := false) -> PanelContainer:
	var card := UIKit.card(Color.WHITE if big else Color(1, 1, 1, 0.0), 12, Vector4(10, 6, 10, 6) if big else Vector4(0, 2, 0, 2), 0)
	var v := UIKit.vbox(2)
	var hb := UIKit.hbox(6)
	hb.add_child(UIKit.icon(q.get("icon", "flag"), 14 if not big else 18, Cfg.TERRA))
	var t := UIKit.label(q["title"], 12 if not big else 15, Cfg.INK, "body", 900); t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(t)
	hb.add_child(UIKit.label(g.quests.progress_text(g, q), 11 if not big else 13, Cfg.INK2, "body", 800))
	v.add_child(hb)
	if big:
		v.add_child(UIKit.wrap(UIKit.label(q["desc"], 12, Cfg.INK2, "body", 700), 560))
		v.add_child(UIKit.label("Ödül: " + q["reward_text"] + ("" if int(q.get("days", 0)) <= 0 else " · %d gün kaldı" % (int(q["until"]) - g.day + 1)), 12, Cfg.TEAL, "body", 800))
	v.add_child(UIKit.bar(g.quests.progress(g, q), Cfg.MUSTARD, 0, 5))
	card.add_child(v)
	return card

# ================================================================== the rival
static func _rival(h, body: VBoxContainer) -> void:
	var g: Game = h.game
	var rv = g.rival
	if rv == null or not rv.active: return
	body.add_child(UIKit.wrap(UIKit.label(rv.blurb(g), 12, Cfg.INK2, "body", 700), 600))
	var grid := GridContainer.new(); grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8)
	grid.add_child(_stat_card("Mahallede payın", "%%%d" % int(round(rv.share(g) * 100)), Cfg.GOOD if rv.share(g) >= 0.5 else Cfg.BAD, 180))
	grid.add_child(_stat_card("Dün ona giden", str(rv.lost_yesterday), Cfg.BAD, 180))
	grid.add_child(_stat_card("Onun puanı", "%.1f★" % rv.rating, Cfg.INK, 180))
	body.add_child(grid)
	body.add_child(UIKit.section("Fiyat karşılaştırması"))
	var head := UIKit.hbox(8)
	for c in [["", 36], ["ÜRÜN", 150], ["SEN", 70], [Rival.brand_now, 70], ["", 180]]:
		var l := UIKit.label(c[0], 11, Cfg.INK3, "body", 800); l.custom_minimum_size.x = c[1]; head.add_child(l)
	body.add_child(head)
	for pid in rv.prices:
		if DB.product(pid)["stage"] > g.stage: continue
		var row := UIKit.hbox(8)
		row.add_child(_thumb(h, pid, 34))
		var nl := UIKit.label(DB.product(pid)["name"], 14, Cfg.INK, "body", 800); nl.custom_minimum_size.x = 150; row.add_child(nl)
		var mine: int = g.effective_price(pid)
		var theirs: int = rv.prices[pid]
		var ml := UIKit.label("₺%d" % mine, 16, Cfg.BAD if mine > theirs * 1.12 else Cfg.INK, "display"); ml.custom_minimum_size.x = 70; row.add_child(ml)
		var tl := UIKit.label("₺%d" % theirs, 16, Cfg.INK2, "display"); tl.custom_minimum_size.x = 70; row.add_child(tl)
		var verdict := "Pahalı kalıyorsun" if mine > theirs * 1.12 else ("Başa baş" if mine >= theirs * 0.95 else "Senden ucuz alan yok")
		row.add_child(UIKit.chip(verdict, Cfg.BAD if mine > theirs * 1.12 else (Cfg.MUSTARD if mine >= theirs * 0.95 else Cfg.GOOD), Color.WHITE, 10))
		body.add_child(row)
	body.add_child(UIKit.section("Karşılık ver"))
	for a in rv.actions(g):
		var card := UIKit.card(Color.WHITE, 14, Vector4(12, 8, 12, 8), 0)
		var hb := UIKit.hbox(10)
		var tv := UIKit.vbox(0); tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UIKit.label(a["name"], 15, Cfg.INK, "body", 900))
		tv.add_child(UIKit.wrap(UIKit.label(a["desc"], 12, Cfg.INK2, "body", 700), 400))
		hb.add_child(tv)
		var b := UIKit.button(a["button"], "", true, true)
		b.disabled = a.get("disabled", false)
		var aid: String = a["id"]
		b.pressed.connect(func(): rv.act(g, aid); h.panel_sig = "")
		hb.add_child(b)
		card.add_child(hb)
		body.add_child(card)

# ================================================================== product analysis
static func analysis(h, body: VBoxContainer) -> void:
	var g: Game = h.game
	var log: Array = g.product_log.slice(-7)
	body.add_child(UIKit.wrap(UIKit.label("Son %d günün satışları. Kâr = satış adedi × (fiyat − maliyet). Kaçan satış: rafta bulunamayan ya da pahalı bulunan ürün. Bugünün rakamları gün sonunda eklenir." % log.size(), 12, Cfg.INK2, "body", 700), 700))
	if log.is_empty():
		body.add_child(UIKit.label("İlk gün kapanınca burada ürün ürün analiz çıkacak.", 13, Cfg.INK3, "body", 700)); return
	var rows := []
	for p in g.unlocked_products():
		var pid: String = p["id"]
		var days := []
		var units := 0
		var profit := 0
		var missed := 0
		var exp := 0
		var oos := 0.0
		for e in log:
			var n := int(e["sold"].get(pid, 0))
			days.append(n); units += n
			var pr := int(e["price"].get(pid, p["base"]))
			var cst := int(e.get("cost", {}).get(pid, g.cost_of(pid)))
			profit += n * (pr - cst)
			missed += int(e["missed"].get(pid, 0)); exp += int(e["expensive"].get(pid, 0))
			oos += float(e["oos"].get(pid, 0.0))
		var by: Dictionary = (g.stats["buyers"].get(pid, {}) as Dictionary).duplicate()
		for e in log:
			var eb: Dictionary = e.get("buyers", {}).get(pid, {})
			for a in eb: by[a] = int(by.get(a, 0)) + int(eb[a])
		rows.append({"p": p, "days": days, "units": units, "profit": profit, "missed": missed, "exp": exp, "oos": oos / maxf(1, log.size()), "stocked": g.is_stocked(pid), "by": by})
	rows.sort_custom(func(a, b): return a["profit"] > b["profit"])
	# headline cards
	var stars := rows.filter(func(r): return r["profit"] > 0).slice(0, 3).map(func(r): return r["p"]["name"])
	var asked := rows.filter(func(r): return not r["stocked"] and r["missed"] >= 3)
	var pricey := rows.filter(func(r): return r["exp"] >= 4)
	var tips := UIKit.vbox(4)
	if not stars.is_empty(): tips.add_child(_tip("star", Cfg.MUSTARD, "En çok kazandıran: " + ", ".join(stars)))
	if not asked.is_empty(): tips.add_child(_tip("question", Cfg.VIOLET, "Rafında yok ama soruluyor: " + ", ".join(asked.map(func(r): return "%s (%d kişi)" % [r["p"]["name"], r["missed"]]))))
	if not pricey.is_empty(): tips.add_child(_tip("tag", Cfg.TERRA, "Pahalı bulunuyor: " + ", ".join(pricey.map(func(r): return "%s (%d kez)" % [r["p"]["name"], r["exp"]]))))
	var short := rows.filter(func(r): return r["stocked"] and r["oos"] >= 90.0)
	if not short.is_empty(): tips.add_child(_tip("empty", Cfg.BAD, "Rafta sık bitiyor: " + ", ".join(short.map(func(r): return "%s (günde ~%d dk boş)" % [r["p"]["name"], int(r["oos"])]))))
	body.add_child(tips)
	var head := UIKit.hbox(8)
	for c in [["", 36], ["ÜRÜN", 130], ["SON GÜNLER", 120], ["ADET", 50], ["KÂR", 80], ["KAÇAN", 56], ["KİM ALIYOR", 110], ["DURUM", 130]]:
		var l := UIKit.label(c[0], 11, Cfg.INK3, "body", 800); l.custom_minimum_size.x = c[1]; head.add_child(l)
	body.add_child(head)
	var mx := 1
	for r in rows:
		for n in r["days"]: mx = maxi(mx, n)
	for r in rows:
		var p: Dictionary = r["p"]
		var row := UIKit.hbox(8)
		row.add_child(_thumb(h, p["id"], 34))
		var nv := UIKit.vbox(-3); nv.custom_minimum_size.x = 130
		nv.add_child(UIKit.label(p["name"], 14, Cfg.INK, "body", 800))
		nv.add_child(UIKit.label("₺%d · maliyet ₺%d" % [g.prices[p["id"]], g.cost_of(p["id"])], 10, Cfg.INK3, "body", 700))
		row.add_child(nv)
		row.add_child(_spark(r["days"], mx, Cfg.TEAL))
		for v in [[str(r["units"]), 50, Cfg.INK], [Cfg.fmt_money(r["profit"]), 80, Cfg.GOOD if r["profit"] > 0 else Cfg.INK3], [str(r["missed"] + r["exp"]), 56, Cfg.BAD if r["missed"] + r["exp"] >= 5 else Cfg.INK2]]:
			var l := UIKit.label(v[0], 15, v[2], "display"); l.custom_minimum_size.x = v[1]; row.add_child(l)
		var top := ""
		var topn := 0
		for a in r["by"]:
			if int(r["by"][a]) > topn: topn = int(r["by"][a]); top = a
		var bl := UIKit.label(ARCH_SHORT.get(top, "—") if top != "" else "—", 12, Cfg.INK2, "body", 800); bl.custom_minimum_size.x = 110; row.add_child(bl)
		row.add_child(_verdict(r, g))
		body.add_child(row)

static func _tip(ic: String, col: Color, text: String) -> HBoxContainer:
	var hb := UIKit.hbox(8)
	hb.add_child(UIKit.icon(ic, 16, col))
	hb.add_child(UIKit.wrap(UIKit.label(text, 12, Cfg.INK, "body", 800), 680))
	return hb

static func _spark(days: Array, mx: int, col: Color) -> Control:
	var hb := UIKit.hbox(2); hb.custom_minimum_size = Vector2(120, 30)
	hb.alignment = BoxContainer.ALIGNMENT_BEGIN
	for n in days:
		var holder := Control.new(); holder.custom_minimum_size = Vector2(12, 30)
		var bar := ColorRect.new(); bar.color = col
		var hh := maxf(2.0, 28.0 * float(n) / float(mx))
		bar.position = Vector2(0, 30 - hh); bar.size = Vector2(12, hh)
		bar.tooltip_text = Loc.t("%d adet" % n); bar.mouse_filter = Control.MOUSE_FILTER_PASS
		holder.add_child(bar)
		hb.add_child(holder)
	return hb

static func _verdict(r: Dictionary, g: Game) -> PanelContainer:
	if not r["stocked"]:
		if r["missed"] >= 3: return UIKit.chip("Rafa koy!", Cfg.VIOLET, Color.WHITE, 10)
		return UIKit.chip("Satılmıyor", Color(0.12, 0.16, 0.27, 0.08), Cfg.INK3, 10)
	if r["exp"] >= 4: return UIKit.chip("Fiyat yüksek", Cfg.TERRA, Color.WHITE, 10)
	if r["oos"] >= 90.0: return UIKit.chip("Stok yetmiyor", Cfg.BAD, Color.WHITE, 10)
	if r["units"] <= 2: return UIKit.chip("Durgun, rafı meşgul ediyor", Cfg.MUSTARD, Cfg.INK, 10)
	if r["profit"] > 0: return UIKit.chip("Kazandırıyor", Cfg.GOOD, Color.WHITE, 10)
	return UIKit.chip("Normal", Color(0.12, 0.16, 0.27, 0.08), Cfg.INK2, 10)

# ================================================================== rating breakdown
const MOOD_TIPS := {
	"Raf boş": "Reyon görevlisi al, depoyu dolu tut (Tedarik, T). Depo akşamdan boşalıyorsa bir Depo Rafı daha ekle.",
	"Aradığı ürün satılmıyor": "Analiz sekmesinde en çok sorulanları rafa koy.",
	"Fiyat pahalı": "Ürün & Fiyat'ta kırmızı arketipler var mı bak.",
	"Kuyrukta uzun bekleme": "Ek kasa, kasiyer ya da Temassız POS.",
	"Kuyruktan vazgeçti": "Kasa sayısını artır, kasiyer vardiyalarını kontrol et.",
	"Kirli zemin": "Çöp kovası ve temizlik görevlisi.",
	"Islak zeminde kayma": "Temizlik görevlisi ve uyarı levhası.",
	"Dar koridorlar": "Raflar arasında en az bir kare boşluk bırak.",
	"Levha yok, reyon zor bulunuyor": "Reyon levhası as (İnşa → Ortam).",
	"Bayat ekmek": "Akşam indirimini aç ya da daha az ekmek al.",
	"Bütçe yetmedi": "Ucuz ürün çeşidi ekle ya da veresiyeyi aç.",
	"Rafa giden yol kapalı": "Rafın önünü aç.",
	"Şarküteride usta yok": "Şarküteri Ustası al.",
	"Araba parkı yok": "Alışveriş Arabası Parkı kur.",
}

static func rating(h, body: VBoxContainer) -> void:
	var g: Game = h.game
	var st: Dictionary = g.stats
	var avg: float = float(st["mood_sum"]) / maxf(1.0, float(st["mood_n"]))
	body.add_child(UIKit.wrap(UIKit.label("Mağaza puanı, ayrılan her müşterinin keyfine göre yavaş yavaş değişir: keyfi 80 olan müşteri puanı 4★'a, 50 olan 2,5★'a doğru çeker. Aşağıda bugün müşterilerin keyfini neyin artırıp neyin düşürdüğü var.", 12, Cfg.INK2, "body", 700), 560))
	var grid := GridContainer.new(); grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8)
	grid.add_child(_stat_card("Şu anki puan", "%.2f★" % g.rating, Cfg.INK, 170))
	grid.add_child(_stat_card("Bugünkü ortalama keyif", "%d → %.1f★" % [int(avg), avg / 20.0] if int(st["mood_n"]) > 0 else "—", Cfg.GOOD if avg >= 70 else (Cfg.WARN if avg >= 50 else Cfg.BAD), 170))
	grid.add_child(_stat_card("Ayrılan müşteri", str(st["mood_n"]), Cfg.INK, 170))
	body.add_child(grid)
	var rows: Array = []
	var why: Dictionary = st.get("mood_why", {})
	for k in why: rows.append([k, float(why[k][0]), int(why[k][1])])
	var neg := rows.filter(func(r): return r[1] < 0.0)
	var pos := rows.filter(func(r): return r[1] > 0.0)
	neg.sort_custom(func(a, b): return a[1] < b[1])
	pos.sort_custom(func(a, b): return a[1] > b[1])
	body.add_child(UIKit.section("Keyfi düşürenler"))
	if neg.is_empty(): body.add_child(UIKit.label("Bugün şikâyet yok.", 13, Cfg.GOOD, "body", 800))
	var mx := 1.0
	for r in rows: mx = maxf(mx, absf(r[1]))
	for r in neg.slice(0, 8):
		var hb := UIKit.hbox(8)
		var l := UIKit.label(r[0], 13, Cfg.INK, "body", 800); l.custom_minimum_size.x = 210; hb.add_child(l)
		var b := UIKit.bar(absf(r[1]) / mx, Cfg.BAD, 120, 8); b.size_flags_vertical = Control.SIZE_SHRINK_CENTER; hb.add_child(b)
		hb.add_child(UIKit.label("%d kez" % r[2], 12, Cfg.INK3, "body", 800))
		var tip := UIKit.label(MOOD_TIPS.get(r[0], ""), 11, Cfg.TEAL, "body", 800); tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(tip)
		body.add_child(hb)
	body.add_child(UIKit.section("Keyfi artıranlar"))
	if pos.is_empty(): body.add_child(UIKit.label("Henüz yok.", 13, Cfg.INK3, "body", 800))
	for r in pos.slice(0, 6):
		var hb2 := UIKit.hbox(8)
		var l2 := UIKit.label(r[0], 13, Cfg.INK, "body", 800); l2.custom_minimum_size.x = 210; hb2.add_child(l2)
		var b2 := UIKit.bar(absf(r[1]) / mx, Cfg.GOOD, 120, 8); b2.size_flags_vertical = Control.SIZE_SHRINK_CENTER; hb2.add_child(b2)
		hb2.add_child(UIKit.label("%d kez" % r[2], 12, Cfg.INK3, "body", 800))
		body.add_child(hb2)
	if not g.history.is_empty():
		body.add_child(UIKit.section("Son günlerin puanı"))
		var hh := UIKit.hbox(10)
		for e in g.history.slice(-7):
			hh.add_child(UIKit.label("G%d %.1f" % [e["day"], float(e["rating"])], 12, Cfg.INK2, "body", 800))
		body.add_child(hh)

# ================================================================== stage guides
const STAGE_GUIDE := [
	[],
	[["build", "Manav tezgâhı, gondol ve açık soğutucu açıldı. Yeni alanı İnşa (B) ile doldur."],
	 ["sneak", "Fırsatçılar geliyor: kör noktalara kamera, kapıya alarm. G tuşu kör noktaları gösterir."],
	 ["staff", "Temizlik ve güvenlik görevlisi alınabilir. Islak zemin artık sık olacak."],
	 ["rival", "İki gün sonra karşıya UCUZA açılıyor; Mahalle panelinden (N) takip et."]],
	[["layers", "Süpermarkette levhasız reyon bulunmuyor: her koridora bir Reyon Levhası as."],
	 ["food", "Fırın ve fırıncı, şarküteri ve usta, dondurma dolabı: kârlı ama personel ister."],
	 ["box", "Odalar: depo odası (+600), soğuk oda (bozulmayı durdurur), mola odası."],
	 ["cart", "Haftalık alışverişçiler araba ister; Otopark Anlaşması onları çoğaltır."]],
	[["mall", "Kiracı birimlerini AVM panelinden (V) doldur; her kiracının istediği farklı."],
	 ["floors", "Üst kata PageUp ile çık. Yürüyen merdivenler bozulabilir, teknisyen al."],
	 ["food", "Yemek katına masa, oyun alanı ve tuvalet koy; kirli masa keyfi düşürür."],
	 ["star", "Etkinlik takviminden konser, imza günü, bayram indirimi planla."]],
]
