extends Node
## Entry point: world + HUD. Test hooks: --autostart, --sim=seconds, --panel=id, --select=kind

var game: Game
var hud: Hud
var thumbs: Thumbs
var args_extra := {}

func _ready() -> void:
	Settings.load_settings()
	for a in OS.get_cmdline_user_args(): if a.begins_with("--lang="): Loc.set_lang(a.substr(7))
	SteamBridge.init()
	Settings.deck_defaults()
	Keys.setup()
	Settings.ensure_buses()
	add_child(GameAudio.new())
	add_child(PadCursor.new())
	game = Game.new()
	add_child(game)
	Settings.apply(game, get_tree())
	thumbs = Thumbs.new(); add_child(thumbs); thumbs.build()
	await thumbs.ready_all
	hud = Hud.new(); add_child(hud); hud.setup(game, thumbs)
	if not SaveGame.pending.is_empty():
		var d: Dictionary = SaveGame.pending
		SaveGame.pending = {}
		SaveGame.apply(game, d)
		hud.start(true)
		print("LOADED stage=", game.stage, " day=", game.day, " money=", game.money, " fixtures=", game.fixtures.size(), " staff=", game.staff.size(), " upgrades=", game.upgrades.keys(), " tenants=", game.mall.units.filter(func(u): return not u["tenant"].is_empty()).size() if game.mall else -1, " lot=", game.street.lot != null)
		return
	if SaveGame.pending_scenario != "":
		var sid := SaveGame.pending_scenario
		SaveGame.pending_scenario = ""
		Scenarios.apply(game, sid)
		hud.start(false)
		game.alert("scenario", "map", "%s: %s" % [Scenarios.get_def(sid)["name"], Scenarios.get_def(sid)["goal"]], "info", null, 0.0)
		return
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var i := a.find("=")
			if i > 0: args[a.substr(2, i - 2)] = a.substr(i + 1)
			else: args[a.substr(2)] = "1"
	if args.has("lang"): Loc.set_lang(args["lang"])
	if args.has("menu2"): hud.call_deferred("open_menu", args["menu2"])
	if args.has("scenario"): Scenarios.apply(game, args["scenario"])
	if args.has("load"):
		SaveGame.apply(game, SaveGame._read(int(args["load"]))); hud.start(true)
	if args.has("autostart") or args.has("sim"): hud.start()
	if args.has("sim"):
		for i in int(float(args["sim"]) * 30):
			if game.day_ended_flag: break
			game.tick(1.0 / 30.0)
	if args.has("moodtest"): print("MOODWHY ", game.stats["mood_why"]); get_tree().quit()
	if args.has("saveslot"):
		print("MIDSAVE clock=", game.clock, " rev=", game.stats["revenue"], " ok=", SaveGame.save(game, int(args["saveslot"])))
		if DisplayServer.get_name() == "headless": get_tree().quit()
	if args.has("load"): print("LOADED clock=", game.clock, " rev=", game.stats["revenue"], " served=", game.stats["served"])
	if args.has("quit"): get_tree().quit()
	if args.has("hour"): game.clock = float(args["hour"]) * 60.0
	if args.has("panel"): hud.open_panel(args["panel"])
	if args.has("select"):
		if args["select"] == "customer":
			for c in game.customers: if c.shopper and c.inside(): game.select({"kind": "agent", "obj": c}); break
		else:
			for f in game.fixtures: if f.def["id"] == args["select"]: game.select({"kind": "fixture", "obj": f}); break
	if args.has("place"): game.start_placement(args["place"]); game.update_placement(21, 14)
	if args.has("dayend"): game.end_day()
	if args.has("market"):
		game.money += 60000; game.rating = 4.0; game.totals["happy"] = 400
		game.expand()
		var add := func(id: String, x: int, z: int, r: int, prods: Array):
			var v := game.validate(DB.fixture(id), x, z, r, null)
			if not v["ok"]: print("PLACE FAIL ", id, " ", v["reason"]); return
			var f := game.add_fixture(DB.fixture(id), x, z, r)
			for i in prods.size():
				f.slots[i]["pid"] = prods[i]; f.slots[i]["stock"] = f.cap()
		add.call("gondol", 12, 9, 0, ["cips", "biskuvi", "deterjan"])
		add.call("gondol", 12, 12, 0, ["cikolata", "biskuvi", "cips"])
		add.call("manav", 16, 7, 0, ["domates", "elma"])
		add.call("acik", 11, 6, 0, ["sut", "ayran", "kola"])
		add.call("kasa", 16, 13, 0, [])
		game.hire({"role": "cashier", "name": "Elif", "wage": 300, "skill": 1.0}, true)
		game.hire({"role": "stocker", "name": "Can", "wage": 260, "skill": 1.0}, true)
		for pid in game.backstock: game.backstock[pid] = 12
		game.refresh_all()
		for i in int(float(args.get("msim", "60")) * 30):
			if game.day_ended_flag: game.start_next_day()
			game.tick(1.0 / 30.0)
		print("MARKET day=", game.day, " money=", game.money, " rev=", game.stats["revenue"], " served=", game.stats["served"], " rating=", game.rating)
	args_extra = args
	if args.has("stage"): _stage_test(int(args["stage"]), float(args.get("ssim", "0")))
	if args.has("floor"): game.set_view_floor(int(args["floor"]))
	if args.has("overlay"): game.set_overlay(args["overlay"])
	if args.has("event"): game.mall.schedule(args["event"], "today")
	if args.has("hour"): game.clock = float(args["hour"]) * 60.0
	if args.has("tab"): hud.hood_tab = args["tab"]; hud.prod_tab = args["tab"]
	if args.has("panel2"): hud.open_panel(args["panel2"])
	if args.has("selunit"):
		var u: Dictionary = game.mall.units[int(args["selunit"])]
		game.set_view_floor(u["def"]["floor"])
		game.select({"kind": "unit", "obj": u})
	if args.has("cam"):
		var c: PackedStringArray = args["cam"].split(",")
		game.rig.focus(float(c[0]), float(c[1]), float(c[2]))
	if args.has("yaw"): game.rig.g_yaw = float(args["yaw"])
	if args.has("pitch"): game.rig.g_pitch = float(args["pitch"])
	if args.has("nohud"): hud.visible = false # clean key art for store capsules
	if args.has("menu"): hud.open_menu(args["menu"])
	if args.has("crisis"):
		for k in args["crisis"].split(","):
			var ev := NeighborEvents.roll(game, k)
			game.neighbor_events.append(ev)
			var before := [game.puddles.size(), game.stats.get("spoiled", 0), game.orders.map(func(o): return o["eta"])]
			game.answer_event(ev["id"], 1)
			print("CRISIS %s: %s | before %s after puddles=%d spoiled=%s outage=%.0f strike=%d orders=%s" % [k, ev["title"], before, game.puddles.size(), game.stats.get("spoiled", 0), game.outage_until - game.abs_minutes(), game.strike_day, game.orders.map(func(o): return o["eta"])])
	if args.has("nev"):
		for i in 2:
			var ev := NeighborEvents.roll(game)
			if not ev.is_empty(): game.neighbor_events.append(ev)
		game.events_changed.emit()
	if args.has("bot"):
		hud.start()
		var bot := AutoPlayer.new(game)
		var t0 := Time.get_ticks_msec()
		for d in int(args["bot"]):
			for i in 20000:
				if game.day_ended_flag: break
				game.tick(1.0 / 30.0)
				bot.tick()
			var st: Dictionary = game.stats
			print("BOT day %d stage %d money %d rev %d served %d happy_tot %d rating %.2f lost %d rival %d  |%s" % [game.day, game.stage, int(game.money), st["revenue"], st["served"], game.totals["happy"], game.rating, st["lost"], st["rival_lost"], " ".join(bot.log.slice(-6))])
			var mw: Dictionary = st["mood_why"]
			var ks := mw.keys(); ks.sort_custom(func(x, y): return float(mw[x][0]) < float(mw[y][0]))
			print("  mood: ", ", ".join(ks.slice(0, 5).map(func(k): return "%s %d/%d" % [k, int(mw[k][0]), int(mw[k][1])])), " | missed ", st["missed"], " | depot %d/%d " % [game.backstock_total(), game.depot_capacity()], game.backstock.keys().filter(func(k): return game.is_stocked(k)).map(func(k): return "%s:%d" % [k, game.backstock[k]]))
			bot.log.clear()
			if game.day_ended_flag: game.start_next_day()
		print("BOT stage_times=", bot.stage_times, " cpu_s=", (Time.get_ticks_msec() - t0) / 1000.0)
		if DisplayServer.get_name() == "headless": get_tree().quit()
	if args.has("econ"):
		if args.has("stocker"): game.hire({"role": "stocker", "name": "Can", "wage": 260, "skill": 1.0}, true)
		if args.has("veresiye"): game.neighborhood.mode = args["veresiye"]
		var vans := 0
		var last_state: String = game.van["state"]
		var evs := []
		for d in int(args["econ"]):
			for i in 16000:
				if game.day_ended_flag: break
				game.tick(1.0 / 30.0)
				if last_state == "idle" and game.van["state"] == "arriving": vans += 1; print("  VAN day ", game.day, " ", Cfg.clock_str(game.clock), " cargo=", game.van["cargo"].reduce(func(a, o): return a + int(o["qty"]), 0))
				last_state = game.van["state"]
				for ev in game.neighbor_events.duplicate():
					evs.append(ev["kind"])
					var c: int = 0 if not ev["choices"][0].get("disabled", false) else ev["choices"].size() - 1
					game.answer_event(ev["id"], c)
			var st: Dictionary = game.stats
			print("ECON day ", game.day, " money=", int(game.money), " rev=", st["revenue"], " served=", st["served"], " happy_total=", game.totals["happy"], " rating=", snappedf(game.rating, 0.01), " backstock=", game.backstock_total(), "/", game.depot_capacity(), " missed=", st["missed"])
			print("   ", game.calendar.label(game.day), " ", game.calendar.weather, " util=", game.utilities(), " credit=", st["credit"], "/", st["credit_paid"], " debt=", game.neighborhood.total_debt(), " rival_lost=", st["rival_lost"], " quests_done=", game.quests.done.size(), " active=", game.quests.active.map(func(q): return q["title"]), " loyal=", game.neighborhood.residents.map(func(r): return int(r["loyalty"])))
			if game.day_ended_flag: game.start_next_day()
		print("ECON vans=", vans, " events=", evs)
		hud.modal.visible = false
		if args.has("saveto"):
			print("SAVED ", SaveGame.save(game, int(args["saveto"])))
			if DisplayServer.get_name() == "headless": get_tree().quit()
	if args.has("dbgunit"):
		var un: Node3D = game.mall_shell.unit_nodes[int(args["dbgunit"])]
		for ch in un.get_children():
			if ch is MeshInstance3D: print("MI ", ch.name, " aabb=", (ch as MeshInstance3D).get_aabb(), " gpos=", ch.global_position, " vis=", ch.is_visible_in_tree())
			elif ch is Label3D: print("LB ", (ch as Label3D).text, " gpos=", ch.global_position)
			else: print("N ", ch.get_class(), " gpos=", ch.global_position, " kids=", ch.get_child_count())
	if args.has("dbgsides"):
		for i in 30: await get_tree().process_frame
		for sd in game.mall_shell.sides:
			if sd["unit"] < 0: print("SIDE fl=", sd["floor"], " n=", sd["normal"], " mode=", sd["mode"], " sink=", snappedf(sd["sink"], 0.01), " scale=", (sd["node"] as Node3D).scale.y, " vis=", (sd["node"] as Node3D).is_visible_in_tree(), " kids=", (sd["node"] as Node3D).get_child_count())
	if args.has("itest"): _itest()
	if args.has("savetest"):
		print("SAVING stage=", game.stage, " day=", game.day, " money=", game.money, " fixtures=", game.fixtures.size(), " staff=", game.staff.size(), " upgrades=", game.upgrades.keys())
		print("SAVE ok=", SaveGame.save(game, 3), " info=", SaveGame.info(3))
		SaveGame.load_slot(get_tree(), 3)

