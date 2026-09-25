class_name Rival
extends RefCounted
## UCUZA: a discount chain that opens across the road once the shop becomes a market.
## It undercuts a handful of staples; price-sensitive shoppers walk over to it. The player answers
## with prices, a freshness poster, the neighbourhood's loyalty — or, later, by buying it out.

const LIST := ["ekmek", "sut", "ayran", "kola", "cips", "deterjan", "makarna", "yumurta", "yag", "seker", "un", "peynir", "su", "yogurt"]
## how much each archetype cares about the cheaper shop across the road
const SENS := {"emekli": 1.4, "aile": 1.2, "haftalik": 1.3, "ogrenci": 1.0, "calisan": 0.45, "firsatci": 0.0}
## after UCUZA is gone, the career's second rival: NOKTA 7/24, a convenience chain that fights for
## snacks and drinks, and for the students and office workers who buy them
const LIST2 := ["kola", "cips", "cikolata", "su", "sakiz", "biskuvi", "dondurma", "ayran", "gazete", "pizza"]
const SENS2 := {"ogrenci": 1.6, "calisan": 1.3, "aile": 0.6, "emekli": 0.3, "haftalik": 0.2, "firsatci": 0.4}
const BRANDS := ["", "UCUZA", "NOKTA"]
## the brand on screen right now; texts are written with "UCUZA" and swapped (Loc knows the alias)
static var brand_now := "UCUZA"
static func b(s: String) -> String: return s.replace("UCUZA", brand_now) if brand_now != "UCUZA" else s

var gen := 1
var closed_day := -1

var active := false
var closed := false
var open_day := -1 # construction announced; opens on this day
var prices := {}
var promo := {} # {pid, until}
var rating := 3.3
var lost_today := 0
var lost_yesterday := 0
var mine_yesterday := 0
var poster_until := 0
var solidarity_until := 0
var strong_days := 0 # consecutive days the player held 75%+ of the market
var history: Array = [] # share per day

func list() -> Array: return LIST if gen == 1 else LIST2
func sens() -> Dictionary: return SENS if gen == 1 else SENS2
func brand() -> String: return BRANDS[gen]

func maybe_announce(g) -> void:
	if active or closed or open_day >= 0 or g.stage < 1: return
	open_day = g.day + 2
	g.alert("rival_soon", "rival", "Karşı kaldırımda inşaat var: indirim zinciri UCUZA 2 gün sonra açılıyor. Fiyata hassas müşteriler oraya kayabilir. Mahalle panelinden (N) takip et.", "warn", null, 0.0)

func start_day(g) -> void:
	# the career goes on: a few days after UCUZA is gone, a convenience chain rents the empty shop
	if closed and gen == 1 and g.stage >= 2 and ["kariyer", "serbest"].has(g.scenario.get("id", "kariyer")) and closed_day >= 0 and g.day >= closed_day + 6:
		gen = 2; closed = false; strong_days = 0; history = []; promo = {}; rating = 3.7
		brand_now = brand()
		open_day = g.day + 2
		g.alert("rival_soon", "rival", "Karşıdaki boş dükkâna yeni tabela asılıyor: NOKTA 7/24, 2 gün sonra açılıyor. Kola, cips, çikolata gibi atıştırmalıklarda ucuz olacak; öğrenciler ve çalışanlar karşıya geçebilir.", "warn", null, 0.0)
	maybe_announce(g)
	if not active and not closed and open_day >= 0 and g.day >= open_day:
		active = true
		prices = {}
		for pid in list():
			prices[pid] = int(round(float(DB.product(pid)["base"]) * g.cost_mul * randf_range(0.82, 0.9)))
		g.street.build_rival(false, brand())
		if gen == 1: g.alert("rival_open", "rival", "UCUZA açıldı! Süt, ekmek, deterjan gibi temel ürünlerde senden %10–18 ucuz. Emekliler ve aileler karşıya geçmeye başlayacak.", "bad", Vector3(1.0, 0, 27.0), 0.0)
		else: g.alert("rival_open", "rival", "NOKTA 7/24 açıldı! Atıştırmalık ve içeceklerde senden ucuz. Öğrenciler ve çalışanlar karşıya geçebilir; müdavimlerin ve tazelik senin kozun.", "bad", Vector3(1.0, 0, 27.0), 0.0)
	if not active: return
	# prices follow inflation; now and then a loud promo on one staple
	for pid in prices: prices[pid] = maxi(1, int(round(float(DB.product(pid)["base"]) * g.cost_mul * randf_range(0.82, 0.9))))
	if not promo.is_empty() and g.day > int(promo["until"]): promo = {}
	if promo.is_empty() and randf() < 0.3:
		var cands: Array = list().filter(func(p): return DB.product(p)["stage"] <= g.stage)
		var pid: String = cands.pick_random()
		prices[pid] = int(round(prices[pid] * 0.78))
		promo = {"pid": pid, "until": g.day + 1}
		g.alert("rival_promo", "rival", b("UCUZA'da afiş: \"%s sadece ₺%d!\" İki gün boyunca bu üründe müşteri kaçırabilirsin.") % [DB.product(pid)["name"], prices[pid]], "warn", null, 0.0)
	lost_today = 0

