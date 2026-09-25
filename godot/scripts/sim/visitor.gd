class_name Visitor
extends Agent
## AVM visitor: shops in tenant units, eats in the food court (with a seat if there is one),
## lets the kid play, rests on benches, rides escalators / the lift between floors.

var arch: Dictionary
var mall
var state := "to_mall"
var stops: Array = []
var stop := {}
var mood := 70.0
var spent := 0
var timer := 0.0
var exit_x := 0
var entrance_x := 7
var thoughts: Array = []
var flags := {}
var seat := {} # {table, i}
var child: CharacterView
var trail: Array = []
var child_play = null
var food_unit := {}
var target_fx: Fixture = null

func setup_visitor(a: Dictionary, m) -> void:
	arch = a; mall = m
	var look := Customer.random_look(null)
	look["body"] = a["body"]
	look["top"] = (a["tops"] as Array).pick_random()
	look["bottom"] = (a["bottoms"] as Array).pick_random()
	if a["id"] == "emekliz": look["hair"] = Customer.GREY.pick_random()
	init_agent(look, Cfg.NAMES.pick_random())
	speed = a["speed"] * randf_range(0.92, 1.08)
	if a.get("child", false):
		child = CharacterView.new()
		m.add_child(child)
		var cl := Customer.random_look(null)
		cl["body"] = "rogue"; cl["height"] = 0.62
		cl["top"] = [Color("f2b33d"), Color("61b3ff"), Color("e0663c"), Color("86d6b4"), Color("f08f86")].pick_random()
		child.setup(cl)
		child.position = position + Vector3(0.5, 0, 0.3)
	_plan(m.game)

func log_thought(icon: String, text: String, game, show := true) -> void:
	thoughts.push_front({"icon": icon, "text": text, "t": game.clock})
	if thoughts.size() > 6: thoughts.pop_back()
	if show: think(icon)

func _plan(game) -> void:
	var n := int(round(randf_range(arch["stops"][0], arch["stops"][1])))
	var cands := []
	for u in mall.units:
		if u["tenant"].is_empty() or u["tenant"]["def"].get("food", false): continue
		var cat: String = u["tenant"]["def"]["id"]
		cands.append({"stop": {"kind": "unit", "unit": u}, "w": float(arch["interests"].get(cat, 0.3)) * mall.event_boost(cat)})
	var fam: float = mall.event["def"].get("family", 1.0) if not mall.event.is_empty() else 1.0
	if game.fixtures.any(func(f): return f.def["kind"] == "play") and arch["interests"].has("play"): cands.append({"stop": {"kind": "play"}, "w": float(arch["interests"]["play"]) * fam})
	if game.fixtures.any(func(f): return f.def["kind"] == "bench") and arch["interests"].has("bench"): cands.append({"stop": {"kind": "bench"}, "w": float(arch["interests"]["bench"])})
	for i in n:
		if cands.is_empty(): break
		var tot := 0.0
		for c in cands: tot += c["w"]
		var r := randf() * tot
		var k := 0
		while k < cands.size() - 1:
			r -= cands[k]["w"]
			if r <= 0.0: break
			k += 1
		stops.append(cands[k]["stop"]); cands.remove_at(k)
	var h: float = game.hour()
	var meal := exp(-pow(h - 12.8, 2) / 2.0) + exp(-pow(h - 19.0, 2) / 2.5)
	if randf() < arch["hunger"] * (0.35 + meal): stops.insert(randi() % (stops.size() + 1), {"kind": "food"})
	if stops.is_empty(): stops.append({"kind": "bench"})

