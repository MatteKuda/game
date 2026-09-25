class_name Game
extends Node3D
## Orchestrates the simulation (fixed 1/30 s steps) and the 3D world, from the büfe to the AVM.

signal alert_added(a: Dictionary)
signal selection_changed()
signal day_ended(report: Dictionary)
signal changed()
signal placing_changed()
signal stage_changed()
signal floor_changed()
signal mall_changed()
signal expanded(stage: int)

var grid := Grid.new(0)
var floors: Array = [] # Array[Grid] — index = floor
var view_floor := 0
var sky: DaySky
var street: Street
var shop: ShopShell
var overlays: Overlays
var rig: CameraRig
var fixtures_node: Node3D
var agents_node: Node3D
var props_node: Node3D # campaign props, puddles, wet signs
var mall = null # Mall
var mall_shell = null # MallShell

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
var orders: Array = [] # [{pid, qty, eta, urgent}]
## the wholesaler's single daily round comes right after opening; the auto-order is placed at 18:00
const DELIVERY_AT := Cfg.DAY_OPEN + 5
const AUTO_ORDER_AT := 18 * 60
const URGENT_FEE := 1.25
var last_sold := {} # yesterday's units per product
## mahalle olayları waiting for the player's decision
signal events_changed()
var neighbor_events: Array = []
var match_night := {}
var inspection_at := 0.0
var praise_until := 0.0
var outage_until := 0.0 # crisis: power cut (fewer shoppers)
var strike_day := -1 # crisis: deliveries on this day come in the afternoon
var _next_event_at := 1440.0 + Cfg.DAY_OPEN + 60.0
var neighborhood := Neighborhood.new()
var calendar := Calendar.new()
var product_log: Array = [] # last 14 days: {day, sold, missed, expensive, oos, price, cost}
signal quests_changed()
var quests := Quests.new()
var rival := Rival.new()
var branches := Branches.new()
var vouchers := {} # fixture id -> free builds won from quests
## economy: wholesale prices creep up every week; customers' price expectations follow
var cost_mul := 1.0
var price_mul := 1.0 # inflation already passed on through "update all prices"
var _next_hike_day := 8
var loan := {} # {amount, total, left, daily}
var cat: ShopCat
var manual_orders := 0
var scenario := {} # {id, start, ...} for the other neighbourhoods; empty = career
signal announced(text: String)
signal achievement(id: String)
signal scenario_result(result: String)
var _next_announce := 1440.0 + Cfg.DAY_OPEN + 40.0
var _ach_acc := 0.0
var undo_stack: Array = [] # [{kind: place|move|sell, ...}]
var style := {"wall": 0, "floor": 0, "awning": 0}
var fixtures: Array = []
var customers: Array = []
var staff: Array = []
var litter: Array = [] # [{tile, lvl, node, claimed}]
var puddles: Array = [] # [{id, tile, lvl, node, sign, claimed, dry, age}]
var upgrades := {}
var campaigns := {}
var discounts: Array = []
var multi: Array = [] # "3 al 2 öde" products
var backstock_fresh := {} # bakery pid -> 0..1
var evening_bakery := false # bakery goods -40% after 19:00
var _fresh_acc := 0.0
var stats := {}
var totals := {"served": 0, "happy": 0, "revenue": 0, "visitors": 0, "theft": 0, "credit_paid": 0, "requests": 0}
var history: Array = []
var candidates: Array = []
var alerts: Array = []
var selection := {} # {kind, obj}
var overlay_mode := "none" # none | heat | security
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
var _puddle_id := 1
var _promoter: CharacterView

static func new_stats() -> Dictionary:
	return {"revenue": 0, "served": 0, "happy": 0, "lost": 0, "lost_crowd": 0, "lost_queue": 0, "visitors": 0,
		"abandoned": 0, "impulse": 0, "purchases": 0, "wages": 0, "rent": 0, "utilities": 0, "other": 0,
		"missed": {}, "expensive": {}, "sold": {}, "mood_sum": 0.0, "mood_n": 0,
		"theft": 0, "theft_count": 0, "shrink": 0, "theft_seen": 0, "alarms": 0, "caught": 0, "caught_guard": 0,
		"slips": 0, "spills": 0, "mall_income": 0, "mall_visitors": 0,
		"stale": 0, "stale_cost": 0, "spoiled": 0, "spoiled_cost": 0, "multi": 0, "endcap": 0, "wc": 0, "no_wc": 0,
		"credit": 0, "credit_paid": 0, "credit_lost": 0, "buyers": {}, "oos_min": {}, "loan": 0, "rival_lost": 0, "mood_why": {}}

func _ready() -> void:
	stats = new_stats()
	floors = [grid]
	sky = DaySky.new(); add_child(sky)
	street = Street.new(); add_child(street); street.build()
	grid.apply_layout(Cfg.STAGE_LAYOUTS[0])
	_apply_env_blocks()
	shop = ShopShell.new(); add_child(shop); shop.build(Cfg.STAGE_LAYOUTS[0], 0, upgrades)
	fixtures_node = Node3D.new(); add_child(fixtures_node)
	agents_node = Node3D.new(); add_child(agents_node)
	props_node = Node3D.new(); add_child(props_node)
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
	for pid in ["cips", "biskuvi", "cikolata", "kola", "ayran", "simit", "ekmek"]: backstock[pid] = 24
	hire({"role": "owner", "name": "Kemal Usta", "wage": 0, "skill": 1.1}, true)
	roll_candidates()
	refresh_all()
	calendar.tomorrow = calendar.roll_weather(2)
	sky.set_weather(calendar.weather)
	neighborhood.generate(self)
	neighborhood.start_day(self)
	quests.refill(self)
	cat = ShopCat.new(); add_child(cat); cat.build(); cat.start_day(self)
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

func floor_grid(l: int) -> Grid: return floors[l] if l < floors.size() else grid

# ------------------------------------------------------------------ alerts
func alert(key: String, icon: String, text: String, severity := "warn", focus = null, cooldown := 45.0) -> void:
	if real_time - float(_alert_cd.get(key, -1e9)) < cooldown: return
	_alert_cd[key] = real_time
	var a := {"id": _alert_id, "key": key, "icon": icon, "text": text, "severity": severity, "focus": focus, "t": real_time}
	_alert_id += 1
	alerts.push_front(a)
	if alerts.size() > 5: alerts.pop_back()
	alert_added.emit(a)
	if severity == "bad": GameAudio.play("bad", -8.0, 1.0)
	elif severity == "good": GameAudio.play("good", -8.0, 1.0)

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
	for s in staff: if s.role == r and s.present: return true
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
## electricity, water and gas: a base for the building plus every fridge, freezer and oven
func utilities() -> int:
	var u := float(DB.STAGES[stage]["utilities"])
	var pw := 0.0
	for f in fixtures: pw += float(f.def.get("power", 0))
	if upgrades.has("gunes"): pw *= 0.6
	return int(round((u + pw) * cost_mul))
func power_breakdown() -> Array:
	var out := {}
	for f in fixtures:
		var w := float(f.def.get("power", 0))
		if w > 0.0: out[f.def["name"]] = float(out.get(f.def["name"], 0.0)) + w * (0.6 if upgrades.has("gunes") else 1.0) * cost_mul
	var arr := []
	for k in out: arr.append([k, int(round(out[k]))])
	arr.sort_custom(func(a, b): return a[1] > b[1])
	return arr
func cost_of(pid: String) -> int:
	var c := float(DB.product(pid)["cost"]) * cost_mul
	if upgrades.has("ozelmarka") and DB.PRIVATE.has(pid): c *= 0.8
	return maxi(1, int(round(c)))
## what shoppers consider a normal price today (rises with inflation)
func ref_price(pid: String) -> float: return float(DB.product(pid)["base"]) * cost_mul
func patience_mul() -> float:
	var plants := fixtures.filter(func(f): return f.def["kind"] == "plant" and f.lvl == 0).size()
	return (1.0 + minf(0.25, plants * 0.06)) * (1.2 if upgrades.has("sadakat") else 1.0)
func tolerance_bonus() -> float: return 0.05 if upgrades.has("etiket") else 0.0
func impulse_mul() -> float: return (2.0 if campaigns.has("kasaonu") else 1.0) * (1.2 if upgrades.has("isik") else 1.0)
func is_discounted(pid: String) -> bool: return campaigns.has("indirim") and discounts.has(pid)
func is_multi(pid: String) -> bool: return campaigns.has("ucal") and multi.has(pid)
func evening_sale(pid: String) -> bool: return evening_bakery and DB.BAKERY.has(pid) and clock >= 19 * 60
func effective_price(pid: String) -> int:
	var p: int = prices[pid]
	if is_discounted(pid): p = int(round(p * 0.85))
	if evening_sale(pid): p = int(round(p * 0.6))
	return p
func is_match_time() -> bool: return match_night.get("day", -1) == day and clock >= NeighborEvents.MATCH_FROM and clock < Cfg.DAY_CLOSE
func demand_mul(pid: String) -> float:
	return calendar.demand(day, hour(), pid) * (2.5 if is_match_time() and (pid == "kola" or pid == "cips") else 1.0) * (1.8 if is_discounted(pid) else 1.0) * (1.5 if is_multi(pid) else 1.0) * (1.5 if campaigns.has("tadim") and (pid == "simit" or pid == "ekmek" or pid == "peynir") else 1.0)
func has_cold_room() -> bool: return fixtures.any(func(f): return f.def.get("cold", false))
## freshness of the bakery goods a customer would pick from this slot
func slot_fresh(s: Dictionary) -> float: return float(s.get("fresh", 1.0))
func has_oven() -> bool:
	return fixtures.any(func(f): return f.def["kind"] == "oven") and has_role("baker")
func sign_near(f: Fixture) -> bool:
	for s in fixtures:
		if s.def["kind"] == "sign" and s.center().distance_to(f.center()) <= float(s.def.get("radius", 5.0)): return true
	return false
func _dist2(f: Fixture, t: Vector2i) -> float: return Vector2(f.center().x - t.x - 0.5, f.center().z - t.y - 0.5).length()
func bin_near(t: Vector2i, l := 0) -> bool:
	for f in fixtures:
		if f.def["kind"] == "bin" and f.lvl == l and _dist2(f, t) <= 3.0: return true
	return false
func plant_near(t: Vector2i) -> bool:
	for f in fixtures:
		if f.def["kind"] == "plant" and f.lvl == 0 and _dist2(f, t) <= 2.6: return true
	return false
func litter_near(t: Vector2i, r: float, l := 0) -> bool:
	for L in litter:
		if L["lvl"] == l and Vector2(L["tile"].x - t.x, L["tile"].y - t.y).length() <= r: return true
	return false
func room_door(f: Fixture) -> Vector2i:
	var a := f.access()
	return a[a.size() / 2]
## a point inside a walled room, just behind its door
func room_inside(f: Fixture) -> Vector3:
	var p: Vector3 = f.global_transform * Vector3(0, 0, 0.1)
	if f.def["kind"] == "break" and f.model.has("seat_pt"): p = f.global_transform * (f.model["seat_pt"] as Vector3)
	return Vector3(p.x, f.lvl * Cfg.FLOOR_H + 0.02, p.z)
func nearest_access(f: Fixture, from: Vector3) -> Vector2i:
	if f.def.has("room"): return room_door(f)
	var g := floor_grid(f.lvl)
	var acc: Array = f.access().filter(func(t): return g.walkable(t.x, t.y))
	acc.sort_custom(func(a, b): return Vector2(a.x + 0.5 - from.x, a.y + 0.5 - from.z).length() < Vector2(b.x + 0.5 - from.x, b.y + 0.5 - from.z).length())
	return acc[0] if acc.size() > 0 else f.access()[0]