## chance that a shopper of this archetype goes to UCUZA instead
func diversion(g, arch_id: String, res := {}) -> float:
	if not active: return 0.0
	var gap := 0.0
	var n := 0
	for pid in prices:
		if DB.product(pid)["stage"] > g.stage or not g.is_stocked(pid): continue
		gap += clampf(float(g.effective_price(pid)) / float(prices[pid]) - 1.0, -0.3, 0.6)
		n += 1
	if n > 0: gap /= n
	var d: float = 0.07 + gap * 0.55 + (rating - float(g.rating)) * 0.08
	d *= float(sens().get(arch_id, 1.0))
	if g.day <= poster_until: d *= 0.6
	if g.day <= solidarity_until: d *= 0.7
	if g.upgrades.has("sadakat"): d *= 0.75
	if not res.is_empty():
		if float(res["loyalty"]) >= 70.0: return 0.0
		d *= 1.0 - float(res["loyalty"]) / 120.0
	return clampf(d, 0.0, 0.5)

func share(g) -> float:
	var mine: int = int(g.stats["visitors"]) if g.clock > Cfg.DAY_OPEN + 60 else mine_yesterday
	var lost: int = lost_today if g.clock > Cfg.DAY_OPEN + 60 else lost_yesterday
	return float(mine) / maxf(1.0, float(mine + lost))

func end_day(g) -> void:
	if not active: return
	var s := float(g.stats["visitors"]) / maxf(1.0, float(g.stats["visitors"]) + lost_today)
	history.append(s)
	if history.size() > 14: history.pop_front()
	mine_yesterday = int(g.stats["visitors"])
	lost_yesterday = lost_today
	rating = clampf(rating + (0.02 if s < 0.6 else -0.03), 2.5, 4.4)
	strong_days = strong_days + 1 if s >= 0.75 else 0
	if strong_days >= 7:
		_close(g, b("UCUZA kepenk indirdi! Mahalle senden şaşmadı; karşıdaki dükkân kiralık."))

func _close(g, msg: String) -> void:
	active = false; closed = true; closed_day = g.day
	g.street.build_rival(true, brand())
	g.rating = minf(5.0, g.rating + 0.2)
	g.alert("rival_closed", "trophy", msg + " Mağaza puanı +0,2.", "good", null, 0.0)

func blurb(g) -> String:
	var s := "UCUZA karşı kaldırımda. Temel ürünlerde senden ucuz; emekliler, aileler ve haftalık alışverişçiler fiyata bakıp karşıya geçebilir. Sadakati 70'in üstündeki müdavimlerin hiç gitmez." if gen == 1 else "NOKTA 7/24 karşı kaldırımda. Atıştırmalık ve içeceklerde senden ucuz; öğrenciler ve çalışanlar fiyata bakıp karşıya geçebilir. Sadakati 70'in üstündeki müdavimlerin hiç gitmez."
	if not promo.is_empty(): s += " Bugün afişte: %s ₺%d." % [DB.product(promo["pid"])["name"], prices[promo["pid"]]]
	if strong_days > 0: s += b(" %d gündür pazarın %%75'inden fazlası sende; 7 güne ulaşırsa UCUZA kapanır.") % strong_days
	return s