func update(dt: float, game) -> void:
	var v := view
	if not game.is_open() and state in ["browse", "bench", "play", "eat", "order"]: timer = minf(timer, 1.2)
	match state:
		"to_mall":
			v.play("walk")
			if move(dt, game):
				if not game.is_open():
					_leave_street(game); return
				state = "enter"; go_to(game, Vector2i(entrance_x, 15))
		"enter":
			v.play("walk")
			if move(dt, game):
				mall.stats["visitors"] += 1; _next(game)
		"to_stop":
			v.play("walk"); _ambient(dt, game)
			if move(dt, game): _arrive(game)
		"in_unit":
			v.play("walk")
			if move(dt, game): state = "browse"; timer = randf_range(3.5, 7.0)
		"browse":
			v.play("reach" if sin(timer * 2.0) > 0 else "idle")
			timer -= dt
			if timer <= 0.0:
				var u: Dictionary = stop["unit"]
				if not u["tenant"].is_empty(): mall.shop_at(self, u)
				go_to_any(game, mall.door_outside(u), u["def"]["floor"])
				state = "leaving"; flags["from_unit"] = true; stop = {}
		"to_counter":
			v.play("walk")
			if move(dt, game): state = "order"; timer = randf_range(2.5, 4.0)
		"order":
			v.play("pay")
			timer -= dt
			if timer <= 0.0:
				if not food_unit.is_empty() and not food_unit["tenant"].is_empty(): mall.shop_at(self, food_unit, true)
				_find_seat(game)
		"to_seat":
			v.play("walk")
			if move(dt, game):
				if not seat.is_empty():
					var T: Fixture = seat["table"]
					var p := T.seat_world(seat["i"])
					position = Vector3(p.x, position.y, p.z)
					look_at_pt = T.center()
					facing = atan2(T.center().x - p.x, T.center().z - p.z)
				state = "eat"; timer = randf_range(7.0, 11.0)
		"eat":
			v.play("sit" if not seat.is_empty() else "idle")
			timer -= dt
			if timer <= 0.0:
				if not seat.is_empty():
					var T2: Fixture = seat["table"]
					T2.seats_used[seat["i"]] = null
					if randf() < 0.6: game.dirty_table(T2)
					seat = {}
				elif randf() < 0.5: game.drop_litter(tile(), lvl)
				mood += 6
				log_thought("happy", "Karnım doydu.", game, false)
				look_at_pt = null
				_next(game)
		"play":
			v.play("idle")
			timer -= dt
			if timer <= 0.0:
				mood += 10; log_thought("fun", "Çocuk bayıldı, çıkarmak zor oldu!", game); _next(game)
		"bench":
			v.play("sit")
			timer -= dt
			if timer <= 0.0:
				mood += 5; look_at_pt = null; _next(game)
		"leaving":
			v.play("walk"); _ambient(dt, game)
			if move(dt, game):
				if flags.has("from_unit"):
					flags.erase("from_unit"); _next(game); return
				state = "exit"
				go_to(game, Vector2i(exit_x, Cfg.SIDEWALK_Z0 + 1))
		"exit":
			v.play("walk")
			if move(dt, game): removed = true

func _next(game) -> void:
	stop = stops.pop_front() if not stops.is_empty() else {}
	if stop.is_empty() or not game.is_open():
		mall.record_visit(self)
		state = "leaving"
		var ex: int = MallDB.ENTRANCES[0]
		for e in MallDB.ENTRANCES: if absf(e - position.x) < absf(ex - position.x): ex = e
		go_to_any(game, Vector2i(ex, 15), 0, arch.get("lift", false))
		stop = {}
		return
	var target := Vector2i.ZERO
	var fl := 0
	match stop["kind"]:
		"unit":
			if stop["unit"]["tenant"].is_empty():
				_next(game); return
			target = mall.door_outside(stop["unit"]); fl = stop["unit"]["def"]["floor"]
		"food":
			var foods: Array = mall.units.filter(func(u): return not u["tenant"].is_empty() and u["tenant"]["def"].get("food", false))
			if foods.is_empty():
				log_thought("food", "Acıktım ama yemek yeri yok!", game); mood -= 8; _next(game); return
			food_unit = foods.pick_random()
			target = mall.door_outside(food_unit); fl = food_unit["def"]["floor"]
		_:
			var kind: String = "play" if stop["kind"] == "play" else "bench"
			var fx: Array = game.fixtures.filter(func(f): return f.def["kind"] == kind)
			if fx.is_empty():
				_next(game); return
			target_fx = fx.pick_random()
			target = game.nearest_access(target_fx, position); fl = target_fx.lvl
			look_at_pt = target_fx.center()
	state = "to_stop"
	if not go_to_any(game, target, fl, arch.get("lift", false)) and not riding():
		log_thought("wrench", "Oraya nasıl gidilir ki?", game); mood -= 5; _next(game)

