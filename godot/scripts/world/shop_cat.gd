class_name ShopCat
extends Node3D
## The mahalle cat. Turns up at the door one morning; if adopted it lives in the shop — naps, wanders
## between the aisles, cheers up shoppers and, now and then, knocks something off a shelf.

const NAMES := ["Tekir", "Pamuk", "Duman", "Zeytin", "Maviş", "Karamel", "Fındık", "Şeker"]

var cat_name := "Tekir"
var adopted := false
var state := "away" # away | door | walk | sit | sleep | leave
var path: Array[Vector2i] = []
var target := Vector3.ZERO
var timer := 0.0
var t := 0.0
var fed_today := false
var visit_day := -1 # day the cat will turn up at the door
var cheer_cd := {} # customer instance id -> true
var _body: Node3D
var _head: Node3D
var _tail: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _zz: Label3D
var _bowl: Node3D

func build() -> void:
	var fur := Art.mat(Color("d98a3a"), 0.9)
	var fur2 := Art.mat(Color("a8612a"), 0.9)
	var belly := Art.mat(Color("f6e3c8"), 0.9)
	_body = Node3D.new(); _body.position = Vector3(0, 0.17, 0); add_child(_body)
	Art.box(_body, Vector3(0.18, 0.15, 0.36), fur, Vector3.ZERO, 0.06)
	for i in 3: Art.box(_body, Vector3(0.185, 0.03, 0.04), fur2, Vector3(0, 0.06, -0.1 + i * 0.1), 0.01)
	Art.box(_body, Vector3(0.14, 0.04, 0.26), belly, Vector3(0, -0.07, 0.02), 0.02)
	_head = Node3D.new(); _head.position = Vector3(0, 0.1, 0.2); _body.add_child(_head)
	Art.sphere(_head, 0.09, fur, Vector3.ZERO, 0.92)
	Art.sphere(_head, 0.045, belly, Vector3(0, -0.03, 0.065), 0.8)
	for sx in [-1, 1]:
		var ear := MeshInstance3D.new(); ear.mesh = Art.prim("prism", 0.06, 0.07, 0.03); ear.material_override = fur
		ear.position = Vector3(sx * 0.05, 0.085, -0.01); ear.rotation.z = sx * 0.25; _head.add_child(ear)
		Art.sphere(_head, 0.014, Art.mat(Color("1f2a44"), 0.3), Vector3(sx * 0.035, 0.015, 0.078))
	Art.sphere(_head, 0.01, Art.mat(Color("e07a86"), 0.5), Vector3(0, -0.012, 0.09))
	var prev: Node3D = _body
	var off := Vector3(0, 0.03, -0.18)
	for i in 4:
		var seg := Node3D.new(); seg.position = off; prev.add_child(seg)
		Art.cyl(seg, 0.022, 0.026, 0.09, fur if i % 2 == 0 else fur2, Vector3(0, 0.04, 0), 8)
		_tail.append(seg); prev = seg; off = Vector3(0, 0.085, 0)
	for p in [Vector3(-0.06, -0.09, 0.12), Vector3(0.06, -0.09, 0.12), Vector3(-0.06, -0.09, -0.12), Vector3(0.06, -0.09, -0.12)]:
		var leg := Node3D.new(); leg.position = p; _body.add_child(leg)
		Art.cyl(leg, 0.022, 0.022, 0.1, fur, Vector3(0, -0.03, 0), 8)
		_legs.append(leg)
	_zz = Art.label(self, "z z", 40, Color("7a5ae0"), Vector3(0.1, 0.5, 0), 0.0, "display")
	_zz.billboard = BaseMaterial3D.BILLBOARD_ENABLED; _zz.visible = false
	Art.stylize(self)
	visible = false

func place_bowl(game) -> void:
	if _bowl: _bowl.queue_free()
	_bowl = Node3D.new(); game.props_node.add_child(_bowl)
	var drs: Array = game.grid.layout["doors"]
	var r: Rect2i = game.grid.interior()
	_bowl.position = Vector3(float(drs[drs.size() - 1]) + 1.6, 0.02, r.end.y - 0.45)
	Art.cyl(_bowl, 0.12, 0.09, 0.06, Art.mat(Color("d6333a"), 0.4), Vector3(0, 0.03, 0), 12)
	Art.cyl(_bowl, 0.1, 0.1, 0.01, Art.mat(Color("8a5a35"), 0.9), Vector3(0, 0.061, 0), 12)
	Art.stylize(_bowl)