func nearest_walkable(t: Vector2i, l := 0) -> Vector2i:
	var g := floor_grid(l)
	if g.walkable(t.x, t.y): return t
	for r in range(1, 4):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if g.walkable(t.x + dx, t.y + dz) and g.region[g.idx(t.x + dx, t.y + dz)] != Grid.R_OUT: return Vector2i(t.x + dx, t.y + dz)
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
	if expansion() == null or Demo.stage_locked(stage): return false
	if scenario.get("id", "") == "serbest": return money >= expansion()["cost"]
	for g in goals(): if not g["done"]: return false
	return true

# ------------------------------------------------------------------ floors & connectors
func set_view_floor(f: int) -> void:
	if stage < 3: f = 0
	f = clampi(f, 0, floors.size() - 1)
	if f == view_floor: return
	view_floor = f
	rig.set_floor_y(f * Cfg.FLOOR_H)
	cancel_placement()
	floor_changed.emit()

func pick_connector(from_l: int, to_l: int, pos: Vector3, prefer_lift := false) -> Variant:
	if mall == null: return null
	var best = null
	var best_d := 1e9
	for cs in mall.connectors:
		if cs["broken"]: continue
		var d: Dictionary = cs["def"]
		var conn = null
		if d["from"][0] == from_l and d["to"][0] == to_l:
			conn = {"id": d["id"], "kind": d["kind"], "board": d["from"][1], "board_lvl": from_l, "land": d["to"][1], "land_lvl": to_l, "time": d["time"]}
		elif d.get("bidir", false) and d["to"][0] == from_l and d["from"][0] == to_l:
			conn = {"id": d["id"], "kind": d["kind"], "board": d["to"][1], "board_lvl": from_l, "land": d["from"][1], "land_lvl": to_l, "time": d["time"]}
		if conn == null: continue
		var extra := 0.0
		if d["kind"] == "elevator": extra = -8.0 if prefer_lift else 4.0
		elif d["kind"] == "stairs": extra = 12.0 if prefer_lift else 3.0
		var dist: float = Vector2(conn["board"].x + 0.5 - pos.x, conn["board"].y + 0.5 - pos.z).length() + extra
		if dist < best_d: best_d = dist; best = conn
	return best

func connector_working(id: String) -> bool: return mall == null or mall.connector_working(id)
func on_ride(_a, c: Dictionary) -> void:
	if c["kind"] == "elevator" and mall_shell != null: mall_shell.lift_to(c["board_lvl"], c["land_lvl"])

# ------------------------------------------------------------------ fixtures
func add_fixture(d: Dictionary, x: int, z: int, r: int, l := 0) -> Fixture:
	var f := Fixture.new()
	fixtures_node.add_child(f)
	f.setup(d, x, z, r, l)
	fixtures.append(f)
	var g := floor_grid(l)
	if not f.noblock():
		for t in f.fp["tiles"]: g.fixture[g.idx(t.x, t.y)] = f.uid
	g.version += 1
	if upgrades.has("pos") and f.model["pos_device"]: f.model["pos_device"].visible = true
	layout_changed()
	return f

func remove_fixture(f: Fixture) -> void:
	var g := floor_grid(f.lvl)
	if not f.noblock():
		for t in f.fp["tiles"]: g.fixture[g.idx(t.x, t.y)] = 0
	fixtures.erase(f)
	for s in f.slots:
		if s["pid"] != "" and s["stock"] > 0: backstock[s["pid"]] += int(s["stock"])
	for c in f.queue.duplicate(): c.pick_register(self)
	if f.cashier: f.cashier.register = null
	for s in staff:
		var t = s.task
		if t == null: continue
		if (t["kind"] == "restock" and (t["fixture"] == f or t["depot"] == f)) or (t["kind"] == "table" and t["table"] == f) or (t["kind"] == "rest" and t["spot"] == f) or (t["kind"] == "bake" and t["oven"] == f):
			s.cancel_task(self)
	if mall != null:
		for v in mall.visitors:
			if not v.seat.is_empty() and v.seat["table"] == f: v.seat = {}
	f.queue_free()
	g.version += 1
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
	for f in fixtures:
		if f.def["kind"] == "camera": _camera_cover(f)
	Staff.room_bonus = 1.06 if fixtures.any(func(f): return f.def["id"] == "molaodasi") else 1.0
	refresh_all()
	changed.emit()

func _camera_cover(f: Fixture) -> void:
	f.covers.clear()
	var g := floor_grid(f.lvl)
	var c := f.center()
	var dir := Vector2(sin(f.rot * PI / 2.0), cos(f.rot * PI / 2.0))
	var R: float = f.def.get("radius", 6.0)
	var tall := {}
	for o in fixtures:
		if o.lvl == f.lvl and (o.def["kind"] == "depot" or (o.def["kind"] == "display" and o.def["display"] != "produce" and o.def["display"] != "basket")): tall[o.uid] = true
	for z in range(floori(c.z - R), ceili(c.z + R) + 1):
		for x in range(floori(c.x - R), ceili(c.x + R) + 1):
			if not g.in_bounds(x, z): continue
			var v := Vector2(x + 0.5 - c.x, z + 0.5 - c.z)
			var d := v.length()
			if d > R: continue
			if d > 0.8 and v.normalized().dot(dir) < cos(PI * 0.42): continue
			var reg := g.region[g.idx(x, z)]
			if (reg == Grid.R_IN or reg == Grid.R_MALL) and _los(g, c.x, c.z, x + 0.5, z + 0.5, tall): f.covers[g.idx(x, z)] = true

## tall shelving blocks a ceiling camera's view of the aisle behind it
func _los(g: Grid, ax: float, az: float, bx: float, bz: float, tall: Dictionary) -> bool:
	var n := ceili(Vector2(bx - ax, bz - az).length() / 0.25)
	var target := g.idx(floori(bx), floori(bz))
	for i in range(1, n):
		var k := float(i) / n
		var t := g.idx(floori(ax + (bx - ax) * k), floori(az + (bz - az) * k))
		if t != target and tall.has(g.fixture[t]): return false
	return true

func refresh_all() -> void:
	for f in fixtures: f.refresh(self)
	depot_changed()

func stock_changed(f: Fixture) -> void: f.refresh(self)

func depot_changed() -> void:
	var cap := depot_capacity()
	var fill := minf(1.0, float(backstock_total()) / cap) if cap > 0 else 0.0
	for f in fixtures:
		if f.def["kind"] == "depot": f.set_depot_fill(fill)

const NEEDS_ACCESS := ["display", "register", "depot", "break", "oven", "carts", "table", "play", "bench", "wc"]

func validate(d: Dictionary, x: int, z: int, r: int, ignore: Fixture, l := -1) -> Dictionary:
	if l < 0: l = view_floor
	var fp := Fixture.footprint(d, x, z, r)
	var g := floor_grid(l)
	var ign_uid := ignore.uid if ignore else -999
	var zone := DB.zone(d)
	var in_zone := func(t: Vector2i) -> bool:
		if not g.in_bounds(t.x, t.y): return false
		var reg := g.region[g.idx(t.x, t.y)]
		return (zone != "mall" and reg == Grid.R_IN and l == 0) or (zone != "store" and reg == Grid.R_MALL)
	for t in fp["tiles"]:
		if not in_zone.call(t): return {"ok": false, "reason": "AVM ortak alanına (koridor / yemek katı) yerleştirilmeli" if zone == "mall" else "Dükkânın içine yerleştirilmeli"}
		if d.get("noblock", false):
			for f in fixtures:
				if f != ignore and f.def["id"] == d["id"] and f.lvl == l and f.gx == t.x and f.gz == t.y: return {"ok": false, "reason": "Burada zaten bir tane var"}
			continue
		var occ := g.fixture[g.idx(t.x, t.y)]
		if occ != 0 and occ != ign_uid: return {"ok": false, "reason": "Başka bir eşyanın üstüne gelemez"}
		if g.reserved[g.idx(t.x, t.y)]: return {"ok": false, "reason": "Kapı / geçiş önü boş kalmalı"}
	if d.has("max") and ignore == null:
		var maxc: int = d["max"][stage]
		if fixtures.filter(func(f): return f.def["id"] == d["id"]).size() >= maxc: return {"ok": false, "reason": "Bu aşamada en fazla %d adet" % maxc}
	if d.get("noblock", false): return {"ok": true, "reason": ""}
	if d["kind"] == "gate":
		var near := false
		for dx in grid.layout["doors"]:
			if absi(dx - x) <= 2 and absi(grid.front_z() - z) <= 1: near = true
		if not near: return {"ok": false, "reason": "Alarm kapısı bir giriş kapısının hemen yanına kurulmalı"}
	var needs := NEEDS_ACCESS.has(d["kind"])
	var tile_set := {}
	for t in fp["tiles"]: tile_set[g.idx(t.x, t.y)] = true
	var acc_free := func(t: Vector2i) -> bool:
		if not in_zone.call(t) or tile_set.has(g.idx(t.x, t.y)): return false
		var o := g.fixture[g.idx(t.x, t.y)]
		return o == 0 or o == ign_uid
	if d.has("room") and not acc_free.call(fp["access"][fp["access"].size() / 2]):
		return {"ok": false, "reason": "Oda kapısının önü boş olmalı"}
	if needs:
		var any := false
		for t in fp["access"]: if acc_free.call(t): any = true
		if not any: return {"ok": false, "reason": "Önü açık olmalı (erişim alanı)"}
	if d["kind"] == "register":
		if not acc_free.call(fp["access"][0]): return {"ok": false, "reason": "Kasanın müşteri tarafı boş olmalı"}
		if not d.get("self", false) and not acc_free.call(fp["back"][0]): return {"ok": false, "reason": "Kasiyerin arkada duracağı yer yok"}
	# reachability with the tentative placement
	var saved := []
	if ignore and ignore.lvl == l:
		for t in ignore.fp["tiles"]: saved.append([g.idx(t.x, t.y), g.fixture[g.idx(t.x, t.y)]]); g.fixture[g.idx(t.x, t.y)] = 0
	for t in fp["tiles"]: saved.append([g.idx(t.x, t.y), g.fixture[g.idx(t.x, t.y)]]); g.fixture[g.idx(t.x, t.y)] = -1
	var start := Vector2i(grid.layout["doors"][0], grid.front_z())
	if l == 1 and mall != null: start = MallDB.CONNECTORS[0]["to"][1]
	elif l == 0 and zone == "mall": start = Vector2i(MallDB.ENTRANCES[0], 15)
	var reach := g.reachable_from(start)
	var res := {"ok": true, "reason": ""}
	for f in fixtures:
		if f == ignore or f.lvl != l or f.noblock() or f.def["kind"] == "gate" or not NEEDS_ACCESS.has(f.def["kind"]): continue
		var ok := false
		for t in f.access(): if g.walkable(t.x, t.y) and reach[g.idx(t.x, t.y)]: ok = true
		# fixtures in the other zone are reached from a different start: check from both if needed
		if not ok and l == 0 and DB.zone(f.def) != zone and zone != "any": continue
		if not ok: res = {"ok": false, "reason": "%s ulaşılamaz hâle gelir" % f.def["name"]}; break
		if f.def["kind"] == "register" and not f.def.get("self", false):
			var b: Vector2i = f.back()[0]
			if not reach[g.idx(b.x, b.y)]: res = {"ok": false, "reason": "Kasiyer yeri ulaşılamaz hâle gelir"}; break
	if res["ok"] and needs:
		var ok2 := false
		for t in fp["access"]: if g.walkable(t.x, t.y) and reach[g.idx(t.x, t.y)]: ok2 = true
		if not ok2: res = {"ok": false, "reason": "Bu konuma yol yok"}
	if res["ok"] and l == 0 and zone != "mall":
		for dx in grid.layout["doors"]:
			if not reach[g.idx(dx, grid.front_z())]: res = {"ok": false, "reason": "Kapılardan biri kapanıyor"}
	for i in range(saved.size() - 1, -1, -1): g.fixture[saved[i][0]] = saved[i][1]
	return res

