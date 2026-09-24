class_name Game
extends Node3D
## Orchestrates the simulation (fixed 1/30 s steps) and the 3D world.

signal alert_added(a: Dictionary)
signal selection_changed()
signal day_ended(report: Dictionary)
signal changed()
signal placing_changed()
signal stage_changed()

var grid := Grid.new()
var sky: DaySky
var street: Street
var shop: ShopShell
var overlays: Overlays
var rig: CameraRig
var fixtures_node: Node3D
var agents_node: Node3D

var stage := 0
var money := 6500.0
var day := 1
var clock := float(Cfg.DAY_OPEN)
var speed := 1.0
var paused := true
var day_ended_flag := false
var rating := 3.0
var prices := {}
var auto := {}
var backstock := {}
var orders: Array = [] # [{pid, qty, eta}]
var fixtures: Array = []
var customers: Array = []
var staff: Array = []
var litter: Array = [] # [{tile, node, claimed}]
var upgrades := {}
var stats := {}
var totals := {"served": 0, "happy": 0, "revenue": 0, "visitors": 0}
var history: Array = []
var candidates: Array = []
var alerts: Array = []
var selection := {} # {kind, obj}
var heat_on := false
var van := {"state": "idle", "x": -30.0, "t": 0.0, "cargo": []}
var placing := {}
var real_time := 0.0

var _alert_cd := {}
var _alert_id := 1
var _spawn_acc := 0.0
var _walk_acc := 0.0
var _auto_acc := 0.0
var _status_acc := 0.0
var _heat_acc := 0.0
var _acc := 0.0

static func new_stats() -> Dictionary:
	return {"revenue": 0, "served": 0, "happy": 0, "lost": 0, "lost_crowd": 0, "lost_queue": 0, "visitors": 0,
		"abandoned": 0, "impulse": 0, "purchases": 0, "wages": 0, "rent": 0, "utilities": 0, "other": 0,
		"missed": {}, "expensive": {}, "sold": {}, "mood_sum": 0.0, "mood_n": 0}

func _ready() -> void:
	stats = new_stats()
	sky = DaySky.new(); add_child(sky)
	street = Street.new(); add_child(street); street.build()
	grid.apply_layout(Cfg.STAGE_LAYOUTS[0])
	_apply_env_blocks()
	shop = ShopShell.new(); add_child(shop); shop.build(Cfg.STAGE_LAYOUTS[0], 0, upgrades)
	fixtures_node = Node3D.new(); add_child(fixtures_node)
	agents_node = Node3D.new(); add_child(agents_node)
	overlays = Overlays.new(); add_child(overlays)
	rig = CameraRig.new(); add_child(rig)
	rig.focus(21.5, 14.0, 18.0); rig.g_yaw = -0.18; rig.g_pitch = 0.82; rig.snap()
	for p in DB.PRODUCTS:
		prices[p["id"]] = p["base"]; auto[p["id"]] = true; backstock[p["id"]] = 0
	_add("raf", 20, 10, 0, ["cips", "biskuvi"])
	_add("raf", 18, 10, 1, ["cikolata", ""])
	_add("dolap", 25, 13, 3, ["kola", "ayran"])
	_add("sepet", 25, 12, 3, ["simit", "ekmek"])
	_add("depo", 23, 10, 0)
	_add("kasa", 19, 12, 1)
	_add("saksi", 18, 15, 0)
	_add("cop", 25, 15, 0)
	for pid in ["cips", "biskuvi", "cikolata", "kola", "ayran", "simit", "ekmek"]: backstock[pid] = 8
	hire({"role": "owner", "name": "Kemal Usta", "wage": 0, "skill": 1.1}, true)
	roll_candidates()
	refresh_all()
	for i in 6: _spawn_walker(true)

func _add(id: String, x: int, z: int, r: int, prods := []) -> Fixture:
	var f := add_fixture(DB.fixture(id), x, z, r)
	for i in prods.size():
		if i < f.slots.size() and prods[i] != "":
			f.slots[i]["pid"] = prods[i]; f.slots[i]["stock"] = f.cap()
	return f

func _apply_env_blocks() -> void:
	for t in street.blocked:
		if grid.in_bounds(t.x, t.y) and grid.region[grid.idx(t.x, t.y)] == Grid.R_OUT: grid.region[grid.idx(t.x, t.y)] = Grid.R_VOID
	grid.version += 1

# ------------------------------------------------------------------ alerts
func alert(key: String, icon: String, text: String, severity := "warn", focus = null, cooldown := 45.0) -> void:
	if real_time - float(_alert_cd.get(key, -1e9)) < cooldown: return
	_alert_cd[key] = real_time
	var a := {"id": _alert_id, "key": key, "icon": icon, "text": text, "severity": severity, "focus": focus, "t": real_time}
	_alert_id += 1
	alerts.push_front(a)
	if alerts.size() > 5: alerts.pop_back()
	alert_added.emit(a)

# ------------------------------------------------------------------ queries
func is_open() -> bool: return clock >= Cfg.DAY_OPEN and clock < Cfg.DAY_CLOSE
func hour() -> float: return clock / 60.0
func abs_minutes() -> float: return day * 1440.0 + clock
func customers_inside() -> int:
	var n := 0
	for c in customers: if c.inside(): n += 1
	return n
