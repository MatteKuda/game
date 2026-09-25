class_name Staff
extends Agent
## Employees: owner/cashier at registers; stockers restock and sweep; cleaners mop and clear
## food-court tables; security patrols and chases suspects; bakers bake. Shifts + fatigue.

var role := "stocker"
var base_wage := 0
var wage := 0
var skill := 1.0
var shift := "full"
var energy := 100.0
var present := true
var tired_shown := 0.0
var task = null # Dictionary
var timer := 0.0
var idle_t := 0.0
var register: Fixture = null
var activity := "Hazır"
var persona := ""
var morale := 70.0
var days_worked := 0
var raise_day := 0 # last day a raise was asked for or given
var trained_day := -99
var quit_day := -1 # set when an unhappy worker hands in notice

static func look_for(r: String) -> Dictionary:
	var skin: Color = Customer.SKIN.pick_random()
	var hair: Color = Customer.HAIR.pick_random()
	match r:
		"owner": return {"body": "barbarian", "skin": Color("e8b894"), "hair": Color("3a2a20"), "top": Color("fbf1e2"), "bottom": Color("2b3a55"), "shoes": Color("2a2a2e"), "accent": Cfg.TERRA, "height": 1.04}
		"cashier": return {"body": "rogue", "skin": skin, "hair": hair, "top": Cfg.TEAL, "bottom": Color("2b3a55"), "shoes": Color("2a2a2e"), "accent": Cfg.MUSTARD, "height": 1.0}
		"cleaner": return {"body": "rogue", "skin": skin, "hair": hair, "top": Color("6c4ab6"), "bottom": Color("3a3350"), "shoes": Color("2a2a2e"), "accent": Color("f2b33d"), "height": 1.0}
		"security": return {"body": "knight", "skin": skin, "hair": hair, "top": Color("24324a"), "bottom": Color("1b2130"), "shoes": Color("1a1a1e"), "accent": Color("f2b33d"), "height": 1.06}
		"technician": return {"body": "barbarian", "skin": skin, "hair": hair, "top": Color("e8962c"), "bottom": Color("2b3a55"), "shoes": Color("2a2a2e"), "accent": Color("f2b33d"), "height": 1.02}
		"baker": return {"body": "barbarian", "skin": skin, "hair": hair, "top": Color("f6f1e7"), "bottom": Color("e8e2d6"), "shoes": Color("2a2a2e"), "accent": Color("f6f1e7"), "height": 1.0}
		"deli": return {"body": "barbarian", "skin": skin, "hair": hair, "top": Color("f6f1e7"), "bottom": Color("8a2f2a"), "shoes": Color("2a2a2e"), "accent": Color("8a2f2a"), "height": 1.02}
		_: return {"body": "knight", "skin": skin, "hair": hair, "top": Color("2f5d8a"), "bottom": Color("24324a"), "shoes": Color("2a2a2e"), "accent": Cfg.MUSTARD, "height": 1.0}

func setup_staff(r: String, nm: String, w: int, sk: float, sh := "full", tr := "") -> void:
	role = r; base_wage = w; skill = sk; shift = sh; persona = tr
	wage = int(round(base_wage * DB.SHIFT_WAGE[shift]))
	init_agent(look_for(r), nm)
	speed = 1.6 * (1.15 if persona == "cevik" else 1.0)

func set_shift(sh: String) -> void:
	shift = sh
	wage = int(round(base_wage * DB.SHIFT_WAGE[shift]))

static var room_bonus := 1.0 # set by the game when a break room exists

func tired() -> bool: return energy < 30.0
func eff_skill() -> float:
	var k := skill * (0.7 if tired() else 1.0) * room_bonus * (0.85 + morale * 0.003)
	if persona == "titiz" and task != null and task["kind"] in ["restock", "clean", "mop", "table", "wc"]: k *= 1.25
	if persona == "dalgin": k *= 0.9
	return k
func trait_name() -> String: return DB.TRAITS[persona]["name"] if DB.TRAITS.has(persona) else ""

