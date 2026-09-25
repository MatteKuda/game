class_name AutoPlayer
extends RefCounted
## A scripted "reasonable player" for balance runs (--bot): once per game hour it looks at the shop
## like a player would — stocks what people ask for, hires when shelves or queues suffer, nudges
## prices, answers events, buys the obvious upgrades and expands when the goals are met.
## It is deliberately average, not optimal: the point is to measure how long a normal game takes.

var g
var log: Array = []
var _last_hour := -1
var _price_day := -1
var stage_times := {} # stage -> [day, clock]

func _init(game) -> void:
	g = game
	stage_times[0] = [g.day, g.clock]

func note(t: String) -> void:
	log.append("D%d %s %s" % [g.day, Cfg.clock_str(g.clock), t])

func tick() -> void:
	# answer events at once
	for ev in g.neighbor_events.duplicate():
		var pick := 0
		match ev["kind"]:
			"deal": pick = 0 if not ev["choices"][0].get("disabled", false) and g.money > 3000 else 1
			"bulk": pick = 0 if not ev["choices"][0].get("disabled", false) else 1
			"match": pick = 0 if g.money > 2500 else 1
			"inspect": pick = 1 if g.money > 1500 and g.litter.size() > 1 else 0
			"raise": pick = 0 if g.money > 4000 else 1
			"cat": pick = 0
		if ev["choices"][pick].get("disabled", false): pick = ev["choices"].size() - 1
		g.answer_event(ev["id"], pick)
	if not g.is_open(): return
	var h: int = int(g.clock / 60.0)
	if h == _last_hour: return
	_last_hour = h
	_hourly()

func _hourly() -> void:
	if g.can_expand() and g.money > g.expansion()["cost"] + 3000:
		var to: int = g.expansion()["to"]
		g.expand()
		stage_times[to] = [g.day, g.clock]
		note("EXPAND to %d" % to)
		_furnish_new_stage(to)
	_stock_missing()
	_staff()
	_fixtures_and_upgrades()
	if _price_day != g.day and g.clock > 17 * 60:
		_price_day = g.day
		_prices()
	if g.rival.active and g.rival.share(g) < 0.6 and g.money > 3000 and g.day > g.rival.poster_until:
		g.rival.act(g, "poster"); note("rival poster")
	if g.pending_inflation() > 0.03: g.apply_inflation_to_prices()
	if g.neighborhood.mode == "off" and g.stage >= 1: g.neighborhood.mode = "regulars"
	for r in g.neighborhood.overdue(g): g.neighborhood.remind(g, r)

## put products people asked for on free sections (or new shelves)
func _stock_missing() -> void:
	var missed: Dictionary = g.stats["missed"]
	var want := []
	for pid in missed:
		if int(missed[pid]) >= 3 and not g.is_stocked(pid) and g.calendar.product_active(g.day, pid): want.append(pid)
	for req in g.neighborhood.residents:
		if not req["request"].is_empty() and not g.is_stocked(req["request"]["pid"]): want.append(req["request"]["pid"])
	for pid in want:
		var disp: String = DB.product(pid)["display"]
		var done := false
		for f in g.fixtures:
			if done or not f.is_display() or f.def["display"] != disp: continue
			for i in f.slots.size():
				if f.slots[i]["pid"] == "":
					g.assign_slot(f, i, pid); done = true; note("stock %s" % pid); break
		if not done:
			var fid: String = {"shelf": "gondol" if g.stage >= 1 else "raf", "fridge": "dolap", "basket": "sepet", "produce": "manav", "freezer": "derin", "deli": "sarkuteri"}.get(disp, "raf")
			if DB.fixture(fid)["stage"] <= g.stage and g.money > DB.fixture(fid)["cost"] + 2000:
				var f2 = place(fid)
				if f2 != null:
					g.assign_slot(f2, 0, pid); note("built %s for %s" % [fid, pid])

func _staff() -> void:
	var st: Dictionary = g.stats
	var count := func(role: String) -> int: return g.staff.filter(func(s): return s.role == role).size()
	var hire_role: String = ""
	var empties := 0
	for f in g.fixtures:
		for s in f.slots: if s["pid"] != "" and int(s["stock"]) == 0: empties += 1
	var q: int = 0
	for f in g.fixtures: q += f.queue.size()
	var regs: int = g.fixtures.filter(func(f): return f.def["kind"] == "register" and not f.def.get("self", false)).size()
	if empties >= 2 and count.call("stocker") < 1 + g.stage: hire_role = "stocker"
	elif q >= 4 and count.call("cashier") + 1 < regs: hire_role = "cashier"
	elif g.stage >= 1 and (g.litter.size() >= 4 or g.puddles.size() >= 2) and count.call("cleaner") < 1 + int(g.stage >= 2): hire_role = "cleaner"
	elif g.stage >= 1 and int(g.totals["theft"]) > 300 and count.call("security") < 1: hire_role = "security"
	elif g.fixtures.any(func(f): return f.def["kind"] == "oven") and count.call("baker") < 1: hire_role = "baker"
	elif g.fixtures.any(func(f): return f.def.get("staffed", false)) and count.call("deli") < 1: hire_role = "deli"
	elif g.stage >= 3 and count.call("technician") < 1: hire_role = "technician"
	if hire_role == "" or g.money < 3000: return
	for c in g.candidates:
		if c["role"] == hire_role:
			g.hire(c); note("hire %s" % hire_role); return