# ------------------------------------------------------------------ daily
func start_day(game) -> void:
	fed_today = false
	cheer_cd.clear()
	if adopted:
		state = "sleep"; visible = true
		position = _spot(game); timer = randf_range(20.0, 60.0)
		return
	state = "away"; visible = false
	if visit_day < 0: visit_day = game.day + 1
	elif game.day > visit_day and randf() < 0.35: visit_day = game.day

## the cat shows up at the door and asks to be let in (a mahalle olayı card)
func maybe_arrive(game) -> void:
	if adopted or state != "away" or game.day != visit_day or game.clock < Cfg.DAY_OPEN + 90: return
	state = "door"; visible = true
	var drs: Array = game.grid.layout["doors"]
	position = Vector3(float(drs[0]) - 0.6, 0.02, game.grid.front_z() + 1.4)
	rotation.y = 0.0
	visit_day = game.day
	cat_name = NAMES.pick_random()
	game.push_event({"kind": "cat", "title": "Kapıda bir kedi", "icon": "cat", "expires": game.abs_minutes() + 120.0,
		"text": "Turuncu tekir bir kedi kapının önüne oturmuş, içeri bakıp miyavlıyor. Sahiplenirsen dükkânın maskotu olur: müşteriler bayılır ama arada bir raftan bir şey düşürür. Maması günde ₺15.",
		"choices": [{"label": "Sahiplen, adı %s olsun" % cat_name, "primary": true}, {"label": "Kovala"}], "data": {}})

func adopt(game) -> void:
	adopted = true
	state = "walk"; visible = true
	GameAudio.play("meow", -8.0, 0.5)
	_go(game, _rand_tile(game))
	place_bowl(game)

func shoo(game) -> void:
	state = "leave"
	_go(game, Vector2i(0, Cfg.SIDEWALK_Z0 + 1))
	visit_day = game.day + 3 + randi() % 4

# ------------------------------------------------------------------ behaviour
func _spot(game) -> Vector3:
	# favourite nap spots: next to a plant, on top of the depot rack, by the bowl
	var spots := []
	for f in game.fixtures:
		if f.lvl != 0: continue
		if f.def["kind"] == "plant": spots.append(f.center() + Vector3(0.45, 0.02, 0.35))
		elif f.def["id"] == "depo": spots.append(f.center() + Vector3(0.3, 2.02, -0.1))
	if _bowl: spots.append(_bowl.position + Vector3(0.35, 0, 0))
	if spots.is_empty():
		var c := Cfg.rc(game.grid.interior())
		return Vector3(c.x, 0.02, c.y)
	return spots.pick_random()

func _rand_tile(game) -> Vector2i:
	var r: Rect2i = game.grid.interior()
	for i in 20:
		var tt := Vector2i(r.position.x + randi() % r.size.x, r.position.y + randi() % r.size.y)
		if game.grid.walkable(tt.x, tt.y): return tt
	return Vector2i(r.position.x + 1, r.end.y - 1)

func _go(game, to: Vector2i) -> void:
	var from := Vector2i(floori(position.x), floori(position.z))
	path = game.grid.find_path(from, to)
	if path.is_empty(): path = [to]

func update(dt: float, game) -> void:
	t += dt
	if state == "away": return
	var speed := 1.3
	match state:
		"door":
			_anim_sit(dt)
			timer -= dt
			if timer <= 0.0:
				timer = randf_range(3.0, 6.0)
				if game.rig.far_factor() < 0.6:
					game.float_text(position + Vector3(0, 0.6, 0), "Miyav!", Cfg.TERRA)
					GameAudio.play("meow", -14.0, 4.0)
		"walk", "leave":
			if path.is_empty():
				if state == "leave":
					state = "away"; visible = false; return
				state = "sit" if randf() < 0.6 else "sleep"
				timer = randf_range(12.0, 30.0) if state == "sit" else randf_range(30.0, 70.0)
				if state == "sleep" and randf() < 0.5: position = _spot(game)
				return
			var nxt: Vector2i = path[0]
			var p := Vector3(nxt.x + 0.5, position.y, nxt.y + 0.5)
			var d := p - position; d.y = 0.0
			if d.length() < 0.05: path.pop_front(); return
			var step := minf(d.length(), speed * dt)
			position += d.normalized() * step
			rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), minf(1.0, dt * 10.0))
			position.y = 0.02
			_anim_walk(dt)
		"sit":
			_anim_sit(dt)
			timer -= dt
			if timer <= 0.0: state = "walk"; _go(game, _rand_tile(game))
		"sleep":
			_anim_sleep(dt)
			timer -= dt
			if timer <= 0.0:
				position.y = 0.02
				state = "walk"; _go(game, _rand_tile(game))
	_zz.visible = state == "sleep"
	if adopted and game.is_open(): _cheer(game)

