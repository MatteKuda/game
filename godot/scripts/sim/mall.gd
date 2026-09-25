class_name Mall
extends Node3D
## AVM simulation: tenant units, offers, explainable satisfaction, events, breakdowns and visitors.

var game
var units: Array = [] # [{idx, def, tenant: {} or tenant state, offers: []}]
var connectors: Array = [] # [{def, broken, repair_t}]
var visitors: Array = []
var event := {} # {def, day}
var scheduled: Array = [] # [{day, id}]
var mood := 3.5
var stats := {}
var history: Array = []
var _spawn_acc := 0.0
var _hour_acc := 0.0
var _sat_acc := 0.0

static func new_stats() -> Dictionary:
	return {"visitors": 0, "tenant_sales": 0, "rent": 0, "share": 0, "incidents": 0, "no_seat": 0}

func setup(g) -> void:
	game = g
	stats = new_stats()
	for i in MallDB.UNITS.size(): units.append({"idx": i, "def": MallDB.UNITS[i], "tenant": {}, "offers": []})
	for d in MallDB.CONNECTORS: connectors.append({"def": d, "broken": false, "repair_t": 0.0, "claimed": 0})
	roll_offers()

# ------------------------------------------------------------ layout
func apply_grids(g0: Grid, g1: Grid) -> void:
	for r in MallDB.F0_CORRIDORS:
		for z in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x): g0.region[g0.idx(x, z)] = Grid.R_MALL
	var F := MallDB.FOOTPRINT
	g1.region.fill(0)
	for z in range(F.position.y, F.end.y):
		for x in range(F.position.x, F.end.x): g1.region[g1.idx(x, z)] = Grid.R_MALL
	for u in units:
		var d: Dictionary = u["def"]
		var g: Grid = g1 if d["floor"] == 1 else g0
		var r: Rect2i = d["rect"]
		for z in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x): g.region[g.idx(x, z)] = Grid.R_UNIT0 + u["idx"]
		for t in d["door"]:
			var o: Vector2i = t + d["dir"]
			g.add_door(t.x, t.y, o.x, o.y)
			g.reserved[g.idx(o.x, o.y)] = 1
	for W in [MallDB.WELL, MallDB.STAGE]:
		for z in range(W.position.y, W.end.y):
			for x in range(W.position.x, W.end.x): g1.region[g1.idx(x, z)] = 0
	for c in MallDB.CONNECTORS:
		var b: Rect2i = c["blocked"]
		for g in [g0, g1]:
			for z in range(b.position.y, b.end.y):
				for x in range(b.position.x, b.end.x): g.region[g.idx(x, z)] = 0
		for e in [c["from"], c["to"]]:
			var g2: Grid = g1 if e[0] == 1 else g0
			g2.reserved[g2.idx(e[1].x, e[1].y)] = 1
	for u in units: _apply_furniture(u, g1 if u["def"]["floor"] == 1 else g0)
	for x in MallDB.ENTRANCES:
		g0.add_door(x, 15, x, 16)
		g0.reserved[g0.idx(x, 15)] = 1
	g0.version += 1; g1.version += 1

## the back band of a leased unit holds racks, counters and clerks: not walkable
func furniture_tiles(u: Dictionary) -> Array:
	var d: Dictionary = u["def"]
	var r: Rect2i = d["rect"]
	var dir: Vector2i = d["dir"]
	var band := furniture_band(u)
	var out := []
	for z in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var dd := 0
			if dir.x > 0: dd = x - r.position.x
			elif dir.x < 0: dd = r.end.x - 1 - x
			elif dir.y > 0: dd = z - r.position.y
			else: dd = r.end.y - 1 - z
			if dd < band: out.append(Vector2i(x, z))
	return out

static func furniture_band(u: Dictionary) -> int:
	var r: Rect2i = u["def"]["rect"]
	var depth: int = r.size.x if (u["def"]["dir"] as Vector2i).x != 0 else r.size.y
	return 1 if depth <= 4 else 2

func _apply_furniture(u: Dictionary, g: Grid = null) -> void:
	if g == null: g = game.floors[u["def"]["floor"]]
	var on: bool = not u["tenant"].is_empty()
	for t in furniture_tiles(u):
		var i := g.idx(t.x, t.y)
		if on: g.fixture[i] = -2
		elif g.fixture[i] == -2: g.fixture[i] = 0
	g.version += 1