# ------------------------------------------------------------------ placement (build mode)
func start_placement(id: String, moving: Fixture = null) -> void:
	cancel_placement()
	var d := DB.fixture(id)
	if moving and moving.lvl != view_floor: set_view_floor(moving.lvl)
	var ghost := Node3D.new()
	var m := Props.build(d)
	ghost.add_child(m["root"])
	add_child(ghost)
	_ghostify(ghost)
	placing = {"def": d, "rot": moving.rot if moving else 0, "ghost": ghost, "moving": moving, "x": -1, "z": -1, "ok": false, "reason": "Bir konum seç",
		"old": [moving.gx, moving.gz, moving.rot] if moving else [], "copy": []}
	if moving: moving.visible = false
	placing_changed.emit()

func _ghostify(n: Node) -> void:
	for c in Art._all(n):
		if c is MeshInstance3D: (c as MeshInstance3D).transparency = 0.35
		elif c is Label3D: (c as Label3D).modulate.a = 0.6
		elif c is Light3D: c.visible = false

func update_placement(x: int, z: int) -> void:
	if placing.is_empty(): return
	var d: Dictionary = placing["def"]
	var fp := Fixture.footprint(d, x, z, placing["rot"])
	var gx := x - int(fp["fw"] / 2)
	var gz := z - int(fp["fd"] / 2)
	placing["x"] = gx; placing["z"] = gz
	var v := validate(d, gx, gz, placing["rot"], placing["moving"])
	var afford: bool = placing["moving"] != null or money >= d["cost"] or int(vouchers.get(d["id"], 0)) > 0
	placing["ok"] = v["ok"] and afford
	placing["reason"] = v["reason"] if not v["ok"] else ("" if afford else "Yeterli para yok")
	fp = Fixture.footprint(d, gx, gz, placing["rot"])
	var ghost: Node3D = placing["ghost"]
	var y := view_floor * Cfg.FLOOR_H
	ghost.position = Vector3(gx + fp["fw"] * 0.5, y + 0.03, gz + fp["fd"] * 0.5)
	ghost.rotation.y = placing["rot"] * PI / 2.0
	var ok_col := Cfg.place_color(placing["ok"])
	var tiles := []
	for t in fp["tiles"]: tiles.append([t, ok_col])
	if NEEDS_ACCESS.has(d["kind"]):
		for t in fp["access"]: tiles.append([t, Color(0.38, 0.7, 1.0, 0.45)])
	if d["kind"] == "register" and not d.get("self", false): tiles.append([fp["back"][0], Color(0.95, 0.7, 0.24, 0.5)])
	if d["kind"] == "camera" or d["kind"] == "sign":
		var tmp := {"def": d, "rot": placing["rot"]}
		for t in _preview_cover(d, gx, gz, placing["rot"]): tiles.append([t, Color(0.48, 0.35, 0.88, 0.25) if d["kind"] == "camera" else Color(0.95, 0.7, 0.24, 0.2)])
	overlays.set_marks(tiles, y)
	placing_changed.emit()

func _preview_cover(d: Dictionary, x: int, z: int, r: int) -> Array:
	var out := []
	var g := floor_grid(view_floor)
	var R: float = d.get("radius", 5.0)
	var c := Vector2(x + 0.5, z + 0.5)
	var dir := Vector2(sin(r * PI / 2.0), cos(r * PI / 2.0))
	for zz in range(floori(c.y - R), ceili(c.y + R) + 1):
		for xx in range(floori(c.x - R), ceili(c.x + R) + 1):
			if not g.in_bounds(xx, zz): continue
			var v := Vector2(xx + 0.5, zz + 0.5) - c
			if v.length() > R: continue
			if d["kind"] == "camera" and v.length() > 0.8 and v.normalized().dot(dir) < cos(PI * 0.42): continue
			var reg := g.region[g.idx(xx, zz)]
			if reg == Grid.R_IN or reg == Grid.R_MALL: out.append(Vector2i(xx, zz))
	return out

func rotate_placement() -> void:
	if placing.is_empty(): return
	placing["rot"] = (int(placing["rot"]) + 1) % 4
	var fp := Fixture.footprint(placing["def"], placing["x"], placing["z"], placing["rot"])
	update_placement(int(placing["x"]) + int(fp["fw"] / 2), int(placing["z"]) + int(fp["fd"] / 2))

func confirm_placement(keep := false) -> bool:
	if placing.is_empty() or not placing["ok"]: return false
	var d: Dictionary = placing["def"]
	var mv: Fixture = placing["moving"]
	if mv:
		var g := floor_grid(mv.lvl)
		if not mv.noblock():
			for t in mv.fp["tiles"]: g.fixture[g.idx(t.x, t.y)] = 0
		mv.place(placing["x"], placing["z"], placing["rot"])
		if not mv.noblock():
			for t in mv.fp["tiles"]: g.fixture[g.idx(t.x, t.y)] = mv.uid
		mv.visible = true
		g.version += 1
		push_undo({"kind": "move", "fixture": mv, "x": placing["old"][0], "z": placing["old"][1], "rot": placing["old"][2]})
		layout_changed()
		cancel_placement(true)
		return true
	var free := int(vouchers.get(d["id"], 0)) > 0
	if free: vouchers[d["id"]] = int(vouchers[d["id"]]) - 1
	else: money -= d["cost"]; stats["other"] += int(d["cost"])
	var f := add_fixture(d, placing["x"], placing["z"], placing["rot"], view_floor)
	float_text(f.center() + Vector3(0, float(f.model["height"]) + 0.3, 0), "Bedava!" if free else "−" + Cfg.fmt_money(d["cost"]), Cfg.GOOD if free else Cfg.TERRA)
	push_undo({"kind": "place", "fixture": f, "cost": 0 if free else int(d["cost"]), "voucher": free})
	var cps: Array = placing.get("copy", [])
	for i in mini(cps.size(), f.slots.size()):
		if cps[i] != "": f.slots[i]["pid"] = cps[i]
	if not cps.is_empty(): f.refresh(self)
	GameAudio.play("place", -2.0)
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
	overlays.set_marks([], 0.0)
	placing_changed.emit()

## place another one just like this: same fixture, rotation and product assignment
func copy_fixture(f: Fixture) -> void:
	start_placement(f.def["id"])
	placing["rot"] = f.rot
	placing["copy"] = f.slots.map(func(s): return s["pid"])

func sell_fixture(f: Fixture) -> void:
	var refund := int(f.def["cost"] * 0.5)
	push_undo({"kind": "sell", "id": f.def["id"], "x": f.gx, "z": f.gz, "rot": f.rot, "lvl": f.lvl, "refund": refund, "slots": f.slots.map(func(s): return s["pid"])})
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

func next_delivery() -> float: return (day + 1) * 1440.0 + DELIVERY_AT

func order(pid: String, qty: int, is_auto := false, urgent := false) -> bool:
	var p := DB.product(pid)
	var room := depot_capacity() - backstock_total() - incoming_total()
	if room <= 0:
		alert("depofull", "box", ("Depo dolu: otomatik sipariş (%s) verilemedi. Depo rafı ekle ya da yavaş satan ürünü azalt." % p["name"]) if is_auto else "Depo dolu — sipariş verilemedi. Depo rafı ekleyin.", "warn", null, 120.0 if is_auto else 45.0)
		return false
	qty = mini(qty, room)
	var cost: int = int(round(qty * cost_of(pid) * (URGENT_FEE if urgent else 1.0)))
	if money < cost:
		alert("nomoney", "wallet", "Sipariş için yeterli nakit yok.", "bad")
		return false
	money -= cost
	stats["purchases"] += cost
	if not is_auto: manual_orders += 1
	# regular orders ride on tomorrow morning's round; urgent ones come by a separate van within the hour
	var eta := next_delivery()
	if strike_day == day + 1: eta += 7.0 * 60.0
	if urgent and clock + 60.0 < Cfg.DAY_CLOSE: eta = abs_minutes() + 60.0
	for o in orders:
		if o["pid"] == pid and o["eta"] == eta:
			o["qty"] += qty; changed.emit(); return true
	orders.append({"pid": pid, "qty": qty, "eta": eta, "urgent": urgent})
	changed.emit()
	return true

# ------------------------------------------------------------------ staff
func roll_candidates() -> void:
	candidates.clear()
	var roles := ["stocker", "cashier", "cleaner", "technician", "security", "baker", "deli", "stocker"].filter(func(r): return DB.ROLE_STAGE[r] <= stage)
	if stage == 0: roles = ["stocker", "stocker", "cashier"]
	for role in roles.slice(0, 6):
		var skill := 0.85 + randf() * 0.35
		var base: int = DB.ROLE_WAGE[role]
		var tr := ""
		if randf() < 0.7: tr = DB.TRAITS.keys().pick_random()
		var w := base * (0.8 + skill * 0.3) * (0.85 if tr == "keyfi" else (0.9 if tr == "dalgin" else 1.0))
		candidates.append({"role": role, "name": Cfg.NAMES.pick_random(), "wage": int(round(w / 10.0)) * 10, "skill": skill, "trait": tr})

func hire(c: Dictionary, free := false, shift := "full") -> Staff:
	var s := Staff.new()
	agents_node.add_child(s)
	s.setup_staff(c["role"], c["name"], c["wage"], c["skill"], shift, c.get("trait", ""))
	s.raise_day = day
	s.position = Vector3(grid.layout["doors"][0] + 0.5, 0.02, grid.front_z() + 0.5)
	staff.append(s)
	if not free:
		candidates.erase(c)
		float_text(s.position + Vector3(0, 2.2, 0), "%s işe başladı" % DB.ROLE_LABEL[c["role"]], Cfg.TEAL)
	changed.emit()
	return s

func set_shift(s: Staff, sh: String) -> void:
	s.set_shift(sh); changed.emit()

func fire(s: Staff) -> void:
	if s.role == "owner": return
	s.cancel_task(self)
	for f in fixtures: if f.cashier == s: f.cashier = null
	staff.erase(s)
	s.queue_free()
	if is_selected(s): select({})
	changed.emit()

func find_restock_task(st: Staff, threshold: float, only: Fixture = null) -> Variant:
	var depots := fixtures.filter(func(f): return f.def["kind"] == "depot")
	if depots.is_empty(): return null
	var best = null
	for f in fixtures:
		if not f.is_display() or (only != null and f != only): continue
		# the deli counter is the usta's: other staff only fill it when there is no usta at all
		if only == null and f.def.get("staffed", false) and has_role("deli"): continue
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
	st.has_goal = false; st.dest = {}
	return {"kind": "restock", "fixture": bf, "slot": best["i"], "pid": slot["pid"], "qty": mini(bf.cap() - int(slot["stock"]), 16), "depot": depots[0], "phase": "to_depot"}

func find_clean_task(st: Staff) -> Variant:
	var free := litter.filter(func(l): return not l["claimed"] and (l["lvl"] == 0 or st.role == "cleaner"))
	if free.is_empty(): return null
	var key := func(l) -> float: return (20.0 if l["lvl"] != st.lvl else 0.0) + Vector2(l["tile"].x - st.position.x, l["tile"].y - st.position.z).length()
	free.sort_custom(func(a, b): return key.call(a) < key.call(b))
	free[0]["claimed"] = st.id
	st.has_goal = false; st.dest = {}
	return {"kind": "clean", "litter": free[0], "phase": "go"}