## rooms are solid fixtures on the grid: staff step straight in through the door and back out
func _step_to(p: Vector3, dt: float) -> bool:
	var d := Vector3(p.x - position.x, 0, p.z - position.z)
	var l := d.length()
	if l < 0.04: moving = 0.0; return true
	var st := minf(l, speed * speed_mul * dt * 0.8)
	position += d / l * st
	facing = atan2(d.x, d.z)
	moving = 1.0
	return st >= l - 0.001
func on_duty(clock: float) -> bool:
	var h: Array = DB.SHIFT_HOURS[shift]
	return clock >= h[0] and clock < h[1]

func at_register(reg: Fixture) -> bool:
	if register != reg or task != null or not present or lvl != 0: return false
	var b: Vector2i = reg.back()[0]
	return absf(position.x - (b.x + 0.5)) < 0.35 and absf(position.z - (b.y + 0.5)) < 0.35

func update(dt: float, game) -> void:
	var duty := role == "owner" or on_duty(game.clock)
	if not duty and game.clock >= Cfg.DAY_OPEN:
		if present: _go_home(dt, game)
		return
	if duty and not present: _arrive(game)
	if not present: return
	# fatigue
	var working: bool = task != null and task["kind"] != "rest"
	var drain := (1.0 if shift == "full" else 0.55) * (0.6 if role == "owner" else 1.0) * (1.0 if working else 0.5) * (1.3 if persona == "keyfi" else 1.0)
	if task == null or task["kind"] != "rest": energy = maxf(0.0, energy - dt * 0.11 * drain * Cfg.MIN_PER_SEC)
	speed_mul = (0.72 if tired() else 1.0) * (1.35 if task != null and task["kind"] == "chase" else 1.0)
	if tired():
		tired_shown -= dt
		if tired_shown <= 0.0: think("wait", 2.0); tired_shown = 14.0
		if task == null or task["kind"] == "clean":
			var spot = null
			for f in game.fixtures:
				if f.def["kind"] == "break" and (spot == null or float(f.def.get("rest", 1.0)) > float(spot.def.get("rest", 1.0))): spot = f
			var can_leave := not (role == "owner" or role == "cashier") or register == null or register.queue.is_empty()
			if spot != null and can_leave:
				if task != null: cancel_task(game)
				task = {"kind": "rest", "spot": spot, "phase": "go"}; dest = {}
	if role == "owner" or role == "cashier":
		_cashier_logic(dt, game); return
	if role == "deli":
		_counter_logic(dt, game); return
	if task == null: task = _find_work(game)
	if task != null:
		_do_task(dt, game); return
	activity = "Devriye geziyor" if role == "security" else ("Bakım turunda" if role == "technician" else "Boşta, iş bekliyor")
	if has_goal and not move(dt, game):
		view.play("walk"); return
	view.play("idle")
	idle_t += dt
	if idle_t > (2.5 if role == "security" else 6.0):
		idle_t = 0.0
		_wander(game)

func _find_work(game):
	var t = null
	match role:
		"stocker":
			t = game.find_restock_task(self, 0.55)
			if t == null: t = game.find_mop_task(self)
			if t == null: t = game.find_clean_task(self)
		"cleaner":
			t = game.find_mop_task(self)
			if t == null: t = game.find_table_task(self)
			if t == null: t = game.find_wc_task(self)
			if t == null: t = game.find_clean_task(self)
		"baker": t = game.find_bake_task(self)
		"security": t = game.find_chase_task(self)
		"technician": t = game.find_repair_task(self)
	return t

func _wander(game) -> void:
	var g: Grid = game.grid
	var r := g.interior()
	for i in 12:
		var mall: bool = (role == "security" and game.stage >= 3 and randf() < 0.4) or role == "technician"
		var tx := (6 + randi() % 32) if mall else r.position.x + randi() % r.size.x
		var tz := (randi() % 16) if mall else r.position.y + randi() % maxi(1, r.size.y - 1)
		var fl := 1 if role == "technician" and game.floors.size() > 1 and randf() < 0.5 else 0
		var gg: Grid = game.floor_grid(fl)
		if gg.walkable(tx, tz) and (gg.is_interior(tx, tz) or (mall and gg.is_mall(tx, tz))):
			go_to_any(game, Vector2i(tx, tz), fl); return