func max_inside() -> int: return DB.STAGES[stage]["max_inside"]
func has_role(r: String) -> bool:
	for s in staff: if s.role == r: return true
	return false
func depot_capacity() -> int:
	var n := 0
	for f in fixtures: n += int(f.def.get("depot", 0))
	return n
func backstock_total() -> int:
	var n := 0
	for k in backstock: n += int(backstock[k])
	return n
func incoming(pid: String) -> int:
	var n := 0
	for o in orders + van["cargo"]: if o["pid"] == pid: n += int(o["qty"])
	return n
func incoming_total() -> int:
	var n := 0
	for o in orders + van["cargo"]: n += int(o["qty"])
	return n
func shelf_stock(pid: String) -> int:
	var n := 0
	for f in fixtures:
		for s in f.slots: if s["pid"] == pid: n += int(s["stock"])
	return n
func shelf_cap(pid: String) -> int:
	var n := 0
	for f in fixtures:
		for s in f.slots: if s["pid"] == pid: n += f.cap()
	return n
func is_stocked(pid: String) -> bool:
	for f in fixtures:
		for s in f.slots: if s["pid"] == pid: return true
	return false
func unlocked_products() -> Array: return DB.PRODUCTS.filter(func(p): return p["stage"] <= stage)
func wages_per_day() -> int:
	var n := 0
	for s in staff: n += s.wage
	return n
func rent() -> int: return DB.STAGES[stage]["rent"]
func utilities() -> int: return DB.STAGES[stage]["utilities"]
func patience_mul() -> float:
	var plants := fixtures.filter(func(f): return f.def["kind"] == "plant").size()
	return 1.0 + minf(0.25, plants * 0.06)
func tolerance_bonus() -> float: return 0.05 if upgrades.has("etiket") else 0.0
func impulse_mul() -> float: return 1.2 if upgrades.has("isik") else 1.0
func effective_price(pid: String) -> int: return int(prices[pid])
func bin_near(t: Vector2i) -> bool:
	for f in fixtures:
		if f.def["kind"] == "bin" and Vector2(f.center().x - t.x - 0.5, f.center().z - t.y - 0.5).length() <= 3.0: return true
	return false
func plant_near(t: Vector2i) -> bool:
	for f in fixtures:
		if f.def["kind"] == "plant" and Vector2(f.center().x - t.x - 0.5, f.center().z - t.y - 0.5).length() <= 2.6: return true
	return false
func litter_near(t: Vector2i, r: float) -> bool:
	for l in litter:
		if Vector2(l["tile"].x - t.x, l["tile"].y - t.y).length() <= r: return true
	return false
func nearest_access(f: Fixture, from: Vector3) -> Vector2i:
	var acc: Array = f.access().filter(func(t): return grid.walkable(t.x, t.y))
	acc.sort_custom(func(a, b): return Vector2(a.x + 0.5 - from.x, a.y + 0.5 - from.z).length() < Vector2(b.x + 0.5 - from.x, b.y + 0.5 - from.z).length())
	return acc[0] if acc.size() > 0 else f.access()[0]
func nearest_walkable(t: Vector2i) -> Vector2i:
	if grid.walkable(t.x, t.y): return t
	for r in range(1, 4):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if grid.walkable(t.x + dx, t.y + dz) and grid.region[grid.idx(t.x + dx, t.y + dz)] != Grid.R_OUT: return Vector2i(t.x + dx, t.y + dz)
	return t

func expansion() -> Variant:
	for e in DB.EXPANSIONS:
		if e["to"] == stage + 1: return e
	return null
func goals() -> Array:
	var e = expansion()
	if e == null: return []
	var out := []
	for g in e["goals"]:
		var v: float = rating if g[0] == "rating" else (float(totals["happy"]) if g[0] == "served" else money)
		out.append({"id": g[0], "label": g[1], "target": g[2], "value": v, "done": v >= g[2]})
	return out
func can_expand() -> bool:
	if expansion() == null: return false
	for g in goals(): if not g["done"]: return false
	return true

# ------------------------------------------------------------------ fixtures
func add_fixture(d: Dictionary, x: int, z: int, r: int) -> Fixture:
	var f := Fixture.new()
	fixtures_node.add_child(f)
	f.setup(d, x, z, r)
	fixtures.append(f)
	for t in f.fp["tiles"]: grid.fixture[grid.idx(t.x, t.y)] = f.uid
	grid.version += 1
	if upgrades.has("pos") and f.model["pos_device"]: f.model["pos_device"].visible = true
	layout_changed()
	return f

func remove_fixture(f: Fixture) -> void:
	for t in f.fp["tiles"]: grid.fixture[grid.idx(t.x, t.y)] = 0
	fixtures.erase(f)
	for s in f.slots:
		if s["pid"] != "" and s["stock"] > 0: backstock[s["pid"]] += int(s["stock"])
	for c in f.queue.duplicate(): c.pick_register(self)
	if f.cashier: f.cashier.register = null
	for s in staff:
		if s.task != null and s.task["kind"] == "restock" and (s.task["fixture"] == f or s.task["depot"] == f): s.cancel_task(self)
	f.queue_free()
	grid.version += 1
	layout_changed()

