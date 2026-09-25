class_name Neighborhood
extends RefCounted
## The people of the mahalle: named regulars with habits and favourite products, their loyalty,
## the veresiye defteri (credit book) and the small requests they bring to the counter.

const FEMALE := ["Kerime", "Nuriye", "Sevgi", "Ayşe", "Hatice", "Gülten", "Serap", "Filiz", "Emine", "Nermin", "Songül", "Dilek", "Zehra", "Melek", "Aslı", "Elif", "Zeynep", "Selin"]
const MALE := ["Hüsnü", "Selim", "Hakan", "Murat", "Nihat", "Rıza", "Kadir", "Orhan", "Tuncay", "Levent", "Cemal", "Yılmaz", "Ali", "Emre", "Kerem", "Burak", "Oğuz", "Serkan"]
## how a regular is addressed, by archetype
const TITLE := {
	"emekli": [["%s Teyze", "f"], ["%s Amca", "m"]],
	"calisan": [["%s Hanım", "f"], ["%s Bey", "m"]],
	"ogrenci": [["%s", "f"], ["%s", "m"]],
	"aile": [["%s Hanım", "f"], ["%s Abi", "m"]],
	"haftalik": [["Öğretmen %s", "f"], ["Doktor %s", "m"]],
}
## chance to ask for credit at the till, by archetype
const ASK := {"emekli": 0.18, "aile": 0.15, "ogrenci": 0.12, "calisan": 0.05, "haftalik": 0.08}
const HABIT := {"emekli": 8.5, "calisan": 8.2, "ogrenci": 16.0, "aile": 11.5, "haftalik": 11.0}
## a line about each regular: tied to a favourite product, but only when it suits who they are
const QUIRKS := {
	"gazete": ["Her sabah gazetesini alır, manşetleri yorumlamadan gitmez.", ["emekli", "calisan"]],
	"ekmek": ["Ekmeği sıcak sever, bayatsa hemen fark eder.", ["emekli", "aile", "haftalik"]],
	"simit": ["Simitsiz güne başlamaz.", ["calisan", "emekli", "ogrenci"]],
	"cikolata": ["Torunlarına çikolata götürür.", ["emekli"]],
	"kola": ["Maç günleri kolayı kasayla alır.", ["calisan", "aile"]],
	"cay": ["Çayın markasını sorar, demini anlatır.", ["emekli", "calisan"]],
	"ayran": ["Öğle yemeğine ayransız oturmaz.", ["calisan", "emekli"]],
	"dondurma": ["Havalar ısındı mı ilk dondurmayı o alır.", ["ogrenci", "aile"]],
	"sut": ["Sütün son kullanma tarihine bakar.", ["aile", "emekli", "haftalik"]],
	"peynir": ["Peynirin tuzunu tadıp öyle alır.", ["emekli", "aile", "haftalik"]],
	"domates": ["Domatesleri tek tek seçer.", ["emekli", "aile", "haftalik"]],
	"cips": ["Ders çalışırken cips atıştırır.", ["ogrenci"]],
	"yumurta": ["Köy yumurtası ister, sarısına bakar.", ["emekli", "aile", "haftalik"]],
	"sampuan": ["Kampanya varsa üç tane birden alır.", ["aile", "haftalik"]],
	"sakiz": ["Teneffüste sakız dağıtır, sınıfın en sevileni.", ["ogrenci"]],
	"biskuvi": ["Çayın yanına bisküvisiz oturmaz.", ["emekli", "calisan"]],
}
const ARCH_QUIRKS := {
	"ogrenci": ["Dersten çıkınca uğrar, cebindeki son bozukluğu harcar.", "Sınav haftası atıştırmalığa abanır."],
	"calisan": ["İşe giderken aceleyle uğrar, kuyruk görünce kaşları çatılır.", "Öğle arasında koşa koşa gelir."],
	"emekli": ["Sabahın ilk müşterisidir, fiyatları ezbere bilir.", "Kasada mahallenin bütün haberlerini anlatır."],
	"aile": ["Çocuklarıyla gelir, liste hep uzundur.", "Okul çıkışı çocukları alıp uğrar."],
	"haftalik": ["Cumartesi arabayla gelip bagajı doldurur.", "Listesini telefondan okur, hiçbir şeyi unutmaz."],
}