## scripted stage-2/3 setup for headless balance runs and screenshots
func _stage_test(n: int, secs: float) -> void:
	game.money += 400000; game.rating = float(args_extra.get("rating0", "4.2"))
	for st in range(1, n + 1): game.apply_stage(st)
	for f in game.fixtures.duplicate(): game.remove_fixture(f)
	var add := func(id: String, x: int, z: int, r: int, prods: Array, l := 0):
		var d := DB.fixture(id)
		if game.view_floor != l: game.set_view_floor(l)
		var v := game.validate(d, x, z, r, null)
		if not v["ok"]:
			var gg: Grid = game.floor_grid(l)
			var occ := []
			for t in Fixture.footprint(d, x, z, r)["tiles"]: occ.append(gg.fixture[gg.idx(t.x, t.y)])
			print("PLACE FAIL ", id, " @", x, ",", z, " ", v["reason"], " occ=", occ); return
		var f := game.add_fixture(d, x, z, r, l)
		for i in mini(prods.size(), f.slots.size()):
			f.slots[i]["pid"] = prods[i]; f.slots[i]["stock"] = f.cap()
	# back wall: cold + fresh + bakery
	add.call("acik", 11, 4, 0, ["sut", "ayran", "peynir"])
	add.call("acik", 14, 4, 0, ["kola", "su", "ayran"])
	add.call("manav", 17, 4, 0, ["domates", "elma"])
	add.call("firin", 24, 4, 0, [])
	add.call("sepet", 22, 4, 0, ["simit", "ekmek"])
	game.evening_bakery = args_extra.has("evening")
	if args_extra.has("ucal"): game.start_campaign("ucal", ["makarna", "biskuvi"])
	add.call("sepet", 23, 4, 0, ["ekmek", "simit"])
	add.call("acik", 18, 13, 2, ["su", "sut", "peynir"])
	add.call("soguk", 27, 4, 0, [])
	add.call("depooda", 31, 4, 0, [])
	add.call("molaodasi", 10, 12, 0, [])
	add.call("gondolbasi", 15, 7, 0, ["cikolata"])
	add.call("gondolbasi", 27, 10, 0, ["cips"])
	# aisles
	for x in [12, 16, 24, 28]:
		add.call("gondol", x, 7, 0, ["cips", "biskuvi", "makarna"])
		add.call("gondol", x, 10, 0, ["cikolata", "cay", "deterjan"])
	add.call("levha", 13, 8, 0, [])
	add.call("levha", 25, 8, 0, [])
	add.call("kamera", 20, 8, 0, [])
	add.call("kamera", 31, 11, 0, [])
	# checkout line
	add.call("bantkasa", 15, 13, 0, [])
	add.call("bantkasa", 25, 13, 0, [])
	add.call("selfkasa", 20, 13, 0, [])
	add.call("alarm", 15, 15, 0, [])
	add.call("araba", 32, 14, 0, [])
	add.call("saksi", 10, 15, 0, [])
	add.call("cop", 33, 15, 0, [])
	for r in [["cashier", "Elif", 300], ["cashier", "Deniz", 300], ["stocker", "Can", 260], ["cleaner", "Nermin", 230], ["security", "Tarık", 340], ["baker", "Hatice", 380]]:
		game.hire({"role": r[0], "name": r[1], "wage": r[2], "skill": 1.0}, true)
	for i in int(args_extra.get("stockers", "0")):
		game.hire({"role": "stocker", "name": "Reyon %d" % (i + 2), "wage": 260, "skill": 1.0}, true)
	game.buy_upgrade("otopark")
	if n >= 3:
		var U3: Dictionary = game.mall.units[6]
		U3["offers"] = [{"def": MallDB.tenant("sinema"), "rent": 1700}]
		for u in game.mall.units:
			if not u["offers"].is_empty(): game.mall.lease(u, 0)
		add.call("wc", 28, 5, 0, [], 1)
		game.hire({"role": "technician", "name": "Usta Ali", "wage": 360, "skill": 1.0}, true)
		for p in [[14, 7], [17, 7], [20, 9], [25, 9], [28, 7], [31, 7], [14, 10], [28, 10]]:
			add.call("masa", p[0], p[1], 0, [], 1)
		add.call("oyunalani", 11, 7, 0, [], 1)
		add.call("bank", 31, 5, 0, [], 1)
		add.call("bank", 3, 5, 0, [], 1)
		add.call("cop", 22, 6, 0, [], 1)
		add.call("saksi", 11, 12, 0, [], 1)
		game.hire({"role": "cleaner", "name": "Songül", "wage": 230, "skill": 1.0}, true)
		game.set_view_floor(0)
	for pid in game.backstock: game.backstock[pid] = 6 if game.is_stocked(pid) else 0
	game.refresh_all()
	var day0: int = game.day
	hud.modal.visible = false
	for i in int(secs * 30):
		if game.day_ended_flag:
			var st: Dictionary = game.stats
			print("DAY ", game.day, " money=", game.money, " rev=", st["revenue"], " served=", st["served"], " happy=", st["happy"], " lost=", st["lost"], " rating=", snappedf(game.rating, 0.01), " stale=", st["stale"], "/₺", st["stale_cost"], " spoiled=", st["spoiled"], " endcap=", st["endcap"], " multi=", st["multi"], " missed=", st["missed"], " thefts=", st["theft_count"], " slips=", st["slips"])
			if game.mall: print("  MALL ", game.mall.history.back() if not game.mall.history.is_empty() else {}, " visitors_now=", game.mall.visitors.size(), " mood=", snappedf(game.mall.mood, 0.01))
			game.start_next_day()
		game.tick(1.0 / 30.0)
	hud.modal.visible = false
	print("STAGE", n, " after ", secs, "s day=", game.day - day0, " clock=", game.clock, " money=", game.money, " customers=", game.customers.size(), " staff=", game.staff.size(), " fixtures=", game.fixtures.size(), " stats=", game.stats)
	if game.mall:
		print("  mall visitors=", game.mall.visitors.size(), " mood=", game.mall.mood, " stats=", game.mall.stats)
		for u in game.mall.units:
			if not u["tenant"].is_empty(): print("  unit ", u["def"]["id"], " ", u["tenant"]["def"]["brand"], " sat=", u["tenant"]["sat"], " sales=", u["tenant"]["sales"], " vis=", u["tenant"]["visitors"])