func _fixtures_and_upgrades() -> void:
	var buffer: float = 4000.0 + g.stage * 4000.0
	# a second till when queues are long
	var q: int = 0
	for f in g.fixtures: q += f.queue.size()
	var reg_id := "bantkasa" if g.stage >= 2 else "kasa"
	if q >= 5 and g.money > DB.fixture(reg_id)["cost"] + buffer:
		if place(reg_id) != null: note("built %s" % reg_id)
	if g.litter.size() >= 3 and g.money > 2000 and g.fixtures.filter(func(f): return f.def["kind"] == "bin").size() < 1 + g.stage:
		if place("cop") != null: note("built bin")
	if g.stage >= 2 and g.money > 1500 and g.fixtures.filter(func(f): return f.def["kind"] == "sign").size() < 4:
		if place("levha") != null: note("built sign")
	if g.stage >= 1 and int(g.stats["theft_count"]) >= 2 and g.money > 3000 and g.fixtures.filter(func(f): return f.def["kind"] == "camera").size() < 1 + g.stage:
		if place("kamera") != null: note("built camera")
	for u in ["pos", "tente", "neon", "etiket", "isik", "sadakat", "gunes", "otopark", "ozelmarka"]:
		var d: Dictionary = DB.UPGRADES.filter(func(x): return x["id"] == u)[0]
		if d["stage"] <= g.stage and not g.upgrades.has(u) and g.money > d["cost"] + buffer:
			g.buy_upgrade(u); note("upgrade %s" % u); break

func _prices() -> void:
	for p in g.unlocked_products():
		var pid: String = p["id"]
		if not g.is_stocked(pid): continue
		var exp: int = int(g.stats["expensive"].get(pid, 0))
		var sold: int = int(g.stats["sold"].get(pid, 0))
		if exp >= 3: g.set_price(pid, g.prices[pid] - 1)
		elif exp == 0 and sold >= 15 and g.prices[pid] < g.ref_price(pid) * 1.08: g.set_price(pid, g.prices[pid] + 1)

## the obvious extra fixtures for a new stage (on top of what is already there)
func _furnish_new_stage(n: int) -> void:
	var plan := []
	match n:
		1: plan = [["gondol", ["cips", "biskuvi", "deterjan"]], ["manav", ["domates", "elma"]], ["acik", ["sut", "yogurt", "ayran"]], ["kasa", []], ["depo", []], ["cop", []]]
		2: plan = [["gondol", ["makarna", "un", "seker"]], ["gondol", ["cay", "yag", "bebekbezi"]], ["acik", ["peynir", "su", "kola"]], ["bantkasa", []], ["depooda", []], ["soguk", []], ["levha", []], ["levha", []], ["araba", []], ["firin", []]]
		3: plan = [["masa", []], ["masa", []], ["masa", []], ["wc", []], ["oyunalani", []]]
	for it in plan:
		if g.money < DB.fixture(it[0])["cost"] + 2000: break
		var l: int = 1 if DB.zone(DB.fixture(it[0])) == "mall" else 0
		var f = place(it[0], l)
		if f == null: continue
		for i in mini(it[1].size(), f.slots.size()): g.assign_slot(f, i, it[1][i])
		note("built %s" % it[0])
	if n == 3 and g.mall != null:
		for u in g.mall.units:
			if u["tenant"].is_empty() and not u["offers"].is_empty(): g.mall.lease(u, 0)
	for pid in g.backstock:
		if g.is_stocked(pid) and int(g.backstock[pid]) < 12: g.order(pid, 24, false, true)

## first valid spot for a fixture, scanning from the back wall
func place(id: String, l := 0):
	var d := DB.fixture(id)
	if g.money < d["cost"]: return null
	if g.view_floor != l: g.set_view_floor(l)
	var r: Rect2i = g.grid.interior() if l == 0 and DB.zone(d) != "mall" else Rect2i(1, 1, Cfg.MAP_W - 2, 18)
	for z in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			for rot in [0, 2, 1, 3]:
				if g.validate(d, x, z, rot, null, l)["ok"]:
					g.money -= d["cost"]; g.stats["other"] += int(d["cost"])
					var f = g.add_fixture(d, x, z, rot, l)
					g.set_view_floor(0)
					return f
	g.set_view_floor(0)
	return null
