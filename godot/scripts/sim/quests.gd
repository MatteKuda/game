class_name Quests
extends RefCounted
## Small side goals ("görevler") so there is always something to aim for between expansions.
## Three are open at once; a finished or expired one is replaced the next morning.

var active: Array = []
var done: Array = []
var _next_id := 1

const MONEY := [350, 900, 2200, 4500]

func refill(g) -> void:
	active = active.filter(func(q): return int(q.get("until", 1 << 30)) >= g.day)
	var tries := 0
	while active.size() < 3 and tries < 40:
		tries += 1
		var q := _make(g)
		if q.is_empty() or active.any(func(a): return a["kind"] == q["kind"] and a.get("pid", "") == q.get("pid", "")): continue
		q["id"] = _next_id; _next_id += 1
		q["start"] = _snapshot(g)
		active.append(q)
	g.quests_changed.emit()

func _snapshot(g) -> Dictionary:
	return {"credit_paid": int(g.totals.get("credit_paid", 0)), "requests": int(g.totals.get("requests", 0)), "happy": int(g.totals["happy"])}

func _reward(g, mult := 1.0) -> Dictionary:
	var m := int(round(MONEY[g.stage] * mult / 50.0)) * 50
	var r := {"money": m, "rating": 0.0, "voucher": ""}
	var roll := randf()
	if roll < 0.25: r["rating"] = 0.05
	elif roll < 0.45:
		var cands := DB.FIXTURES.filter(func(f): return f["stage"] <= g.stage and f["cost"] <= MONEY[g.stage] * 3 and DB.zone(f) != "mall" and not f.has("room"))
		if not cands.is_empty(): r["voucher"] = cands.pick_random()["id"]
	var parts := [Cfg.fmt_money(m)]
	if r["rating"] > 0.0: parts.append("+0,05★")
	if r["voucher"] != "": parts.append("bedava " + DB.fixture(r["voucher"])["name"])
	r["text"] = " + ".join(parts)
	return r