var residents: Array = [] # Dictionaries, see _make()
var mode := "off" # veresiye policy: off | regulars | all
var limit := 300 # max debt per person
var today: Array = [] # [{rid, at}] planned visits for today
var _next_id := 1

# ------------------------------------------------------------------ setup
func generate(game) -> void:
	residents.clear()
	for arch_id in ["emekli", "emekli", "emekli", "emekli", "calisan", "calisan", "calisan", "ogrenci", "ogrenci", "ogrenci", "ogrenci", "calisan"]:
		residents.append(_make(game, arch_id))

## new neighbours move in when the shop grows and serves more of the block
func grow(game) -> void:
	var add := []
	match game.stage:
		1: add = ["aile", "aile", "aile", "aile", "emekli", "calisan"]
		2: add = ["haftalik", "haftalik", "haftalik", "aile", "aile", "ogrenci"]
		3: add = ["calisan", "calisan", "aile", "ogrenci"]
	for a in add:
		var r := _make(game, a)
		residents.append(r)

func _make(game, arch_id: String) -> Dictionary:
	var arch := _arch(arch_id)
	var t: Array = (TITLE[arch_id] as Array).pick_random()
	var used := residents.map(func(r): return r["name"])
	var nm := ""
	for i in 20:
		nm = (t[0] as String) % ((FEMALE if t[1] == "f" else MALE) as Array).pick_random()
		if not used.has(nm): break
	var favs := []
	var pool: Array = (arch["wants"] as Dictionary).keys().filter(func(pid): return DB.product(pid)["stage"] <= maxi(game.stage, 0) and not DB.product(pid).get("only_season", false))
	pool.sort_custom(func(a, b): return arch["wants"][a] > arch["wants"][b])
	for pid in pool.slice(0, 4):
		if favs.size() < 2 and randf() < 0.7: favs.append(pid)
	if favs.is_empty() and pool.size() > 0: favs.append(pool[0])
	var look := Customer.random_look(arch)
	var r := {
		"id": _next_id, "name": nm, "arch": arch_id, "look": look,
		"loyalty": 45.0 + randf() * 20.0, "trust": clampf(randfn(0.7, 0.2), 0.1, 0.98),
		"debt": 0, "debt_day": 0, "reminded": false, "favs": favs,
		"habit": float(HABIT.get(arch_id, 12.0)) + randf_range(-1.2, 1.2),
		"visits": 0, "spent": 0, "last": 0, "request": {}, "quirk": "",
	}
	_next_id += 1
	r["quirk"] = (ARCH_QUIRKS.get(arch_id, ["Mahallenin tanıdık yüzlerinden."]) as Array).pick_random()
	if favs.size() > 0 and QUIRKS.has(favs[0]) and (QUIRKS[favs[0]][1] as Array).has(arch_id): r["quirk"] = QUIRKS[favs[0]][0]
	return r

static func _arch(id: String) -> Dictionary:
	for a in DB.ARCHETYPES:
		if a["id"] == id: return a
	return DB.ARCHETYPES[0]

func by_id(id: int) -> Dictionary:
	for r in residents:
		if r["id"] == id: return r
	return {}

# ------------------------------------------------------------------ daily rhythm
func start_day(game) -> void:
	today.clear()
	for r in residents:
		if _arch(r["arch"])["stage"] > game.stage: continue
		var p: float = 0.2 + float(r["loyalty"]) * 0.006
		if float(r["loyalty"]) < 15.0: p = 0.04 # küstü: hardly comes any more
		if r["reminded"] and int(r["debt"]) > 0: p = 0.95
		if not r["request"].is_empty(): p = maxf(p, 0.7)
		if randf() < p:
			var at: float = clampf(float(r["habit"]) * 60.0 + randf_range(-70.0, 70.0), Cfg.DAY_OPEN + 10, Cfg.DAY_CLOSE - 40)
			today.append({"rid": r["id"], "at": at})
	today.sort_custom(func(a, b): return a["at"] < b["at"])
	_maybe_request(game)

## called every tick: regulars show up at their usual hour
func update(game) -> void:
	while not today.is_empty() and game.clock >= float(today[0]["at"]):
		var v: Dictionary = today.pop_front()
		var r := by_id(int(v["rid"]))
		if r.is_empty() or not game.is_open(): continue
		if game.customers.any(func(c): return c.resident == r): continue
		game.spawn_resident(r)