func _cashier_logic(dt: float, game) -> void:
	if register == null or not game.fixtures.has(register) or register.cashier != self:
		register = null
		for f in game.fixtures:
			if f.def["kind"] == "register" and not f.def.get("self", false) and (f.cashier == null or f.cashier == self or not game.staff.has(f.cashier) or not f.cashier.present):
				register = f; break
		if register: register.cashier = self
		has_goal = false; dest = {}
	var reg := register
	var busy := reg != null and reg.queue.size() > 0
	if task != null and busy and not (task["kind"] == "restock" and (task["phase"] == "to_shelf" or task["phase"] == "stock")) and task["kind"] != "mop":
		cancel_task(game)
	if task != null:
		_do_task(dt, game); return
	if reg:
		var b: Vector2i = reg.back()[0]
		if not same_dest(b, 0): go_to_any(game, b, 0)
		if move(dt, game):
			var a: Vector2i = reg.access()[0]
			look_at_pt = Vector3(a.x + 0.5, 0, a.y + 0.5)
			var serving: bool = reg.queue.size() > 0 and reg.queue[0].state == "paying"
			view.play("work" if serving else "idle")
			activity = "Müşteriye hizmet veriyor" if serving else "Kasada bekliyor"
			if not busy:
				idle_t += dt
				if idle_t > 0.8:
					var t = null
					if not game.has_role("stocker"): t = game.find_restock_task(self, 0.4)
					if t == null and not game.has_role("stocker") and not game.has_role("cleaner"):
						t = game.find_mop_task(self)
						if t == null: t = game.find_clean_task(self)
					if t != null: task = t; idle_t = 0.0
			else: idle_t = 0.0
		else:
			view.play("walk"); activity = "Kasaya dönüyor"
	else:
		activity = "Kasa yok — boşta"
		var t2 = game.find_restock_task(self, 0.5)
		if t2 == null: t2 = game.find_mop_task(self)
		if t2 == null: t2 = game.find_clean_task(self)
		if t2 != null: task = t2
		else: view.play("idle")

## the şarküteri usta keeps to the deli counter: serves from behind it, refills it when it runs low
func _counter_logic(dt: float, game) -> void:
	if register == null or not game.fixtures.has(register) or register.cashier != self:
		register = null
		for f in game.fixtures:
			if f.def.get("staffed", false) and (f.cashier == null or f.cashier == self or not game.staff.has(f.cashier) or not f.cashier.present):
				register = f; break
		if register: register.cashier = self
		has_goal = false; dest = {}
	var ctr := register
	if task != null:
		_do_task(dt, game); return
	if ctr == null:
		activity = "Şarküteri tezgâhı yok — boşta"; view.play("idle"); return
	var waiting: bool = game.customers.any(func(c): return c.shelf == ctr and c.state in ["to_shelf", "browse"])
	if not waiting:
		idle_t += dt
		if idle_t > 1.5:
			idle_t = 0.0
			var t = game.find_restock_task(self, 0.5, ctr)
			if t != null: task = t; return
	var b: Vector2i = ctr.back()[0]
	if not same_dest(b, 0): go_to_any(game, b, 0)
	if move(dt, game):
		var a: Vector2i = ctr.access()[ctr.access().size() / 2]
		look_at_pt = Vector3(a.x + 0.5, 0, a.y + 0.5)
		view.play("work" if waiting else "idle")
		activity = "Müşteriye kesip tartıyor" if waiting else "Tezgâhın başında"
	else:
		view.play("walk"); activity = "Tezgâha dönüyor"

func _go_home(dt: float, game) -> void:
	if task != null and task["kind"] != "chase": cancel_task(game)
	task = null
	if register and register.cashier == self: register.cashier = null
	register = null
	activity = "Vardiyası bitti, çıkıyor"
	var door := Vector2i(game.grid.layout["doors"][0], game.grid.interior().end.y)
	if not same_dest(door, 0): go_to_any(game, door, 0)
	view.play("walk")
	if move(dt, game):
		present = false; visible = false