func _make(g) -> Dictionary:
	var stocked: Array = g.unlocked_products().filter(func(p): return g.is_stocked(p["id"]) and g.calendar.product_active(g.day, p["id"]))
	var kinds := ["sell", "sell", "happy", "revenue", "clean", "variety", "loyal"]
	if g.stage >= 1: kinds += ["no_theft", "no_queue"]
	if g.neighborhood.mode != "off" and g.neighborhood.total_debt() >= 100: kinds.append("collect")
	if g.neighborhood.residents.any(func(r): return not r["request"].is_empty()): kinds.append("request")
	if g.rival != null and g.rival.active: kinds.append("rival")
	var sp: Dictionary = g.calendar.special(g.day)
	if g.calendar.season(g.day) == 1 and g.is_stocked("dondurma"): kinds += ["season_ice", "season_ice"]
	if sp.get("id", "") == "ramazan": kinds += ["season_iftar", "season_iftar"]
	var kind: String = kinds.pick_random()
	var st: int = g.stage
	var sc: float = [1.0, 2.0, 3.5, 5.0][st]
	var q := {"kind": kind, "icon": "flag"}
	match kind:
		"sell":
			if stocked.is_empty(): return {}
			var p: Dictionary = stocked.pick_random()
			var base := maxi(int(g.last_sold.get(p["id"], 0)), g.shelf_cap(p["id"]))
			var n := maxi(15, int(ceil(base * randf_range(1.4, 1.8) / 5.0)) * 5)
			q.merge({"pid": p["id"], "n": n, "until": g.day, "title": "Bugün %d %s sat" % [n, (p["name"] as String).to_lower()],
				"desc": "Rafı dolu tut, fiyatı makul, gerekirse gondol başına ya da kampanyaya koy.", "icon": "tag", "reward": _reward(g, 0.8)})
		"happy":
			var last_h: int = int(g.history[-1].get("happy", 0)) if not g.history.is_empty() else 0
			var n := maxi(int(round((60 + randi() % 20) * sc / 5.0)) * 5, int(round(last_h * 1.2 / 5.0)) * 5)
			q.merge({"n": n, "until": g.day, "title": "Bugün %d mutlu müşteri" % n, "desc": "Kuyruğu kısa, rafları dolu, yeri temiz tut. Mutlu ayrılan müşteri sayılır.", "icon": "heart", "reward": _reward(g)})
		"revenue":
			var last_r: int = int(g.history[-1].get("revenue", 0)) if not g.history.is_empty() else 0
			var n := maxi(int(round((3200 + randi() % 800) * sc / 100.0)) * 100, int(round(last_r * 1.2 / 100.0)) * 100)
			q.merge({"n": n, "until": g.day, "title": "Bugün %s ciro" % Cfg.fmt_money(n), "desc": "Günlük satış toplamı. Pahalı ama aranan ürünler ve kampanyalar işe yarar.", "icon": "coin", "reward": _reward(g)})
		"clean":
			q.merge({"until": g.day + 2, "days": 3, "title": "Tertemiz kapanış", "desc": "Bir günü yerde en fazla 1 çöp ve hiç ıslak zemin olmadan kapat. 3 gün içinde.", "icon": "broom", "reward": _reward(g, 0.8)})
		"variety":
			var n: int = mini(g.unlocked_products().size(), [8, 14, 22, 26][st])
			q.merge({"n": n, "until": g.day + 3, "days": 4, "title": "Aynı anda %d çeşit ürün" % n, "desc": "Rafa en az %d farklı ürün ata ve hepsinde stok olsun. Çeşit artınca \"satılmıyor mu\" diyen azalır." % n, "icon": "box", "reward": _reward(g, 1.2)})
		"loyal":
			var n := 3 + st
			q.merge({"n": n, "until": g.day + 5, "days": 6, "title": "%d müdavimin sadakati 80+" % n, "desc": "Mahalle panelinden (N) müdavimleri izle: sevdikleri ürünü rafta tut, kuyrukta bekletme.", "icon": "people", "reward": _reward(g, 1.4)})
		"no_theft":
			q.merge({"n": 2, "streak": 0, "until": g.day + 4, "days": 5, "title": "2 gün üst üste hırsızlıksız", "desc": "Kamera, alarm kapısı ve güvenlik görevlisiyle kör noktaları kapat (G).", "icon": "shield", "reward": _reward(g, 1.2)})
		"no_queue":
			var n := int(30 * sc)
			q.merge({"n": n, "until": g.day + 2, "days": 3, "title": "Kuyruktan kimse kaçmasın", "desc": "En az %d müşteriye hizmet verip hiç kimseyi kuyrukta sıkıp göndermeden bir gün kapat." % n, "icon": "queue", "reward": _reward(g, 1.1)})
		"collect":
			var n: int = maxi(100, int(round(g.neighborhood.total_debt() * 0.6 / 50.0)) * 50)
			q.merge({"n": n, "until": g.day + 4, "days": 5, "title": "Defterden %s tahsil et" % Cfg.fmt_money(n), "desc": "Borçlulara hatırlat; sözünün eri olanlar hemen öder.", "icon": "note", "reward": _reward(g, 0.9)})
		"request":
			q.merge({"n": 1, "until": g.day + 3, "days": 4, "title": "Bir müdavimin isteğini karşıla", "desc": "Mahalle panelindeki istek listesinden bir ürünü rafa koy; sahibi gelip alsın.", "icon": "question", "reward": _reward(g)})
		"rival":
			q.merge({"n": 3, "streak": 0, "until": g.day + 6, "days": 7, "title": "3 gün üst üste pazarın %60'ı", "desc": Rival.b("UCUZA'ya giden müşteriyi geri kazan: fiyat, tazelik, sadakat."), "icon": "rival", "reward": _reward(g, 1.8)})
		"season_ice":
			q.merge({"pid": "dondurma", "n": 20 + st * 10, "until": g.day, "title": "Bugün %d dondurma sat" % (20 + st * 10), "desc": "Yaz geldi! Dondurma dolabını kapının yakınına koy, sıcak günlerde talep uçar.", "icon": "sun", "reward": _reward(g)})
		"season_iftar":
			var pid := "pide" if g.is_stocked("pide") else "ekmek"
			q.merge({"pid": pid, "n": 20 + st * 12, "until": g.day, "title": "İftara %d %s" % [20 + st * 12, "pide" if pid == "pide" else "ekmek"], "desc": "17:30–19:30 arası fırın ürünleri kapışılır. Sepetleri dolu tut.", "icon": "moon", "reward": _reward(g)})
	q["reward_text"] = q["reward"]["text"]
	return q