func door_outside(u: Dictionary) -> Vector2i:
	return (u["def"]["door"][0] as Vector2i) + (u["def"]["dir"] as Vector2i)

func random_inside(u: Dictionary) -> Vector2i:
	var r: Rect2i = u["def"]["rect"]
	var x := r.position.x + 1 + randi() % maxi(1, r.size.x - 2)
	var z := r.position.y + 1 + randi() % maxi(1, r.size.y - 2)
	var g: Grid = game.floors[u["def"]["floor"]]
	return Vector2i(x, z) if g.walkable(x, z) else u["def"]["door"][0]

# ------------------------------------------------------------ tenants
func roll_offers() -> void:
	var present := {}
	for u in units: if not u["tenant"].is_empty(): present[u["tenant"]["def"]["id"]] = true
	for u in units:
		if not u["tenant"].is_empty():
			u["offers"] = []; continue
		var food: bool = u["def"].get("food", false)
		var big := MallDB.unit_area(u) >= 45
		var pool := MallDB.TENANTS.filter(func(t): return t.get("food", false) == food and not present.has(t["id"]) and (big or not t.get("big", false)))
		pool.shuffle()
		var offers := []
		for d in pool.slice(0, 3): offers.append({"def": d, "rent": int(round(d["rent"] * randf_range(0.85, 1.15) / 10.0)) * 10})
		u["offers"] = offers

func lease(u: Dictionary, i: int) -> void:
	if i >= u["offers"].size() or not u["tenant"].is_empty(): return
	var o: Dictionary = u["offers"][i]
	u["tenant"] = {"def": o["def"], "rent": o["rent"], "sat": 65.0, "reasons": [], "sales": 0, "visitors": 0, "low_days": 0, "since": game.day}
	for other in units: other["offers"] = other["offers"].filter(func(x): return x["def"]["id"] != o["def"]["id"])
	u["offers"] = []
	_apply_furniture(u)
	recalc_sat()
	game.mall_changed.emit()

func evict(u: Dictionary, reason := "Sözleşme feshedildi") -> void:
	if u["tenant"].is_empty(): return
	var t: Dictionary = u["tenant"]
	game.alert("tenantLeft%d" % u["idx"], "shop", "%s (%s) çıktı: %s. Birim yeniden kiralık." % [t["def"]["brand"], t["def"]["name"], reason], "bad")
	u["tenant"] = {}
	_apply_furniture(u)
	roll_offers()
	game.mall_changed.emit()

func event_boost(cat: String) -> float:
	if event.is_empty(): return 1.0
	var e: Dictionary = event["def"]
	return (2.6 if e.get("boost", "") == cat else 1.0) * (1.15 if e["tenants"] > 1.0 else 1.0)

func shop_at(v, u: Dictionary, food := false) -> void:
	var t: Dictionary = u["tenant"]
	var d: Dictionary = t["def"]
	var m := clampf(0.6 + (mood - 3.0) * 0.2 + (t["sat"] - 50.0) / 200.0, 0.3, 1.4)
	var ev_mul: float = event["def"]["tenants"] if not event.is_empty() else 1.0
	var boosted: bool = not event.is_empty() and event["def"].get("boost", "") == d["id"]
	var chance: float = d["buy"] * m * ev_mul * (1.6 if boosted else 1.0)
	if food or randf() < chance:
		var amt := int(round(randf_range(d["spend"][0], d["spend"][1])))
		if game.upgrades.has("dijital"): amt = int(round(amt * 1.15))
		if boosted: amt = int(round(amt * 1.5))
		t["sales"] += amt; stats["tenant_sales"] += amt
		v.spent += amt
		if not food:
			v.view.add_bag(d["color"])
			v.log_thought("shop", "%s'dan alışveriş yaptım." % d["brand"], game)
		v.mood += 5
	else:
		v.log_thought("wallet", "%s'da beğendiğim bir şey yoktu." % d["brand"], game, false)

func record_visit(v) -> void:
	mood += (clampf(v.mood / 20.0, 0.0, 5.0) - mood) * 0.03

