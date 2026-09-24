extends Node
## Entry point: world + HUD. Test hooks: --autostart, --sim=seconds, --panel=id, --select=kind

var game: Game
var hud: Hud
var thumbs: Thumbs

func _ready() -> void:
	game = Game.new()
	add_child(game)
	thumbs = Thumbs.new(); add_child(thumbs); thumbs.build()
	await thumbs.ready_all
	hud = Hud.new(); add_child(hud); hud.setup(game, thumbs)
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var i := a.find("=")
			if i > 0: args[a.substr(2, i - 2)] = a.substr(i + 1)
			else: args[a.substr(2)] = "1"
	if args.has("autostart") or args.has("sim"): hud.start()
	if args.has("sim"):
		for i in int(float(args["sim"]) * 30):
			if game.day_ended_flag: break
			game.tick(1.0 / 30.0)
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
	if args.has("itest"): _itest()

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