# ------------------------------------------------------------------ progress
func value(g, q: Dictionary) -> float:
	match q["kind"]:
		"sell", "season_ice", "season_iftar": return float(g.stats["sold"].get(q["pid"], 0))
		"happy": return float(g.stats["happy"])
		"revenue": return float(g.stats["revenue"])
		"variety":
			var n := 0
			for p in g.unlocked_products():
				if g.shelf_stock(p["id"]) > 0: n += 1
			return float(n)
		"loyal": return float(g.neighborhood.residents.filter(func(r): return float(r["loyalty"]) >= 80.0).size())
		"no_theft", "rival": return float(q.get("streak", 0))
		"collect": return float(int(g.totals.get("credit_paid", 0)) - int(q["start"]["credit_paid"]))
		"request": return float(int(g.totals.get("requests", 0)) - int(q["start"]["requests"]))
		"clean", "no_queue": return 1.0 if q.get("ok", false) else 0.0
	return 0.0

func target(q: Dictionary) -> float: return float(q.get("n", 1))
func progress(g, q: Dictionary) -> float: return clampf(value(g, q) / maxf(1.0, target(q)), 0.0, 1.0)
func progress_text(g, q: Dictionary) -> String:
	match q["kind"]:
		"revenue", "collect": return "%s / %s" % [Cfg.fmt_money(value(g, q)), Cfg.fmt_money(target(q))]
		"clean", "no_queue": return "bekliyor"
	return "%d / %d" % [int(value(g, q)), int(target(q))]

## live check (cheap; called a few times per game minute)
func check(g) -> void:
	for q in active.duplicate():
		if q["kind"] in ["clean", "no_queue", "no_theft", "rival"]: continue # judged at closing time
		if value(g, q) >= target(q): _complete(g, q)

## closing-time goals
func end_day(g) -> void:
	for q in active.duplicate():
		match q["kind"]:
			"clean":
				if g.litter.size() <= 1 and g.puddles.is_empty(): q["ok"] = true; _complete(g, q)
			"no_queue":
				if int(g.stats["lost_queue"]) == 0 and int(g.stats["abandoned"]) == 0 and int(g.stats["served"]) >= int(q["n"]): q["ok"] = true; _complete(g, q)
			"no_theft":
				q["streak"] = int(q["streak"]) + 1 if int(g.stats["theft_count"]) == 0 else 0
				if int(q["streak"]) >= int(q["n"]): _complete(g, q)
			"rival":
				q["streak"] = int(q["streak"]) + 1 if g.rival.share(g) >= 0.6 else 0
				if int(q["streak"]) >= int(q["n"]): _complete(g, q)
			_:
				if value(g, q) >= target(q): _complete(g, q)
		if active.has(q) and int(q.get("until", 1 << 30)) <= g.day and not q["kind"] in ["no_theft", "rival"]:
			pass # expires in refill tomorrow
	g.quests_changed.emit()

func _complete(g, q: Dictionary) -> void:
	if not active.has(q): return
	active.erase(q)
	done.append({"title": q["title"], "reward_text": q["reward_text"], "day": g.day})
	var r: Dictionary = q["reward"]
	g.money += int(r["money"]); g.stats["other"] -= int(r["money"])
	if float(r["rating"]) > 0.0: g.rating = minf(5.0, g.rating + float(r["rating"]))
	if r["voucher"] != "": g.vouchers[r["voucher"]] = int(g.vouchers.get(r["voucher"], 0)) + 1
	g.alert("quest%d" % q["id"], "star", "Görev tamam: %s! Ödül: %s" % [q["title"], q["reward_text"]], "good", null, 0.0)
	GameAudio.play("coin", -4.0)
	g.overlays.float_text(g.rig.target + Vector3(0, 3.5, 0), "Görev tamam!", Cfg.MUSTARD)
	g.quests_changed.emit()

func serialize() -> Dictionary:
	return {"active": active, "done": done.slice(-30), "next": _next_id}

func apply(d: Dictionary) -> void:
	if d.is_empty(): return
	active = []
	for q in d.get("active", []):
		for k in ["id", "n", "until", "days", "streak"]: if q.has(k): q[k] = int(q[k])
		active.append(q)
	done = d.get("done", [])
	_next_id = int(d.get("next", 1))
