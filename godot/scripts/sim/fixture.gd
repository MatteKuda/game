class_name Fixture
extends Node3D
## A placed fixture: simulation state (slots, queue, footprint) + its 3D model.

static var _next_uid := 1
static var _badges := {}

var uid := 0
var def: Dictionary
var gx := 0
var gz := 0
var rot := 0
var fp := {}
var slots: Array = [] # [{pid, stock, claimed}]
var model: Dictionary
var units: Array = [] # per slot: Array[MeshInstance3D]
var tags: Array = [] # per slot: {plate: MeshInstance3D, label: Label3D}
var status: Sprite3D
var status_kind := ""
var queue: Array = [] # Customers (registers)
var queue_slots: Array[Vector2i] = []
var cashier = null # Staff
var highlight := 0.0
var lvl := 0 # floor
var claimed := 0 # staff id working on it (tables, ovens)
var dirty := false # food-court table needs clearing
var baking := false
var seats_used: Array = [] # visitor or null per seat
var covers := {} # camera: tile indices within the view cone
var alarm_t := 0.0

static func footprint(d: Dictionary, x: int, z: int, r: int) -> Dictionary:
	var odd := r % 2 == 1
	var fw: int = d["d"] if odd else d["w"]
	var fd: int = d["w"] if odd else d["d"]
	var tiles: Array[Vector2i] = []
	for dz in fd:
		for dx in fw: tiles.append(Vector2i(x + dx, z + dz))
	var access: Array[Vector2i] = []
	var back: Array[Vector2i] = []
	match r:
		0:
			for i in fw: access.append(Vector2i(x + i, z + fd)); back.append(Vector2i(x + i, z - 1))
		1:
			for i in fd: access.append(Vector2i(x + fw, z + fd - 1 - i)); back.append(Vector2i(x - 1, z + fd - 1 - i))
		2:
			for i in fw: access.append(Vector2i(x + fw - 1 - i, z - 1)); back.append(Vector2i(x + fw - 1 - i, z + fd))
		3:
			for i in fd: access.append(Vector2i(x - 1, z + i)); back.append(Vector2i(x + fw, z + i))
	return {"fw": fw, "fd": fd, "tiles": tiles, "access": access, "back": back}

func setup(d: Dictionary, x: int, z: int, r: int, l := 0) -> void:
	uid = _next_uid; _next_uid += 1
	def = d
	lvl = l
	model = Props.build(d)
	add_child(model["root"])
	Art.stylize(model["root"], true)
	for i in int(d.get("slots", 0)):
		slots.append({"pid": "", "stock": 0, "claimed": 0})
		units.append([])
		var s: Dictionary = model["slots"][i]
		var tag := Node3D.new()
		tag.position = s["tag"]
		model["root"].add_child(tag)
		var plate := Art.box(tag, Vector3(0.2, 0.085, 0.012), Art.mat(Color("d9d4ca")), Vector3.ZERO, 0.008)
		var lab := Art.label(tag, "", 30, Cfg.INK, Vector3(0, 0, 0.008), 0.0, "display")
		lab.pixel_size = 0.0032
		tags.append({"node": tag, "plate": plate, "label": lab})
	status = Sprite3D.new()
	status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status.no_depth_test = true
	status.pixel_size = 0.0045
	status.render_priority = 10
	status.position.y = float(model["height"]) + 0.45
	status.visible = false
	add_child(status)
	for i in (model.get("seats", []) as Array).size(): seats_used.append(null)
	place(x, z, r)

func place(x: int, z: int, r: int) -> void:
	gx = x; gz = z; rot = r
	fp = footprint(def, x, z, r)
	position = Vector3(x + fp["fw"] * 0.5, lvl * Cfg.FLOOR_H + 0.02, z + fp["fd"] * 0.5)
	rotation.y = r * PI / 2.0

func center() -> Vector3: return Vector3(gx + fp["fw"] * 0.5, lvl * Cfg.FLOOR_H, gz + fp["fd"] * 0.5)
func noblock() -> bool: return def.get("noblock", false)
func seat_world(i: int) -> Vector3:
	var seats: Array = model.get("seats", [])
	if i >= seats.size(): return center()
	return global_transform * (seats[i] as Vector3)
func is_display() -> bool: return def["kind"] == "display"
func cap() -> int: return int(def.get("cap", 0))
func access() -> Array[Vector2i]: return fp["access"]
func back() -> Array[Vector2i]: return fp["back"]

func set_status(kind: String) -> void:
	if kind == status_kind: return
	status_kind = kind
	status.visible = kind != ""
	if kind != "":
		if not _badges.has(kind): _badges[kind] = load("res://assets/icons/badge/%s.svg" % kind)
		status.texture = _badges[kind]

## sync visible product units + price tag colours with slot state
func refresh(game) -> void:
	for i in slots.size():
		var s: Dictionary = slots[i]
		var lay: Array = model["slots"][i]["units"]
		var list: Array = units[i]
		var pid: String = s["pid"]
		if list.size() > 0 and (pid == "" or list[0].get_meta("pid", "") != pid):
			for mi in list: mi.queue_free()
			list.clear()
		if pid != "" and list.is_empty():
			var mesh := Products3D.mesh(pid)
			for xf in lay:
				var mi := MeshInstance3D.new()
				mi.mesh = mesh
				mi.material_override = Art.vcol_mat()
				mi.transform = xf
				mi.set_meta("pid", pid)
				model["root"].add_child(mi)
				list.append(mi)
		for k in list.size(): list[k].visible = k < int(s["stock"])
		# price tag
		var t: Dictionary = tags[i]
		var plate: MeshInstance3D = t["plate"]
		var lab: Label3D = t["label"]
		if pid == "":
			plate.material_override = Art.mat(Color("d9d4ca")); lab.text = "—"; lab.modulate = Cfg.INK3
		else:
			var price: int = game.effective_price(pid)
			var sale: bool = game.is_discounted(pid)
			var ratio := float(s["stock"]) / maxf(1.0, cap())
			var col := Color("fbf6ee")
			var txt := Cfg.INK
			if int(s["stock"]) == 0: col = Cfg.BAD; txt = Color.WHITE
			elif sale: col = Color("d6333a"); txt = Color.WHITE
			elif ratio < 0.34: col = Color("f6b24a")
			plate.material_override = Art.mat(col, 0.6)
			lab.text = "₺%d" % price
			lab.modulate = txt

func set_depot_fill(f: float) -> void:
	var boxes: Array = model["boxes"]
	var n := ceili(f * boxes.size())
	for i in boxes.size(): boxes[i].visible = i < n