## tenant satisfaction with explainable reasons
func recalc_sat() -> void:
	var fx: Array = game.fixtures
	var lit := 0
	for L in game.litter:
		if L["lvl"] == 1 or game.grid.is_mall(L["tile"].x, L["tile"].y): lit += 1
	var seats := 0
	var dirty := 0
	for f in fx:
		if f.def["kind"] == "table":
			seats += int(f.def.get("seats", 0))
			if f.dirty: dirty += 1
	var noisy := units.filter(func(u): return not u["tenant"].is_empty() and u["tenant"]["def"].get("noisy", false))
	var dist := func(a: Dictionary, p: Vector2i, fl: int) -> float:
		if a["def"]["floor"] != fl: return 99.0
		var d := door_outside(a)
		return Vector2(d.x - p.x, d.y - p.y).length()
	var broken_any := connectors.any(func(c): return c["broken"])
	var wcs: Array = fx.filter(func(f): return f.def["kind"] == "wc")
	for u in units:
		var t: Dictionary = u["tenant"]
		if t.is_empty(): continue
		var R := []
		var add := func(text: String, v: int) -> void:
			if v != 0: R.append({"text": text, "v": v})
		add.call("Temel memnuniyet", 55)
		add.call("Bugünkü ziyaretçi (%d)" % t["visitors"], mini(22, int(round(t["visitors"] * 1.5))) - (10 if game.clock > 13 * 60 and t["visitors"] < 5 else 0))
		add.call("AVM keyfi", int(round((mood - 3.2) * 10.0)))
		var fl: int = u["def"]["floor"]
		match t["def"]["id"]:
			"giyim": add.call("Zemin katta, girişe yakın" if fl == 0 else "Üst katta, girişten uzak", 10 if fl == 0 else -6)
			"elektronik":
				var near := false
				for c in MallDB.CONNECTORS:
					for e in [c["from"], c["to"]]:
						if dist.call(u, e[1], e[0]) < 10.0: near = true
				add.call("Yürüyen merdiven / asansöre yakın" if near else "Merdiven ve asansörden uzak", 12 if near else -14)
			"oyuncak":
				var play := false
				for f in fx:
					if f.def["kind"] == "play" and dist.call(u, Vector2i(floori(f.center().x), floori(f.center().z)), f.lvl) < 12.0: play = true
				add.call("Çocuk oyun alanı yakında" if play else "Yakında oyun alanı yok", 18 if play else -6)
			"spor": add.call("Üst kat vitrini" if fl == 1 else "Zemin kat", 6 if fl == 1 else 0)
			"kuafor": add.call("Koridorlar kirli" if lit >= 3 else "Koridorlar temiz", -12 if lit >= 3 else 5)
			"kitap":
				if not event.is_empty() and event["def"].get("noisy", false): add.call("Konser gürültüsü", -15)
		if t["def"].get("food", false):
			add.call(("Yemek katında %d koltuk" % seats) if seats >= 8 else ("Sadece %d koltuk var" % seats), 16 if seats >= 12 else (10 if seats >= 8 else (-10 if seats >= 4 else -26)))
			if dirty >= 2: add.call("%d kirli masa" % dirty, -14)
		if not t["def"].get("noisy", false) and t["def"]["id"] != "oyuncak":
			var n := 0
			for o in noisy:
				if o != u and o["def"]["floor"] == fl and dist.call(u, door_outside(o), fl) < 11.0: n += 1
			if n > 0: add.call("Yanında gürültülü oyun salonu", -12 * n)
		if broken_any and fl == 1: add.call("Yürüyen merdiven arızalı", -8)
		if wcs.is_empty(): add.call("AVM'de tuvalet yok", -8)
		elif wcs.any(func(w): return w.dirty): add.call("Tuvaletler kirli", -4)
		if t["def"]["id"] == "sinema":
			var foods := units.filter(func(o): return not o["tenant"].is_empty() and o["tenant"]["def"].get("food", false)).size()
			add.call(("Yemek katında %d restoran" % foods) if foods >= 2 else "Yemek katı cılız", 10 if foods >= 2 else -8)
		if not event.is_empty() and event["def"].get("boost", "") == t["def"]["id"]: add.call("%s etkinliği" % event["def"]["name"], 15)
		t["reasons"] = R
		var total := 0
		for x in R: total += int(x["v"])
		t["sat"] = clampf(total, 0.0, 100.0)