func find_mop_task(st: Staff) -> Variant:
	var free := puddles.filter(func(p): return not p["claimed"] and p["dry"] <= 0.0 and (p["lvl"] == 0 or st.role == "cleaner"))
	if free.is_empty(): return null
	free.sort_custom(func(a, b): return Vector2(a["tile"].x - st.position.x, a["tile"].y - st.position.z).length() < Vector2(b["tile"].x - st.position.x, b["tile"].y - st.position.z).length())
	free[0]["claimed"] = st.id
	st.has_goal = false; st.dest = {}
	return {"kind": "mop", "puddle": free[0], "phase": "go"}

func find_table_task(st: Staff) -> Variant:
	for f in fixtures:
		if f.def["kind"] == "table" and f.dirty and not f.claimed:
			f.claimed = st.id; st.has_goal = false; st.dest = {}
			return {"kind": "table", "table": f, "phase": "go"}
	return null

func find_bake_task(st: Staff) -> Variant:
	var o = null
	for f in fixtures:
		if f.def["kind"] == "oven" and not f.claimed: o = f; break
	if o == null: return null
	var want := func(pid: String) -> bool: return is_stocked(pid) and int(backstock.get(pid, 0)) < maxi(8, int(round(shelf_cap(pid) * 0.8)))
	if not DB.BAKERY.any(func(b): return calendar.product_active(day, b) and want.call(b)) or depot_capacity() - backstock_total() < 4: return null
	if clock > 19 * 60: return null # no point baking what will be thrown away tonight
	o.claimed = st.id; st.has_goal = false; st.dest = {}
	return {"kind": "bake", "oven": o, "phase": "go"}

func find_repair_task(st: Staff) -> Variant:
	if mall == null: return null
	for c in mall.connectors:
		if not c["broken"] or int(c.get("claimed", 0)) != 0: continue
		c["claimed"] = st.id
		if c["repair_t"] > 0.0: c["repair_t"] = 0.0 # our own technician takes over from the contractor
		var e: Array = c["def"]["from"]
		st.has_goal = false; st.dest = {}
		return {"kind": "repair", "conn": c, "tile": e[1], "lvl": e[0], "phase": "go"}
	return null

func find_wc_task(st: Staff) -> Variant:
	for f in fixtures:
		if f.def["kind"] == "wc" and f.dirty and not f.claimed:
			f.claimed = st.id; st.has_goal = false; st.dest = {}
			return {"kind": "wc", "wc": f, "phase": "go"}
	return null

## one visitor used the toilets; every dozen uses they need a scrub
func use_wc(f: Fixture) -> void:
	f.set_meta("uses", int(f.get_meta("uses", 0)) + 1)
	stats["wc"] += 1
	if int(f.get_meta("uses")) >= 10 and not f.dirty:
		f.dirty = true
		(f.model["dirt"] as Node3D).visible = true
		f.set_status("dirty")
		alert("wcdirty", "dirty", "Tuvaletler kirlendi. Temizlik görevlisi siler; yoksa ziyaretçi keyfi düşer.", "warn", f.center(), 90.0)

func clean_wc(f: Fixture) -> void:
	f.dirty = false; f.claimed = 0; f.set_meta("uses", 0)
	(f.model["dirt"] as Node3D).visible = false
	f.set_status("")

func find_chase_task(st: Staff) -> Variant:
	for c in customers:
		if c.suspect and c.state in ["to_exit", "to_shelf", "browse"]:
			var taken := false
			for o in staff:
				if o.task != null and o.task["kind"] == "chase" and o.task["target"] == c: taken = true
			if not taken:
				st.has_goal = false; st.dest = {}
				return {"kind": "chase", "target": c, "t": 0.0}
	return null

# ------------------------------------------------------------------ security
func watch_info(t: Vector2i, l := 0) -> Dictionary:
	var p := Vector3(t.x + 0.5, l * Cfg.FLOOR_H + 0.02, t.y + 0.5)
	var watcher = null
	for s in staff:
		if s.present and s.lvl == l and s.position.distance_to(p) < (5.5 if s.role == "security" else 3.2) * (1.4 if s.persona == "dikkatli" else 1.0): watcher = s; break
	var g := floor_grid(l)
	var cam := false
	for f in fixtures:
		if f.def["kind"] == "camera" and f.lvl == l and f.covers.has(g.idx(t.x, t.y)): cam = true; break
	return {"staff": watcher, "camera": cam}

func suspect_seen(c: Customer, text: String) -> void:
	stats["theft_seen"] += 1
	alert("suspect", "sneak", text + (" Güvenlik peşine düştü." if has_role("security") else " Güvenlik görevlisi olsaydı yakalanabilirdi."), "bad", c.position, 20.0)
	var guards := staff.filter(func(s): return s.role == "security" and s.present and (s.task == null or s.task["kind"] != "chase"))
	guards.sort_custom(func(a, b): return a.position.distance_to(c.position) < b.position.distance_to(c.position))
	if guards.size() > 0:
		var g: Staff = guards[0]
		if g.task != null: g.cancel_task(self)
		g.task = {"kind": "chase", "target": c, "t": 0.0}; g.dest = {}

func thief_at_door(c: Customer) -> String:
	var door := Vector2i(c.door_x, grid.front_z())
	var gate = null
	for f in fixtures:
		if f.def["kind"] == "gate" and absi(f.gx - door.x) <= 2 and absi(f.gz - door.y) <= 1: gate = f; break
	if gate != null and randf() < 0.85:
		gate.alarm_t = 3.5
		GameAudio.play("alarm", -6.0, 2.0)
		stats["alarms"] += 1
		c.think("alarm", 3.0)
		for s in staff:
			if s.role == "security" and s.present and s.position.distance_to(c.position) < 9.0:
				stats["caught_guard"] += 1
				return "caught"
		for pid in c.stolen: backstock[pid] = int(backstock.get(pid, 0)) + 1
		c.stolen.clear(); c.view.set_basket_items([])
		alert("alarm", "alarm", "Alarm kapısı öttü! Hırsız ürünleri bırakıp kaçtı.", "warn", c.position, 10.0)
		return "alarm"
	return "escaped"

func record_theft(c: Customer) -> void:
	if c.stolen.is_empty(): return
	var value := 0
	for pid in c.stolen: value += int(prices[pid])
	stats["theft"] += value; stats["theft_count"] += c.stolen.size(); totals["theft"] += value
	if c.suspect: alert("theft", "sneak", "Şüpheli %s değerinde ürünle kaçtı! Alarm kapısı ve güvenlik görevlisi caydırır." % Cfg.fmt_money(value), "bad", c.position, 10.0)
	c.stolen.clear()

func record_shrink(pid: String) -> void:
	stats["shrink"] += int(prices[pid]); stats["theft_count"] += 1

func security_mask(l: int) -> PackedByteArray:
	var g := floor_grid(l)
	var out := PackedByteArray(); out.resize(g.w * g.h)
	for i in out.size():
		var r := g.region[i]
		if r == Grid.R_IN or r == Grid.R_MALL: out[i] = 1
	for f in fixtures:
		if f.def["kind"] == "camera" and f.lvl == l:
			for i in f.covers: out[i] = 2
	for s in staff:
		if not s.present or s.lvl != l: continue
		var R := 5 if s.role == "security" else 3
		for dz in range(-R, R + 1):
			for dx in range(-R, R + 1):
				var x := floori(s.position.x) + dx
				var z := floori(s.position.z) + dz
				if not g.in_bounds(x, z) or Vector2(dx, dz).length() > R: continue
				var i := g.idx(x, z)
				if out[i] > 0: out[i] = maxi(out[i], 3)
	return out

# ------------------------------------------------------------------ litter, spills, tables
func drop_litter(t: Vector2i, l := 0) -> void:
	var g := floor_grid(l)
	if not g.in_bounds(t.x, t.y): return
	var reg := g.region[g.idx(t.x, t.y)]
	if not (reg == Grid.R_IN or reg == Grid.R_MALL) or litter.size() > 40: return
	for L in litter: if L["tile"] == t and L["lvl"] == l: return
	var n := overlays.litter_mesh()
	n.position = Vector3(t.x + randf_range(0.25, 0.75), l * Cfg.FLOOR_H + 0.02, t.y + randf_range(0.25, 0.75))
	litter.append({"tile": t, "lvl": l, "node": n, "claimed": 0})

func remove_litter(L: Dictionary) -> void:
	L["node"].queue_free()
	litter.erase(L)

func puddle_at(t: Vector2i, l := 0) -> Variant:
	for p in puddles:
		if p["lvl"] == l and p["tile"] == t: return p
	return null

func spill_at(t: Vector2i, l := 0, reason := "Yere bir şey döküldü") -> void:
	var g := floor_grid(l)
	if not g.in_bounds(t.x, t.y): return
	var reg := g.region[g.idx(t.x, t.y)]
	if not (reg == Grid.R_IN or reg == Grid.R_MALL) or puddles.size() >= 8 or puddle_at(t, l) != null: return
	var n := overlays.puddle_mesh()
	n.position = Vector3(t.x + 0.5, l * Cfg.FLOOR_H + 0.03, t.y + 0.5)
	props_node.add_child(n)
	var P := {"id": _puddle_id, "tile": t, "lvl": l, "node": n, "sign": null, "claimed": 0, "dry": 0.0, "age": 0.0}
	_puddle_id += 1
	puddles.append(P)
	g.extra_cost[g.idx(t.x, t.y)] += 3.0
	g.version += 1
	stats["spills"] += 1
	var can_mop := has_role("cleaner") or has_role("stocker") or l == 0
	alert("spill", "slip", "%s: zemin ıslak!%s" % [reason, " Temizlik görevlisi yolda." if has_role("cleaner") else (" Boştaki personel paspas yapacak." if can_mop else "")], "warn", n.position, 25.0)

func place_wet_sign(P: Dictionary) -> void:
	if P["sign"] != null: return
	var s := overlays.wet_sign_mesh()
	s.position = Vector3(P["tile"].x + 0.85, P["lvl"] * Cfg.FLOOR_H + 0.02, P["tile"].y + 0.2)
	s.rotation.y = randf() * 3.0
	props_node.add_child(s)
	P["sign"] = s

func mopped(P: Dictionary) -> void:
	(P["node"] as Node3D).visible = false
	P["dry"] = 25.0
	var g := floor_grid(P["lvl"])
	var i := g.idx(P["tile"].x, P["tile"].y)
	g.extra_cost[i] = maxf(0.0, g.extra_cost[i] - 1.5)
	g.version += 1

func dirty_table(f: Fixture) -> void:
	f.dirty = true
	if f.model.get("trays"): f.model["trays"].visible = true
	var n := fixtures.filter(func(x): return x.def["kind"] == "table" and x.dirty).size()
	if n >= 3: alert("tables", "dirty", "%d masa kirli. Temizlik görevlisi olmadan yemek katı dağılır." % n, "warn", f.center(), 60.0)

func clean_table(f: Fixture) -> void:
	f.dirty = false; f.claimed = 0
	if f.model.get("trays"): f.model["trays"].visible = false

# ------------------------------------------------------------------ campaigns
func start_campaign(id: String, products := []) -> bool:
	var c: Dictionary = DB.CAMPAIGNS.filter(func(x): return x["id"] == id)[0]
	if campaigns.has(id): return false
	if money < c["cost"]:
		alert("nomoney", "wallet", "Kampanya için yeterli nakit yok.", "bad"); return false
	if (id == "indirim" or id == "ucal") and products.is_empty(): return false
	money -= c["cost"]; stats["other"] += int(c["cost"])
	campaigns[id] = true
	if id == "indirim": discounts = products.slice(0, 3)
	if id == "ucal": multi = products.slice(0, 3)
	refresh_all()
	_campaign_visuals()
	float_text(rig.target + Vector3(0, 3, 0), c["name"] + "!", Color("d6333a"))
	changed.emit()
	return true

