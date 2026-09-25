class_name Customer
extends Agent
## Shopper state machine: door -> shelves -> queue -> pay -> leave, with readable reactions.

const SKIN := [Color("f6d2b8"), Color("e8b894"), Color("d29a74"), Color("b57b55"), Color("8d5a3b"), Color("f1c7a5")]
const HAIR := [Color("2b1d16"), Color("4a2f1f"), Color("7a4b2a"), Color("b88a4a"), Color("1a1a1a"), Color("8e3b24")]
const GREY := [Color("d9d6d0"), Color("bcb7ae"), Color("e8e4dc")]
const INSIDE := ["decide", "to_cart", "to_shelf", "browse", "to_queue", "queue", "paying", "to_exit", "caught"]

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
var stolen: Array = []
var suspect := false
var has_cart := false
var slip_t := 0.0
var search_t := 0.0
var car_slot := -1 # parking-lot slot when the shopper came by car
var resident: Dictionary = {} # a named regular from the Neighborhood, or empty
var deli_wait := 0.0

func thief() -> bool: return arch != null and arch.get("thief", false)

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

func setup_customer(a, is_shopper: bool, game, res := {}) -> void:
	arch = a
	shopper = is_shopper
	resident = res
	if not res.is_empty(): init_agent(res["look"], res["name"])
	else: init_agent(random_look(a), Cfg.NAMES.pick_random())
	budget = int(randf_range(a["budget"][0], a["budget"][1])) if a != null else 0
	speed = a["speed"] * randf_range(0.92, 1.08) if a != null else randf_range(1.1, 1.5)
	if a != null and is_shopper:
		var n := int(round(randf_range(a["list"][0], a["list"][1])))
		var pool := []
		for pid in a["wants"]:
			# people know what the shop carries: products it never stocks are asked for far less often
			if DB.product(pid)["stage"] <= game.stage: pool.append([pid, float(a["wants"][pid]) * (1.0 if game.is_stocked(pid) else 0.15)])
		if not res.is_empty():
			for pid in game.neighborhood.wants_for(res):
				if DB.product(pid)["stage"] > game.stage or wants.any(func(w): return w["pid"] == pid): continue
				wants.append({"pid": pid, "qty": 1, "status": "pending", "tried": {}})
				for e in pool:
					if e[0] == pid: pool.erase(e); break
				n -= 1
		for i in n:
			if pool.is_empty(): break
			var tot := 0.0
			for e in pool: tot += e[1] * game.demand_mul(e[0])
			var r := randf() * tot
			var k := 0
			while k < pool.size() - 1:
				r -= pool[k][1] * game.demand_mul(pool[k][0])
				if r <= 0.0: break
				k += 1
			var pid: String = pool[k][0]
			pool.remove_at(k)
			wants.append({"pid": pid, "qty": 2 if (a["id"] == "aile" or a["id"] == "haftalik") and randf() < 0.4 else 1, "status": "pending", "tried": {}})

func spent() -> int:
	var s := 0
	for b in basket: s += int(b["price"])
	return s

func inside() -> bool: return INSIDE.has(state)

func log_thought(icon: String, text: String, game, show := true) -> void:
	thoughts.push_front({"icon": icon, "text": text, "t": game.clock})
	if thoughts.size() > 6: thoughts.pop_back()
	if show: think(icon)

var _umbrella := false
const OUTDOOR := ["walkby", "exit", "to_door", "leaving", "flee", "to_car"]