func layout_changed() -> void:
	var L := grid.layout
	for f in fixtures:
		if f.def["kind"] != "register": continue
		var svc: Vector2i = f.access()[0]
		var best: Array[Vector2i] = []
		for dx in L["doors"]:
			var p := grid.find_path(svc, Vector2i(dx, grid.front_z()))
			if p.size() > 0 and (best.is_empty() or p.size() < best.size()): best = p
		var slots_: Array[Vector2i] = []
		if best.is_empty(): slots_.append(svc)
		else:
			slots_.append_array(best)
			var last: Vector2i = best[-1]
			for i in 4: slots_.append(Vector2i(last.x + i, grid.interior().end.y))
		var uniq: Array[Vector2i] = []
		for t in slots_:
			if not uniq.has(t) and grid.walkable(t.x, t.y): uniq.append(t)
		f.queue_slots = uniq
	refresh_all()
	changed.emit()

func refresh_all() -> void:
	for f in fixtures: f.refresh(self)
	depot_changed()

func stock_changed(f: Fixture) -> void: f.refresh(self)

func depot_changed() -> void:
	var cap := depot_capacity()
	var fill := minf(1.0, float(backstock_total()) / cap) if cap > 0 else 0.0
	for f in fixtures:
		if f.def["kind"] == "depot": f.set_depot_fill(fill)

func validate(d: Dictionary, x: int, z: int, r: int, ignore: Fixture) -> Dictionary:
	var fp := Fixture.footprint(d, x, z, r)
	var ign_uid := ignore.uid if ignore else -999
	for t in fp["tiles"]:
		if not grid.is_interior(t.x, t.y): return {"ok": false, "reason": "Dükkânın içine yerleştirilmeli"}
		var occ := grid.fixture[grid.idx(t.x, t.y)]
		if occ != 0 and occ != ign_uid: return {"ok": false, "reason": "Başka bir eşyanın üstüne gelemez"}
		if grid.reserved[grid.idx(t.x, t.y)]: return {"ok": false, "reason": "Kapı önü boş kalmalı"}
	var needs := ["display", "register", "depot"].has(d["kind"])
	var tile_set := {}
	for t in fp["tiles"]: tile_set[grid.idx(t.x, t.y)] = true
	var acc_free := func(t: Vector2i) -> bool:
		if not grid.is_interior(t.x, t.y) or tile_set.has(grid.idx(t.x, t.y)): return false
		var o := grid.fixture[grid.idx(t.x, t.y)]
		return o == 0 or o == ign_uid
	if needs:
		var any := false
		for t in fp["access"]: if acc_free.call(t): any = true
		if not any: return {"ok": false, "reason": "Önü açık olmalı (erişim alanı)"}
	if d["kind"] == "register":
		if not acc_free.call(fp["access"][0]): return {"ok": false, "reason": "Kasanın müşteri tarafı boş olmalı"}
		if not acc_free.call(fp["back"][0]): return {"ok": false, "reason": "Kasiyerin arkada duracağı yer yok"}
	if d.has("max") and ignore == null:
		var maxc: int = d["max"][stage]
		if fixtures.filter(func(f): return f.def["id"] == d["id"]).size() >= maxc: return {"ok": false, "reason": "Bu aşamada en fazla %d adet" % maxc}
	# reachability with the tentative placement
	var saved := []
	if ignore:
		for t in ignore.fp["tiles"]: saved.append([grid.idx(t.x, t.y), grid.fixture[grid.idx(t.x, t.y)]]); grid.fixture[grid.idx(t.x, t.y)] = 0
	for t in fp["tiles"]: saved.append([grid.idx(t.x, t.y), grid.fixture[grid.idx(t.x, t.y)]]); grid.fixture[grid.idx(t.x, t.y)] = -1
	var reach := grid.reachable_from(Vector2i(grid.layout["doors"][0], grid.front_z()))
	var res := {"ok": true, "reason": ""}
	for f in fixtures:
		if f == ignore or not ["display", "depot", "register"].has(f.def["kind"]): continue
		var ok := false
		for t in f.access(): if grid.walkable(t.x, t.y) and reach[grid.idx(t.x, t.y)]: ok = true
		if not ok: res = {"ok": false, "reason": "%s ulaşılamaz hâle gelir" % f.def["name"]}; break
		if f.def["kind"] == "register":
			var b: Vector2i = f.back()[0]
			if not reach[grid.idx(b.x, b.y)]: res = {"ok": false, "reason": "Kasiyer yeri ulaşılamaz hâle gelir"}; break
	if res["ok"] and needs:
		var ok2 := false
		for t in fp["access"]: if grid.walkable(t.x, t.y) and reach[grid.idx(t.x, t.y)]: ok2 = true
		if not ok2: res = {"ok": false, "reason": "Bu konuma yol yok"}
	if res["ok"]:
		for dx in grid.layout["doors"]:
			if not reach[grid.idx(dx, grid.front_z())]: res = {"ok": false, "reason": "Kapılardan biri kapanıyor"}
	for i in range(saved.size() - 1, -1, -1): grid.fixture[saved[i][0]] = saved[i][1]
	return res