func _campaign_visuals() -> void:
	for n in props_node.get_children():
		if n.has_meta("campaign"): n.queue_free()
	if _promoter: _promoter.visible = false
	var L := grid.layout
	if campaigns.has("brosur"):
		if _promoter == null:
			_promoter = CharacterView.new(); add_child(_promoter)
			_promoter.setup({"body": "rogue", "skin": Color("e8b894"), "hair": Color("2b1d16"), "top": Color("d6333a"), "bottom": Color("2b3a55"), "shoes": Color("2a2a2e"), "accent": Cfg.MUSTARD})
			var flyer := Art.box(_promoter, Vector3(0.2, 0.26, 0.03), Art.mat(Cfg.CREAM), Vector3(0.24, 0.8, 0.25), 0.01)
			flyer.rotation.x = -0.5
		_promoter.visible = true
		_promoter.position = Vector3(float(L["doors"][0]) - 1.2, 0.02, grid.interior().end.y + 1.1)
		_promoter.rotation.y = 0.4
		_promoter.play("pay")
	if campaigns.has("kasaonu"):
		for f in fixtures:
			if f.def["kind"] != "register": continue
			var st := Node3D.new(); st.set_meta("campaign", true); props_node.add_child(st)
			Art.box(st, Vector3(0.5, 1.1, 0.35), Art.mat(Color("6c4ab6"), 0.5), Vector3(0, 0.55, 0), 0.04)
			var cols := [Color("e5484d"), Color("f2b33d"), Color("2fae7a"), Color("61b3ff")]
			for i in 12: Art.box(st, Vector3(0.1, 0.05, 0.08), Art.mat(cols[i % 4], 0.4), Vector3(-0.16 + (i % 4) * 0.1, 0.5 + (i / 4) * 0.22, 0.2), 0.01)
			Art.label(st, "ŞEKER", 28, Color.WHITE, Vector3(0, 1.0, 0.18), 0.0, "display")
			var a: Vector2i = f.access()[f.access().size() - 1]
			st.position = Vector3(a.x + 0.5 + (0.0 if f.rot % 2 else 0.6), 0.02, a.y + 0.5 + (0.6 if f.rot % 2 else 0.0))
	if campaigns.has("tadim"):
		for f in fixtures:
			if f.def["kind"] != "oven": continue
			var t := Node3D.new(); t.set_meta("campaign", true); props_node.add_child(t)
			Art.box(t, Vector3(1.0, 0.8, 0.5), Art.mat(Color("faf6ea"), 0.6), Vector3(0, 0.4, 0), 0.03)
			for i in 6: Art.box(t, Vector3(0.08, 0.04, 0.08), Art.mat(Color("f2d9a0"), 0.8), Vector3(-0.3 + i * 0.12, 0.83, 0), 0.01)
			Art.label(t, "TADIM", 40, Cfg.TERRA, Vector3(0, 0.5, 0.26), 0.0, "display")
			var a2: Vector2i = f.access()[0]
			t.position = Vector3(a2.x + 0.5, 0.02, a2.y + 1.3)
			break
	shop.set_campaign(not campaigns.is_empty())

# ------------------------------------------------------------------ sales & visits
func sale(c: Customer, total: int) -> void:
	money += total
	stats["revenue"] += total
	totals["revenue"] += total
	for b in c.basket: stats["sold"][b["pid"]] = int(stats["sold"].get(b["pid"], 0)) + 1
	if c.register == null or c.register.lvl == view_floor: GameAudio.play("cash", -9.0, 0.25)
	var at: Vector3 = c.register.center() + Vector3(0, 1.9, 0) if c.register else c.position + Vector3(0, 2.0, 0)
	float_text(at, "+" + Cfg.fmt_money(total), Color("1a7f5a"))

## the till: a normal sale, or a line in the veresiye defteri for a regular
func checkout(c: Customer) -> void:
	var total := c.spent()
	for b in c.basket:
		var by: Dictionary = stats["buyers"].get(b["pid"], {})
		by[c.arch["id"]] = int(by.get(c.arch["id"], 0)) + 1
		stats["buyers"][b["pid"]] = by
	if neighborhood.at_till(self, c, total) == "credit":
		for b in c.basket: stats["sold"][b["pid"]] = int(stats["sold"].get(b["pid"], 0)) + 1
		var at: Vector3 = c.register.center() + Vector3(0, 1.9, 0) if c.register else c.position + Vector3(0, 2.0, 0)
		float_text(at, "Deftere yazıldı " + Cfg.fmt_money(total), Cfg.VIOLET)
		GameAudio.play("ui", -8.0)
		return
	sale(c, total)

## the deli counter only serves when its usta stands behind it
func deli_staffed(f: Fixture) -> bool:
	var s = f.cashier
	return s != null and is_instance_valid(s) and staff.has(s) and s.present and s.role == "deli" and s.at_register(f)

func record_visit(c: Customer, paid: bool) -> void:
	stats["mood_n"] += 1; stats["mood_sum"] += c.mood
	rating += (c.mood / 20.0 - rating) * (0.03 if upgrades.has("sadakat") else 0.045)
	if paid:
		stats["served"] += 1; totals["served"] += 1
		if c.mood >= 60: stats["happy"] += 1; totals["happy"] += 1
	else:
		stats["lost"] += 1

func float_text(pos: Vector3, text: String, col: Color) -> void:
	# in the AVM, pop-ups from the floor you are not looking at would float in the wrong place
	if stage >= 3 and rig.far_factor() < 0.5 and floori((pos.y - 0.5) / Cfg.FLOOR_H + 0.25) != view_floor: return
	overlays.float_text(pos, text, col)

# ------------------------------------------------------------------ spawning
# ------------------------------------------------------------------ mahalle olayları
func _update_neighbor_events() -> void:
	var now := abs_minutes()
	if is_open() and now >= _next_event_at and neighbor_events.size() < 2 and clock < 20 * 60:
		var ev := NeighborEvents.roll(self)
		if not ev.is_empty():
			neighbor_events.append(ev); events_changed.emit(); GameAudio.play("bell", -6.0)
		_next_event_at = now + 150.0 + randf() * 150.0
	# a crisis nobody answered happens anyway (the "do nothing" choice)
	for e in neighbor_events.duplicate():
		if e.get("crisis", false) and e["expires"] <= now: answer_event(e["id"], e["choices"].size() - 1)
	var n := neighbor_events.size()
	neighbor_events = neighbor_events.filter(func(e): return e["expires"] > now)
	if neighbor_events.size() != n: events_changed.emit()
	if inspection_at > 0.0 and now >= inspection_at:
		inspection_at = 0.0
		var dirt := litter.filter(func(l): return l["lvl"] == 0).size()
		var empty := 0
		for f in fixtures:
			for s in f.slots:
				if s["pid"] != "" and int(s["stock"]) == 0: empty += 1
		if dirt + empty == 0:
			rating = minf(5.0, rating + 0.15)
			if Progress.unlock("denetim"): achievement.emit("denetim")
			alert("inspect", "star", "Zabıta denetimi: dükkân tertemiz, raflar dolu. Puanın yükseldi!", "good", null, 0.0)
		else:
			var fine := 150 * dirt + 100 * empty
			money -= fine; stats["other"] += fine
			alert("inspect", "angry", "Zabıta denetimi: %d çöp, %d boş raf bölmesi. ₺%d ceza." % [dirt, empty, fine], "bad", null, 0.0)

func answer_event(id: int, choice: int) -> void:
	var ev = null
	for e in neighbor_events: if e["id"] == id: ev = e
	if ev == null or choice >= ev["choices"].size() or ev["choices"][choice].get("disabled", false): return
	neighbor_events.erase(ev)
	var msg := NeighborEvents.resolve(self, ev, choice)
	if msg != "": alert("event%d" % id, "star", msg, "good", null, 0.0)
	events_changed.emit(); changed.emit()

## one evening order for tomorrow's round: a day of sales plus a shelf refill, within the depot
func auto_order() -> void:
	var oven := has_oven()
	# with an oven, keep depot room free for fresh bread instead of filling it with wholesale stock
	var reserve := 24 if oven else 0
	var stocked_n := maxi(1, unlocked_products().filter(func(p): return is_stocked(p["id"]) and not (oven and DB.BAKERY.has(p["id"]))).size())
	var fair := maxi(12, int((depot_capacity() - reserve) / stocked_n * 1.3))
	var lines := []
	# first work out what every product wants, then share the free depot room fairly — ordering
	# one by one used to fill the room with the first products and leave the rest with nothing
	var wants := {}
	var total_need := 0
	for p in unlocked_products():
		var pid: String = p["id"]
		if not auto[pid] or not is_stocked(pid) or (oven and DB.BAKERY.has(pid)): continue # own oven bakes the bread
		var exp := calendar.expected(day + 1, pid)
		if exp <= 0.0: continue # e.g. no pide outside Ramazan
		# demand = what sold plus what people asked for and could not find
		var sold := maxi(int(last_sold.get(pid, 0)), int(stats["sold"].get(pid, 0)) + int(stats["missed"].get(pid, 0)) / 2)
		# floor: one shelf's worth of reserve for proven sellers, two for new products with no history
		var target := mini(int(fair * clampf(exp, 0.5, 2.0)), maxi(shelf_cap(pid) * (2 if sold == 0 else 1), int(round(sold * 1.25 * clampf(exp / maxf(0.2, calendar.expected(day, pid)), 0.3, 3.0)))))
		var need := target - (int(backstock[pid]) + incoming(pid))
		if need >= 4: wants[pid] = need; total_need += need
	var room := depot_capacity() - reserve - backstock_total() - incoming_total()
	var share := minf(1.0, float(room) / maxf(1.0, float(total_need)))
	for pid in wants:
		var q := int(wants[pid] * share) / 6 * 6
		if q < 6 and share < 1.0: q = mini(6, room)
		room = depot_capacity() - reserve - backstock_total() - incoming_total()
		q = mini(q, room)
		if q < 4: continue
		if order(pid, q, true): lines.append("%s ×%d" % [DB.product(pid)["name"], q])
	if not lines.is_empty():
		alert("autoorder", "box", "Yarın sabahki teslimat için otomatik sipariş verildi: %s%s" % [", ".join(lines.slice(0, 5)), "…" if lines.size() > 5 else ""], "info", null, 0.0)

func _attract() -> float:
	var a := 0.55 + (rating / 5.0) * 0.75
	if abs_minutes() < outage_until: a *= 0.6 # power cut: a dark shop looks closed
	if stage == 0: a *= 1.35 # the büfe needs a busier street to be worth playing
	if abs_minutes() < praise_until: a *= 1.2
	if is_match_time(): a *= 1.55 if match_night.get("poster", false) else 1.2
	if upgrades.has("neon"): a *= 1.45 if hour() > 18.0 else 1.15
	if upgrades.has("tente"): a *= 1.1
	if stage >= 1: a *= 1.3
	if stage >= 2: a *= 1.45
	if campaigns.has("brosur"): a *= 1.35
	if cat != null and cat.adopted: a *= 1.04
	a *= float(scenario.get("traffic", 1.0))
	if mall != null:
		a *= 1.0 + minf(0.45, mall.visitors.size() * 0.012)
		if not mall.event.is_empty(): a *= float(mall.event["def"]["store"])
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

func spawn_resident(r: Dictionary) -> void:
	_spawn_shopper(Neighborhood._arch(r["arch"]), r)

