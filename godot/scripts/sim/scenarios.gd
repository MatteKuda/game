class_name Scenarios
## Other neighbourhoods: short scenarios with their own start and a win condition, plus a free
## sandbox. Progress (medals) is kept across games in user://progress.json via Progress.

const LIST := [
	{"id": "kariyer", "name": "Köşebaşı", "sub": "Kariyer", "icon": "store",
		"desc": "Köşedeki küçük büfeden dört katlı AVM'ye. Asıl hikâye.", "goal": "Hedefleri tutarak büyü."},
	{"id": "moda", "name": "Moda Sahili", "sub": "Batmak üzere", "icon": "chart", "days": 30,
		"desc": "Eski sahibi borca girmiş bir mahalle marketi. Kasada ₺4.000, raflar yarı boş, komşular küs.",
		"goal": "30 gün içinde puanı 3,6'ya ve kasayı ₺20.000'e çıkar. Kasa −₺3.000'e düşerse iflas."},
	{"id": "kampus", "name": "Kampüs Yolu", "sub": "Öğrenci akını", "icon": "school", "days": 12,
		"desc": "Üniversitenin yolunda bir büfe. Dersten çıkan öğrenciler dalga dalga gelir; bütçeleri az, sabırları hiç yok.",
		"goal": "12 günde 1.400 mutlu müşteri."},
	{"id": "carsi", "name": "Çarşı", "sub": "Rakip kapıda", "icon": "rival", "days": 28,
		"desc": "Çarşının ortasında bir süpermarket devraldın; karşıda güçlü bir UCUZA şubesi var.",
		"goal": "28 gün içinde UCUZA'yı kapattır ya da satın al."},
	{"id": "serbest", "name": "Serbest Mod", "sub": "Kum havuzu", "icon": "sparkle",
		"desc": "Kasada ₺250.000. Genişlemek için hedef yok, sadece para. Kafana göre kur.",
		"goal": "Hedef yok, keyfine bak."},
]

static func get_def(id: String) -> Dictionary:
	for s in LIST:
		if s["id"] == id: return s
	return LIST[0]

## set up the freshly built world for the scenario (called by main before the first frame)
static func apply(g, id: String) -> void:
	g.scenario = {"id": id, "start": g.day}
	match id:
		"moda":
			g.apply_stage(1)
			furnish(g, 1)
			g.money = 4000.0; g.rating = 2.3
			# the depot has a little of everything on the shelves, a bit more of the staples
			for pid in g.backstock: g.backstock[pid] = 8 if g.is_stocked(pid) else 0
			for pid in ["ekmek", "sut", "kola", "cips"]: g.backstock[pid] = 16
			for f in g.fixtures:
				for sl in f.slots: sl["stock"] = int(sl["stock"]) / 2
			for r in g.neighborhood.residents: r["loyalty"] = randf_range(20.0, 40.0)
			g.neighborhood.grow(g)
			for r in g.neighborhood.residents: r["loyalty"] = minf(float(r["loyalty"]), 40.0)
			g.refresh_all()
		"kampus":
			g.scenario["traffic"] = 1.6
			g.scenario["arch"] = {"ogrenci": 3.5, "calisan": 1.2, "emekli": 0.3}
			g.money = 5000.0
		"carsi":
			g.apply_stage(1); g.apply_stage(2)
			furnish(g, 2)
			g.money = 30000.0; g.rating = 3.4
			g.neighborhood.grow(g)
			g.rival.open_day = g.day
			g.rival.start_day(g)
			g.rival.rating = 3.9
			for pid in g.backstock: if DB.product(pid)["stage"] <= 2 and g.is_stocked(pid): g.backstock[pid] = 30
			g.refresh_all()
		"serbest":
			g.money = 250000.0
	g.stage_changed.emit(); g.changed.emit()