# ------------------------------------------------------------------ placement (build mode)
func start_placement(id: String, moving: Fixture = null) -> void:
	cancel_placement()
	var d := DB.fixture(id)
	var ghost := Node3D.new()
	var m := Props.build(d)
	ghost.add_child(m["root"])
	add_child(ghost)
	_ghostify(ghost)
	placing = {"def": d, "rot": moving.rot if moving else 0, "ghost": ghost, "moving": moving, "x": -1, "z": -1, "ok": false, "reason": "Bir konum seç"}
	if moving: moving.visible = false
	placing_changed.emit()

func _ghostify(n: Node) -> void:
	for c in Art._all(n):
		if c is MeshInstance3D:
			(c as MeshInstance3D).transparency = 0.35
		elif c is Label3D:
			(c as Label3D).modulate.a = 0.6
		elif c is Light3D:
			c.visible = false

func update_placement(x: int, z: int) -> void:
	if placing.is_empty(): return
	var d: Dictionary = placing["def"]
	var fp := Fixture.footprint(d, x, z, placing["rot"])
	var gx := x - int(fp["fw"] / 2)
	var gz := z - int(fp["fd"] / 2)
	placing["x"] = gx; placing["z"] = gz
	var v := validate(d, gx, gz, placing["rot"], placing["moving"])
	var afford: bool = placing["moving"] != null or money >= d["cost"]
	placing["ok"] = v["ok"] and afford
	placing["reason"] = v["reason"] if not v["ok"] else ("" if afford else "Yeterli para yok")
	fp = Fixture.footprint(d, gx, gz, placing["rot"])
	var ghost: Node3D = placing["ghost"]
	ghost.position = Vector3(gx + fp["fw"] * 0.5, 0.03, gz + fp["fd"] * 0.5)
	ghost.rotation.y = placing["rot"] * PI / 2.0
	var ok_col := Color(0.35, 0.82, 0.6, 0.55) if placing["ok"] else Color(0.9, 0.3, 0.3, 0.55)
	var tiles := []
	for t in fp["tiles"]: tiles.append([t, ok_col])
	if ["display", "register", "depot"].has(d["kind"]):
		for t in fp["access"]: tiles.append([t, Color(0.38, 0.7, 1.0, 0.45)])
	if d["kind"] == "register": tiles.append([fp["back"][0], Color(0.95, 0.7, 0.24, 0.5)])
	overlays.set_marks(tiles)
	placing_changed.emit()

func rotate_placement() -> void:
	if placing.is_empty(): return
	placing["rot"] = (int(placing["rot"]) + 1) % 4
	var fp := Fixture.footprint(placing["def"], placing["x"], placing["z"], placing["rot"])
	update_placement(int(placing["x"]) + int(fp["fw"] / 2), int(placing["z"]) + int(fp["fd"] / 2))

func confirm_placement(keep := false) -> bool:
	if placing.is_empty() or not placing["ok"]:
		return false
	var d: Dictionary = placing["def"]
	var mv: Fixture = placing["moving"]
	if mv:
		for t in mv.fp["tiles"]: grid.fixture[grid.idx(t.x, t.y)] = 0
		mv.place(placing["x"], placing["z"], placing["rot"])
		for t in mv.fp["tiles"]: grid.fixture[grid.idx(t.x, t.y)] = mv.uid
		mv.visible = true
		grid.version += 1
		layout_changed()
		cancel_placement(true)
		return true
	money -= d["cost"]; stats["other"] += int(d["cost"])
	var f := add_fixture(d, placing["x"], placing["z"], placing["rot"])
	float_text(f.center() + Vector3(0, float(f.model["height"]) + 0.3, 0), "−" + Cfg.fmt_money(d["cost"]), Cfg.TERRA)
	if keep and money >= d["cost"]:
		update_placement(int(placing["x"]), int(placing["z"]))
	else:
		cancel_placement(true)
		select({"kind": "fixture", "obj": f})
	return true

func cancel_placement(done := false) -> void:
	if placing.is_empty(): return
	if placing["moving"] and not done: placing["moving"].visible = true
	placing["ghost"].queue_free()
	placing = {}
	overlays.set_marks([])
	placing_changed.emit()

func sell_fixture(f: Fixture) -> void:
	var refund := int(f.def["cost"] * 0.5)
	money += refund
	float_text(f.center() + Vector3(0, 1.8, 0), "+" + Cfg.fmt_money(refund), Cfg.GOOD)
	remove_fixture(f)
	select({})

func assign_slot(f: Fixture, i: int, pid: String) -> void:
	var s: Dictionary = f.slots[i]
	if s["pid"] != "" and s["stock"] > 0: backstock[s["pid"]] += int(s["stock"])
	s["pid"] = pid; s["stock"] = 0; s["claimed"] = 0
	for st in staff:
		if st.task != null and st.task["kind"] == "restock" and st.task["fixture"] == f and st.task["slot"] == i: st.cancel_task(self)
	f.refresh(self)
	changed.emit()

func set_price(pid: String, p: int) -> void:
	prices[pid] = clampi(p, 1, 999)
	refresh_all()
	changed.emit()

