class_name SaveGame
## JSON saves in user:// (Windows: %APPDATA%/Godot/app_userdata/Tezgâh).
## Slot 0 is the automatic save made every morning; slots 1-3 are manual.
## A save keeps the whole shop and mall. A save made during the day also keeps the clock, the day's
## figures and today's campaigns, so loading continues from that time (shoppers inside are not kept).
## Files are written atomically with a .bak copy; a damaged file falls back to its backup.

const VERSION := 2
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

static func _read_file(p: String) -> Variant:
	if not FileAccess.file_exists(p): return null
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null: return null
	var d = JSON.parse_string(f.get_as_text())
	return _migrate(d) if d is Dictionary and _valid(d) else null

## the main file, or its backup when the main one is missing or damaged
static func _read(slot: int) -> Variant:
	var d = _read_file(path(slot))
	if d == null: d = _read_file(path(slot) + ".bak")
	return d

## just enough structure to rebuild a world without crashing
static func _valid(d: Dictionary) -> bool:
	if not (d.get("stage") is float or d.get("stage") is int) or int(d["stage"]) < 0 or int(d["stage"]) > 3: return false
	if not (d.get("day") is float or d.get("day") is int) or not (d.get("money") is float or d.get("money") is int): return false
	if not (d.get("fixtures", []) is Array) or not (d.get("staff", []) is Array): return false
	for f in d.get("fixtures", []):
		if not (f is Dictionary) or not f.has("id") or not f.has("x") or not f.has("z"): return false
	return true

## older saves: fill in what later versions added (most fields already default on load)
static func _migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 1))
	if v < 2:
		d["midday"] = {}
	d["version"] = VERSION
	return d

## the backup only protects against a damaged write, so the previous good file becomes .bak
static func save(game, slot: int) -> bool:
	var d := serialize(game)
	var p := path(slot)
	var tmp := p + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	if _read_file(tmp) == null: return false
	var dir := DirAccess.open("user://")
	if dir == null: return false
	var base := p.get_file()
	if dir.file_exists(base):
		if dir.file_exists(base + ".bak"): dir.remove(base + ".bak")
		dir.rename(base, base + ".bak")
	return dir.rename(base + ".tmp", base) == OK

## JSON turns every number into a float; counters in the day figures should stay whole
static func _intify(v):
	if v is Dictionary:
		for k in v: v[k] = _intify(v[k])
		return v
	if v is float and v == floorf(v) and absf(v) < 1e15: return int(v)
	return v

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
		"style": game.style,
		"strike_day": game.strike_day,
		"branches": game.branches.serialize(),
		"rival": game.rival.serialize(),
		"economy": {"cost_mul": game.cost_mul, "price_mul": game.price_mul, "next_hike": game._next_hike_day, "loan": game.loan, "vouchers": game.vouchers},
		"midday": _midday(game),
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

## state of the day in progress (empty for the morning autosave or after closing)
static func _midday(game) -> Dictionary:
	if game.day_ended_flag or game.clock <= Cfg.DAY_OPEN + 1.0: return {}
	var energies := []
	for s in game.staff: energies.append(s.energy)
	var cargo := []
	for o in game.van["cargo"]: cargo.append({"pid": o["pid"], "qty": o["qty"], "eta": game.abs_minutes()})
	return {"clock": game.clock, "stats": game.stats, "campaigns": game.campaigns.keys(), "discounts": game.discounts, "multi": game.multi,
		"energy": energies, "cargo": cargo, "match": game.match_night, "inspection": game.inspection_at, "praise": game.praise_until, "outage": game.outage_until}

static func _apply_midday(game, m: Dictionary) -> void:
	if m.is_empty(): return
	game.clock = float(m["clock"])
	var st: Dictionary = _intify(m.get("stats", {}))
	for k in st: game.stats[k] = st[k]
	for c in m.get("campaigns", []): game.campaigns[c] = true
	game.discounts = m.get("discounts", []); game.multi = m.get("multi", [])
	var en: Array = m.get("energy", [])
	for i in mini(en.size(), game.staff.size()): game.staff[i].energy = float(en[i])
	for o in m.get("cargo", []): game.orders.append({"pid": o["pid"], "qty": int(o["qty"]), "eta": float(o["eta"])})
	game.match_night = m.get("match", {})
	if game.match_night.has("day"): game.match_night["day"] = int(game.match_night["day"])
	game.inspection_at = float(m.get("inspection", 0.0)); game.praise_until = float(m.get("praise", 0.0)); game.outage_until = float(m.get("outage", 0.0))
	game.neighborhood.today = game.neighborhood.today.filter(func(v): return float(v["at"]) > game.clock)
	game._next_announce = game.abs_minutes() + 60.0
	game.refresh_all(); game._campaign_visuals()

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
	game.strike_day = int(d.get("strike_day", -1))
	game.branches.apply(d.get("branches", []))
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
	var sty: Dictionary = d.get("style", {})
	for k in sty: game.style[k] = int(sty[k])
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
	_apply_midday(game, d.get("midday", {}))
	var cam: Array = d.get("camera", [])
	if cam.size() == 2: game.rig.focus(float(cam[0]), float(cam[1]))