func end_day(game) -> void:
	for r in residents:
		var req: Dictionary = r["request"]
		if not req.is_empty() and game.day >= int(req["until"]):
			r["request"] = {}
			r["loyalty"] = maxf(0.0, float(r["loyalty"]) - 8.0)
			game.alert("req_fail%d" % r["id"], "angry", "%s istediği %s gelmeyince kırıldı." % [r["name"], DB.product(req["pid"])["name"].to_lower()], "warn", null, 0.0)
	var late := overdue(game)
	if late.size() > 0:
		game.alert("overdue", "wallet", "Defterde %d kişinin borcu bir haftayı geçti (%s). Mahalle panelinden (N) hatırlat." % [late.size(), Cfg.fmt_money(late.reduce(func(s, r): return s + int(r["debt"]), 0))], "warn", null, 0.0)

func _maybe_request(game) -> void:
	if randf() > 0.45: return
	var missing: Array = game.unlocked_products().filter(func(p): return not game.is_stocked(p["id"]) and not p.get("only_season", false))
	var cands := residents.filter(func(r): return r["request"].is_empty() and float(r["loyalty"]) >= 35.0 and _arch(r["arch"])["stage"] <= game.stage)
	if missing.is_empty() or cands.is_empty(): return
	var r: Dictionary = cands.pick_random()
	var arch := _arch(r["arch"])
	var liked: Array = missing.filter(func(p): return (arch["wants"] as Dictionary).has(p["id"]))
	var p: Dictionary = (liked if not liked.is_empty() else missing).pick_random()
	r["request"] = {"pid": p["id"], "until": game.day + 3}
	today.append({"rid": r["id"], "at": clampf(float(r["habit"]) * 60.0 + 45.0, Cfg.DAY_OPEN + 30.0, Cfg.DAY_CLOSE - 60.0)})
	today.sort_custom(func(a, b): return a["at"] < b["at"])
	game.alert("request%d" % r["id"], "question", "%s soruyor: \"%s da getirsen ya?\" 3 gün içinde rafa koyarsan sevinir." % [r["name"], p["name"]], "info", null, 0.0)

# ------------------------------------------------------------------ visits
## wants for a regular: their favourites first, then the usual archetype picks
func wants_for(r: Dictionary) -> Array:
	var out := []
	for pid in r["favs"]: out.append(pid)
	var req: Dictionary = r["request"]
	if not req.is_empty() and not out.has(req["pid"]): out.push_front(req["pid"])
	return out

func can_credit(game, r: Dictionary, amount: int) -> bool:
	if mode == "off" or r.is_empty(): return false
	if mode == "regulars" and float(r["loyalty"]) < 55.0: return false
	return int(r["debt"]) + amount <= limit

func headroom(r: Dictionary) -> int:
	if mode == "off" or r.is_empty(): return 0
	if mode == "regulars" and float(r["loyalty"]) < 55.0: return 0
	return maxi(0, limit - int(r["debt"]))

## called by the till; returns "credit" when the sale goes into the book, "" for a normal sale
func at_till(game, c, total: int) -> String:
	var r: Dictionary = c.resident
	if r.is_empty(): return ""
	var out := ""
	var need: bool = c.flags.has("credit_need")
	if total > 0 and (need or randf() < float(ASK.get(r["arch"], 0.08))) and can_credit(game, r, total):
		if int(r["debt"]) == 0: r["debt_day"] = game.day
		r["debt"] = int(r["debt"]) + total
		game.stats["credit"] += total
		game.totals["credit"] = int(game.totals.get("credit", 0)) + total
		GameAudio.play("paper", -12.0, 1.0)
		out = "credit"
		c.log_thought("happy", "Deftere yazdırdım, ay başında öderim.", game)
	elif int(r["debt"]) > 0 and randf() < float(r["trust"]) * (1.25 if r["reminded"] else 0.7):
		var paid: int = r["debt"]
		game.money += paid
		game.stats["credit_paid"] += paid
		game.stats["revenue"] += paid; game.totals["revenue"] += paid
		game.totals["credit_paid"] = int(game.totals.get("credit_paid", 0)) + paid
		r["debt"] = 0; r["reminded"] = false
		game.float_text(c.position + Vector3(0, 2.3, 0), "Borç ödendi +" + Cfg.fmt_money(paid), Cfg.GOOD)
		c.log_thought("happy", "Veresiye borcumu kapattım, içim rahatladı.", game)
	r["visits"] = int(r["visits"]) + 1
	r["spent"] = int(r["spent"]) + total
	return out