func _arrive(game) -> void:
	if stop.is_empty():
		_next(game); return
	match stop["kind"]:
		"unit":
			var u: Dictionary = stop["unit"]
			if u["tenant"].is_empty():
				_next(game); return
			state = "in_unit"
			go_to(game, mall.random_inside(u))
			u["tenant"]["visitors"] += 1
		"food":
			state = "to_counter"
			go_to(game, food_unit["def"]["door"][0])
		"play":
			state = "play"; timer = randf_range(8.0, 13.0)
			look_at_pt = target_fx.center()
			if child: child_play = target_fx.center() + Vector3(randf_range(-0.8, 0.8), 0.12, randf_range(-0.8, 0.8))
		_:
			var c := target_fx.center()
			position = Vector3(c.x - 0.2, position.y, c.z - 0.05)
			facing = target_fx.rot * PI / 2.0
			look_at_pt = null
			state = "bench"; timer = randf_range(5.0, 9.0)

func _find_seat(game) -> void:
	var best = null
	var best_d := 1e9
	for T in game.fixtures:
		if T.def["kind"] != "table" or T.lvl != lvl: continue
		for i in T.seats_used.size():
			if T.seats_used[i] != null: continue
			var d: float = T.center().distance_to(position) + (6.0 if T.dirty else 0.0)
			if d < best_d: best_d = d; best = [T, i]
	if best == null:
		log_thought("food", "Oturacak masa yok, ayakta yiyorum…", game); mood -= 10
		mall.stats["no_seat"] += 1
		state = "eat"; timer = randf_range(5.0, 7.0); seat = {}
		return
	var T3: Fixture = best[0]
	if T3.dirty:
		log_thought("dirty", "Masalar kirli, kimse toplamıyor mu?", game); mood -= 8
	T3.seats_used[best[1]] = self
	seat = {"table": T3, "i": best[1]}
	state = "to_seat"
	go_to(game, game.nearest_access(T3, T3.seat_world(best[1])))

func _ambient(dt: float, game) -> void:
	var t := tile()
	if not flags.has("dirty") and game.litter_near(t, 1.6, lvl):
		flags["dirty"] = true; mood -= 6; log_thought("dirty", "AVM pek temiz değil.", game)
	if crowd_t > 3.0 and not flags.has("crowd"):
		flags["crowd"] = true; mood -= 5; log_thought("crowd", "Çok kalabalık!", game)
	if not mall.event.is_empty() and not flags.has("event"):
		flags["event"] = true; mood += 6; log_thought("fun", "%s! Tam zamanında geldik." % mall.event["def"]["name"], game)
	if randf() < 0.0015 * dt and not game.bin_near(t, lvl): game.drop_litter(t, lvl)

func _leave_street(game) -> void:
	state = "exit"; go_to(game, Vector2i(exit_x, Cfg.SIDEWALK_Z0 + 1))

func track_child(dt: float) -> void:
	if child == null: return
	trail.append(position)
	if trail.size() > 24: trail.pop_front()
	var target: Vector3 = trail[0]
	if state == "play" and child_play != null: target = child_play
	elif state == "eat" and not seat.is_empty(): target = (seat["table"] as Fixture).center() + Vector3(0.55, 0, 0.55)
	var d := child.position.distance_to(target)
	var mv := d > 0.05
	if mv:
		var dir := (target - child.position).normalized()
		child.position += dir * minf(d, (speed * 1.2 + d) * dt)
		child.rotation.y = atan2(dir.x, dir.z)
	child.position.y = target.y
	child.play("happy" if state == "play" else ("walk" if mv else "idle"))
	child.visible = visible

func status_label() -> String:
	match state:
		"to_mall", "enter": return "AVM'ye giriyor"
		"to_stop":
			if stop.get("kind", "") == "unit": return "%s mağazasına gidiyor" % (stop["unit"]["tenant"]["def"]["brand"] if not stop["unit"]["tenant"].is_empty() else "Mağaza")
			return "Yemek katına gidiyor" if stop.get("kind", "") == "food" else "Geziniyor"
		"in_unit", "browse": return "Mağazada bakınıyor"
		"to_counter", "order": return "Yemek sipariş ediyor"
		"to_seat": return "Masaya geçiyor"
		"eat": return "Yemek yiyor" if not seat.is_empty() else "Ayakta yemek yiyor"
		"play": return "Çocuk oyun alanında"
		"bench": return "Bankta dinleniyor"
		"leaving": return "Ayrılıyor"
	return "Gitti"

func dispose() -> void:
	if not seat.is_empty(): (seat["table"] as Fixture).seats_used[seat["i"]] = null
	if child: child.queue_free()
	queue_free()