func order(pid: String, qty: int, is_auto := false) -> bool:
	var p := DB.product(pid)
	var room := depot_capacity() - backstock_total() - incoming_total()
	if room <= 0:
		alert("depofull", "box", ("Depo dolu: otomatik sipariş (%s) verilemedi. Depo rafı ekle." % p["name"]) if is_auto else "Depo dolu — sipariş verilemedi. Depo rafı ekleyin.", "warn", null, 120.0 if is_auto else 45.0)
		return false
	qty = mini(qty, room)
	var cost: int = qty * int(p["cost"])
	if money < cost:
		alert("nomoney", "wallet", "Sipariş için yeterli nakit yok.", "bad")
		return false
	money -= cost
	stats["purchases"] += cost
	var eta := abs_minutes() + 50.0
	if clock + 50.0 >= Cfg.DAY_CLOSE: eta = (day + 1) * 1440.0 + Cfg.DAY_OPEN + 20.0
	orders.append({"pid": pid, "qty": qty, "eta": eta})
	changed.emit()
	return true

# ------------------------------------------------------------------ staff
func roll_candidates() -> void:
	candidates.clear()
	for role in ["stocker", "cashier", "stocker"]:
		var skill := 0.85 + randf() * 0.35
		var base: int = DB.ROLE_WAGE[role]
		candidates.append({"role": role, "name": Cfg.NAMES.pick_random(), "wage": int(round(base * (0.8 + skill * 0.3) / 10.0)) * 10, "skill": skill})

func hire(c: Dictionary, free := false) -> Staff:
	var s := Staff.new()
	agents_node.add_child(s)
	s.setup_staff(c["role"], c["name"], c["wage"], c["skill"])
	s.position = Vector3(grid.layout["doors"][0] + 0.5, 0.02, grid.front_z() + 0.5)
	staff.append(s)
	if not free:
		candidates.erase(c)
		float_text(s.position + Vector3(0, 2.2, 0), "%s işe başladı" % DB.ROLE_LABEL[c["role"]], Cfg.TEAL)
	changed.emit()
	return s

func fire(s: Staff) -> void:
	if s.role == "owner": return
	s.cancel_task(self)
	for f in fixtures: if f.cashier == s: f.cashier = null
	staff.erase(s)
	s.queue_free()
	if selection.get("obj") == s: select({})
	changed.emit()

func find_restock_task(st: Staff, threshold: float) -> Variant:
	var depots := fixtures.filter(func(f): return f.def["kind"] == "depot")
	if depots.is_empty(): return null
	var best = null
	for f in fixtures:
		if not f.is_display(): continue
		for i in f.slots.size():
			var s: Dictionary = f.slots[i]
			if s["pid"] == "" or s["claimed"]: continue
			var ratio: float = float(s["stock"]) / f.cap()
			if ratio >= threshold or int(backstock.get(s["pid"], 0)) <= 0: continue
			var d := st.position.distance_to(f.center())
			if best == null or ratio < best["ratio"] - 0.1 or (absf(ratio - best["ratio"]) <= 0.1 and d < best["d"]):
				best = {"f": f, "i": i, "ratio": ratio, "d": d}
	if best == null: return null
	var bf: Fixture = best["f"]
	var slot: Dictionary = bf.slots[best["i"]]
	slot["claimed"] = st.id
	depots.sort_custom(func(a, b): return a.center().distance_to(st.position) < b.center().distance_to(st.position))
	st.has_goal = false
	return {"kind": "restock", "fixture": bf, "slot": best["i"], "pid": slot["pid"], "qty": mini(bf.cap() - int(slot["stock"]), 16), "depot": depots[0], "phase": "to_depot"}

func find_clean_task(st: Staff) -> Variant:
	var free := litter.filter(func(l): return not l["claimed"])
	if free.is_empty(): return null
	free.sort_custom(func(a, b): return Vector2(a["tile"].x - st.position.x, a["tile"].y - st.position.z).length() < Vector2(b["tile"].x - st.position.x, b["tile"].y - st.position.z).length())
	free[0]["claimed"] = st.id
	st.has_goal = false
	return {"kind": "clean", "litter": free[0], "phase": "go"}

# ------------------------------------------------------------------ litter
func drop_litter(t: Vector2i) -> void:
	if not grid.is_interior(t.x, t.y) or litter.size() > 30: return
	for l in litter: if l["tile"] == t: return
	var n := overlays.litter_mesh()
	n.position = Vector3(t.x + randf_range(0.25, 0.75), 0.02, t.y + randf_range(0.25, 0.75))
	litter.append({"tile": t, "node": n, "claimed": 0})

func remove_litter(L: Dictionary) -> void:
	L["node"].queue_free()
	litter.erase(L)

# ------------------------------------------------------------------ sales & visits
func sale(c: Customer, total: int) -> void:
	money += total
	stats["revenue"] += total
	totals["revenue"] += total
	for b in c.basket: stats["sold"][b["pid"]] = int(stats["sold"].get(b["pid"], 0)) + 1
	var at: Vector3 = c.register.center() + Vector3(0, 1.9, 0) if c.register else c.position + Vector3(0, 2.0, 0)
	float_text(at, "+" + Cfg.fmt_money(total), Color("1a7f5a"))

