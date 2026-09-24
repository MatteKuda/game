class_name Customer
extends Agent
## Shopper state machine: door -> shelves -> queue -> pay -> leave, with readable reactions.

const SKIN := [Color("f6d2b8"), Color("e8b894"), Color("d29a74"), Color("b57b55"), Color("8d5a3b"), Color("f1c7a5")]
const HAIR := [Color("2b1d16"), Color("4a2f1f"), Color("7a4b2a"), Color("b88a4a"), Color("1a1a1a"), Color("8e3b24")]
const GREY := [Color("d9d6d0"), Color("bcb7ae"), Color("e8e4dc")]
const INSIDE := ["decide", "to_shelf", "browse", "to_queue", "queue", "paying"]

var arch = null # Dictionary or null (ambient walker)
var shopper := false
var state := "to_door"
var wants: Array = [] # [{pid, qty, status, tried: {}}]
var basket: Array = [] # [{pid, price}]
var budget := 0
var mood := 70.0
var wait := 0.0
var timer := 0.0
var shelf: Fixture = null
var register: Fixture = null
var queue_idx := -1
var exit_x := 0
var door_x := 22
var thoughts: Array = []
var flags := {}
var impulse_checked := {}

static func random_look(a) -> Dictionary:
	var old: bool = a != null and a["id"] == "emekli"
	var body := "rogue"
	if a != null: body = a["body"]
	else: body = ["rogue", "rogue", "mage", "barbarian"].pick_random()
	return {
		"body": body,
		"skin": SKIN.pick_random(),
		"hair": GREY.pick_random() if old else HAIR.pick_random(),
		"top": (a["tops"] as Array).pick_random() if a != null else [Color("9aa5b1"), Color("6d7b8a"), Color("c9b79c"), Color("8c6f5a"), Color("5f7f99"), Color("b27a6e")].pick_random(),
		"bottom": (a["bottoms"] as Array).pick_random() if a != null else [Color("2b3a55"), Color("3d3d45"), Color("5b4a3a")].pick_random(),
		"shoes": [Color("2a2a2e"), Color("6b4a33"), Color("f2f0ea"), Color("3a4a6a")].pick_random(),
		"accent": [Color("e0663c"), Color("1f8a86"), Color("f2b33d"), Color("6c4ab6"), Color("d6333a")].pick_random(),
		"height": randf_range(0.9, 0.97) if (a != null and a["id"] == "ogrenci") else randf_range(0.96, 1.05),
	}

func setup_customer(a, is_shopper: bool, game) -> void:
	arch = a
	shopper = is_shopper
	init_agent(random_look(a), Cfg.NAMES.pick_random())
	budget = int(randf_range(a["budget"][0], a["budget"][1])) if a != null else 0
	speed = a["speed"] * randf_range(0.92, 1.08) if a != null else randf_range(1.1, 1.5)
	if a != null and is_shopper:
		var n := int(round(randf_range(a["list"][0], a["list"][1])))
		var pool := []
		for pid in a["wants"]:
			if DB.product(pid)["stage"] <= game.stage: pool.append([pid, float(a["wants"][pid])])
		for i in n:
			if pool.is_empty(): break
			var tot := 0.0
			for e in pool: tot += e[1]
			var r := randf() * tot
			var k := 0
			while k < pool.size() - 1:
				r -= pool[k][1]
				if r <= 0.0: break
				k += 1
			var pid: String = pool[k][0]
			pool.remove_at(k)
			wants.append({"pid": pid, "qty": 2 if a["id"] == "aile" and randf() < 0.4 else 1, "status": "pending", "tried": {}})

func spent() -> int:
	var s := 0
	for b in basket: s += int(b["price"])
	return s

func inside() -> bool: return INSIDE.has(state)

func log_thought(icon: String, text: String, game, show := true) -> void:
	thoughts.push_front({"icon": icon, "text": text, "t": game.clock})
	if thoughts.size() > 6: thoughts.pop_back()
	if show: think(icon)