func update(dt: float, game) -> void:
	var v := view
	var want: bool = game.calendar.weather == "yagmur" and OUTDOOR.has(state)
	if want != _umbrella:
		_umbrella = want
		v.set_umbrella(want, [Color("d6333a"), Color("2f6fb5"), Color("f2b33d"), Color("1f8a86"), Color("2a2233")][get_instance_id() % 5])
	if slip_t > 0.0:
		slip_t -= dt; v.play("fall"); moving = 0.0
		if slip_t <= 0.0: v.play("idle")
		return
	if inside() and state != "caught": _check_puddle(game)
	match state:
		"in_car":
			if game.street.slot_parked(car_slot):
				hidden_agent = false
				position = Vector3(floori(game.street.slot_x(car_slot)) + 0.5, 0.02, Cfg.FAR_WALK_Z0 + 1.5)
				state = "to_door"
				go_to(game, Vector2i(door_x, game.grid.interior().end.y))
				log_thought("happy", "Arabayı otoparka bıraktım, karşıya geçeyim.", game, false)
		"to_car":
			v.play("walk")
			if move(dt, game):
				game.street.car_leave(car_slot); car_slot = -1
				removed = true
		"walkby", "exit":
			v.play("walk")
			if move(dt, game): removed = true
		"to_door":
			v.play("walk")
			if move(dt, game):
				var crowd: bool = game.customers_inside() >= game.max_inside()
				if crowd or not game.is_open():
					if not thief():
						log_thought("crowd", "İçerisi çok kalabalık, vazgeçtim." if crowd else "Dükkân kapalı.", game)
						game.stats["lost"] += 1
						if crowd: game.stats["lost_crowd"] += 1
					leave_street(game)
				else:
					if not thief(): game.stats["visitors"] += 1
					GameAudio.play("bell", -16.0, 1.5)
					var station = null
					if arch.get("cart", false):
						for f in game.fixtures:
							if f.def["kind"] == "carts": station = f; break
					if station != null:
						state = "to_cart"
						go_to(game, game.nearest_access(station, position))
					else:
						v.ensure_basket()
						if arch.get("cart", false):
							wants = wants.slice(0, 3); mood -= 6; flags["nocart"] = true
						state = "decide"
						go_to(game, Vector2i(door_x, game.grid.front_z()))
		"to_cart":
			v.play("walk")
			if move(dt, game):
				has_cart = true; v.set_cart(true)
				next_want(game)
		"decide":
			v.play("walk")
			if move(dt, game):
				if flags.has("nocart"): log_thought("box", "Araba yok, bu sepete her şey sığmaz. Listemi kısalttım.", game)
				next_want(game)
		"to_shelf":
			v.play("walk")
			_inside_tick(dt, game)
			if move(dt, game):
				state = "browse"; timer = randf_range(0.8, 1.5) + search_t; search_t = 0.0
				look_at_pt = shelf.center() if shelf else null
		"browse":
			v.play("reach")
			_inside_tick(dt, game)
			if shelf and shelf.def.get("staffed", false) and not thief():
				# the deli counter needs its usta: wait a little, then give up
				if not game.deli_staffed(shelf):
					deli_wait += dt; v.play("idle")
					if deli_wait > 9.0:
						deli_wait = 0.0; mood -= 8
						log_thought("nocashier", "Şarküteride kimse yok, bekledim bekledim…", game)
						for w in wants:
							if w["status"] == "pending" and DB.product(w["pid"])["display"] == "deli":
								w["status"] = "notfound"
								game.stats["missed"][w["pid"]] = int(game.stats["missed"].get(w["pid"], 0)) + 1
						next_want(game)
					return
				elif not flags.has("deli_served"):
					flags["deli_served"] = true; timer += 2.2
					log_thought("happy", "Usta ince ince kesti, tarttı.", game, false)
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
				var self_s: bool = reg.def.get("self", false)
				var staffed: bool = self_s or (reg.cashier != null and reg.cashier.at_register(reg))
				if idx == 0 and staffed:
					state = "paying"
					var sk: float = 1.0 if self_s else reg.cashier.eff_skill()
					timer = (2.0 + 0.55 * basket.size()) * (0.65 if game.upgrades.has("pos") else 1.0) * float(reg.def.get("service", 1.0)) / sk
					if not self_s:
						var tr: String = reg.cashier.persona
						if tr == "geveze":
							timer *= 1.15; mood += 5
							if randf() < 0.3: log_thought("happy", "%s hal hatır sordu, ne tatlı insan." % reg.cashier.person_name, game, false)
						elif tr == "guleryuz":
							mood += 6
							if randf() < 0.3: log_thought("happy", "Kasadaki %s hep gülümsüyor." % reg.cashier.person_name, game, false)
				elif idx == 0 and not staffed and not flags.has("nocashier"):
					flags["nocashier"] = true; log_thought("nocashier", "Kasada kimse yok!", game)
			else:
				v.play("walk")
				if state == "queue": wait += dt
		"paying":
			v.play("pay")
			timer -= dt
			if timer <= 0.0:
				if register and register.def.get("self", false) and basket.size() > 2 and randf() < 0.08:
					var b: Dictionary = basket.pop_back()
					game.record_shrink(b["pid"])
				game.checkout(self)
				if register: register.queue.erase(self)
				if wait < arch["patience"] * 0.3: mood += 6
				finish_visit(game, true)
		"leaving":
			v.play("walk")
			if move(dt, game): leave_street(game)
		"to_exit":
			v.play("walk")
			_inside_tick(dt, game)
			if move(dt, game):
				var res: String = game.thief_at_door(self)
				if res == "caught": be_caught(game)
				elif res == "alarm":
					state = "flee"; speed_mul = 1.7
					go_to(game, Vector2i(exit_x, Cfg.SIDEWALK_Z0 + 1))
				else:
					game.record_theft(self); leave_street(game)
		"flee":
			v.play("walk")
			if move(dt, game): removed = true
		"caught":
			v.play("angry"); moving = 0.0
			timer -= dt
			if timer <= 0.0:
				speed_mul = 0.8; state = "leaving"
				go_to(game, Vector2i(door_x, game.grid.interior().end.y))