## scripted input test: real mouse/keyboard events through the viewport
func _itest() -> void:
	var vp := get_viewport()
	var key := func(k: Key):
		var e := InputEventKey.new(); e.keycode = k; e.pressed = true; Input.parse_input_event(e)
		var e2 := InputEventKey.new(); e2.keycode = k; e2.pressed = false; Input.parse_input_event(e2)
	var click := func(p: Vector2):
		var m := InputEventMouseMotion.new(); m.position = p; m.global_position = p; Input.parse_input_event(m)
		await get_tree().process_frame
		var d := InputEventMouseButton.new(); d.button_index = MOUSE_BUTTON_LEFT; d.pressed = true; d.position = p; d.global_position = p; Input.parse_input_event(d)
		var u := InputEventMouseButton.new(); u.button_index = MOUSE_BUTTON_LEFT; u.pressed = false; u.position = p; u.global_position = p; Input.parse_input_event(u)
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	key.call(KEY_B)
	await get_tree().create_timer(0.4).timeout
	print("ITEST panel=", hud.panel_id)
	# first build card (Ahşap Raf)
	var cards := hud.panel.find_children("*", "Button", true, false).filter(func(b): return b.custom_minimum_size == Vector2(140, 188))
	print("ITEST cards=", cards.size())
	await click.call(cards[0].get_global_rect().get_center())
	print("ITEST placing=", not game.placing.is_empty())
	var target := game.rig.cam.unproject_position(Vector3(21.5, 0, 13.5))
	var m := InputEventMouseMotion.new(); m.position = target; m.global_position = target; Input.parse_input_event(m)
	await get_tree().create_timer(0.3).timeout
	print("ITEST ghost ok=", game.placing.get("ok"), " reason=", game.placing.get("reason"), " at=", game.placing.get("x"), ",", game.placing.get("z"))
	var n0 := game.fixtures.size()
	await click.call(target)
	await get_tree().create_timer(0.3).timeout
	print("ITEST placed=", game.fixtures.size() - n0, " selected=", game.selection.get("obj") is Fixture)
	# assign product to first slot via inspector
	var slot_btns := hud.inspector.find_children("*", "Button", true, false).filter(func(b): return b.custom_minimum_size == Vector2(0, 58))
	print("ITEST slot buttons=", slot_btns.size())
	if slot_btns.size() > 0:
		await click.call(slot_btns[0].get_global_rect().get_center())
		await get_tree().create_timer(0.3).timeout
		var picks := hud.inspector.find_children("*", "Button", true, false).filter(func(b): return b.custom_minimum_size == Vector2(58, 58))
		print("ITEST product choices=", picks.size())
		if picks.size() > 0:
			await click.call(picks[0].get_global_rect().get_center())
			await get_tree().create_timer(0.3).timeout
			var f: Fixture = game.selection.get("obj")
			print("ITEST slot0 pid=", f.slots[0]["pid"])
	# click a customer
	for i in 60: await get_tree().process_frame
	for c in game.customers:
		if c.shopper and c.inside():
			var p := game.rig.cam.unproject_position(c.position + Vector3(0, 0.8, 0))
			await click.call(p)
			print("ITEST clicked customer -> selected=", game.selection.get("obj") is Customer)
			break

var _presence_t := 0.0
func _process(dt: float) -> void:
	SteamBridge.tick()
	_presence_t -= dt
	if _presence_t <= 0.0 and game != null and SteamBridge.ok:
		_presence_t = 15.0
		var names := ["Büfe", "Mahalle Marketi", "Süpermarket", "Köşebaşı AVM"]
		SteamBridge.presence(Loc.t("%s · Gün %d") % [Loc.t(names[game.stage]), game.day])