func actions(g) -> Array:
	var loyal: int = g.neighborhood.residents.filter(func(r): return float(r["loyalty"]) >= 70.0).size()
	var buyout := buyout_cost()
	return [
		{"id": "match", "name": "Fiyatları eşle", "desc": b("UCUZA'nın sattığı ve senin rafında olan ürünlerde fiyatını onunkine indir (maliyetin altına düşmez). Kâr marjın incelir."), "button": "Eşle"},
		{"id": "poster", "name": "\"Taze & Yakın\" afişi", "desc": "Vitrine ve kaldırıma afiş: 3 gün boyunca karşıya geçen müşteri %40 azalır.", "button": "Afiş as · ₺600", "disabled": g.money < 600 or g.day <= poster_until},
		{"id": "solidarity", "name": "Mahalle dayanışması", "desc": "En az 6 müdavimin sadakati 70+ ise çay ikram edip komşuları toplarsın: 5 gün boyunca kayıp %30 azalır, müşteri %15 artar. (Şu an %d)" % loyal, "button": "Topla", "disabled": loyal < 6 or g.day <= solidarity_until},
		{"id": "buyout", "name": b("UCUZA'yı satın al"), "desc": "Süpermarket aşamasında zincirin bu şubesini devral: rakip kapanır, müşterileri sana gelir.", "button": "Satın al · " + Cfg.fmt_money(buyout), "disabled": g.stage < 2 or g.money < buyout},
	]

func act(g, id: String) -> void:
	match id:
		"match":
			var n := 0
			for pid in prices:
				if DB.product(pid)["stage"] > g.stage or not g.is_stocked(pid): continue
				var p := maxi(g.cost_of(pid) + 1, int(prices[pid]))
				if g.prices[pid] > p: g.prices[pid] = p; n += 1
			g.refresh_all(); g.changed.emit()
			g.alert("rival_match", "tag", b("%d üründe fiyatını UCUZA'ya eşitledin.") % n, "info", null, 0.0)
		"poster":
			if g.money < 600: return
			g.money -= 600; g.stats["other"] += 600
			poster_until = g.day + 2
			g.alert("rival_poster", "megaphone2", "\"Taze & Yakın\" afişi asıldı: 3 gün boyunca müşteri kaçağı azalacak.", "good", null, 0.0)
		"solidarity":
			solidarity_until = g.day + 4
			g.praise_until = maxf(g.praise_until, (g.day + 4) * 1440.0 + Cfg.DAY_CLOSE)
			g.alert("rival_sol", "heart", "Komşular çay içmeye toplandı: \"Biz mahallenin bakkalını bırakmayız!\"", "good", null, 0.0)
		"buyout":
			var cost := buyout_cost()
			if g.stage < 2 or g.money < cost: return
			g.money -= cost; g.stats["other"] += cost
			_close(g, b("UCUZA şubesini satın aldın, tabelası indirildi."))

func buyout_cost() -> int: return 45000 + int(rating * 5000) if gen == 1 else 70000 + int(rating * 6000)

func serialize() -> Dictionary:
	return {"gen": gen, "closed_day": closed_day, "active": active, "closed": closed, "open_day": open_day, "prices": prices, "promo": promo, "rating": rating,
		"lost_y": lost_yesterday, "mine_y": mine_yesterday, "poster": poster_until, "sol": solidarity_until, "strong": strong_days, "history": history}

func apply(g, d: Dictionary) -> void:
	if d.is_empty(): return
	active = d.get("active", false); closed = d.get("closed", false); open_day = int(d.get("open_day", -1))
	prices = {}
	for k in d.get("prices", {}): prices[k] = int(d["prices"][k])
	promo = d.get("promo", {})
	if not promo.is_empty(): promo["until"] = int(promo["until"])
	rating = float(d.get("rating", 3.3)); lost_yesterday = int(d.get("lost_y", 0)); mine_yesterday = int(d.get("mine_y", 0))
	poster_until = int(d.get("poster", 0)); solidarity_until = int(d.get("sol", 0)); strong_days = int(d.get("strong", 0))
	history = d.get("history", [])
	gen = int(d.get("gen", 1)); closed_day = int(d.get("closed_day", -1))
	brand_now = brand()
	if active: g.street.build_rival(false, brand())
	elif closed: g.street.build_rival(true, brand())