func update(dt: float, game) -> void:
	var v := view
	match state:
		"walkby", "exit":
			v.play("walk")
			if move(dt, game): removed = true
		"to_door":
			v.play("walk")
			if move(dt, game):
				var crowd: bool = game.customers_inside() >= game.max_inside()
				if crowd or not game.is_open():
					log_thought("crowd", "İçerisi çok kalabalık, vazgeçtim." if crowd else "Dükkân kapalı.", game)
					game.stats["lost"] += 1
					if crowd: game.stats["lost_crowd"] += 1
					leave_street(game)
				else:
					game.stats["visitors"] += 1
					v.ensure_basket()
					state = "decide"
					go_to(game, Vector2i(door_x, game.grid.front_z()))
		"decide":
			v.play("walk")
			if move(dt, game): next_want(game)
		"to_shelf":
			v.play("walk")
			_inside_tick(dt, game)
			if move(dt, game):
				state = "browse"; timer = randf_range(0.8, 1.5)
				look_at_pt = shelf.center() if shelf else null
		"browse":
			v.play("reach")
			_inside_tick(dt, game)
			timer -= dt
			if timer <= 0.0: _evaluate_shelf(game)
		"to_queue", "queue":
			_inside_tick(dt, game)
			var reg := register
			if reg == null or not game.fixtures.has(reg):
				pick_register(game); return
			var idx := reg.queue.find(self)
			if idx != queue_idx:
				queue_idx = idx
				var qs := reg.queue_slots
				var slot: Vector2i = qs[mini(idx, qs.size() - 1)] if qs.size() > 0 else reg.access()[0]
				go_to(game, slot)
			if move(dt, game):
				state = "queue"
				v.play("idle")
				look_at_pt = reg.center()
				wait += dt
				_check_impulse(game)
				var pat: float = arch["patience"] * game.patience_mul()
				if wait > pat * 0.55 and not flags.has("wait_warn"):
					flags["wait_warn"] = true; log_thought("wait", "Bu kuyruk hiç ilerlemiyor…", game); mood -= 8
				if wait > pat:
					_abandon(game); return
				var staffed: bool = reg.cashier != null and reg.cashier.at_register(reg)
				if idx == 0 and staffed:
					state = "paying"
					timer = (2.0 + 0.55 * basket.size()) * (0.65 if game.upgrades.has("pos") else 1.0) / reg.cashier.skill
				elif idx == 0 and not staffed and not flags.has("nocashier"):
					flags["nocashier"] = true; log_thought("nocashier", "Kasada kimse yok!", game)
			else:
				v.play("walk")
				if state == "queue": wait += dt
		"paying":
			v.play("pay")
			timer -= dt
			if timer <= 0.0:
				game.sale(self, spent())
				if register: register.queue.erase(self)
				if wait < arch["patience"] * 0.3: mood += 6
				finish_visit(game, true)
		"leaving":
			v.play("walk")
			if move(dt, game): leave_street(game)

func _inside_tick(dt: float, game) -> void:
	var t := tile()
	if arch and randf() < arch["litter"] * dt and not game.bin_near(t): game.drop_litter(t)
	if not flags.has("dirty") and game.litter_near(t, 1.6):
		flags["dirty"] = true; mood -= 7; log_thought("dirty", "Yerler çok kirli…", game)
	if not flags.has("ambiance") and game.plant_near(t):
		flags["ambiance"] = true; mood += 4 + (2 if game.upgrades.has("isik") else 0)
	if crowd_t > 2.5 and not flags.has("crowd"):
		flags["crowd"] = true; mood -= 6; log_thought("crowd", "Koridorlar çok dar, sıkıştım.", game)