func _spawn_shopper(forced := {}, res := {}) -> void:
	var h := hour()
	var arch: Dictionary = forced
	if arch.is_empty():
		var pool := DB.ARCHETYPES.filter(func(a): return a["stage"] <= stage)
		var ws := []
		var tot := 0.0
		var base_t := calendar.traffic(day, h)
		for a in pool:
			var w := DB.curve(a, h) * (1.6 if a["id"] == "haftalik" and upgrades.has("otopark") else 1.0) * (1.5 if a.get("thief", false) and stage >= 2 else 1.0)
			w *= calendar.traffic(day, h, a["id"]) / maxf(0.01, base_t)
			w *= float(scenario.get("arch", {}).get(a["id"], 1.0))
			ws.append(w); tot += w
		var r := randf() * tot
		arch = pool[-1]
		for i in pool.size():
			r -= ws[i]
			if r <= 0.0: arch = pool[i]; break
	if rival.active and randf() < rival.diversion(self, arch["id"], res):
		_spawn_to_rival(arch, res)
		return
	var c := Customer.new()
	agents_node.add_child(c)
	c.setup_customer(arch, true, self, res)
	if arch.get("cart", false) and upgrades.has("otopark"):
		var slot := street.request_car()
		if slot >= 0:
			# arrives by car: hidden until the car has parked, then crosses at the zebra
			c.car_slot = slot; c.state = "in_car"; c.hidden_agent = true
			c.position = Vector3(street.slot_x(slot), 0.02, 30.0)
			c.exit_x = floori(street.slot_x(slot))
			var drs: Array = grid.layout["doors"]
			c.door_x = drs[drs.size() - 1]
			customers.append(c)
			return
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

## a shopper who picked UCUZA today: walks past, crosses at the zebra and goes in over there
func _spawn_to_rival(arch: Dictionary, res := {}) -> void:
	rival.lost_today += 1; stats["rival_lost"] += 1
	var c := Customer.new()
	agents_node.add_child(c)
	c.setup_customer(arch, false, self, res)
	var from_left := randf() < 0.5
	var z := Cfg.SIDEWALK_Z0 + randi() % 3
	var x := 0 if from_left else Cfg.MAP_W - 1
	if not grid.walkable(x, z):
		c.queue_free(); return
	c.position = Vector3(x + 0.5, 0.02, z + 0.5)
	c.state = "walkby"
	c.flags["to_rival"] = true
	c.exit_x = 2
	c.go_to(self, Vector2i(2, Cfg.FAR_WALK_Z0 + 1))
	if not res.is_empty(): c.log_thought("price", "UCUZA'da süt daha ucuzmuş, bugün oradan alayım." if rival.gen == 1 else "NOKTA'da kola daha ucuzmuş, bugün oradan alayım.", self, false)
	customers.append(c)

func _demand(h: float) -> float:
	var pool := DB.ARCHETYPES.filter(func(a): return a["stage"] <= stage and not a.get("thief", false))
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
	var far := rig.far_factor()
	var all: Array = customers + staff
	if mall != null: all += mall.visitors
	for a in all:
		a.sync_view(view_dt, real_time)
		if not (a is Staff and not a.present): a.visible = _agent_visible(a, far) and not a.hidden_agent
	if mall != null: mall.sync_children(view_dt)
	sky.set_time(hour())
	sky.follow(rig.target, real_dt)
	var cam_dir := -rig.cam.global_transform.basis.z
	var agent_pos := []
	for a in all: agent_pos.append(a.position)
	# floor visibility in the AVM: looking at floor 1 hides the ground-floor interior
	var lower_hidden := stage >= 3 and view_floor >= 1 and far < 0.5
	shop.visible = not lower_hidden
	for f in fixtures:
		if f.lvl == 0 and stage >= 3: f.visible = not lower_hidden and not (not placing.is_empty() and placing["moving"] == f)
		elif f.lvl == 1: f.visible = view_floor >= 1 or far > 0.5
	for p in puddles:
		(p["node"] as Node3D).visible = p["dry"] <= 0.0 and (p["lvl"] == view_floor or far > 0.5 or stage < 3)
	shop.update(real_dt, cam_dir, far, agent_pos, sky.night)
	if GameAudio.I:
		var busy := float(customers_inside()) / maxf(1.0, max_inside()) + (float(mall.visitors.size()) / 40.0 if mall != null else 0.0)
		GameAudio.I.weather = calendar.weather
		GameAudio.I.update(real_dt, hour(), busy, paused or not is_open())
	if mall_shell != null: mall_shell.update(real_dt, view_dt, cam_dir, view_floor, far, shop.cutaway, sky.night, agent_pos)
	street.update(view_dt if running else 0.0, sky.night, van["x"], van["state"] != "idle", agent_pos)
	if _promoter and _promoter.visible:
		_promoter.play("pay" if sin(real_time * 0.7) > 0 else "idle")
	_heat_acc += real_dt
	if _heat_acc > 0.4:
		_heat_acc = 0.0
		if overlay_mode == "heat": overlays.update_heat(floor_grid(view_floor), view_floor * Cfg.FLOOR_H)
		elif overlay_mode == "security": overlays.update_security(security_mask(view_floor), floor_grid(view_floor), view_floor * Cfg.FLOOR_H)
		var sel = selection.get("obj")
		overlays.set_queue_line(sel.queue_slots if (sel is Fixture and is_instance_valid(sel) and sel.def["kind"] == "register") else [])
	_update_selection_visual()
	var t := real_time
	for f in fixtures:
		for l in f.model["lights"]: l.light_energy = 0.6 + sky.night * 0.8
		var m: Dictionary = f.model
		if m.get("led"): (m["led"] as StandardMaterial3D).emission_energy_multiplier = 3.0 if sin(t * 4.0) > 0 else 0.3
		if m.get("alarm_light"):
			f.alarm_t = maxf(0.0, f.alarm_t - real_dt)
			(m["alarm_light"] as StandardMaterial3D).emission_energy_multiplier = (5.0 if sin(t * 22.0) > 0 else 0.2) if f.alarm_t > 0.0 else 0.05
		if m.get("belt"):
			m["belt_off"] = float(m.get("belt_off", 0.0)) + view_dt * (0.6 if (f.queue.size() > 0 and f.queue[0].state == "paying") else 0.05)
			(m["belt"] as ShaderMaterial).set_shader_parameter("offset", m["belt_off"])
		if m.get("oven_glow"): (m["oven_glow"] as StandardMaterial3D).emission_energy_multiplier = (2.5 + sin(t * 9.0) * 0.6) if f.baking else 0.6
		if m.get("spin"): (m["spin"] as Node3D).rotation.y = sin(t * 0.6 + f.uid) * 0.7

func _agent_visible(a, far: float) -> bool:
	if far > 0.5 or stage < 3: return true
	if a.riding():
		var c: Dictionary = a.ride["conn"]
		return view_floor == c["board_lvl"] or view_floor == c["land_lvl"]
	if a.lvl == view_floor: return true
	if a.lvl == 0 and not MallDB.FOOTPRINT.has_point(Vector2i(floori(a.position.x), floori(a.position.z))): return true
	return false

func tick(dt: float) -> void:
	var prev := clock
	clock += dt * Cfg.MIN_PER_SEC
	for g in floors: g.occupancy.fill(0)
	var all: Array = customers + staff
	if mall != null: all += mall.visitors
	for a in all:
		if a.riding() or (a is Staff and not a.present): continue
		var g: Grid = floor_grid(a.lvl)
		var t: Vector2i = a.tile()
		if g.in_bounds(t.x, t.y): g.occupancy[g.idx(t.x, t.y)] = mini(255, g.occupancy[g.idx(t.x, t.y)] + 1)
		var reg := g.region[g.idx(t.x, t.y)] if g.in_bounds(t.x, t.y) else 0
		if (reg == Grid.R_IN and a is Customer and a.shopper) or reg == Grid.R_MALL: g.traffic[g.idx(t.x, t.y)] += dt
	var h := hour()
	_walk_acc += dt * 0.35
	while _walk_acc > 1.0:
		_walk_acc -= randf() * 2.0
		if customers.size() < 50: _spawn_walker()
	if is_open():
		_spawn_acc += dt * 0.34 * _demand(h) * _attract() * calendar.traffic(day, h)
		while _spawn_acc > 1.0:
			_spawn_acc -= 1.0
			if customers.size() < 60 + stage * 20: _spawn_shopper()
	_fresh_acc += dt * Cfg.MIN_PER_SEC
	if _fresh_acc >= 5.0:
		var k := _fresh_acc * DB.STALE_RATE
		_fresh_acc = 0.0
		for pid in DB.BAKERY: backstock_fresh[pid] = maxf(0.0, float(backstock_fresh.get(pid, 1.0)) - k)
		for f in fixtures:
			if not f.is_display(): continue
			for sl in f.slots:
				if DB.BAKERY.has(sl["pid"]) and int(sl["stock"]) > 0: sl["fresh"] = maxf(0.0, float(sl.get("fresh", 1.0)) - k)
	if is_open(): neighborhood.update(self)
	cat.maybe_arrive(self)
	cat.update(dt, self)
	if cat.adopted and randf() < dt * 0.0011: cat.mischief(self)
	if is_open() and abs_minutes() >= _next_announce:
		_next_announce = abs_minutes() + randf_range(100.0, 170.0)
		announced.emit(Announcer.pick(self))
	_ach_acc += dt
	if _ach_acc > 5.0:
		_ach_acc = 0.0
		for id in Progress.check(self): achievement.emit(id)
	# rainy days: muddy footprints by the doors
	if calendar.weather in ["yagmur", "kar"] and is_open() and randf() < dt * 0.0012 * maxf(1.0, customers_inside() * 0.25):
		var drs: Array = grid.layout["doors"]
		spill_at(Vector2i(drs.pick_random(), grid.interior().end.y - 1), 0, "Yağmurdan gelenler kapının önünü çamur etti")
	for c in customers: c.update(dt, self)
	for s in staff: s.update(dt, self)
	if mall != null: mall.update(dt)
	for i in range(customers.size() - 1, -1, -1):
		var c: Customer = customers[i]
		if c.removed:
			if c.state == "flee" or (c.thief() and c.stolen.size() > 0): record_theft(c)
			customers.remove_at(i)
			if is_selected(c): select({})
			c.queue_free()
	# wet floors dry after mopping
	for i in range(puddles.size() - 1, -1, -1):
		var p: Dictionary = puddles[i]
		p["age"] += dt
		if p["dry"] > 0.0:
			p["dry"] -= dt
			if p["dry"] <= 0.0:
				if p["sign"] != null: p["sign"].queue_free()
				p["node"].queue_free()
				var g2 := floor_grid(p["lvl"])
				g2.extra_cost[g2.idx(p["tile"].x, p["tile"].y)] = 0.0; g2.version += 1
				puddles.remove_at(i)
	# fridges occasionally leak in bigger stores
	if stage >= 1 and randf() < dt * 0.0006:
		var fr := fixtures.filter(func(f): return f.def.get("display", "") == "fridge")
		if fr.size() > 0:
			var f: Fixture = fr.pick_random()
			spill_at(f.access()[0], f.lvl, "%s su sızdırıyor" % f.def["name"])
	_update_van(dt)
	var due := orders.filter(func(o): return o["eta"] <= abs_minutes())
	if due.size() > 0 and van["state"] == "idle":
		van["cargo"] = due
		orders = orders.filter(func(o): return not due.has(o))
		van["state"] = "arriving"; van["x"] = -32.0
	if prev < AUTO_ORDER_AT and clock >= AUTO_ORDER_AT:
		# the depot ran dry before evening while shelves were empty: the shop has outgrown it
		var empty_hits: int = int(stats["mood_why"].get("Raf boş", [0, 0])[1])
		var dry := unlocked_products().filter(func(p): return is_stocked(p["id"]) and int(backstock[p["id"]]) == 0).size()
		if dry >= 3 and empty_hits >= 20:
			alert("depodry", "box", "Depo akşam olmadan boşaldı, raflar gün içinde boş kaldı. Bir Depo Rafı daha ekle (İnşa → Kasa & Depo): otomatik sipariş yarından itibaren daha çok getirir. Az satan ürünler depoda yer kaplıyorsa Ürünler'den kaldır.", "warn", null, 0.0)
		auto_order()
	_update_neighbor_events()
	_status_acc += dt
	if _status_acc > 0.25:
		_status_acc = 0.0
		_update_statuses()
		quests.check(self)
	if prev < 19 * 60 and clock >= 19 * 60 and evening_bakery:
		refresh_all()
		alert("evening", "tag", "19:00: akşam indirimi başladı, simit ve ekmek %40 ucuz.", "info")
	if prev < Cfg.DAY_CLOSE and clock >= Cfg.DAY_CLOSE:
		alert("closing", "wait", "Saat 22:00 — kapanış. Son müşteriler çıkınca gün sonu raporu gelecek.", "info")
	var mall_busy: bool = mall != null and mall.visitors.any(func(v): return v.state != "exit")
	if clock >= Cfg.DAY_CLOSE and ((customers_inside() == 0 and not mall_busy) or clock > Cfg.DAY_CLOSE + 50): end_day()