## shoppers who pass the cat light up (students and families most)
func _cheer(game) -> void:
	for c in game.customers:
		if not c.shopper or c.thief() or not c.inside(): continue
		var id: int = c.get_instance_id()
		if cheer_cd.has(id) or c.position.distance_to(position) > 1.6: continue
		cheer_cd[id] = true
		var aid: String = c.arch["id"]
		var bonus := 6.0 if aid in ["ogrenci", "aile"] else (3.0 if aid != "calisan" else 2.0)
		c._feel(game, bonus, "Dükkân kedisi")
		if game.rig.far_factor() < 0.5: GameAudio.play("purr" if state == "sleep" else "meow", -18.0, 6.0)
		var lines := ["%s ne tatlı! Başını okşadım." % cat_name, "Kedili dükkân, ne güzel.", "%s bana baktı, gün güzel başladı." % cat_name, "Pisi pisi! Sonra alışveriş."]
		if state == "sleep": lines = ["%s mışıl mışıl uyuyor, sessiz olayım." % cat_name]
		c.log_thought("happy", lines.pick_random(), game, randf() < 0.5)

## a daily mischief roll: something falls off a shelf
func mischief(game) -> void:
	if not adopted or not game.is_open() or state == "sleep": return
	var shelves: Array = game.fixtures.filter(func(f): return f.is_display() and f.lvl == 0 and f.slots.any(func(s): return s["pid"] != "" and int(s["stock"]) > 0))
	if shelves.is_empty(): return
	var f: Fixture = shelves.pick_random()
	var sl: Array = f.slots.filter(func(s): return s["pid"] != "" and int(s["stock"]) > 0)
	var s: Dictionary = sl.pick_random()
	s["stock"] = int(s["stock"]) - 1
	game.stock_changed(f)
	game.drop_litter(game.nearest_access(f, f.center()), 0)
	position = f.center() + Vector3(0.6, 0.02, 0.6)
	state = "sit"; timer = 6.0
	game.alert("catmess", "cat", "%s raftan bir %s düşürdü, yere saçıldı. Masum masum bakıyor." % [cat_name, (DB.product(s["pid"])["name"] as String).to_lower()], "info", position, 0.0)

# ------------------------------------------------------------------ animation
func _anim_walk(dt: float) -> void:
	for i in _legs.size(): _legs[i].rotation.x = sin(t * 12.0 + (PI if i % 3 == 0 else 0.0)) * 0.5
	_body.position.y = 0.17 + absf(sin(t * 12.0)) * 0.012
	_body.rotation.z = 0.0; _body.rotation.x = 0.0
	for i in _tail.size(): _tail[i].rotation.x = -0.35 + sin(t * 5.0 + i) * 0.12
	_head.rotation.x = 0.0

func _anim_sit(dt: float) -> void:
	_body.rotation.x = -0.45; _body.position.y = 0.2
	for i in _legs.size(): _legs[i].rotation.x = 0.45 if i < 2 else -0.9
	for i in _tail.size(): _tail[i].rotation.x = 0.6 + sin(t * 2.0 + i * 0.8) * 0.25
	_head.rotation.x = 0.45 + sin(t * 0.7) * 0.05
	_head.rotation.y = sin(t * 0.4) * 0.5

func _anim_sleep(dt: float) -> void:
	_body.rotation.x = 0.0; _body.rotation.z = 1.2
	_body.position.y = 0.1 + sin(t * 1.6) * 0.004
	for i in _legs.size(): _legs[i].rotation.x = 0.8
	for i in _tail.size(): _tail[i].rotation.x = 1.2
	_head.rotation.x = 0.4; _head.rotation.y = 0.0
	_zz.position.y = 0.45 + fmod(t * 0.2, 0.25)

func serialize() -> Dictionary: return {"adopted": adopted, "name": cat_name, "visit_day": visit_day}
func apply(game, d: Dictionary) -> void:
	if d.is_empty(): return
	adopted = d.get("adopted", false); cat_name = d.get("name", "Tekir"); visit_day = int(d.get("visit_day", -1))
	if adopted: place_bowl(game)