# ------------------------------------------------------------ connectors
func connector_working(id: String) -> bool:
	for c in connectors: if c["def"]["id"] == id: return not c["broken"]
	return false

## a fix finished (by our technician or the outside contractor)
func fixed(c: Dictionary, by_tech := false) -> void:
	c["broken"] = false; c["repair_t"] = 0.0; c["claimed"] = 0
	game.alert("fixed" + c["def"]["id"], "wrench", "%s %s." % [c["def"]["name"], "teknisyen tarafından onarıldı" if by_tech else "tamir edildi"], "good")
	game.mall_changed.emit()

func repair(c: Dictionary) -> void:
	if not c["broken"] or c["repair_t"] > 0.0 or int(c.get("claimed", 0)) != 0: return
	if game.money < 600:
		game.alert("nomoney", "wallet", "Tamir için yeterli nakit yok.", "bad"); return
	game.money -= 600; game.stats["other"] += 600
	c["repair_t"] = 40.0
	game.mall_changed.emit()

# ------------------------------------------------------------ events
func schedule(id: String, when: String) -> bool:
	var d := MallDB.event(id)
	var dd: int = game.day if when == "today" else game.day + 1
	if scheduled.any(func(s): return s["day"] == dd) or (when == "today" and not event.is_empty()):
		game.alert("evbusy", "crowd", "O gün için zaten bir etkinlik var.", "warn"); return false
	if d.get("needs", "") == "play" and not game.fixtures.any(func(f): return f.def["kind"] == "play"):
		game.alert("evneeds", "fun", "Çocuk Şenliği için önce bir oyun alanı kur.", "warn"); return false
	if d.has("needs") and d["needs"] != "play" and not units.any(func(u): return not u["tenant"].is_empty() and u["tenant"]["def"]["id"] == d["needs"]):
		game.alert("evneeds", "shop", "Bu etkinlik için ilgili kiracı (kitabevi) gerekli.", "warn"); return false
	if game.money < d["cost"]:
		game.alert("nomoney", "wallet", "Etkinlik için yeterli nakit yok.", "bad"); return false
	game.money -= d["cost"]; game.stats["other"] += int(d["cost"])
	if when == "today": _begin_event(d, dd)
	else: scheduled.append({"day": dd, "id": id})
	game.mall_changed.emit()
	return true

func _begin_event(d: Dictionary, dd: int) -> void:
	event = {"def": d, "day": dd}
	if game.mall_shell: game.mall_shell.set_event(d["id"])

func start_day() -> void:
	stats = new_stats()
	for u in units:
		if not u["tenant"].is_empty(): u["tenant"]["sales"] = 0; u["tenant"]["visitors"] = 0
	event = {}
	if game.mall_shell: game.mall_shell.set_event("")
	for s in scheduled:
		if s["day"] == game.day:
			_begin_event(MallDB.event(s["id"]), s["day"])
			scheduled.erase(s)
			game.alert("eventday", "fun", "Bugün: %s! Kalabalık bekleniyor." % event["def"]["name"], "good", null, 0.0)
			break
	roll_offers()

func end_day() -> Dictionary:
	recalc_sat()
	var rent := 0
	var share := 0
	for u in units:
		var t: Dictionary = u["tenant"]
		if t.is_empty(): continue
		rent += int(t["rent"])
		share += int(round(t["sales"] * t["def"]["share"]))
		if t["sat"] < 25.0:
			t["low_days"] += 1
			if t["low_days"] >= 2: evict(u, "memnun kalmadı")
			else: game.alert("tenantWarn%d" % u["idx"], "angry", "%s memnun değil (%d). Sebepleri kiracı kartında." % [t["def"]["brand"], int(t["sat"])], "warn", null, 0.0)
		else: t["low_days"] = 0
	stats["rent"] = rent; stats["share"] = share
	history.append({"day": game.day, "income": rent + share, "visitors": stats["visitors"]})
	return {"rent": rent, "share": share, "visitors": stats["visitors"], "sales": stats["tenant_sales"], "incidents": stats["incidents"], "mood": mood}