func _update_statuses() -> void:
	if is_open():
		var oos: Dictionary = stats["oos_min"]
		var seen := {}
		for f in fixtures:
			if not f.is_display(): continue
			for sl in f.slots:
				if sl["pid"] == "" or seen.has(sl["pid"]): continue
				seen[sl["pid"]] = true
				if shelf_stock(sl["pid"]) == 0: oos[sl["pid"]] = float(oos.get(sl["pid"], 0.0)) + 0.25 * Cfg.MIN_PER_SEC
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
			if not f.def.get("self", false) and (f.cashier == null or not staff.has(f.cashier) or not f.cashier.present): k = "nocashier"
			elif f.queue.size() >= 4: k = "queue"
			if f.queue.size() >= 5: alert("queue", "queue", "Kasada %d kişilik kuyruk! Hızlı ödeme ya da ek kasa bekleme süresini düşürür." % f.queue.size(), "warn", f.center(), 60.0)
			if k == "nocashier" and f.queue.size() > 0: alert("nocashier", "nocashier", "Bir kasada kasiyer yok. Personel panelinden kasiyer al ya da vardiyaları kontrol et.", "bad", f.center(), 60.0)
		elif f.def["kind"] == "depot":
			var cap := depot_capacity()
			if cap > 0 and backstock_total() + incoming_total() < cap * 0.08: k = "box"
		elif f.def["kind"] == "table":
			k = "dirty" if f.dirty else ""
		elif f.def["kind"] == "oven":
			k = "" if has_role("baker") else "nocashier"
		f.set_status(k)
	var tired = null
	for s in staff:
		if s.tired() and s.present: tired = s; break
	if tired != null and not fixtures.any(func(f): return f.def["kind"] == "break"):
		alert("tired", "tired", "%s çok yorgun, yavaşladı. Bir Çay Ocağı (Mola) kur ya da vardiyaları böl." % tired.person_name, "warn", tired.position, 90.0)

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
					if put > 0 and DB.BAKERY.has(o["pid"]): add_fresh(o["pid"], put, 0.8)
					backstock[o["pid"]] += put; n += put
					if int(o["qty"]) - put > 0: overflow += (int(o["qty"]) - put) * cost_of(o["pid"])
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
	last_sold = (stats["sold"] as Dictionary).duplicate()
	var unit_costs := {}
	for p in DB.PRODUCTS: unit_costs[p["id"]] = cost_of(p["id"])
	product_log.append({"day": day, "sold": (stats["sold"] as Dictionary).duplicate(), "missed": (stats["missed"] as Dictionary).duplicate(),
		"expensive": (stats["expensive"] as Dictionary).duplicate(), "oos": (stats["oos_min"] as Dictionary).duplicate(), "price": prices.duplicate(), "cost": unit_costs, "buyers": (stats["buyers"] as Dictionary).duplicate(true)})
	if product_log.size() > 14: product_log.pop_front()
	neighborhood.end_day(self)
	rival.end_day(self)
	quests.end_day(self)
	_pay_loan()
	if cat.adopted: money -= 15; stats["other"] += 15
	_staff_day()
	for c in customers:
		if c.inside():
			if c.register: c.register.queue.erase(c)
			c.finish_visit(self, false)
	_overnight_losses()
	var wages := wages_per_day()
	var mall_sum := {}
	if mall != null:
		mall_sum = mall.end_day()
		var inc: int = mall_sum["rent"] + mall_sum["share"]
		money += inc
		stats["mall_income"] = inc; stats["mall_visitors"] = mall_sum["visitors"]
	money -= wages + rent() + utilities()
	stats["wages"] = wages; stats["rent"] = rent(); stats["utilities"] = utilities()
	stats["branch_income"] = branches.end_day(self)
	var income: int = stats["revenue"] + stats["mall_income"] + int(stats["branch_income"])
	var costs: int = stats["purchases"] + wages + rent() + utilities() + stats["other"] + int(stats["loan"])
	history.append({"day": day, "revenue": income, "costs": costs, "profit": income - costs, "rating": rating, "happy": stats["happy"]})
	day_ended_flag = true
	GameAudio.play("coin", -4.0)
	day_ended.emit({"day": day, "stats": stats, "costs": costs, "income": income, "rating": rating, "money": money, "mall": mall_sum})
	for id in Progress.check(self): achievement.emit(id)
	if not scenario.is_empty():
		var res := Scenarios.check(self)
		if res != "": scenario_result.emit(res)

## unsold bread goes stale overnight; without a cold room, 30% of chilled backstock spoils
func _overnight_losses() -> void:
	for f in fixtures:
		if not f.is_display(): continue
		for sl in f.slots:
			if DB.BAKERY.has(sl["pid"]) and int(sl["stock"]) > 0:
				stats["stale"] += int(sl["stock"]); stats["stale_cost"] += int(sl["stock"]) * cost_of(sl["pid"])
				sl["stock"] = 0
	for pid in DB.BAKERY:
		var b := int(backstock.get(pid, 0))
		if b > 0:
			stats["stale"] += b; stats["stale_cost"] += b * cost_of(pid)
			backstock[pid] = 0
	if stage >= 1 and not has_cold_room():
		for p in unlocked_products():
			if not DB.is_cold(p["id"]): continue
			var lost := int(floor(int(backstock[p["id"]]) * 0.3))
			if lost > 0:
				backstock[p["id"]] -= lost
				stats["spoiled"] += lost; stats["spoiled_cost"] += lost * cost_of(p["id"])
	refresh_all(); depot_changed()

func add_fresh(pid: String, qty: int, fresh: float) -> void:
	var have := int(backstock.get(pid, 0))
	var f0 := float(backstock_fresh.get(pid, 1.0)) if have > 0 else fresh
	backstock_fresh[pid] = (f0 * have + fresh * qty) / maxf(1.0, have + qty)

## the morning bread run: the baker's night batch (or the bakery's delivery) goes straight onto the baskets
func _morning_bread() -> void:
	var oven := has_oven()
	var total_cost := 0
	for f in fixtures:
		if not f.is_display(): continue
		for sl in f.slots:
			if not DB.BAKERY.has(sl["pid"]) or not auto.get(sl["pid"], true) or not calendar.product_active(day, sl["pid"]): continue
			var n: int = f.cap() - int(sl["stock"])
			if n <= 0: continue
			sl["stock"] = f.cap(); sl["fresh"] = 1.0 if oven else 0.85
			total_cost += int(round(n * (DB.BAKED[sl["pid"]] if oven else float(cost_of(sl["pid"])))))
	if total_cost > 0:
		money -= total_cost; stats["purchases"] += total_cost
		alert("morningbread", "star", ("Fırıncının gece pişirdiği sıcak ekmek ve simit raflarda (%s)." if oven else "Fırından sabah ekmek teslimatı raflara dizildi (%s).") % Cfg.fmt_money(total_cost), "good", null, 0.0)
	refresh_all()

func start_next_day() -> void:
	neighbor_events = []; events_changed.emit()
	_next_event_at = (day + 1) * 1440.0 + Cfg.DAY_OPEN + 50.0 + randf() * 90.0
	day += 1
	clock = float(Cfg.DAY_OPEN)
	stats = new_stats()
	calendar.advance(day)
	sky.set_weather(calendar.weather)
	neighborhood.start_day(self)
	rival.start_day(self)
	quests.refill(self)
	_inflation()
	cat.start_day(self)
	update_festive()
	_next_announce = day * 1440.0 + Cfg.DAY_OPEN + randf_range(30.0, 90.0)
	_announce_day()
	day_ended_flag = false
	campaigns.clear(); discounts = []; multi = []
	refresh_all()
	_campaign_visuals()
	roll_candidates()
	for s in staff: s.energy = 100.0
	_morning_bread()
	for g in floors:
		for i in g.traffic.size(): g.traffic[i] *= 0.5
	if mall != null: mall.start_day()
	SaveGame.save(self, 0)
	changed.emit()

# ------------------------------------------------------------------ economy
## once a week the wholesaler raises prices; shoppers' idea of a fair price rises with them
func _inflation() -> void:
	if day < _next_hike_day: return
	_next_hike_day = day + 7
	var hike := randf_range(0.02, 0.045)
	cost_mul *= 1.0 + hike
	alert("inflation", "chart", "Toptancı zam yaptı: ortalama %%%.1f. Müşterilerin \"normal fiyat\" beklentisi de arttı. Ürün & Fiyat panelinden fiyatlarını güncellemeyi unutma." % (hike * 100.0), "warn", null, 0.0)
	refresh_all(); changed.emit()

func pending_inflation() -> float: return cost_mul / price_mul - 1.0

## pass the inflation since the last update on to every shelf price
func apply_inflation_to_prices() -> void:
	var k := cost_mul / price_mul
	if k <= 1.001: return
	for pid in prices: prices[pid] = maxi(1, int(round(prices[pid] * k)))
	price_mul = cost_mul
	refresh_all(); changed.emit()

func take_loan(i: int) -> bool:
	if not loan.is_empty() or i < 0 or i >= DB.LOANS.size(): return false
	var l: Dictionary = DB.LOANS[i]
	if l["stage"] > stage: return false
	var total := int(round(l["amount"] * (1.0 + l["rate"])))
	loan = {"amount": l["amount"], "total": total, "left": total, "daily": int(ceil(total / float(l["days"])))}
	money += l["amount"]
	alert("loan", "bank", "Mahalle Bankası'ndan %s kredi çektin. Her gün sonunda %s taksit düşülecek." % [Cfg.fmt_money(l["amount"]), Cfg.fmt_money(loan["daily"])], "info", null, 0.0)
	changed.emit()
	return true

func repay_loan() -> void:
	if loan.is_empty() or money < loan["left"]: return
	money -= loan["left"]; stats["loan"] += int(loan["left"])
	loan = {}
	alert("loan_done", "bank", "Kredinin tamamını erken kapattın.", "good", null, 0.0)
	if Progress.unlock("borcsuz"): achievement.emit("borcsuz")
	changed.emit()

func _pay_loan() -> void:
	if loan.is_empty(): return
	var pay := mini(int(loan["daily"]), int(loan["left"]))
	money -= pay; stats["loan"] = pay
	loan["left"] = int(loan["left"]) - pay
	if int(loan["left"]) <= 0:
		loan = {}
		alert("loan_done", "bank", "Kredi borcu bitti. Tebrikler!", "good", null, 0.0)
		if Progress.unlock("borcsuz"): achievement.emit("borcsuz")