func be_caught(game) -> void:
	state = "caught"; timer = 2.2; path = []; has_goal = false
	for pid in stolen: game.backstock[pid] = int(game.backstock.get(pid, 0)) + 1
	game.stats["caught"] += 1
	game.totals["caught"] = int(game.totals.get("caught", 0)) + 1
	stolen.clear()
	view.set_basket_items([])
	log_thought("angry", "Yakalandım…", game)
	game.float_text(position + Vector3(0, view.head_y + 0.6, 0), "Yakalandı!", Cfg.TEAL)

func _check_puddle(game) -> void:
	var p = game.puddle_at(tile(), lvl)
	if p == null or p["dry"] > 0.0: return
	var key := "slip%d" % p["id"]
	if flags.has(key): return
	flags[key] = true
	# the yellow warning sign makes people watch their step
	if randf() < (0.07 if p.get("sign") != null else 0.4):
		slip_t = 1.7; mood -= 16
		GameAudio.play("slip", -6.0, 0.5)
		game.stats["slips"] += 1
		log_thought("slip", "Kaydım! Kimse paspas yapmıyor mu?", game)
		game.alert("slip", "slip", "Bir müşteri ıslak zeminde kaydı! Temizlik görevlisi paspas yapıp uyarı levhası koyar.", "bad", p["node"].position, 40.0)