func record_visit(c: Customer, paid: bool) -> void:
	stats["mood_n"] += 1; stats["mood_sum"] += c.mood
	rating += (c.mood / 20.0 - rating) * 0.045
	if paid:
		stats["served"] += 1; totals["served"] += 1
		if c.mood >= 60: stats["happy"] += 1; totals["happy"] += 1
	else:
		stats["lost"] += 1

func float_text(pos: Vector3, text: String, col: Color) -> void:
	overlays.float_text(pos, text, col)

# ------------------------------------------------------------------ spawning
func _attract() -> float:
	var a := 0.55 + (rating / 5.0) * 0.75
	if upgrades.has("neon"): a *= 1.45 if hour() > 18.0 else 1.15
	if upgrades.has("tente"): a *= 1.1
	if stage >= 1: a *= 1.3
	return a

func _spawn_walker(anywhere := false) -> void:
	var c := Customer.new()
	agents_node.add_child(c)
	c.setup_customer(null, false, self)
	var from_left := randf() < 0.5
	var z := Cfg.SIDEWALK_Z0 + randi() % 3
	var x := 0 if from_left else Cfg.MAP_W - 1
	if anywhere: x = 1 + randi() % (Cfg.MAP_W - 2)
	if not grid.walkable(x, z):
		c.queue_free(); return
	c.position = Vector3(x + 0.5, 0.02, z + 0.5)
	c.exit_x = Cfg.MAP_W - 1 if from_left else 0
	c.state = "walkby"
	var ez := z
	if not grid.walkable(c.exit_x, ez): ez = Cfg.SIDEWALK_Z0
	c.go_to(self, Vector2i(c.exit_x, ez))
	customers.append(c)

func _spawn_shopper() -> void:
	var h := hour()
	var pool := DB.ARCHETYPES.filter(func(a): return a["stage"] <= stage)
	var tot := 0.0
	for a in pool: tot += DB.curve(a, h)
	var r := randf() * tot
	var arch: Dictionary = pool[-1]
	for a in pool:
		r -= DB.curve(a, h)
		if r <= 0.0: arch = a; break
	var c := Customer.new()
	agents_node.add_child(c)
	c.setup_customer(arch, true, self)
	var from_left := randf() < 0.5
	var z := Cfg.SIDEWALK_Z0 + randi() % 3
	var x := 0 if from_left else Cfg.MAP_W - 1
	if not grid.walkable(x, z):
		c.queue_free(); return
	c.position = Vector3(x + 0.5, 0.02, z + 0.5)
	c.exit_x = 0 if randf() < 0.5 else Cfg.MAP_W - 1
	var doors: Array = grid.layout["doors"]
	var best: int = doors[0]
	for d in doors: if absi(d - x) < absi(best - x): best = d
	c.door_x = best
	c.state = "to_door"
	c.go_to(self, Vector2i(c.door_x, grid.interior().end.y))
	customers.append(c)

func _demand(h: float) -> float:
	var pool := DB.ARCHETYPES.filter(func(a): return a["stage"] <= stage)
	var s := 0.0
	for a in pool: s += DB.curve(a, h)
	return s / pool.size()

# ------------------------------------------------------------------ main loop
func _process(real_dt: float) -> void:
	real_dt = clampf(real_dt, 0.0, 0.1)
	real_time += real_dt
	var running := not paused and not day_ended_flag
	if running:
		var total := real_dt * speed
		var steps := ceili(total / (1.0 / 30.0))
		for i in steps: tick(total / steps)
	var view_dt := real_dt * speed if running else 0.0
	for a in customers + staff: a.sync_view(view_dt, real_time)
	sky.set_time(hour())
	var cam_dir := -rig.cam.global_transform.basis.z
	var agent_pos := []
	for a in customers + staff: agent_pos.append(a.position)
	shop.update(real_dt, cam_dir, rig.far_factor(), agent_pos, sky.night)
	street.update(view_dt if running else 0.0, sky.night, van["x"], van["state"] != "idle")
	_heat_acc += real_dt
	if _heat_acc > 0.4:
		_heat_acc = 0.0
		if heat_on: overlays.update_heat(grid)
		var sel = selection.get("obj")
		overlays.set_queue_line(sel.queue_slots if (sel is Fixture and sel.def["kind"] == "register") else [])
	_update_selection_visual()
	for f in fixtures:
		for l in f.model["lights"]: l.light_energy = 0.6 + sky.night * 0.8