# ------------------------------------------------------------------ staff life
## experience, raise requests and notices, once a day
func _staff_day() -> void:
	var asked := false
	for s in staff.duplicate():
		if s.role == "owner": continue
		s.days_worked += 1
		s.skill = minf(1.45, s.skill + 0.006)
		if s.quit_day >= 0 and day >= s.quit_day:
			alert("quit%d" % s.get_instance_id(), "staff", "%s istifa etti ve bugün son günüydü. Personel panelinden yenisini al." % s.person_name, "bad", null, 0.0)
			fire(s); continue
		s.morale = clampf(s.morale + (1.5 if not s.tired() else -3.0), 0.0, 100.0)
		if not asked and day - s.raise_day >= 9 and randf() < 0.35:
			asked = true
			s.raise_day = day
			var nw := int(round(s.base_wage * 1.1 / 10.0)) * 10
			push_event({"kind": "raise", "title": "%s zam istiyor" % s.person_name, "icon": "staff", "expires": (day + 1) * 1440.0 + Cfg.DAY_OPEN + 240.0,
				"text": "%s (%s) %d gündür burada çalışıyor, maaşının %s'den %s'ye çıkmasını istiyor. Reddedersen morali düşer; çok küserse istifa edebilir." % [s.person_name, DB.ROLE_LABEL[s.role], s.days_worked, Cfg.fmt_money(s.base_wage), Cfg.fmt_money(nw)],
				"choices": [{"label": "Zam yap · +%s/gün" % Cfg.fmt_money(nw - s.base_wage), "primary": true}, {"label": "Şimdi olmaz"}], "data": {"staff": s.get_instance_id(), "wage": nw}})

func staff_by_iid(iid: int) -> Staff:
	for s in staff:
		if s.get_instance_id() == iid: return s
	return null

func train(s: Staff) -> bool:
	var cost := 300 * (stage + 1)
	if money < cost or day - s.trained_day < 3 or s.skill >= 1.45: return false
	money -= cost; stats["other"] += cost
	s.skill = minf(1.45, s.skill + 0.08); s.morale = minf(100.0, s.morale + 8.0); s.trained_day = day
	float_text(s.position + Vector3(0, 2.3, 0), "Eğitim +beceri", Cfg.VIOLET)
	changed.emit()
	return true

## a mahalle olayı card raised by the game itself (cat at the door, a raise request)
func push_event(ev: Dictionary) -> void:
	ev["id"] = NeighborEvents.next_id()
	neighbor_events.append(ev)
	events_changed.emit()
	GameAudio.play("bell", -6.0)

# ------------------------------------------------------------------ undo & copy (build mode)
func push_undo(a: Dictionary) -> void:
	undo_stack.append(a)
	if undo_stack.size() > 20: undo_stack.pop_front()

func undo() -> bool:
	if undo_stack.is_empty() or not placing.is_empty(): return false
	var a: Dictionary = undo_stack.pop_back()
	match a["kind"]:
		"place":
			var f = a["fixture"]
			if not is_instance_valid(f) or not fixtures.has(f): return undo()
			money += int(a["cost"]); stats["other"] -= int(a["cost"])
			if a.get("voucher", false): vouchers[f.def["id"]] = int(vouchers.get(f.def["id"], 0)) + 1
			remove_fixture(f)
			float_text(f.center() + Vector3(0, 1.8, 0), "Geri alındı", Cfg.BLUE)
		"move":
			var f2 = a["fixture"]
			if not is_instance_valid(f2) or not fixtures.has(f2): return undo()
			var g := floor_grid(f2.lvl)
			if not f2.noblock():
				for t in f2.fp["tiles"]: g.fixture[g.idx(t.x, t.y)] = 0
			f2.place(a["x"], a["z"], a["rot"])
			if not f2.noblock():
				for t in f2.fp["tiles"]: g.fixture[g.idx(t.x, t.y)] = f2.uid
			g.version += 1
			layout_changed()
		"sell":
			if money < int(a["refund"]): return false
			money -= int(a["refund"])
			var f3 := add_fixture(DB.fixture(a["id"]), a["x"], a["z"], a["rot"], a["lvl"])
			for i in mini(f3.slots.size(), a["slots"].size()):
				f3.slots[i]["pid"] = a["slots"][i]
			f3.refresh(self)
	changed.emit()
	return true

## morning news: what kind of day it is and what tomorrow looks like
func _announce_day() -> void:
	var sp := calendar.special(day)
	var w := calendar.weather_info()
	var msg := "%s, %s." % [calendar.label(day), (w["name"] as String).to_lower()]
	if not sp.is_empty(): msg += " %s: %s" % [sp["name"], sp["desc"]]
	var tip := ""
	match calendar.weather:
		"sicak": tip = " Dondurma, su ve kola dolapta hazır olsun."
		"yagmur": tip = " Şemsiye satılır, kapının önü çamur olur."
		"kar": tip = " Salep aranır, müşteri azdır."
	alert("day", sp.get("icon", w["icon"]), msg + tip, "info", null, 0.0)

## facade decorations follow the calendar
func update_festive() -> void:
	var k := ""
	if calendar.is_bayram(day) or calendar.is_arife(day): k = "bayram"
	elif calendar.is_ramazan(day): k = "ramazan"
	shop.set_festive(k)

func set_style(key: String, i: int) -> void:
	style[key] = i
	shop.style = style
	shop.build(grid.layout, stage, upgrades)
	_campaign_visuals(); update_festive()
	changed.emit()

## upgrade visuals after loading a save
func apply_upgrade_visuals() -> void:
	shop.style = style
	shop.build(grid.layout, stage, upgrades)
	update_festive()
	_campaign_visuals()
	if upgrades.has("pos"):
		for f in fixtures: if f.model["pos_device"]: f.model["pos_device"].visible = true
	if upgrades.has("otopark"): street.build_parking()

## a loaded game starts at the opening of the saved day
func resume_day() -> void:
	clock = float(Cfg.DAY_OPEN)
	stats = new_stats()
	day_ended_flag = false
	campaigns.clear(); discounts = []; multi = []
	roll_candidates()
	for s in staff: s.energy = 100.0
	if mall != null: mall.start_day()
	layout_changed()
	depot_changed()
	_campaign_visuals()
	changed.emit()

func buy_upgrade(id: String) -> bool:
	var u: Dictionary = DB.UPGRADES.filter(func(x): return x["id"] == id)[0]
	if upgrades.has(id) or money < u["cost"]: return false
	money -= u["cost"]; stats["other"] += int(u["cost"])
	upgrades[id] = true
	if id == "pos":
		for f in fixtures: if f.model["pos_device"]: f.model["pos_device"].visible = true
	if id == "neon" or id == "tente": shop.build(grid.layout, stage, upgrades); update_festive()
	if id == "otopark": street.build_parking()
	float_text(rig.target + Vector3(0, 3, 0), u["name"] + "!", Cfg.VIOLET)
	changed.emit()
	return true

func expand() -> bool:
	var e = expansion()
	if e == null or not can_expand(): return false
	money -= e["cost"]; stats["other"] += int(e["cost"])
	apply_stage(e["to"])
	neighborhood.grow(self)
	expanded.emit(e["to"])
	GameAudio.play("levelup", -4.0)
	var msg: String = ["", "Mahalle Marketi açıldı! Yeni reyonlar, manav ve aile alışverişçileri seni bekliyor.",
		"Süpermarket açıldı! Bantlı kasalar, fırın, reyon levhaları ve araba parkı kilidi açıldı.",
		"Köşebaşı AVM açıldı! Kiracı birimlerini AVM panelinden (V) doldur, üst kata PageUp ile çık."][e["to"]]
	alert("expanded", "star", msg, "good", null, 0.0)
	overlays.float_text(rig.g_target + Vector3(0, 5, 0), (DB.STAGES[e["to"]]["name"] as String).to_upper() + "!", Cfg.TERRA)
	return true

func apply_stage(n: int) -> void:
	stage = n
	street.remove_for_stage(n)
	grid.apply_layout(Cfg.STAGE_LAYOUTS[n])
	_apply_env_blocks()
	if n >= 3 and mall == null:
		var g1 := Grid.new(1)
		g1.apply_layout(Cfg.STAGE_LAYOUTS[n]); g1.clear_all()
		floors = [grid, g1]
		mall = Mall.new(); add_child(mall); mall.setup(self)
		mall.apply_grids(grid, g1)
		mall_shell = MallShell.new(); add_child(mall_shell); mall_shell.build(mall)
		mall_changed.connect(func(): mall_shell.sync_units())
		rig.bounds = Rect2(4, -2, 36, 30)
	elif n >= 3:
		mall.apply_grids(grid, floors[1])
	for f in fixtures:
		if f.noblock(): continue
		var g := floor_grid(f.lvl)
		for t in f.fp["tiles"]: g.fixture[g.idx(t.x, t.y)] = f.uid
	shop.build(Cfg.STAGE_LAYOUTS[n], n, upgrades)
	update_festive()
	_campaign_visuals()
	for g in floors: g.version += 1
	layout_changed()
	roll_candidates()
	var r: Rect2i = Cfg.STAGE_LAYOUTS[n]["interior"]
	rig.focus(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5 + 1.0, [18.0, 26.0, 32.0, 36.0][n])
	stage_changed.emit()
	changed.emit()

# ------------------------------------------------------------------ overlays
func set_overlay(mode: String) -> void:
	overlay_mode = "none" if overlay_mode == mode else mode
	overlays.heat.visible = overlay_mode != "none"
	if overlay_mode == "heat": overlays.update_heat(floor_grid(view_floor), view_floor * Cfg.FLOOR_H)
	elif overlay_mode == "security": overlays.update_security(security_mask(view_floor), floor_grid(view_floor), view_floor * Cfg.FLOOR_H)

# ------------------------------------------------------------------ picking & selection
func ground_at(screen: Vector2, y := -1.0) -> Variant:
	if y < 0.0: y = view_floor * Cfg.FLOOR_H
	var from := rig.cam.project_ray_origin(screen)
	var dir := rig.cam.project_ray_normal(screen)
	if absf(dir.y) < 1e-4: return null
	var t := (y - from.y) / dir.y
	if t < 0.0: return null
	return from + dir * t

func pick(screen: Vector2) -> Dictionary:
	var out := {}
	var best := 34.0
	var all: Array = customers + staff
	if mall != null: all += mall.visitors
	for a in all:
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
		var gr := floor_grid(view_floor)
		if not out.has("agent"):
			for L in litter:
				if L["tile"] == t and L["lvl"] == view_floor: out["litter"] = L
			var p2 = puddle_at(t, view_floor)
			if p2 != null and p2["dry"] <= 0.0: out["puddle"] = p2
			if gr.in_bounds(t.x, t.y):
				var uid := gr.fixture[gr.idx(t.x, t.y)]
				if uid > 0:
					for f in fixtures: if f.uid == uid: out["fixture"] = f
				if not out.has("fixture") and mall != null:
					var reg := gr.region[gr.idx(t.x, t.y)]
					if reg >= Grid.R_UNIT0: out["unit"] = mall.units[reg - Grid.R_UNIT0]
					for cs in mall.connectors:
						var b: Rect2i = cs["def"]["blocked"]
						if b.grow(1).has_point(t): out["connector"] = cs
		if not out.has("fixture") and not out.has("agent") and not out.has("unit"):
			for f in fixtures:
				if not f.visible: continue
				var c: Vector3 = f.center() + Vector3(0, float(f.model["height"]) * 0.55, 0)
				if rig.cam.unproject_position(c).distance_to(screen) < 40.0: out["fixture"] = f
	return out

## selection can hold an agent/fixture or a plain dictionary (unit, connector, puddle)
func is_selected(o) -> bool:
	var s = selection.get("obj")
	return s is Object and is_instance_valid(s) and s == o

func select(sel: Dictionary) -> void:
	selection = sel
	selection_changed.emit()

func _update_selection_visual() -> void:
	var o = selection.get("obj")
	if o == null or (o is Object and not is_instance_valid(o)) or not (o is Node3D):
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