## a ready-made shop floor for scenarios that start bigger than the kiosk
static func furnish(g, n: int) -> void:
	for f in g.fixtures.duplicate(): g.remove_fixture(f)
	var add := func(id: String, x: int, z: int, r: int, prods: Array) -> void:
		var d := DB.fixture(id)
		if not g.validate(d, x, z, r, null, 0)["ok"]: return
		var f: Fixture = g.add_fixture(d, x, z, r, 0)
		for i in mini(prods.size(), f.slots.size()):
			f.slots[i]["pid"] = prods[i]; f.slots[i]["stock"] = f.cap() / 2
	if n == 1:
		add.call("acik", 11, 6, 0, ["sut", "ayran", "kola"])
		add.call("manav", 16, 7, 0, ["domates", "elma"])
		add.call("sepet", 19, 6, 0, ["simit", "ekmek"])
		add.call("gondol", 12, 9, 0, ["cips", "biskuvi", "deterjan"])
		add.call("gondol", 12, 12, 0, ["cikolata", "yumurta", ""])
		add.call("raf", 20, 10, 0, ["gazete", ""])
		add.call("dolap", 24, 7, 0, ["yogurt", ""])
		add.call("depo", 22, 6, 0, [])
		add.call("kasa", 16, 13, 0, [])
		add.call("saksi", 25, 14, 0, [])
		add.call("cop", 10, 15, 0, [])
	else:
		add.call("acik", 11, 4, 0, ["sut", "ayran", "peynir"])
		add.call("acik", 14, 4, 0, ["kola", "su", "yogurt"])
		add.call("manav", 17, 4, 0, ["domates", "elma"])
		add.call("sepet", 22, 4, 0, ["simit", "ekmek"])
		add.call("depooda", 31, 4, 0, [])
		for x in [12, 16, 24, 28]:
			add.call("gondol", x, 7, 0, ["cips", "biskuvi", "makarna"])
			add.call("gondol", x, 10, 0, ["cikolata", "deterjan", "un"])
		add.call("levha", 13, 8, 0, [])
		add.call("levha", 25, 8, 0, [])
		add.call("sarkuteri", 19, 7, 0, ["sucuk", "kasar"])
		add.call("derin", 20, 10, 0, ["dondurma", "pizza"])
		add.call("kasa", 15, 13, 0, [])
		add.call("bantkasa", 25, 13, 0, [])
		add.call("araba", 32, 14, 0, [])
		add.call("saksi", 10, 15, 0, [])
		add.call("cop", 33, 15, 0, [])
	for s in g.staff.duplicate():
		if s.role != "owner": g.fire(s)
	g.hire({"role": "cashier", "name": "Elif", "wage": 300, "skill": 1.0}, true)
	g.hire({"role": "stocker", "name": "Can", "wage": 260, "skill": 1.0}, true)
	if n >= 2:
		g.hire({"role": "cashier", "name": "Deniz", "wage": 300, "skill": 1.0}, true)
		g.hire({"role": "stocker", "name": "Oğuz", "wage": 260, "skill": 1.0}, true)
		g.hire({"role": "cleaner", "name": "Nermin", "wage": 230, "skill": 1.0}, true)
		g.hire({"role": "deli", "name": "Rıza Usta", "wage": 360, "skill": 1.0, "trait": "guleryuz"}, true)
	g.refresh_all()

## the scenario's goal line for the goal card
static func goal_rows(g) -> Array:
	var id: String = g.scenario.get("id", "kariyer")
	var d := get_def(id)
	var left: int = int(d.get("days", 0)) - (g.day - int(g.scenario.get("start", 1)))
	match id:
		"moda": return [["rating", "Mağaza puanı", g.rating, 3.6], ["cash", "Kasada nakit", g.money, 20000.0], ["days", "Kalan gün", float(left), 0.0]]
		"kampus": return [["served", "Mutlu müşteri", float(g.totals["happy"]), 1400.0], ["days", "Kalan gün", float(left), 0.0]]
		"carsi": return [["rival", "Mahallede payın", g.rival.share(g) * 100.0, 75.0], ["days", "Kalan gün", float(left), 0.0]]
	return []

## end of day: won, lost or still going
static func check(g) -> String:
	var id: String = g.scenario.get("id", "kariyer")
	if id == "kariyer" or id == "serbest": return ""
	var d := get_def(id)
	var used: int = g.day - int(g.scenario.get("start", 1)) + 1
	match id:
		"moda":
			if g.rating >= 3.6 and g.money >= 20000: return "win"
			if g.money < -3000: return "lose"
		"kampus":
			if int(g.totals["happy"]) >= 1400: return "win"
		"carsi":
			if g.rival.closed: return "win"
	if used >= int(d["days"]): return "lose"
	return ""