func _inside_tick(dt: float, game) -> void:
	var t := tile()
	if not thief() and state in ["to_shelf", "to_queue"]: _check_endcap(game)
	if arch and randf() < arch["litter"] * dt and not game.bin_near(t, lvl): game.drop_litter(t, lvl)
	for b in basket:
		if ["kola", "ayran", "sut", "su"].has(b["pid"]):
			if randf() < 0.0008 * dt: game.spill_at(t, lvl, "Bir müşteri içeceğini döktü")
			break
	if not flags.has("dirty") and game.litter_near(t, 1.6, lvl):
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
			if w["status"] == "notfound" and not thief():
				# a regular's favourite or a staple hurts; an odd request the shop never carried barely does
				mood -= 13 if DB.product(w["pid"]).get("staple", false) or not resident.is_empty() else 3
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
		if thief():
			if stolen.size() > 0:
				state = "to_exit"; go_to(game, Vector2i(door_x, game.grid.front_z()))
			else:
				state = "leaving"; go_to(game, Vector2i(door_x, game.grid.interior().end.y))
			return
		if basket.size() > 0: pick_register(game)
		else:
			log_thought("angry" if mood < 40 else "wallet", "Eli boş çıkıyorum.", game)
			finish_visit(game, false)
		return
	var bw: Dictionary = best[0]
	var bf: Fixture = best[1]
	shelf = bf
	deli_wait = 0.0
	bw["tried"][bf.uid] = true
	if game.stage >= 2 and not thief() and not game.sign_near(bf):
		search_t = 2.4; mood -= 3
		if not flags.has("lost"):
			flags["lost"] = true; log_thought("notfound", "Reyonu bulmak zor, levha yok mu?", game)
	var acc: Array = []
	for t in bf.access():
		if game.grid.walkable(t.x, t.y): acc.append(t)
	acc.sort_custom(func(a, b): return Vector2(a.x + 0.5 - position.x, a.y + 0.5 - position.z).length() < Vector2(b.x + 0.5 - position.x, b.y + 0.5 - position.z).length())
	var target = acc[randi() % mini(2, acc.size())] if acc.size() > 0 else null
	if target == null or not go_to(game, target):
		bw["status"] = "notfound"
		if not thief(): mood -= 10; log_thought("notfound", "Rafa ulaşamıyorum, yol kapalı!", game)
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
				w["status"] = "oos"
				if not thief():
					mood -= 16
					log_thought("empty", "%s bitmiş!" % p["name"], game)
					game.stats["missed"][w["pid"]] = int(game.stats["missed"].get(w["pid"], 0)) + 1
			continue
		if thief():
			_try_steal(game, w, slot, f); continue
		var price: int = game.effective_price(w["pid"])
		var tol: float = arch["tol"] + game.tolerance_bonus()
		if price > game.ref_price(w["pid"]) * (1.0 + tol) and not game.is_discounted(w["pid"]):
			w["status"] = "expensive"; mood -= 12
			log_thought("price", "%s ₺%d? Çok pahalı!" % [p["name"], price], game)
			game.stats["expensive"][w["pid"]] = int(game.stats["expensive"].get(w["pid"], 0)) + 1
			continue
		var fresh: float = game.slot_fresh(slot) if DB.BAKERY.has(w["pid"]) else 1.0
		if fresh < 0.3 and not game.evening_sale(w["pid"]):
			mood -= 8
			if randf() < 0.5:
				w["status"] = "stale"; log_thought("dirty", "%s bayatlamış, almadım." % p["name"], game)
				game.stats["missed"][w["pid"]] = int(game.stats["missed"].get(w["pid"], 0)) + 1
				continue
			log_thought("dirty", "%s biraz bayat ama idare eder." % p["name"], game, false)
		var multi: bool = game.is_multi(w["pid"])
		var want_n := maxi(int(w["qty"]), 3) if multi else int(w["qty"])
		var took := 0
		var credit_room: int = game.neighborhood.headroom(resident) if not resident.is_empty() else 0
		for q in want_n:
			var unit_price := 0 if multi and (q + 1) % 3 == 0 else price
			if slot["stock"] <= 0: break
			if spent() + unit_price > budget:
				if spent() + unit_price > budget + credit_room: break
				flags["credit_need"] = true
			slot["stock"] -= 1
			basket.append({"pid": w["pid"], "price": unit_price}); took += 1
		if multi and took >= 3:
			game.stats["multi"] += 1
			if randf() < 0.5: log_thought("cheap", "3 al 2 öde! %s stok yaptım." % p["name"], game)
		if took == 0:
			w["status"] = "budget"; mood -= 6; log_thought("wallet", "Param yetmiyor.", game)
			continue
		w["status"] = "got"; mood += 6
		if game.is_discounted(w["pid"]):
			mood += 4
			if randf() < 0.6: log_thought("cheap", "%s indirimde, iyi denk geldi!" % p["name"], game)
		elif price <= game.ref_price(w["pid"]) * 0.9 and randf() < 0.5:
			mood += 4; log_thought("cheap", "%s ucuzmuş!" % p["name"], game)
		if DB.BAKERY.has(w["pid"]) and fresh >= 0.75 and not flags.has("fresh"):
			flags["fresh"] = true; mood += 5; log_thought("happy", "%s sıcacık, fırından yeni çıkmış!" % p["name"], game)
		elif game.evening_sale(w["pid"]) and randf() < 0.5:
			log_thought("cheap", "Akşam indirimi, %s ucuzladı!" % p["name"].to_lower(), game, false)
		game.stock_changed(f)
	view.set_basket_items(basket.map(func(b): return b["pid"]) + stolen)
	next_want(game)