func _arrive(game) -> void:
	present = true; visible = true
	lvl = 0
	position = Vector3(game.grid.layout["doors"][0] + 0.5, 0.02, game.grid.interior().end.y + 0.5)
	energy = maxf(energy, 100.0)
	has_goal = false; dest = {}; legs = []; ride = {}
	activity = "Vardiyaya geldi"

func cancel_task(game) -> void:
	if task == null: return
	match task["kind"]:
		"restock":
			task["fixture"].slots[task["slot"]]["claimed"] = 0
			if task["phase"] in ["to_shelf", "stock", "leave_room"]:
				game.backstock[task["pid"]] = int(game.backstock.get(task["pid"], 0)) + int(task["qty"])
		"clean": task["litter"]["claimed"] = 0
		"mop": task["puddle"]["claimed"] = 0
		"table": task["table"].claimed = 0
		"bake": task["oven"].claimed = 0; task["oven"].baking = false
		"repair": task["conn"]["claimed"] = 0
		"wc": task["wc"].claimed = 0
	if task.has("door"): position = task["door"] # never leave someone stuck inside a room
	task = null
	view.set_carry(false)
	has_goal = false; dest = {}; legs = []

func _done() -> void:
	task = null; has_goal = false; dest = {}; look_at_pt = null

func _do_task(dt: float, game) -> void:
	var t: Dictionary = task
	var v := view
	match t["kind"]:
		"restock":
			var fx: Fixture = t["fixture"]
			var dep: Fixture = t["depot"]
			if not game.fixtures.has(fx) or not game.fixtures.has(dep):
				cancel_task(game); return
			match t["phase"]:
				"to_depot":
					activity = "Depoya gidiyor"; v.play("walk")
					var acc: Vector2i = game.nearest_access(dep, position)
					if not same_dest(acc, 0): go_to_any(game, acc, 0)
					if move(dt, game):
						if dep.def.has("room"):
							t["phase"] = "enter"; t["door"] = position
						else:
							t["phase"] = "pickup"; timer = 0.9; look_at_pt = dep.center()
				"enter":
					activity = "Depo odasına giriyor"; v.play("walk")
					if _step_to(game.room_inside(dep), dt):
						t["phase"] = "pickup"; timer = 1.1; look_at_pt = dep.center() + (dep.center() - position)
				"pickup":
					activity = "Koli alıyor"; v.play("reach")
					timer -= dt
					if timer <= 0.0:
						var have: int = int(game.backstock.get(t["pid"], 0))
						var qty := mini(int(t["qty"]), have)
						if qty <= 0:
							cancel_task(game); return
						game.backstock[t["pid"]] = have - qty
						t["qty"] = qty
						game.depot_changed()
						v.set_carry(true); look_at_pt = null
						t["phase"] = "leave_room" if t.has("door") else "to_shelf"; has_goal = false; dest = {}
				"leave_room":
					activity = "Koliyle depodan çıkıyor"; v.play("carry")
					if _step_to(t["door"], dt): t["phase"] = "to_shelf"
				"to_shelf":
					activity = "%s rafa taşıyor" % DB.product(t["pid"])["name"]; v.play("carry")
					var acc2: Vector2i = game.nearest_access(fx, position)
					if dest.is_empty(): go_to_any(game, acc2, 0)
					if move(dt, game):
						t["phase"] = "stock"; timer = 1.4 / eff_skill(); look_at_pt = fx.center(); v.set_carry(false)
				"stock":
					activity = "Rafı dolduruyor"; v.play("work")
					timer -= dt
					if timer <= 0.0:
						var s: Dictionary = fx.slots[t["slot"]]
						if s["pid"] == t["pid"]:
							var put := mini(fx.cap() - int(s["stock"]), int(t["qty"]))
							if DB.BAKERY.has(t["pid"]) and put > 0:
								var old := int(s["stock"])
								s["fresh"] = (float(s.get("fresh", 1.0)) * old + float(game.backstock_fresh.get(t["pid"], 1.0)) * put) / float(old + put)
							s["stock"] += put
							if int(t["qty"]) - put > 0: game.backstock[t["pid"]] += int(t["qty"]) - put
						else:
							game.backstock[t["pid"]] += int(t["qty"])
						s["claimed"] = 0
						game.stock_changed(fx)
						game.float_text(fx.center() + Vector3(0, float(fx.model["height"]) + 0.2, 0), "+%d %s" % [t["qty"], DB.product(t["pid"])["name"]], Cfg.BLUE)
						_done()
		"clean":
			var L: Dictionary = t["litter"]
			if not game.litter.has(L):
				_done(); return
			if t["phase"] == "go":
				activity = "Çöpü temizlemeye gidiyor"; v.play("walk")
				var tgt: Vector2i = game.nearest_walkable(L["tile"], L["lvl"])
				if not same_dest(tgt, L["lvl"]):
					if not go_to_any(game, tgt, L["lvl"]) and not riding():
						cancel_task(game); return
				if move(dt, game):
					t["phase"] = "sweep"; timer = 1.8 / eff_skill()
					look_at_pt = Vector3(L["tile"].x + 0.5, position.y, L["tile"].y + 0.5)
			else:
				activity = "Süpürüyor"; v.play("sweep")
				timer -= dt
				if timer <= 0.0:
					game.remove_litter(L); _done()
		"mop":
			var P: Dictionary = t["puddle"]
			if not game.puddles.has(P):
				_done(); return
			if t["phase"] == "go":
				activity = "Islak zemine koşuyor"; v.play("walk")
				var tgt2: Vector2i = game.nearest_walkable(P["tile"], P["lvl"])
				if not same_dest(tgt2, P["lvl"]):
					if not go_to_any(game, tgt2, P["lvl"]) and not riding():
						cancel_task(game); return
				if move(dt, game):
					t["phase"] = "mop"
					timer = (2.2 if role == "cleaner" else 4.5) / eff_skill()
					look_at_pt = P["node"].position
					game.place_wet_sign(P)
			else:
				activity = "Paspas yapıyor"; v.play("sweep")
				timer -= dt
				if timer <= 0.0:
					game.mopped(P); _done()
		"table":
			var T: Fixture = t["table"]
			if not game.fixtures.has(T) or not T.dirty:
				T.claimed = 0; _done(); return
			if t["phase"] == "go":
				activity = "Kirli masaya gidiyor"; v.play("walk")
				var acc3: Vector2i = game.nearest_access(T, position)
				if not same_dest(acc3, T.lvl): go_to_any(game, acc3, T.lvl)
				if move(dt, game):
					t["phase"] = "wipe"; timer = 2.0 / eff_skill(); look_at_pt = T.center()
			else:
				activity = "Masayı siliyor"; v.play("work")
				timer -= dt
				if timer <= 0.0:
					game.clean_table(T); _done()
		"rest":
			var S: Fixture = t["spot"]
			if not game.fixtures.has(S):
				_done(); return
			if t["phase"] == "go":
				activity = "Molaya gidiyor"; v.play("walk")
				var acc4: Vector2i = game.nearest_access(S, position)
				if not same_dest(acc4, S.lvl): go_to_any(game, acc4, S.lvl)
				if move(dt, game):
					if S.def.has("room"):
						t["phase"] = "enter"; t["door"] = position
					else:
						t["phase"] = "rest"; timer = 11.0; look_at_pt = S.center()
			elif t["phase"] == "enter":
				activity = "Mola odasına geçiyor"; v.play("walk")
				if _step_to(game.room_inside(S), dt):
					t["phase"] = "rest"; timer = 9.0; look_at_pt = null
					facing = S.rotation.y
			elif t["phase"] == "leave_room":
				activity = "Moladan dönüyor"; v.play("walk")
				if _step_to(t["door"], dt): _done()
			else:
				activity = "Mola odasında dinleniyor" if S.def.has("room") else "Çay molasında"; v.play("sit")
				timer -= dt
				energy = minf(100.0, energy + dt * 5.5 * float(S.def.get("rest", 1.0)))
				if timer <= 0.0 or energy >= 98.0:
					if t.has("door"): t["phase"] = "leave_room"
					else: _done()
		"bake":
			var O: Fixture = t["oven"]
			if not game.fixtures.has(O):
				_done(); return
			if t["phase"] == "go":
				activity = "Fırına geçiyor"; v.play("walk")
				var acc5: Vector2i = game.nearest_access(O, position)
				if not same_dest(acc5, 0): go_to_any(game, acc5, 0)
				if move(dt, game):
					t["phase"] = "bake"; timer = 9.0 / eff_skill(); look_at_pt = O.center(); O.baking = true
			else:
				activity = "Hamur yoğuruyor, fırın yanıyor"; v.play("work")
				timer -= dt
				if timer <= 0.0:
					O.baking = false; O.claimed = 0
					# bake whichever stocked bread is lowest (pide only in Ramazan)
					var pid := "simit"
					var low := 1 << 30
					for b in DB.BAKERY:
						if game.is_stocked(b) and game.calendar.product_active(game.day, b) and int(game.backstock.get(b, 0)) < low:
							low = int(game.backstock.get(b, 0)); pid = b
					var n := mini(8, game.depot_capacity() - game.backstock_total())
					if n > 0:
						game.add_fresh(pid, n, 1.0)
						game.backstock[pid] = int(game.backstock.get(pid, 0)) + n
						var cost := int(round(n * DB.BAKED[pid]))
						game.money -= cost; game.stats["purchases"] += cost
						game.depot_changed()
						game.float_text(O.center() + Vector3(0, 1.9, 0), "+%d sıcak %s" % [n, DB.product(pid)["name"].to_lower()], Cfg.TERRA_DARK)
					_done()
		"repair":
			var C: Dictionary = t["conn"]
			if not C["broken"]:
				C["claimed"] = 0; _done(); return
			var bt: Vector2i = t["tile"]
			if t["phase"] == "go":
				activity = "%s tamirine gidiyor" % C["def"]["name"]; v.play("walk")
				if not same_dest(bt, t["lvl"]):
					if not go_to_any(game, bt, t["lvl"]) and not riding():
						cancel_task(game); return
				if move(dt, game):
					t["phase"] = "fix"; timer = 14.0 / eff_skill()
					var b: Rect2i = C["def"]["blocked"]
					look_at_pt = Vector3(Cfg.rc(b).x, position.y, Cfg.rc(b).y)
			else:
				activity = "Tamir ediyor"; v.play("work")
				timer -= dt
				if timer <= 0.0:
					game.mall.fixed(C, true); C["claimed"] = 0; think("happy", 2.0); _done()
		"wc":
			var W: Fixture = t["wc"]
			if not game.fixtures.has(W) or not W.dirty:
				if game.fixtures.has(W): W.claimed = 0
				_done(); return
			if t["phase"] == "go":
				activity = "Tuvaletleri temizlemeye gidiyor"; v.play("walk")
				var acc6: Vector2i = game.nearest_access(W, position)
				if not same_dest(acc6, W.lvl): go_to_any(game, acc6, W.lvl)
				if move(dt, game):
					t["phase"] = "scrub"; timer = 4.0 / eff_skill(); look_at_pt = W.center()
			else:
				activity = "Tuvaleti temizliyor"; v.play("sweep")
				timer -= dt
				if timer <= 0.0:
					game.clean_wc(W); _done()
		"chase":
			var c: Customer = t["target"]
			t["t"] += dt
			if not is_instance_valid(c) or c.removed or c.state in ["caught", "exit", "flee"] or t["t"] > 25.0:
				_done(); return
			activity = "Şüphelinin peşinde!"; v.play("walk")
			var ct := c.tile()
			if dest.is_empty() or absi(dest["tile"].x - ct.x) + absi(dest["tile"].y - ct.y) > 1: go_to_any(game, ct, 0)
			move(dt, game)
			if position.distance_to(c.position) < 1.3:
				c.be_caught(game)
				game.stats["caught_guard"] += 1
				think("happy", 2.0)
				_done()