func tick(dt: float) -> void:
	var prev := clock
	clock += dt * Cfg.MIN_PER_SEC
	grid.occupancy.fill(0)
	for a in customers + staff:
		var t: Vector2i = a.tile()
		if grid.in_bounds(t.x, t.y): grid.occupancy[grid.idx(t.x, t.y)] = mini(255, grid.occupancy[grid.idx(t.x, t.y)] + 1)
	for c in customers:
		if not c.shopper: continue
		var t: Vector2i = c.tile()
		if grid.is_interior(t.x, t.y): grid.traffic[grid.idx(t.x, t.y)] += dt
	var h := hour()
	_walk_acc += dt * 0.35
	while _walk_acc > 1.0:
		_walk_acc -= randf() * 2.0
		if customers.size() < 50: _spawn_walker()
	if is_open():
		_spawn_acc += dt * 0.34 * _demand(h) * _attract()
		while _spawn_acc > 1.0:
			_spawn_acc -= 1.0
			if customers.size() < 60 + stage * 20: _spawn_shopper()
	for c in customers: c.update(dt, self)
	for s in staff: s.update(dt, self)
	for i in range(customers.size() - 1, -1, -1):
		var c: Customer = customers[i]
		if c.removed:
			customers.remove_at(i)
			if selection.get("obj") == c: select({})
			c.queue_free()
	_update_van(dt)
	var due := orders.filter(func(o): return o["eta"] <= abs_minutes())
	if due.size() > 0 and van["state"] == "idle":
		van["cargo"] = due
		orders = orders.filter(func(o): return not due.has(o))
		van["state"] = "arriving"; van["x"] = -32.0
	_auto_acc += dt * Cfg.MIN_PER_SEC
	if _auto_acc > 30.0:
		_auto_acc = 0.0
		var stocked_n := maxi(1, unlocked_products().filter(func(p): return is_stocked(p["id"])).size())
		var fair := maxi(8, int(depot_capacity() / stocked_n * 1.4))
		if clock < Cfg.DAY_CLOSE - 60:
			for p in unlocked_products():
				var pid: String = p["id"]
				if not auto[pid] or not is_stocked(pid): continue
				var have := int(backstock[pid]) + incoming(pid)
				var target := mini(fair, maxi(12, int(round(shelf_cap(pid) * 1.2))))
				if have < target * 0.5: order(pid, ceili((target - have) / 6.0) * 6, true)
	_status_acc += dt
	if _status_acc > 0.25:
		_status_acc = 0.0
		_update_statuses()
	if prev < Cfg.DAY_CLOSE and clock >= Cfg.DAY_CLOSE:
		alert("closing", "wait", "Saat 22:00 — dükkân kapanıyor. Son müşteriler çıkınca gün sonu raporu gelecek.", "info")
	if clock >= Cfg.DAY_CLOSE and (customers_inside() == 0 or clock > Cfg.DAY_CLOSE + 50): end_day()

func _update_statuses() -> void:
	for f in fixtures:
		var k := ""
		if f.is_display():
			var assigned: Array = f.slots.filter(func(s): return s["pid"] != "")
			if assigned.any(func(s): return s["stock"] == 0): k = "empty"
			elif assigned.any(func(s): return float(s["stock"]) / f.cap() < 0.34 and int(backstock.get(s["pid"], 0)) == 0): k = "low"
			elif assigned.size() < f.slots.size(): k = "noproduct"
			if k == "empty":
				var s: Dictionary = assigned.filter(func(x): return x["stock"] == 0)[0]
				var no_back := int(backstock.get(s["pid"], 0)) == 0
				if not no_back and not has_role("stocker"):
					alert("needstocker", "nocashier", "Kemal Usta kasadan ayrılamıyor, raflar boş kalıyor. Personel panelinden (H) reyon görevlisi al.", "bad", f.center(), 70.0)
				alert("empty:" + s["pid"], "empty", "%s rafta bitti%s" % [DB.product(s["pid"])["name"], " ve depoda da yok — sipariş ver!" if no_back else "."], "bad" if no_back else "warn", f.center(), 50.0)
		elif f.def["kind"] == "register":
			if f.cashier == null or not staff.has(f.cashier): k = "nocashier"
			elif f.queue.size() >= 4: k = "queue"
			if f.queue.size() >= 5: alert("queue", "queue", "Kasada %d kişilik kuyruk! Kasaya yakın düzen ve hızlı ödeme bekleme süresini düşürür." % f.queue.size(), "warn", f.center(), 60.0)
		elif f.def["kind"] == "depot":
			var cap := depot_capacity()
			if cap > 0 and backstock_total() + incoming_total() < cap * 0.08: k = "box"
		f.set_status(k)

func _update_van(dt: float) -> void:
	var park: float = grid.layout["doors"][0] - 0.5
	match van["state"]:
		"arriving":
			van["x"] += maxf(1.2, (park - van["x"]) * 1.4) * dt
			if van["x"] >= park: van["x"] = park; van["state"] = "unloading"; van["t"] = 2.5
		"unloading":
			van["t"] -= dt
			if van["t"] <= 0.0:
				var n := 0
				var overflow := 0
				var cap := depot_capacity()
				for o in van["cargo"]:
					var room := maxi(0, cap - backstock_total())
					var put := mini(room, int(o["qty"]))
					backstock[o["pid"]] += put; n += put
					if int(o["qty"]) - put > 0: overflow += (int(o["qty"]) - put) * int(DB.product(o["pid"])["cost"])
				if overflow > 0:
					money += overflow; stats["purchases"] -= overflow
					alert("overflow", "box", "Depo doldu, %s tutarında mal iade edildi." % Cfg.fmt_money(overflow), "warn")
				van["cargo"] = []
				depot_changed()
				float_text(Vector3(park, 3.2, 19.5), "Teslimat +%d birim" % n, Cfg.BLUE)
				van["state"] = "leaving"
				changed.emit()
		"leaving":
			van["x"] += minf(9.0, 1.5 + (van["x"] - park) * 1.2) * dt
			if van["x"] > Cfg.MAP_W + 32: van["state"] = "idle"