func after_visit(game, c) -> void:
	var r: Dictionary = c.resident
	if r.is_empty(): return
	r["last"] = game.day
	var d := 0.0
	if c.mood >= 70: d = 4.0
	elif c.mood >= 50: d = 1.5
	elif c.mood < 35: d = -7.0
	else: d = -2.0
	var req: Dictionary = r["request"]
	if not req.is_empty() and c.basket.any(func(b): return b["pid"] == req["pid"]):
		d += 15.0
		r["request"] = {}
		game.totals["requests"] = int(game.totals.get("requests", 0)) + 1
		game.rating = minf(5.0, game.rating + 0.03)
		c.log_thought("happy", "İstediğim %s gelmiş, sağ ol komşu!" % DB.product(req["pid"])["name"].to_lower(), game)
		game.alert("req_ok%d" % r["id"], "heart", "%s istediği ürünü rafta buldu, çok sevindi. Mahallede adın iyiye çıkıyor." % r["name"], "good", null, 0.0)
	r["loyalty"] = clampf(float(r["loyalty"]) + d, 0.0, 100.0)

# ------------------------------------------------------------------ the book
func debtors() -> Array:
	return residents.filter(func(r): return int(r["debt"]) > 0)

func total_debt() -> int:
	var n := 0
	for r in residents: n += int(r["debt"])
	return n

func overdue(game) -> Array:
	return residents.filter(func(r): return int(r["debt"]) > 0 and game.day - int(r["debt_day"]) >= 7)

func remind(game, r: Dictionary) -> void:
	if r["reminded"] or int(r["debt"]) <= 0: return
	r["reminded"] = true
	r["loyalty"] = maxf(0.0, float(r["loyalty"]) - 4.0)
	if not today.any(func(v): return v["rid"] == r["id"]):
		today.append({"rid": r["id"], "at": minf(Cfg.DAY_CLOSE - 60.0, game.clock + randf_range(40.0, 160.0))})
		today.sort_custom(func(a, b): return a["at"] < b["at"])

func forgive(game, r: Dictionary) -> void:
	var d: int = r["debt"]
	if d <= 0: return
	game.stats["credit_lost"] += d
	if Progress.unlock("helal"): game.achievement.emit("helal")
	r["debt"] = 0; r["reminded"] = false
	r["loyalty"] = minf(100.0, float(r["loyalty"]) + 12.0)
	game.rating = minf(5.0, game.rating + 0.02)
	game.alert("forgive%d" % r["id"], "heart", "%s'in %s borcunu sildin. \"Hakkını helal et komşu\" diyor, mahallede sözün geçer oldu." % [r["name"], Cfg.fmt_money(d)], "good", null, 0.0)

# ------------------------------------------------------------------ save
func serialize() -> Dictionary:
	var rs := []
	for r in residents:
		var d: Dictionary = r.duplicate(true)
		var lk := {}
		for k in r["look"]:
			var v = r["look"][k]
			lk[k] = v.to_html() if v is Color else v
		d["look"] = lk
		rs.append(d)
	return {"residents": rs, "mode": mode, "limit": limit, "next": _next_id}

func apply(d: Dictionary) -> void:
	if d.is_empty(): return
	residents.clear()
	for rd in d.get("residents", []):
		var r: Dictionary = rd.duplicate(true)
		var lk := {}
		for k in rd["look"]:
			var v = rd["look"][k]
			lk[k] = Color(v) if k in ["skin", "hair", "top", "bottom", "shoes", "accent"] else v
		r["look"] = lk
		for k in ["id", "debt", "debt_day", "visits", "spent", "last"]: r[k] = int(r.get(k, 0))
		for k in ["loyalty", "trust", "habit"]: r[k] = float(r.get(k, 0.0))
		if r["request"] is Dictionary and not r["request"].is_empty(): r["request"]["until"] = int(r["request"]["until"])
		residents.append(r)
	mode = d.get("mode", "off")
	limit = int(d.get("limit", 300))
	_next_id = int(d.get("next", residents.size() + 1))