func next_want(game) -> void:
	var best = null
	var best_d := 1e9
	for w in wants:
		if w["status"] != "pending": continue
		var cands := []
		for f in game.fixtures:
			if not f.is_display() or w["tried"].has(f.uid): continue
			for s in f.slots:
				if s["pid"] == w["pid"]: cands.append(f); break
		if cands.is_empty():
			w["status"] = "oos" if not w["tried"].is_empty() else "notfound"
			if w["status"] == "notfound":
				mood -= 13
				log_thought("notfound", "%s arıyordum, satılmıyor mu?" % DB.product(w["pid"])["name"], game)
				game.stats["missed"][w["pid"]] = int(game.stats["missed"].get(w["pid"], 0)) + 1
			continue
		for f in cands:
			var stocked := false
			for s in f.slots:
				if s["pid"] == w["pid"] and s["stock"] > 0: stocked = true
			var d := position.distance_to(f.center()) + (0.0 if stocked else 8.0)
			if d < best_d: best_d = d; best = [w, f]
	if best == null:
		if basket.size() > 0: pick_register(game)
		else:
			log_thought("angry" if mood < 40 else "wallet", "Eli boş çıkıyorum.", game)
			finish_visit(game, false)
		return
	var bw: Dictionary = best[0]
	var bf: Fixture = best[1]
	shelf = bf
	bw["tried"][bf.uid] = true
	var acc: Array = []
	for t in bf.access():
		if game.grid.walkable(t.x, t.y): acc.append(t)
	acc.sort_custom(func(a, b): return Vector2(a.x + 0.5 - position.x, a.y + 0.5 - position.z).length() < Vector2(b.x + 0.5 - position.x, b.y + 0.5 - position.z).length())
	var target = acc[randi() % mini(2, acc.size())] if acc.size() > 0 else null
	if target == null or not go_to(game, target):
		bw["status"] = "notfound"
		mood -= 10; log_thought("notfound", "Rafa ulaşamıyorum, yol kapalı!", game)
		next_want(game)
		return
	state = "to_shelf"

func _evaluate_shelf(game) -> void:
	var f := shelf
	look_at_pt = null
	for w in wants:
		if w["status"] != "pending": continue
		var slot = null
		var any := false
		for s in f.slots:
			if s["pid"] == w["pid"]:
				any = true
				if s["stock"] > 0 and slot == null: slot = s
		if not any: continue
		var p: Dictionary = DB.product(w["pid"])
		if slot == null:
			var other := false
			for o in game.fixtures:
				if o != f and o.is_display() and not w["tried"].has(o.uid):
					for s in o.slots:
						if s["pid"] == w["pid"] and s["stock"] > 0: other = true
			if not other:
				w["status"] = "oos"; mood -= 16
				log_thought("empty", "%s bitmiş!" % p["name"], game)
				game.stats["missed"][w["pid"]] = int(game.stats["missed"].get(w["pid"], 0)) + 1
			continue
		var price: int = game.effective_price(w["pid"])
		var tol: float = arch["tol"] + game.tolerance_bonus()
		if price > p["base"] * (1.0 + tol):
			w["status"] = "expensive"; mood -= 12
			log_thought("price", "%s ₺%d? Çok pahalı!" % [p["name"], price], game)
			game.stats["expensive"][w["pid"]] = int(game.stats["expensive"].get(w["pid"], 0)) + 1
			continue
		var took := 0
		for q in int(w["qty"]):
			if spent() + price > budget or slot["stock"] <= 0: break
			slot["stock"] -= 1
			basket.append({"pid": w["pid"], "price": price}); took += 1
		if took == 0:
			w["status"] = "budget"; mood -= 6; log_thought("wallet", "Param yetmiyor.", game)
			continue
		w["status"] = "got"; mood += 6
		if price <= p["base"] * 0.9 and randf() < 0.5:
			mood += 4; log_thought("cheap", "%s ucuzmuş!" % p["name"], game)
		game.stock_changed(f)
	view.set_basket_items(basket.map(func(b): return b["pid"]))
	next_want(game)