func end_day() -> void:
	if day_ended_flag: return
	for c in customers:
		if c.inside():
			if c.register: c.register.queue.erase(c)
			c.finish_visit(self, false)
	var wages := wages_per_day()
	money -= wages + rent() + utilities()
	stats["wages"] = wages; stats["rent"] = rent(); stats["utilities"] = utilities()
	var costs: int = stats["purchases"] + wages + rent() + utilities() + stats["other"]
	history.append({"day": day, "revenue": stats["revenue"], "costs": costs, "profit": stats["revenue"] - costs, "rating": rating})
	day_ended_flag = true
	day_ended.emit({"day": day, "stats": stats, "costs": costs, "rating": rating, "money": money})

func start_next_day() -> void:
	day += 1
	clock = float(Cfg.DAY_OPEN)
	stats = new_stats()
	day_ended_flag = false
	roll_candidates()
	for i in grid.traffic.size(): grid.traffic[i] *= 0.5
	changed.emit()

func buy_upgrade(id: String) -> bool:
	var u: Dictionary = DB.UPGRADES.filter(func(x): return x["id"] == id)[0]
	if upgrades.has(id) or money < u["cost"]: return false
	money -= u["cost"]; stats["other"] += int(u["cost"])
	upgrades[id] = true
	if id == "pos":
		for f in fixtures: if f.model["pos_device"]: f.model["pos_device"].visible = true
	if id == "neon" or id == "tente": shop.build(grid.layout, stage, upgrades)
	float_text(rig.target + Vector3(0, 3, 0), u["name"] + "!", Cfg.VIOLET)
	changed.emit()
	return true

func expand() -> bool:
	var e = expansion()
	if e == null or not can_expand(): return false
	money -= e["cost"]; stats["other"] += int(e["cost"])
	apply_stage(e["to"])
	alert("expanded", "star", "Mahalle Marketi açıldı! Yeni reyonlar, manav ve aile alışverişçileri seni bekliyor.", "good", null, 0.0)
	float_text(Vector3(18, 5, 12), "MAHALLE MARKETİ!", Cfg.TERRA)
	stage_changed.emit()
	changed.emit()
	return true

func apply_stage(n: int) -> void:
	stage = n
	if n >= 1: street.remove_for_market()
	grid.apply_layout(Cfg.STAGE_LAYOUTS[n])
	_apply_env_blocks()
	for f in fixtures:
		for t in f.fp["tiles"]: grid.fixture[grid.idx(t.x, t.y)] = f.uid
	shop.build(Cfg.STAGE_LAYOUTS[n], n, upgrades)
	grid.version += 1
	layout_changed()
	roll_candidates()
	var r: Rect2i = Cfg.STAGE_LAYOUTS[n]["interior"]
	rig.focus(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5 + 1.0, 28.0)

# ------------------------------------------------------------------ picking & selection
func ground_at(screen: Vector2) -> Variant:
	var from := rig.cam.project_ray_origin(screen)
	var dir := rig.cam.project_ray_normal(screen)
	if absf(dir.y) < 1e-4: return null
	var t := -from.y / dir.y
	if t < 0.0: return null
	return from + dir * t

func pick(screen: Vector2) -> Dictionary:
	var out := {}
	var best := 34.0
	for a in customers + staff:
		if not a.visible: continue
		for hgt in [0.5, 1.0]:
			var p: Vector3 = a.position + Vector3(0, hgt, 0)
			if rig.cam.is_position_behind(p): continue
			var d := rig.cam.unproject_position(p).distance_to(screen)
			if d < best: best = d; out["agent"] = a
	var g = ground_at(screen)
	if g != null:
		out["ground"] = g
		var t := Vector2i(floori(g.x), floori(g.z))
		if not out.has("agent"):
			for l in litter:
				if l["tile"] == t: out["litter"] = l
			if grid.in_bounds(t.x, t.y):
				var uid := grid.fixture[grid.idx(t.x, t.y)]
				if uid > 0:
					for f in fixtures: if f.uid == uid: out["fixture"] = f
		if not out.has("fixture") and not out.has("agent"):
			# tall fixtures: test their projected body too
			for f in fixtures:
				var c: Vector3 = f.center() + Vector3(0, float(f.model["height"]) * 0.55, 0)
				if rig.cam.unproject_position(c).distance_to(screen) < 40.0: out["fixture"] = f
	return out

func select(sel: Dictionary) -> void:
	selection = sel
	selection_changed.emit()

func _update_selection_visual() -> void:
	var o = selection.get("obj")
	if o == null or not is_instance_valid(o):
		overlays.select_ring.visible = false
		return
	overlays.select_ring.visible = true
	if o is Fixture:
		overlays.select_ring.position = o.center() + Vector3(0, 0.06, 0)
		var s: float = maxf(o.fp["fw"], o.fp["fd"]) * 0.95
		overlays.select_ring.scale = Vector3(s, 0.2, s)
	else:
		overlays.select_ring.position = o.position + Vector3(0, 0.06, 0)
		overlays.select_ring.scale = Vector3(1, 0.2, 1)
