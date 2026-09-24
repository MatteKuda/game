class_name Staff
extends Agent
## Employees: owner / cashier stay at a register; stockers carry boxes and sweep.

var role := "stocker"
var wage := 0
var skill := 1.0
var task = null # Dictionary
var timer := 0.0
var idle_t := 0.0
var register: Fixture = null
var activity := "Hazır"

static func look_for(r: String) -> Dictionary:
	var skin: Color = Customer.SKIN.pick_random()
	match r:
		"owner": return {"body": "barbarian", "skin": Color("e8b894"), "hair": Color("3a2a20"), "top": Color("fbf1e2"), "bottom": Color("2b3a55"), "shoes": Color("2a2a2e"), "accent": Cfg.TERRA, "height": 1.04}
		"cashier": return {"body": "rogue", "skin": skin, "hair": Customer.HAIR.pick_random(), "top": Cfg.TEAL, "bottom": Color("2b3a55"), "shoes": Color("2a2a2e"), "accent": Cfg.MUSTARD, "height": 1.0}
		_: return {"body": "knight", "skin": skin, "hair": Customer.HAIR.pick_random(), "top": Color("2f5d8a"), "bottom": Color("24324a"), "shoes": Color("2a2a2e"), "accent": Cfg.MUSTARD, "height": 1.0}

func setup_staff(r: String, nm: String, w: int, sk: float) -> void:
	role = r; wage = w; skill = sk
	init_agent(look_for(r), nm)
	speed = 1.6

func at_register(reg: Fixture) -> bool:
	if register != reg or task != null: return false
	var b: Vector2i = reg.back()[0]
	return absf(position.x - (b.x + 0.5)) < 0.35 and absf(position.z - (b.y + 0.5)) < 0.35

func update(dt: float, game) -> void:
	if role == "owner" or role == "cashier":
		_cashier_logic(dt, game); return
	if task == null: task = game.find_restock_task(self, 0.55)
	if task == null: task = game.find_clean_task(self)
	if task != null:
		_do_task(dt, game); return
	activity = "Boşta, iş bekliyor"
	if has_goal and not move(dt, game):
		view.play("walk"); return
	view.play("idle")
	idle_t += dt
	if idle_t > 6.0:
		idle_t = 0.0
		var r := game.grid.interior() as Rect2i
		for i in 12:
			var tx := r.position.x + randi() % r.size.x
			var tz := r.position.y + randi() % (r.size.y - 1)
			if game.grid.walkable(tx, tz):
				go_to(game, Vector2i(tx, tz)); break

func _cashier_logic(dt: float, game) -> void:
	if register == null or not game.fixtures.has(register) or register.cashier != self:
		register = null
		for f in game.fixtures:
			if f.def["kind"] == "register" and (f.cashier == null or f.cashier == self or not game.staff.has(f.cashier)):
				register = f; break
		if register: register.cashier = self
		has_goal = false
	var reg := register
	var busy := reg != null and reg.queue.size() > 0
	if task != null and busy and not (task["kind"] == "restock" and (task["phase"] == "to_shelf" or task["phase"] == "stock")):
		cancel_task(game)
	if task != null:
		_do_task(dt, game); return
	if reg:
		var b: Vector2i = reg.back()[0]
		if not same_goal(b): go_to(game, b)
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
					if not game.has_role("stocker"):
						t = game.find_restock_task(self, 0.4)
						if t == null: t = game.find_clean_task(self)
					if t != null: task = t; idle_t = 0.0
			else: idle_t = 0.0
		else:
			view.play("walk"); activity = "Kasaya dönüyor"
	else:
		activity = "Kasa yok — boşta"
		var t = game.find_restock_task(self, 0.5)
		if t == null: t = game.find_clean_task(self)
		if t != null: task = t
		else: view.play("idle")

func cancel_task(game) -> void:
	if task == null: return
	if task["kind"] == "restock":
		task["fixture"].slots[task["slot"]]["claimed"] = 0
		if task["phase"] == "to_shelf" or task["phase"] == "stock":
			game.backstock[task["pid"]] = int(game.backstock.get(task["pid"], 0)) + int(task["qty"])
	elif task["kind"] == "clean":
		task["litter"]["claimed"] = 0
	task = null
	view.set_carry(false)
	has_goal = false

func _do_task(dt: float, game) -> void:
	var t: Dictionary = task
	var v := view
	if t["kind"] == "restock":
		var fx: Fixture = t["fixture"]
		var dep: Fixture = t["depot"]
		if not game.fixtures.has(fx) or not game.fixtures.has(dep):
			cancel_task(game); return
		match t["phase"]:
			"to_depot":
				activity = "Depoya gidiyor"
				v.play("walk")
				var acc: Vector2i = game.nearest_access(dep, position)
				if not same_goal(acc): go_to(game, acc)
				if move(dt, game):
					t["phase"] = "pickup"; timer = 0.9; look_at_pt = dep.center()
			"pickup":
				activity = "Koli alıyor"
				v.play("reach")
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
					t["phase"] = "to_shelf"; has_goal = false
			"to_shelf":
				activity = "%s rafa taşıyor" % DB.product(t["pid"])["name"]
				v.play("carry")
				var acc2: Vector2i = game.nearest_access(fx, position)
				if not has_goal: go_to(game, acc2)
				if move(dt, game):
					t["phase"] = "stock"; timer = 1.4 / skill; look_at_pt = fx.center(); v.set_carry(false)
			"stock":
				activity = "Rafı dolduruyor"
				v.play("work")
				timer -= dt
				if timer <= 0.0:
					var s: Dictionary = fx.slots[t["slot"]]
					if s["pid"] == t["pid"]:
						var room: int = fx.cap() - int(s["stock"])
						var put := mini(room, int(t["qty"]))
						s["stock"] += put
						if int(t["qty"]) - put > 0: game.backstock[t["pid"]] += int(t["qty"]) - put
					else:
						game.backstock[t["pid"]] += int(t["qty"])
					s["claimed"] = 0
					game.stock_changed(fx)
					game.float_text(fx.center() + Vector3(0, float(fx.model["height"]) + 0.2, 0), "+%d %s" % [t["qty"], DB.product(t["pid"])["name"]], Cfg.BLUE)
					task = null; has_goal = false; look_at_pt = null
	elif t["kind"] == "clean":
		var L: Dictionary = t["litter"]
		if not game.litter.has(L):
			task = null; has_goal = false; return
		if t["phase"] == "go":
			activity = "Çöpü temizlemeye gidiyor"
			v.play("walk")
			var tgt: Vector2i = game.nearest_walkable(L["tile"])
			if not same_goal(tgt):
				if not go_to(game, tgt):
					cancel_task(game); return
			if move(dt, game):
				t["phase"] = "sweep"; timer = 1.8 / skill
				look_at_pt = Vector3(L["tile"].x + 0.5, 0, L["tile"].y + 0.5)
		else:
			activity = "Süpürüyor"
			v.play("sweep")
			timer -= dt
			if timer <= 0.0:
				game.remove_litter(L)
				task = null; has_goal = false; look_at_pt = null