# ------------------------------------------------------------ tick
func update(dt: float) -> void:
	var open := units.filter(func(u): return not u["tenant"].is_empty()).size()
	if game.is_open() and open > 0:
		var h: float = game.hour()
		var w := 0.0
		for a in MallDB.VISITORS: w += DB.curve(a, h)
		w /= MallDB.VISITORS.size()
		var ev: float = event["def"]["visitors"] if not event.is_empty() else 1.0
		var rate := 0.1 * w * (0.4 + 0.1 * open) * (0.6 + mood / 5.0 * 0.7) * ev * (1.5 if not event.is_empty() and event["def"]["id"] == "konser" and h > 17.0 else 1.0) * (1.1 if game.upgrades.has("klima") else 1.0)
		_spawn_acc += dt * rate
		var cap := 60 if not event.is_empty() else 44
		while _spawn_acc > 1.0:
			_spawn_acc -= 1.0
			if visitors.size() < cap: _spawn()
	for v in visitors: v.update(dt, game)
	for i in range(visitors.size() - 1, -1, -1):
		var v = visitors[i]
		if v.removed:
			visitors.remove_at(i)
			if game.is_selected(v): game.select({})
			v.dispose()
	_hour_acc += dt * Cfg.MIN_PER_SEC
	for c in connectors:
		if c["repair_t"] > 0.0:
			c["repair_t"] -= dt * Cfg.MIN_PER_SEC
			if c["repair_t"] <= 0.0: fixed(c)
	if _hour_acc > 60.0:
		_hour_acc = 0.0
		if game.is_open():
			var maint := 0.5 if game.has_role("technician") else 1.0
			for c in connectors:
				if c["def"]["kind"] == "stairs": continue
				if not c["broken"] and randf() < (0.02 if c["def"]["kind"] == "escalator" else 0.012) * maint:
					c["broken"] = true
					var b: Rect2i = c["def"]["blocked"]
					game.alert("broke" + c["def"]["id"], "wrench", ("%s arızalandı! Teknisyen yolda." if game.has_role("technician") else "%s arızalandı! Ziyaretçiler dolaşmak zorunda. Tıklayıp tamir ettir ya da teknisyen al.") % c["def"]["name"], "bad", Vector3(Cfg.rc(b).x, c["def"]["from"][0] * Cfg.FLOOR_H, Cfg.rc(b).y), 0.0)
					game.mall_changed.emit()
		if not event.is_empty() and visitors.size() > 32 and not game.has_role("security") and randf() < 0.4:
			var v = visitors.pick_random()
			v.view.play("angry"); v.log_thought("angry", "Kalabalıkta itiş kakış çıktı!", game)
			stats["incidents"] += 1
			mood = maxf(0.0, mood - 0.25)
			game.alert("incident", "crowd", "Etkinlik kalabalığında arbede çıktı! Güvenlik görevlisi olmadan büyük etkinlik riskli.", "bad", v.position, 60.0)
	_sat_acc += dt
	if _sat_acc > 1.5:
		_sat_acc = 0.0; recalc_sat()

func sync_children(dt: float) -> void:
	for v in visitors: v.track_child(dt)

func _spawn() -> void:
	var h: float = game.hour()
	var ws := []
	var tot := 0.0
	for a in MallDB.VISITORS:
		var w := DB.curve(a, h) * (float(event["def"].get("family", 1.0)) if a.get("child", false) and not event.is_empty() else 1.0)
		ws.append(w); tot += w
	var r := randf() * tot
	var arch: Dictionary = MallDB.VISITORS[-1]
	for i in ws.size():
		r -= ws[i]
		if r <= 0.0: arch = MallDB.VISITORS[i]; break
	var from_left := randf() < 0.5
	var z := Cfg.SIDEWALK_Z0 + randi() % 3
	var x := 0 if from_left else Cfg.MAP_W - 1
	if not game.grid.walkable(x, z): return
	var v := Visitor.new()
	add_child(v)
	v.setup_visitor(arch, self)
	v.position = Vector3(x + 0.5, 0.02, z + 0.5)
	v.exit_x = 0 if randf() < 0.5 else Cfg.MAP_W - 1
	var best: int = MallDB.ENTRANCES[0]
	for e in MallDB.ENTRANCES: if absi(e - x) < absi(best - x): best = e
	v.entrance_x = best
	v.go_to(game, Vector2i(v.entrance_x, 16))
	visitors.append(v)