func _check_impulse(game) -> void:
	var t := tile()
	var key := t.x * 1000 + t.y
	if impulse_checked.has(key): return
	impulse_checked[key] = true
	for f in game.fixtures:
		if not f.is_display(): continue
		var near := false
		for a in f.access():
			if maxi(absi(a.x - t.x), absi(a.y - t.y)) <= 1: near = true
		if not near: continue
		for s in f.slots:
			if s["pid"] == "" or s["stock"] <= 0: continue
			var p: Dictionary = DB.product(s["pid"])
			if not p.get("impulse", false): continue
			var has := false
			for b in basket:
				if b["pid"] == p["id"]: has = true
			if has: continue
			var price: int = game.effective_price(p["id"])
			if price > p["base"] * (1.0 + arch["tol"]) or spent() + price > budget: continue
			if randf() < arch["impulse"] * game.impulse_mul():
				s["stock"] -= 1
				basket.append({"pid": p["id"], "price": price})
				view.set_basket_items(basket.map(func(b): return b["pid"]))
				game.stock_changed(f)
				game.stats["impulse"] += 1
				game.float_text(position + Vector3(0, view.head_y + 0.4, 0), "+" + p["name"], Cfg.VIOLET)
				log_thought("happy", "Kasanın yanında %s gördüm, aldım." % p["name"].to_lower(), game, false)
				return

func pick_register(game) -> void:
	var regs: Array = game.fixtures.filter(func(f): return f.def["kind"] == "register")
	if regs.is_empty():
		log_thought("nocashier", "Kasa yok! Nasıl ödeyeceğim?", game)
		_return_items(game); finish_visit(game, false)
		return
	regs.sort_custom(func(a, b): return (0 if a.cashier else 50) + a.queue.size() < (0 if b.cashier else 50) + b.queue.size())
	var reg: Fixture = regs[0]
	if register and register != reg: register.queue.erase(self)
	register = reg
	if not reg.queue.has(self): reg.queue.append(self)
	queue_idx = -1
	state = "to_queue"

func _return_items(game) -> void:
	for b in basket: game.backstock[b["pid"]] = int(game.backstock.get(b["pid"], 0)) + 1
	basket.clear()
	view.set_basket_items([])

func _abandon(game) -> void:
	if register: register.queue.erase(self)
	mood = minf(mood, 15.0) - 10.0
	log_thought("angry", "Yeter! Sepeti bırakıp gidiyorum.", game)
	view.play("angry")
	game.stats["abandoned"] += 1
	game.stats["lost_queue"] += 1
	_return_items(game)
	finish_visit(game, false)

func finish_visit(game, paid: bool) -> void:
	mood = clampf(mood, 0.0, 100.0)
	game.record_visit(self, paid)
	if paid and mood >= 60: log_thought("happy", "Güzel dükkân, yine gelirim!", game)
	elif paid and mood < 40: log_thought("angry", "Aldım ama memnun kalmadım.", game)
	state = "leaving"
	register = null
	go_to(game, Vector2i(door_x, game.grid.interior().end.y))

func leave_street(game) -> void:
	state = "exit"
	var t := tile()
	go_to(game, Vector2i(exit_x, t.y if t.y >= Cfg.SIDEWALK_Z0 and t.y < Cfg.SIDEWALK_Z1 else Cfg.SIDEWALK_Z0 + 1))

func status_label() -> String:
	match state:
		"walkby": return "Geçip gidiyor"
		"to_door": return "Dükkâna yöneliyor"
		"decide": return "İçeri giriyor"
		"to_shelf": return ("%s rafına gidiyor" % shelf.def["name"]) if shelf else "Raf arıyor"
		"browse": return "Ürünlere bakıyor"
		"to_queue": return "Kasaya gidiyor"
		"queue": return "Kuyrukta (%d. sırada)" % (queue_idx + 1)
		"paying": return "Ödeme yapıyor"
	return "Ayrılıyor"

func face_mood() -> String:
	return "happy" if mood >= 70 else ("neutral" if mood >= 45 else ("sad" if mood >= 25 else "angry"))
