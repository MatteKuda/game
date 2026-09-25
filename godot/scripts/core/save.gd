class_name SaveGame
## JSON saves in user:// (Windows: %APPDATA%/Godot/app_userdata/Tezgâh).
## Slot 0 is the automatic save made every morning; slots 1-3 are manual.
## A save keeps the whole shop and mall; loading resumes at 07:00 of the saved day.

const VERSION := 1
static var pending: Dictionary = {} # set before reloading the scene; main applies it
static var pending_scenario := "" # a new game in another neighbourhood (Scenarios)

static func path(slot: int) -> String:
	return "user://tezgah_%s.json" % ("otomatik" if slot == 0 else "kayit%d" % slot)

static func exists(slot: int) -> bool: return FileAccess.file_exists(path(slot))

## short description for the slot list, or {} when empty
static func info(slot: int) -> Dictionary:
	if not exists(slot): return {}
	var d = _read(slot)
	if d == null: return {}
	return {"day": d.get("day", 1), "stage": d.get("stage", 0), "money": d.get("money", 0), "saved_at": d.get("saved_at", "")}

static func _read(slot: int) -> Variant:
	var f := FileAccess.open(path(slot), FileAccess.READ)
	if f == null: return null
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else null

static func save(game, slot: int) -> bool:
	var d := serialize(game)
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(d, "\t"))
	return true

## remember the save and restart the scene; main.gd applies it on the fresh world
static func load_slot(tree: SceneTree, slot: int) -> bool:
	var d = _read(slot)
	if d == null: return false
	pending = d
	tree.reload_current_scene()
	return true

# ------------------------------------------------------------------ serialize
static func _v2(v: Vector2i) -> Array: return [v.x, v.y]

static func serialize(game) -> Dictionary:
	var fx := []
	for f in game.fixtures:
		var slots := []
		for s in f.slots: slots.append({"pid": s["pid"], "stock": s["stock"], "fresh": s.get("fresh", 1.0)})
		fx.append({"id": f.def["id"], "x": f.gx, "z": f.gz, "r": f.rot, "l": f.lvl, "slots": slots, "dirty": f.dirty, "uses": f.get_meta("uses", 0)})
	var st := []
	for s in game.staff:
		st.append({"role": s.role, "name": s.person_name, "wage": s.base_wage, "skill": s.skill, "shift": s.shift, "trait": s.persona, "morale": s.morale, "days": s.days_worked, "raise_day": s.raise_day})
	var d := {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"stage": game.stage, "day": game.day, "money": game.money, "rating": game.rating,
		"prices": game.prices, "auto": game.auto, "backstock": game.backstock, "backstock_fresh": game.backstock_fresh,
		"orders": game.orders, "upgrades": game.upgrades.keys(), "totals": game.totals, "history": game.history,
		"evening_bakery": game.evening_bakery, "fixtures": fx, "staff": st, "last_sold": game.last_sold,
		"camera": [game.rig.target.x, game.rig.target.z],
		"neighborhood": game.neighborhood.serialize(),
		"weather": [game.calendar.weather, game.calendar.tomorrow],
		"product_log": game.product_log,
		"quests": game.quests.serialize(),
		"cat": game.cat.serialize(),
		"scenario": game.scenario,
		"rival": game.rival.serialize(),
		"economy": {"cost_mul": game.cost_mul, "price_mul": game.price_mul, "next_hike": game._next_hike_day, "loan": game.loan, "vouchers": game.vouchers},
	}
	if game.mall != null:
		var m = game.mall
		var units := []
		for u in m.units:
			var t := {}
			if not u["tenant"].is_empty():
				var tt: Dictionary = u["tenant"]
				t = {"id": tt["def"]["id"], "rent": tt["rent"], "sat": tt["sat"], "low_days": tt["low_days"], "since": tt["since"]}
			var offers := []
			for o in u["offers"]: offers.append({"id": o["def"]["id"], "rent": o["rent"]})
			units.append({"tenant": t, "offers": offers})
		var conns := []
		for c in m.connectors: conns.append({"broken": c["broken"]})
		d["mall"] = {"units": units, "connectors": conns, "scheduled": m.scheduled, "mood": m.mood, "history": m.history}
	return d

