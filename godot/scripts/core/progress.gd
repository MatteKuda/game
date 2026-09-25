class_name Progress
## Things that outlive a single save: achievements and scenario medals (user://progress.json).

const PATH := "user://progress.json"
const ACHIEVEMENTS := [
	{"id": "ilk_gun", "name": "İlk Kepenk", "desc": "İlk günü kapat."},
	{"id": "market", "name": "Mahallenin Marketi", "desc": "Mahalle Marketi'ne büyü."},
	{"id": "super", "name": "Süper!", "desc": "Süpermarket aç."},
	{"id": "avm", "name": "AVM Patronu", "desc": "Köşebaşı AVM'yi aç."},
	{"id": "bin_mutlu", "name": "Bin Tebessüm", "desc": "Toplam 1.000 mutlu müşteri."},
	{"id": "on_bin_mutlu", "name": "Mahallenin Gözbebeği", "desc": "Toplam 10.000 mutlu müşteri."},
	{"id": "zengin", "name": "Kasa Dolu", "desc": "Kasada ₺100.000."},
	{"id": "yildiz", "name": "Dört Buçuk Yıldız", "desc": "Mağaza puanı 4,5."},
	{"id": "kedi", "name": "Kedili Dükkân", "desc": "Mahallenin kedisini sahiplen."},
	{"id": "defter", "name": "Defter Kabarık", "desc": "Toplam ₺1.000 veresiye yaz."},
	{"id": "helal", "name": "Hakkını Helal Et", "desc": "Bir komşunun borcunu sil."},
	{"id": "rakip", "name": "Kepenk İndirttin", "desc": "UCUZA'yı kapattır ya da satın al."},
	{"id": "rakip2", "name": "Sokağın Tek Esnafı", "desc": "İkinci rakip NOKTA'yı da kapattır ya da satın al."},
	{"id": "sube", "name": "Zincir Oluyoruz", "desc": "Başka bir mahallede ilk şubeni aç."},
	{"id": "gorev10", "name": "Görev Avcısı", "desc": "10 görev tamamla."},
	{"id": "hirsiz", "name": "Yakaladım!", "desc": "10 hırsız yakala."},
	{"id": "denetim", "name": "Pırıl Pırıl", "desc": "Zabıta denetiminden tam not al."},
	{"id": "derbi", "name": "Derbi Gecesi", "desc": "Bir maç gününde 60 kola sat."},
	{"id": "iftar", "name": "İftara Yetiştir", "desc": "Ramazan'da bir günde 40 pide sat."},
	{"id": "borcsuz", "name": "Borçsuz Esnaf", "desc": "Bir krediyi tamamen öde."},
	{"id": "sadik", "name": "Mahalle Bizimle", "desc": "10 müdavimin sadakati 80+ olsun."},
	{"id": "istek", "name": "Sen İste", "desc": "Müdavimlerin 5 isteğini karşıla."},
	{"id": "moda", "name": "Moda'yı Kurtardın", "desc": "Moda Sahili senaryosunu kazan."},
	{"id": "kampus", "name": "Kampüs Efsanesi", "desc": "Kampüs Yolu senaryosunu kazan."},
	{"id": "carsi", "name": "Çarşının Hakimi", "desc": "Çarşı senaryosunu kazan."},
]

static var data := {}

static func load_data() -> void:
	if not data.is_empty(): return
	data = {"ach": {}, "medals": {}, "glossary": {}}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null: return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		data["ach"] = d.get("ach", {})
		data["medals"] = d.get("medals", {})
		data["glossary"] = d.get("glossary", {})

static func save_data() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(data, "\t"))

static func has(id: String) -> bool:
	load_data()
	return data["ach"].has(id)

## returns true when newly unlocked
static func unlock(id: String) -> bool:
	load_data()
	if data["ach"].has(id): return false
	data["ach"][id] = Time.get_date_string_from_system()
	save_data()
	SteamBridge.achievement(id)
	return true

static func medal(id: String) -> bool:
	load_data()
	return data["medals"].has(id)

static func give_medal(id: String) -> void:
	load_data()
	data["medals"][id] = Time.get_date_string_from_system()
	save_data()

static func glossary_seen(k: String) -> bool:
	load_data()
	return data["glossary"].has(k)

static func mark_glossary(k: String) -> void:
	load_data()
	data["glossary"][k] = true
	save_data()

static func ach_def(id: String) -> Dictionary:
	for a in ACHIEVEMENTS:
		if a["id"] == id: return a
	return {}

## check the conditions that can be read off the game state; returns newly unlocked ids
static func check(g) -> Array:
	var out := []
	var conds := {
		"ilk_gun": g.day >= 2 or g.day_ended_flag,
		"market": g.stage >= 1, "super": g.stage >= 2, "avm": g.stage >= 3,
		"bin_mutlu": int(g.totals["happy"]) >= 1000, "on_bin_mutlu": int(g.totals["happy"]) >= 10000,
		"zengin": g.money >= 100000, "yildiz": g.rating >= 4.5,
		"kedi": g.cat != null and g.cat.adopted,
		"defter": int(g.totals.get("credit", 0)) >= 1000,
		"rakip": g.rival.closed or g.rival.gen >= 2,
		"rakip2": g.rival.gen == 2 and g.rival.closed,
		"sube": not g.branches.list.is_empty(),
		"gorev10": g.quests.done.size() >= 10,
		"hirsiz": int(g.totals.get("caught", 0)) >= 10,
		"sadik": g.neighborhood.residents.filter(func(r): return float(r["loyalty"]) >= 80.0).size() >= 10,
		"istek": int(g.totals.get("requests", 0)) >= 5,
		"derbi": g.match_night.get("day", -1) == g.day and int(g.stats["sold"].get("kola", 0)) >= 60,
		"iftar": g.calendar.is_ramazan(g.day) and int(g.stats["sold"].get("pide", 0)) >= 40,
	}
	for id in conds:
		if conds[id] and unlock(id): out.append(id)
	return out