func _try_steal(game, w: Dictionary, slot: Dictionary, f: Fixture) -> void:
	var watch: Dictionary = game.watch_info(tile(), lvl)
	if watch["staff"] != null:
		w["status"] = "skipped"
		if not flags.has("nervous"):
			flags["nervous"] = true; log_thought("sneak", "Burada göz var… başka rafa bakayım.", game, false)
		return
	if watch["camera"] and randf() < 0.5:
		w["status"] = "skipped"; log_thought("sneak", "Kamera var, riskli.", game, false)
		return
	slot["stock"] -= 1
	stolen.append(w["pid"]); w["status"] = "stolen"
	game.stock_changed(f)
	if watch["camera"]:
		suspect = true
		think("sneak", 6.0)
		game.suspect_seen(self, "Kamera bir müşterinin ürünü cebine attığını kaydetti!")

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
			if price > game.ref_price(p["id"]) * (1.0 + arch["tol"]) or spent() + price > budget: continue
			if randf() < arch["impulse"] * game.impulse_mul():
				s["stock"] -= 1
				basket.append({"pid": p["id"], "price": price})
				view.set_basket_items(basket.map(func(b): return b["pid"]))
				game.stock_changed(f)
				game.stats["impulse"] += 1
				game.float_text(position + Vector3(0, view.head_y + 0.4, 0), "+" + p["name"], Cfg.VIOLET)
				log_thought("happy", "Kasanın yanında %s gördüm, aldım." % p["name"].to_lower(), game, false)
				return

## "gondol başı" displays catch the eye of shoppers walking past
func _check_endcap(game) -> void:
	for f in game.fixtures:
		if not f.def.get("endcap", false) or impulse_checked.has(-f.uid): continue
		if Vector2(f.center().x - position.x, f.center().z - position.z).length() > 1.9: continue
		impulse_checked[-f.uid] = true
		var s: Dictionary = f.slots[0]
		if s["pid"] == "" or s["stock"] <= 0: continue
		var pid: String = s["pid"]
		if basket.any(func(b): return b["pid"] == pid) or wants.any(func(w): return w["pid"] == pid): continue
		var p: Dictionary = DB.product(pid)
		var price: int = game.effective_price(pid)
		if price > game.ref_price(p["id"]) * (1.0 + arch["tol"]) or spent() + price > budget: continue
		if randf() < (0.2 + arch["impulse"]) * game.impulse_mul() * (1.4 if game.is_discounted(pid) or game.is_multi(pid) else 1.0):
			s["stock"] -= 1
			basket.append({"pid": pid, "price": price})
			view.set_basket_items(basket.map(func(b): return b["pid"]))
			game.stock_changed(f)
			game.stats["impulse"] += 1; game.stats["endcap"] += 1
			game.float_text(position + Vector3(0, view.head_y + 0.4, 0), "+" + p["name"], Cfg.VIOLET)
			log_thought("happy", "Gondol başında %s gözüme çarptı, aldım." % p["name"].to_lower(), game, false)

func pick_register(game) -> void:
	var regs: Array = game.fixtures.filter(func(f): return f.def["kind"] == "register")
	if regs.is_empty():
		log_thought("nocashier", "Kasa yok! Nasıl ödeyeceğim?", game)
		_return_items(game); finish_visit(game, false)
		return
	var score := func(f) -> float:
		var sv: float = f.def.get("service", 1.0)
		return (0.0 if (f.def.get("self", false) or f.cashier) else 50.0) + f.queue.size() * sv + (4.0 if f.def.get("self", false) and basket.size() > 5 else 0.0)
	regs.sort_custom(func(a, b): return score.call(a) < score.call(b))
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
	if not thief(): game.record_visit(self, paid)
	if not resident.is_empty() and not flags.has("visited"):
		flags["visited"] = true
		game.neighborhood.after_visit(game, self)
	if paid and mood >= 60: log_thought("happy", "Güzel dükkân, yine gelirim!", game)
	elif paid and mood < 40: log_thought("angry", "Aldım ama memnun kalmadım.", game)
	state = "leaving"
	register = null
	if has_cart: has_cart = false; view.set_cart(false)
	go_to(game, Vector2i(door_x, game.grid.interior().end.y))

func leave_street(game) -> void:
	if car_slot >= 0:
		state = "to_car"
		go_to(game, Vector2i(floori(game.street.slot_x(car_slot)), Cfg.FAR_WALK_Z0 + 1))
		return
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
		"to_cart": return "Araba alıyor"
		"to_exit": return "Ödemeden kapıya gidiyor!" if suspect else "Kapıya yöneliyor"
		"flee": return "Kaçıyor!"
		"caught": return "Güvenliğe yakalandı"
	return "Ayrılıyor"

func face_mood() -> String:
	return "happy" if mood >= 70 else ("neutral" if mood >= 45 else ("sad" if mood >= 25 else "angry"))