# ------------------------------------------------------------------ apply (on a freshly built stage-0 world)
static func apply(game, d: Dictionary) -> void:
	var n := int(d.get("stage", 0))
	for s in range(1, n + 1): game.apply_stage(s)
	for f in game.fixtures.duplicate(): game.remove_fixture(f)
	for s in game.staff.duplicate():
		game.staff.erase(s); s.queue_free()
	game.day = int(d.get("day", 1))
	game.money = float(d.get("money", 0))
	game.rating = float(d.get("rating", 3.0))
	for k in d.get("prices", {}): game.prices[k] = int(d["prices"][k])
	for k in d.get("auto", {}): game.auto[k] = bool(d["auto"][k])
	for k in d.get("backstock", {}): game.backstock[k] = int(d["backstock"][k])
	for k in d.get("backstock_fresh", {}): game.backstock_fresh[k] = float(d["backstock_fresh"][k])
	game.orders = []
	for o in d.get("orders", []): game.orders.append({"pid": o["pid"], "qty": int(o["qty"]), "eta": float(o["eta"])})
	game.evening_bakery = bool(d.get("evening_bakery", false))
	game.last_sold = {}
	for k in d.get("last_sold", {}): game.last_sold[k] = int(d["last_sold"][k])
	for k in d.get("totals", {}): game.totals[k] = int(d["totals"][k])
	game.history = []
	for h in d.get("history", []): game.history.append(h)
	game.neighborhood.apply(d.get("neighborhood", {}))
	if game.neighborhood.residents.is_empty(): game.neighborhood.generate(game)
	var wt: Array = d.get("weather", [])
	if wt.size() == 2: game.calendar.weather = wt[0]; game.calendar.tomorrow = wt[1]
	game.sky.set_weather(game.calendar.weather)
	game.product_log = []
	for e in d.get("product_log", []): game.product_log.append(e)
	var eco: Dictionary = d.get("economy", {})
	game.cost_mul = float(eco.get("cost_mul", 1.0)); game.price_mul = float(eco.get("price_mul", 1.0))
	game._next_hike_day = int(eco.get("next_hike", game.day + 7))
	game.loan = {}
	var ln: Dictionary = eco.get("loan", {})
	for k in ln: game.loan[k] = int(ln[k])
	game.vouchers = {}
	for k in eco.get("vouchers", {}): game.vouchers[k] = int(eco["vouchers"][k])
	game.rival.apply(game, d.get("rival", {}))
	game.cat.apply(game, d.get("cat", {}))
	game.scenario = d.get("scenario", {})
	if game.scenario.has("start"): game.scenario["start"] = int(game.scenario["start"])
	game.quests.apply(d.get("quests", {}))
	for fd in d.get("fixtures", []):
		var def := DB.fixture(fd["id"])
		if def.is_empty(): continue
		var f: Fixture = game.add_fixture(def, int(fd["x"]), int(fd["z"]), int(fd["r"]), int(fd["l"]))
		var slots: Array = fd.get("slots", [])
		for i in mini(slots.size(), f.slots.size()):
			f.slots[i]["pid"] = slots[i]["pid"]
			f.slots[i]["stock"] = int(slots[i]["stock"])
			f.slots[i]["fresh"] = float(slots[i].get("fresh", 1.0))
		if fd.get("dirty", false):
			if def["kind"] == "table": game.dirty_table(f)
			elif def["kind"] == "wc":
				f.set_meta("uses", 99); game.use_wc(f)
		elif int(fd.get("uses", 0)) > 0: f.set_meta("uses", int(fd["uses"]))
	for sd in d.get("staff", []):
		var ns: Staff = game.hire({"role": sd["role"], "name": sd["name"], "wage": int(sd["wage"]), "skill": float(sd["skill"]), "trait": sd.get("trait", "")}, true, sd.get("shift", "full"))
		ns.morale = float(sd.get("morale", 70.0)); ns.days_worked = int(sd.get("days", 0)); ns.raise_day = int(sd.get("raise_day", game.day))
	for u in d.get("upgrades", []): game.upgrades[u] = true
	game.apply_upgrade_visuals()
	if d.has("mall") and game.mall != null:
		var md: Dictionary = d["mall"]
		var m = game.mall
		var units: Array = md.get("units", [])
		for i in mini(units.size(), m.units.size()):
			var u: Dictionary = m.units[i]
			var ud: Dictionary = units[i]
			u["offers"] = []
			for o in ud.get("offers", []):
				var td := MallDB.tenant(o["id"])
				if not td.is_empty(): u["offers"].append({"def": td, "rent": int(o["rent"])})
			u["tenant"] = {}
			var t: Dictionary = ud.get("tenant", {})
			if not t.is_empty() and not MallDB.tenant(t["id"]).is_empty():
				u["tenant"] = {"def": MallDB.tenant(t["id"]), "rent": int(t["rent"]), "sat": float(t["sat"]), "reasons": [], "sales": 0, "visitors": 0, "low_days": int(t.get("low_days", 0)), "since": int(t.get("since", 1))}
			m._apply_furniture(u)
		var cs: Array = md.get("connectors", [])
		for i in mini(cs.size(), m.connectors.size()): m.connectors[i]["broken"] = bool(cs[i]["broken"])
		m.scheduled = []
		for s in md.get("scheduled", []): m.scheduled.append({"day": int(s["day"]), "id": s["id"]})
		m.mood = float(md.get("mood", 3.5))
		m.history = md.get("history", [])
		m.recalc_sat()
		game.mall_changed.emit()
	game.resume_day()
	game.neighborhood.start_day(game)
	game.quests.refill(game)
	game.cat.start_day(game)
	var cam: Array = d.get("camera", [])
	if cam.size() == 2: game.rig.focus(float(cam[0]), float(cam[1]))
