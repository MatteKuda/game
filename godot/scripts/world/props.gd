class_name Props
## Hand-built fixture models in the "Mahalle Pop" style. Origin = footprint centre on the floor,
## front (customer side) faces +Z. Returns a model dictionary:
##   root, height, slots: [{units: Array[Transform3D], tag: Vector3}], boxes: Array[Node3D],
##   pos_device: Node3D, lights: Array[Light3D]

static func build(def: Dictionary) -> Dictionary:
	var m := {"root": Node3D.new(), "height": 1.0, "slots": [], "boxes": [], "pos_device": null, "lights": []}
	match def["id"]:
		"raf": _shelf_wood(m)
		"dolap": _fridge(m)
		"sepet": _bread_basket(m)
		"kasa": _register(m)
		"depo": _depot(m)
		"saksi": _plant(m)
		"cop": _bin(m)
		"gondol": _gondola(m)
		"manav": _produce(m)
		"acik": _open_cooler(m)
		"kamera": _camera(m)
		"alarm": _gate(m)
		"cay_ocagi": _tea_station(m)
		"bantkasa": _belt_register(m)
		"selfkasa": _self_checkout(m)
		"levha": _aisle_sign(m)
		"firin": _oven(m)
		"araba": _cart_park(m)
		"masa": _table(m)
		"oyunalani": _play_area(m)
		"bank": _bench(m)
		"gondolbasi": _endcap(m)
		"derin": _freezer(m)
		"sarkuteri": _deli(m)
		"depooda", "soguk", "molaodasi": _room(m, def)
		"wc": _wc(m)
	return m

# ------------------------------------------------------------------ helpers
static func _grid(xs: Array, ys: Array, zs: Array) -> Array:
	var out: Array[Transform3D] = []
	for y in ys:
		for z in zs:
			for x in xs:
				out.append(Transform3D(Basis.from_euler(Vector3(0, randf_range(-0.12, 0.12), 0)), Vector3(x, y, z)))
	return out

static func _span(center: float, width: float, n: int) -> Array:
	var out := []
	for i in n: out.append(center - width * 0.5 + width * (i + 0.5) / n)
	return out

# ------------------------------------------------------------------ Ahşap Raf (2x1)
static func _shelf_wood(m: Dictionary) -> void:
	var r: Node3D = m["root"]
	var wood := Art.mat(Cfg.WOOD, 0.7)
	var dark := Art.mat(Cfg.WOOD_DARK, 0.7)
	var lip := Art.mat(Cfg.TERRA, 0.6)
	Art.box(r, Vector3(1.96, 1.72, 0.05), Art.mat(Color("e9c9a0"), 0.8), Vector3(0, 0.9, -0.38), 0.01)
	for sx in [-1, 1]: Art.box(r, Vector3(0.07, 1.82, 0.62), dark, Vector3(sx * 0.955, 0.91, -0.1), 0.02)
	Art.box(r, Vector3(1.9, 0.14, 0.58), dark, Vector3(0, 0.07, -0.1), 0.02)
	for y in [0.62, 1.16]:
		Art.box(r, Vector3(1.86, 0.045, 0.56), wood, Vector3(0, y, -0.1), 0.012)
		Art.box(r, Vector3(1.86, 0.05, 0.03), lip, Vector3(0, y - 0.01, 0.185), 0.01)
	Art.box(r, Vector3(1.86, 0.045, 0.56), wood, Vector3(0, 0.16, -0.1), 0.012)
	Art.box(r, Vector3(1.86, 0.05, 0.03), lip, Vector3(0, 0.15, 0.185), 0.01)
	# crown sign
	Art.box(r, Vector3(1.4, 0.26, 0.06), lip, Vector3(0, 1.93, -0.3), 0.04)
	Art.label(r, "KURU GIDA", 64, Cfg.CREAM, Vector3(0, 1.93, -0.265))
	for s in 2:
		var cx := -0.47 + s * 0.94
		m["slots"].append({"units": _grid(_span(cx, 0.84, 4), [0.185, 0.645, 1.185], [0.0]), "tag": Vector3(cx, 0.15, 0.205)})
	m["height"] = 2.1

# ------------------------------------------------------------------ İçecek Dolabı (1x1)
static func _fridge(m: Dictionary) -> void:
	var r: Node3D = m["root"]
	var body := Art.mat(Color("f4f1ea"), 0.35, 0.1)
	var inner := Art.mat(Color("d8eef6"), 0.4, 0.0, 0.35)
	Art.box(r, Vector3(0.9, 1.9, 0.08), body, Vector3(0, 0.95, -0.38), 0.02)
	for sx in [-1, 1]: Art.box(r, Vector3(0.07, 1.9, 0.8), body, Vector3(sx * 0.415, 0.95, -0.02), 0.03)
	Art.box(r, Vector3(0.9, 0.16, 0.8), Art.mat(Cfg.STEEL_DARK, 0.5, 0.3), Vector3(0, 0.08, -0.02), 0.03)
	Art.box(r, Vector3(0.9, 0.34, 0.82), Art.mat(Cfg.TEAL, 0.5), Vector3(0, 2.05, -0.02), 0.05)
	Art.label(r, "SOĞUK", 70, Cfg.CREAM, Vector3(0, 2.05, 0.395))
	Art.box(r, Vector3(0.76, 1.66, 0.02), inner, Vector3(0, 1.02, -0.33), 0.0)
	for y in [0.58, 1.18]: Art.box(r, Vector3(0.76, 0.025, 0.62), Art.mat(Cfg.STEEL, 0.3, 0.6), Vector3(0, y, -0.03), 0.005)
	Art.box(r, Vector3(0.76, 0.025, 0.62), Art.mat(Cfg.STEEL, 0.3, 0.6), Vector3(0, 0.2, -0.03), 0.005)
	# glass door with chrome frame and handle
	var door := Node3D.new(); door.position = Vector3(0, 1.02, 0.37); r.add_child(door)
	Art.box(door, Vector3(0.8, 1.72, 0.012), Art.glass(Color(0.8, 0.93, 1.0), 0.18), Vector3.ZERO, 0.0)
	for sx in [-1, 1]: Art.box(door, Vector3(0.04, 1.74, 0.04), Art.mat(Cfg.STEEL, 0.25, 0.8), Vector3(sx * 0.4, 0, 0), 0.01)
	for sy in [-1, 1]: Art.box(door, Vector3(0.84, 0.05, 0.04), Art.mat(Cfg.STEEL, 0.25, 0.8), Vector3(0, sy * 0.86, 0), 0.01)
	Art.box(door, Vector3(0.035, 0.5, 0.05), Art.mat(Cfg.STEEL_DARK, 0.3, 0.6), Vector3(0.33, 0, 0.04), 0.012)
	var l := OmniLight3D.new(); l.light_color = Color("dff4ff"); l.light_energy = 0.6; l.omni_range = 1.6; l.position = Vector3(0, 1.5, 0.1)
	r.add_child(l); m["lights"].append(l)
	for s in 2:
		var y := 1.205 if s == 0 else 0.605
		m["slots"].append({"units": _grid(_span(0, 0.66, 5), [y], [0.12, -0.12]), "tag": Vector3(0, y - 0.03, 0.27)})
	m["height"] = 2.25

# ------------------------------------------------------------------ Fırın Sepeti (1x1)
static func _bread_basket(m: Dictionary) -> void:
	var r: Node3D = m["root"]
	var wood := Art.mat(Cfg.WOOD_DARK, 0.75)
	var wicker := Art.mat(Color("d9a35e"), 0.9)
	var wicker2 := Art.mat(Color("c48a45"), 0.9)
	for sx in [-1, 1]:
		for sz in [-1, 1]: Art.box(r, Vector3(0.05, 1.2, 0.05), wood, Vector3(sx * 0.4, 0.6, sz * 0.3), 0.01)
	# two tilted wicker baskets
	for tier in 2:
		var b := Node3D.new(); b.position = Vector3(0, 0.95 if tier == 0 else 0.45, -0.08 if tier == 0 else 0.02)
		b.rotation.x = 0.28
		r.add_child(b)
		Art.box(b, Vector3(0.84, 0.05, 0.6), wicker2, Vector3.ZERO, 0.02)
		Art.box(b, Vector3(0.84, 0.16, 0.05), wicker, Vector3(0, 0.07, 0.3), 0.02)
		Art.box(b, Vector3(0.84, 0.2, 0.05), wicker, Vector3(0, 0.09, -0.3), 0.02)
		for sx in [-1, 1]: Art.box(b, Vector3(0.05, 0.18, 0.6), wicker, Vector3(sx * 0.42, 0.08, 0), 0.02)
		Art.box(b, Vector3(0.7, 0.012, 0.45), Art.mat(Color("f7efe0"), 0.95), Vector3(0, 0.03, 0), 0.0) # linen cloth
	# chalk sign
	Art.box(r, Vector3(0.5, 0.26, 0.03), Art.mat(Color("2e3b33"), 0.9), Vector3(0, 1.38, -0.28), 0.02)
	Art.label(r, "TAZE", 54, Color("fff7e3"), Vector3(0, 1.38, -0.262), 0.0, "display700")
	for s in 2:
		var y := 0.99 if s == 0 else 0.49
		var zc := -0.08 if s == 0 else 0.02
		var units: Array[Transform3D] = []
		for k in 10:
			var x := -0.3 + (k % 5) * 0.15
			var z := zc + (0.1 if k < 5 else -0.08)
			var yy := y + (0.02 if k < 5 else 0.07)
			units.append(Transform3D(Basis.from_euler(Vector3(0.28, randf_range(-0.6, 0.6), 0)), Vector3(x, yy, z)))
		m["slots"].append({"units": units, "tag": Vector3(0, y - 0.05, zc + 0.33)})
	m["height"] = 1.6

# ------------------------------------------------------------------ Kasa Tezgâhı (2x1)
static func _register(m: Dictionary) -> void:
	var r: Node3D = m["root"]
	var front := Art.mat(Cfg.WOOD, 0.7)
	Art.box(r, Vector3(1.9, 0.9, 0.62), front, Vector3(0, 0.45, 0), 0.03)
	Art.box(r, Vector3(1.9, 0.12, 0.02), Art.mat(Cfg.TEAL, 0.55), Vector3(0, 0.72, 0.315), 0.0)
	Art.box(r, Vector3(1.9, 0.08, 0.02), Art.mat(Cfg.TEAL_DARK, 0.55), Vector3(0, 0.15, 0.315), 0.0)
	Art.box(r, Vector3(2.0, 0.06, 0.74), Art.mat(Color("f3ede2"), 0.35), Vector3(0, 0.93, 0), 0.02)
	# cash register
	var reg := Node3D.new(); reg.position = Vector3(-0.45, 0.96, -0.08); r.add_child(reg)
	Art.box(reg, Vector3(0.42, 0.16, 0.36), Art.mat(Color("3a4458"), 0.45, 0.2), Vector3(0, 0.08, 0), 0.03)
	Art.box(reg, Vector3(0.36, 0.05, 0.2), Art.mat(Color("c9ced6"), 0.4, 0.3), Vector3(0, 0.18, 0.05), 0.015)
	var scr := Art.box(reg, Vector3(0.26, 0.16, 0.03), Art.mat(Color("1f2a44"), 0.3), Vector3(0, 0.28, -0.12), 0.01)
	scr.rotation.x = -0.35
	Art.box(reg, Vector3(0.2, 0.1, 0.005), Art.mat(Color("7fe3c8"), 0.3, 0.0, 1.2), Vector3(0, 0.285, -0.1), 0.0).rotation.x = -0.35
	# little impulse tray + tip jar + sign card
	Art.box(r, Vector3(0.44, 0.08, 0.28), Art.mat(Cfg.MUSTARD, 0.6), Vector3(0.55, 1.0, 0.18), 0.02)
	for i in 5: Art.box(r, Vector3(0.07, 0.04, 0.2), Art.mat([Color("d8352c"), Color("5a2f22"), Color("2e6db4"), Color("f6b93b"), Color("6c4ab6")][i], 0.5), Vector3(0.39 + i * 0.08, 1.06, 0.18), 0.01)
	var card := Node3D.new(); card.position = Vector3(0.1, 1.05, 0.25); r.add_child(card)
	Art.box(card, Vector3(0.3, 0.16, 0.015), Art.mat(Cfg.TERRA, 0.6), Vector3.ZERO, 0.01).rotation.x = -0.25
	var kl := Art.label(card, "KASA", 40, Cfg.CREAM, Vector3(0, 0.0, 0.012)); kl.rotation.x = -0.25
	# contactless POS (upgrade)
	var pos := Node3D.new(); pos.position = Vector3(-0.05, 0.96, 0.2); r.add_child(pos)
	Art.box(pos, Vector3(0.1, 0.03, 0.16), Art.mat(Color("1f2a44"), 0.4), Vector3(0, 0.015, 0), 0.01)
	Art.box(pos, Vector3(0.08, 0.005, 0.07), Art.mat(Color("7fd6ff"), 0.3, 0.0, 1.5), Vector3(0, 0.032, -0.03), 0.0)
	pos.visible = false
	m["pos_device"] = pos
	m["height"] = 1.4

# ------------------------------------------------------------------ Depo Rafı (2x1)
static func _depot(m: Dictionary) -> void:
	var r: Node3D = m["root"]
	var steel := Art.mat(Color("5d6b7a"), 0.45, 0.6)
	for sx in [-1, 1]:
		for sz in [-1, 1]: Art.box(r, Vector3(0.05, 1.9, 0.05), steel, Vector3(sx * 0.94, 0.95, -0.1 + sz * 0.27), 0.01)
	var board := Art.mat(Color("8f9aa6"), 0.5, 0.4)
	for y in [0.12, 0.72, 1.32]: Art.box(r, Vector3(1.92, 0.04, 0.58), board, Vector3(0, y, -0.1), 0.01)
	Art.box(r, Vector3(1.92, 0.06, 0.02), Art.mat(Cfg.MUSTARD, 0.6), Vector3(0, 1.93, 0.18), 0.0)
	var cardboard := [Color("c99a62"), Color("b98b55"), Color("d4a76f")]
	var k := 0
	for y in [0.14, 0.74, 1.34]:
		for x in [-0.62, -0.02, 0.58]:
			var b := Node3D.new(); b.position = Vector3(x + randf_range(-0.04, 0.04), y, -0.1)
			b.rotation.y = randf_range(-0.12, 0.12)
			r.add_child(b)
			var c: Color = cardboard[k % 3]
			var h := randf_range(0.34, 0.5)
			Art.box(b, Vector3(0.5, h, 0.46), Art.mat(c, 0.9), Vector3(0, h * 0.5, 0), 0.02)
			Art.box(b, Vector3(0.08, 0.005, 0.47), Art.mat(Color("e8d7b5"), 0.8), Vector3(0, h + 0.002, 0), 0.0)
			Art.box(b, Vector3(0.16, 0.1, 0.005), Art.mat(Color("f6efe3"), 0.9), Vector3(0.1, h * 0.55, 0.232), 0.0)
			m["boxes"].append(b)
			k += 1
	m["height"] = 2.0

# ------------------------------------------------------------------ Saksı (1x1)
static func _plant(m: Dictionary) -> void:
	var r: Node3D = m["root"]
	Art.cyl(r, 0.24, 0.18, 0.42, Art.mat(Color("c8643c"), 0.8), Vector3(0, 0.21, 0))
	Art.cyl(r, 0.26, 0.26, 0.06, Art.mat(Color("b4552f"), 0.8), Vector3(0, 0.42, 0))
	Art.cyl(r, 0.22, 0.22, 0.02, Art.mat(Color("5b3a26"), 1.0), Vector3(0, 0.44, 0))
	Art.cyl(r, 0.025, 0.035, 0.6, Art.mat(Color("6b4a2f"), 0.9), Vector3(0, 0.72, 0))
	var greens := [Color("5fa35a"), Color("4c8f4f"), Color("73b865"), Color("3f7f47")]
	for i in 9:
		var a := i * 2.4
		var hgt := 0.8 + (i % 3) * 0.22
		var leaf := Art.sphere(r, 0.2, Art.mat(greens[i % 4], 0.8), Vector3(cos(a) * 0.2, hgt, sin(a) * 0.2), 0.55)
		leaf.scale = Vector3(1.0, 0.45, 0.7)
		leaf.rotation = Vector3(randf_range(-0.4, 0.4), a, randf_range(-0.3, 0.3))
	m["height"] = 1.4

# ------------------------------------------------------------------ Çöp Kovası (1x1)
static func _bin(m: Dictionary) -> void:
	var r: Node3D = m["root"]
	Art.cyl(r, 0.2, 0.17, 0.6, Art.mat(Cfg.TEAL, 0.5), Vector3(0, 0.3, 0))
	Art.cyl(r, 0.215, 0.215, 0.06, Art.mat(Cfg.TEAL_DARK, 0.5), Vector3(0, 0.62, 0))
	Art.box(r, Vector3(0.16, 0.03, 0.05), Art.mat(Cfg.STEEL, 0.3, 0.7), Vector3(0, 0.66, 0), 0.01)
	Art.cyl(r, 0.205, 0.205, 0.04, Art.mat(Cfg.CREAM, 0.6), Vector3(0, 0.42, 0))
	m["height"] = 0.8

# ------------------------------------------------------------------ Orta Gondol (3x1)
static func _gondola(m: Dictionary) -> void:
	var r: Node3D = m["root"]
	var white := Art.mat(Color("eef0f2"), 0.4, 0.2)
	var peg := Art.mat(Color("d5dade"), 0.5, 0.2)
	Art.box(r, Vector3(2.94, 1.55, 0.06), peg, Vector3(0, 0.95, -0.3), 0.01)
	Art.box(r, Vector3(2.94, 0.16, 0.62), Art.mat(Color("3a4458"), 0.5), Vector3(0, 0.08, -0.05), 0.02)
	for sx in [-1.47, 1.47]: Art.box(r, Vector3(0.05, 1.7, 0.62), white, Vector3(sx, 0.9, -0.05), 0.01)
	for y in [0.5, 0.98]:
		Art.box(r, Vector3(2.9, 0.035, 0.5), white, Vector3(0, y, -0.03), 0.008)
		Art.box(r, Vector3(2.9, 0.06, 0.02), Art.mat(Cfg.TEAL, 0.5), Vector3(0, y - 0.01, 0.225), 0.0)
	Art.box(r, Vector3(2.9, 0.035, 0.5), white, Vector3(0, 0.17, -0.03), 0.008)
	Art.box(r, Vector3(2.94, 0.28, 0.08), Art.mat(Cfg.TEAL, 0.5), Vector3(0, 1.84, -0.28), 0.04)
	Art.label(r, "MARKET REYONU", 60, Cfg.CREAM, Vector3(0, 1.84, -0.235))
	for s in 3:
		var cx := -0.97 + s * 0.97
		m["slots"].append({"units": _grid(_span(cx, 0.86, 7), [0.515, 0.995], [0.02]), "tag": Vector3(cx, 0.48, 0.24)})
	m["height"] = 2.05

# ------------------------------------------------------------------ Manav Tezgâhı (2x1)
static func _produce(m: Dictionary) -> void:
	var r: Node3D = m["root"]
	var wood := Art.mat(Color("b07a45"), 0.8)
	var crate := Art.mat(Color("d9ad72"), 0.85)
	Art.box(r, Vector3(1.9, 0.5, 0.7), Art.mat(Cfg.WOOD_DARK, 0.8), Vector3(0, 0.25, -0.05), 0.03)
	for s in 2:
		var cx := -0.47 + s * 0.94
		var c := Node3D.new(); c.position = Vector3(cx, 0.62, -0.02); c.rotation.x = 0.35; r.add_child(c)
		Art.box(c, Vector3(0.88, 0.05, 0.66), crate, Vector3.ZERO, 0.01)
		for sz in [-1, 1]: Art.box(c, Vector3(0.88, 0.14, 0.04), crate, Vector3(0, 0.06, sz * 0.33), 0.01)
		for sx in [-1, 1]: Art.box(c, Vector3(0.04, 0.14, 0.66), wood, Vector3(sx * 0.44, 0.06, 0), 0.01)
		var units: Array[Transform3D] = []
		for k in 16:
			var x := -0.33 + (k % 4) * 0.22
			var z := 0.22 - (k / 4) * 0.15
			var y := 0.03 + (0.05 if (k / 4) % 2 == 1 else 0.0)
			units.append(c.transform * Transform3D(Basis.from_euler(Vector3(0, randf() * TAU, 0)), Vector3(x + randf_range(-0.02, 0.02), y, z)))
		m["slots"].append({"units": units, "tag": Vector3(cx, 0.46, 0.31)})
	# little striped awning over the stand
	var aw := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(2.0, 0.5); aw.mesh = pm
	aw.material_override = Art.shader_mat("stripes", {"color_a": Color("3f8f3a"), "color_b": Color("fff1dc"), "count": 7.0})
	aw.position = Vector3(0, 1.62, -0.1); aw.rotation.x = 0.35; r.add_child(aw)
	for sx in [-1, 1]: Art.box(r, Vector3(0.04, 1.2, 0.04), wood, Vector3(sx * 0.93, 1.05, -0.33), 0.01)
	Art.box(r, Vector3(0.7, 0.24, 0.03), Art.mat(Color("2e3b33"), 0.9), Vector3(0, 1.3, -0.33), 0.02)
	Art.label(r, "MANAV", 50, Color("fff7e3"), Vector3(0, 1.3, -0.31), 0.0, "display700")
	m["height"] = 1.8

# ------------------------------------------------------------------ Açık Soğutucu (3x1)
static func _open_cooler(m: Dictionary) -> void:
	var r: Node3D = m["root"]
	var body := Art.mat(Color("f4f1ea"), 0.35, 0.1)
	var inner := Art.mat(Color("cfe9f3"), 0.35, 0.0, 0.3)
	Art.box(r, Vector3(2.96, 1.9, 0.1), body, Vector3(0, 0.95, -0.38), 0.02)
	for sx in [-1, 1]: Art.box(r, Vector3(0.08, 1.9, 0.78), body, Vector3(sx * 1.44, 0.95, -0.04), 0.03)
	Art.box(r, Vector3(2.96, 0.3, 0.78), Art.mat(Cfg.STEEL_DARK, 0.5, 0.3), Vector3(0, 0.15, -0.04), 0.03)
	Art.box(r, Vector3(2.8, 1.5, 0.02), inner, Vector3(0, 1.05, -0.32), 0.0)
	Art.box(r, Vector3(2.96, 0.3, 0.8), Art.mat(Color("2f6fb5"), 0.5), Vector3(0, 2.0, -0.04), 0.05)
	Art.label(r, "SÜT & SOĞUK", 64, Cfg.CREAM, Vector3(0, 2.0, 0.365))
	Art.box(r, Vector3(2.8, 0.03, 0.03), Art.mat(Color("e9fbff"), 0.2, 0.0, 3.0), Vector3(0, 1.83, 0.3), 0.0)
	for y in [0.62, 1.18]:
		Art.box(r, Vector3(2.8, 0.03, 0.6), Art.mat(Cfg.STEEL, 0.3, 0.6), Vector3(0, y, -0.05), 0.005)
		Art.box(r, Vector3(2.8, 0.06, 0.02), Art.mat(Color("2f6fb5"), 0.5), Vector3(0, y - 0.01, 0.255), 0.0)
	var l := OmniLight3D.new(); l.light_color = Color("dff4ff"); l.light_energy = 0.8; l.omni_range = 2.4; l.position = Vector3(0, 1.6, 0.3)
	r.add_child(l); m["lights"].append(l)
	for s in 3:
		var cx := -0.95 + s * 0.95
		m["slots"].append({"units": _grid(_span(cx, 0.8, 5), [0.635, 1.195], [0.05]), "tag": Vector3(cx, 0.6, 0.27)})
	m["height"] = 2.2

# ------------------------------------------------------------------ Güvenlik Kamerası (ceiling, 1x1)
static func _camera(m: Dictionary) -> void:
	var r: Node3D = m["root"]
	var dark := Art.mat(Color("2d3348"), 0.4, 0.3)
	Art.cyl(r, 0.03, 0.03, 0.5, dark, Vector3(0, 2.85, 0), 8)
	var head := Node3D.new(); head.position = Vector3(0, 2.6, 0); r.add_child(head)
	Art.box(head, Vector3(0.18, 0.16, 0.34), Art.mat(Color("f4f1ea"), 0.35), Vector3(0, 0, 0.08), 0.05)
	Art.cyl(head, 0.06, 0.06, 0.04, Art.mat(Color("1f2a44"), 0.2), Vector3(0, 0, 0.26), 14).rotation.x = PI / 2
	var led := StandardMaterial3D.new(); led.albedo_color = Color("ff3b3b"); led.emission_enabled = true; led.emission = Color("ff3b3b"); led.emission_energy_multiplier = 3.0
	Art.sphere(head, 0.02, led, Vector3(0.06, 0.06, 0.2))
	head.rotation.x = 0.35
	m["led"] = led
	m["spin"] = head
	m["height"] = 2.9

# ------------------------------------------------------------------ Alarm Kapısı (1x1)
static func _gate(m: Dictionary) -> void:
	var r: Node3D = m["root"]
	var body := Art.mat(Color("e9ecef"), 0.3, 0.2)
	Art.box(r, Vector3(0.14, 1.5, 0.6), body, Vector3(0, 0.75, 0), 0.05)
	Art.box(r, Vector3(0.16, 0.08, 0.62), Art.mat(Cfg.TEAL, 0.4), Vector3(0, 1.1, 0), 0.02)
	Art.box(r, Vector3(0.3, 0.06, 0.7), Art.mat(Color("5b6570"), 0.4, 0.5), Vector3(0, 0.03, 0), 0.02)
	var light := StandardMaterial3D.new(); light.albedo_color = Color("ff4a4a"); light.emission_enabled = true; light.emission = Color("ff3030"); light.emission_energy_multiplier = 0.05
	Art.box(r, Vector3(0.16, 0.1, 0.5), light, Vector3(0, 1.52, 0), 0.03)
	m["alarm_light"] = light
	m["height"] = 1.6

# ------------------------------------------------------------------ Çay Ocağı (2x1)
static func _tea_station(m: Dictionary) -> void:
	var r: Node3D = m["root"]
	Art.box(r, Vector3(1.8, 0.9, 0.55), Art.mat(Color("8a5a35"), 0.7), Vector3(0, 0.45, -0.15), 0.03)
	Art.box(r, Vector3(1.9, 0.05, 0.62), Art.mat(Color("efe6d8"), 0.4), Vector3(0, 0.92, -0.15), 0.02)
	# double teapot (çaydanlık)
	var steel := Art.mat(Color("d4d8dd"), 0.25, 0.8)
	Art.cyl(r, 0.14, 0.16, 0.22, steel, Vector3(-0.45, 1.06, -0.2))
	Art.cyl(r, 0.09, 0.11, 0.14, steel, Vector3(-0.45, 1.24, -0.2))
	Art.sphere(r, 0.03, Art.mat(Color("1f2a44")), Vector3(-0.45, 1.33, -0.2))
	for i in 5:
		Art.cyl(r, 0.028, 0.02, 0.08, Art.glass(Color(0.75, 0.3, 0.15), 0.85), Vector3(0.05 + i * 0.12, 0.99, -0.1))
		Art.cyl(r, 0.045, 0.045, 0.01, Art.mat(Color("f4f1ea")), Vector3(0.05 + i * 0.12, 0.955, -0.1))
	Art.box(r, Vector3(1.0, 0.3, 0.04), Art.mat(Color("c8643c"), 0.6), Vector3(0, 1.6, -0.4), 0.03)
	Art.label(r, "ÇAY OCAĞI", 44, Cfg.CREAM, Vector3(0, 1.6, -0.375), 0.0, "display")
	for sx in [-0.5, 0.5]:
		Art.cyl(r, 0.16, 0.16, 0.05, Art.mat(Color("d6333a"), 0.6), Vector3(sx, 0.45, 0.32))
		Art.cyl(r, 0.03, 0.03, 0.43, Art.mat(Color("2d3348")), Vector3(sx, 0.22, 0.32), 8)
	m["height"] = 1.8

# ------------------------------------------------------------------ Bantlı Kasa (3x1)
static func _belt_register(m: Dictionary) -> void:
	var r: Node3D = m["root"]
	Art.box(r, Vector3(2.9, 0.85, 0.66), Art.mat(Color("f4f1ea"), 0.4), Vector3(0, 0.425, 0), 0.03)
	Art.box(r, Vector3(2.9, 0.14, 0.02), Art.mat(Cfg.TEAL, 0.5), Vector3(0, 0.66, 0.335), 0.0)
	var belt := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(1.7, 0.03, 0.48); belt.mesh = bm
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/belt.gdshader"); belt.material_override = sm
	belt.position = Vector3(-0.5, 0.87, 0.04); r.add_child(belt)
	m["belt"] = sm
	Art.box(r, Vector3(1.8, 0.05, 0.06), Art.mat(Color("c3cad2"), 0.3, 0.7), Vector3(-0.5, 0.9, 0.3), 0.01)
	Art.box(r, Vector3(0.7, 0.05, 0.6), Art.mat(Color("d8dde2"), 0.3, 0.5), Vector3(0.95, 0.88, 0.0), 0.01)
	var reg := Node3D.new(); reg.position = Vector3(0.6, 0.9, -0.2); r.add_child(reg)
	Art.box(reg, Vector3(0.36, 0.14, 0.3), Art.mat(Color("3a4458"), 0.45, 0.2), Vector3(0, 0.07, 0), 0.03)
	Art.box(reg, Vector3(0.22, 0.14, 0.02), Art.mat(Color("7fe3c8"), 0.3, 0.0, 1.2), Vector3(0, 0.25, -0.1), 0.0).rotation.x = -0.35
	# lane number pole
	Art.cyl(r, 0.025, 0.025, 1.1, Art.mat(Color("2d3348")), Vector3(1.35, 1.4, -0.25), 8)
	var ln := Art.cyl(r, 0.16, 0.16, 0.05, Art.mat(Cfg.MUSTARD, 0.5), Vector3(1.35, 2.0, -0.25), 20); ln.rotation.x = PI / 2
	Art.label(r, "KASA", 30, Cfg.INK, Vector3(1.35, 2.0, -0.22), 0.0, "display")
	var pos := Node3D.new(); pos.position = Vector3(0.95, 0.91, 0.2); r.add_child(pos)
	Art.box(pos, Vector3(0.1, 0.03, 0.16), Art.mat(Color("1f2a44"), 0.4), Vector3(0, 0.015, 0), 0.01)
	pos.visible = false
	m["pos_device"] = pos
	m["height"] = 2.2

# ------------------------------------------------------------------ Self-Servis Kasa (1x1)
static func _self_checkout(m: Dictionary) -> void:
	var r: Node3D = m["root"]
	Art.box(r, Vector3(0.7, 0.9, 0.55), Art.mat(Color("eef0f2"), 0.35, 0.2), Vector3(0, 0.45, -0.1), 0.04)
	Art.box(r, Vector3(0.72, 0.05, 0.6), Art.mat(Color("1f2a44"), 0.3), Vector3(0, 0.92, -0.1), 0.02)
	var scr := Art.box(r, Vector3(0.42, 0.32, 0.04), Art.mat(Color("1f2a44"), 0.3), Vector3(0, 1.25, -0.25), 0.02); scr.rotation.x = -0.25
	var screen := StandardMaterial3D.new(); screen.albedo_color = Color("61d4ff"); screen.emission_enabled = true; screen.emission = Color("3fb6e8"); screen.emission_energy_multiplier = 1.4
	var sc := Art.box(r, Vector3(0.36, 0.26, 0.01), screen, Vector3(0, 1.25, -0.225), 0.0); sc.rotation.x = -0.25
	Art.box(r, Vector3(0.16, 0.02, 0.16), Art.mat(Color("ff5a5a"), 0.2, 0.0, 1.5), Vector3(0.12, 0.955, 0.05), 0.0)
	Art.cyl(r, 0.02, 0.02, 1.2, Art.mat(Color("2d3348")), Vector3(0.3, 1.5, -0.3), 8)
	var lamp := StandardMaterial3D.new(); lamp.albedo_color = Color("2fae7a"); lamp.emission_enabled = true; lamp.emission = Color("2fae7a"); lamp.emission_energy_multiplier = 2.0
	Art.cyl(r, 0.06, 0.06, 0.1, lamp, Vector3(0.3, 2.1, -0.3))
	m["height"] = 2.2

# ------------------------------------------------------------------ Reyon Levhası (ceiling)
static func _aisle_sign(m: Dictionary) -> void:
	var r: Node3D = m["root"]
	var cols := [Cfg.TEAL, Cfg.TERRA, Color("2f6fb5"), Color("7a5ae0")]
	var names := ["GIDA", "İÇECEK", "TEMİZLİK", "KAHVALTI"]
	var k := randi() % 4
	for sx in [-0.5, 0.5]: Art.cyl(r, 0.008, 0.008, 0.6, Art.mat(Color("2d3348")), Vector3(sx, 2.95, 0), 6)
	Art.box(r, Vector3(1.3, 0.42, 0.06), Art.mat(cols[k], 0.5), Vector3(0, 2.5, 0), 0.05)
	for s in [-1, 1]:
		var l := Art.label(r, names[k], 64, Color.WHITE, Vector3(0, 2.5, s * 0.035), 0.0, "display")
		if s < 0: l.rotation.y = PI
	m["height"] = 2.8

# ------------------------------------------------------------------ Fırın Tezgâhı (2x1)
static func _oven(m: Dictionary) -> void:
	var r: Node3D = m["root"]
	var brick := Art.shader_mat("brick", {"brick": Color("b85c3c"), "mortar": Color("e9dcc8")})
	Art.box(r, Vector3(1.9, 0.9, 0.8), brick, Vector3(0, 0.45, -0.05), 0.0)
	var dome := Art.sphere(r, 0.8, brick, Vector3(0, 0.9, -0.1))
	dome.scale = Vector3(1.15, 0.75, 0.55)
	var glow := StandardMaterial3D.new(); glow.albedo_color = Color("ff9a3a"); glow.emission_enabled = true; glow.emission = Color("ff7a1a"); glow.emission_energy_multiplier = 0.6
	var mouth := Art.cyl(r, 0.28, 0.28, 0.04, glow, Vector3(0, 1.05, 0.34), 18); mouth.rotation.x = PI / 2; mouth.scale = Vector3(1.0, 1.0, 0.7)
	Art.box(r, Vector3(1.95, 0.06, 0.4), Art.mat(Cfg.WOOD, 0.6), Vector3(0, 0.92, 0.42), 0.02)
	for i in 4: Art.torus(r, 0.04, 0.09, Art.mat(Color("c9803e"), 0.8), Vector3(-0.6 + i * 0.4, 0.97, 0.42))
	Art.box(r, Vector3(0.9, 0.3, 0.04), Art.mat(Cfg.TERRA, 0.6), Vector3(0, 2.05, -0.3), 0.03)
	Art.label(r, "TAŞ FIRIN", 50, Cfg.CREAM, Vector3(0, 2.05, -0.275), 0.0, "display")
	var peel := Art.box(r, Vector3(0.08, 0.02, 1.2), Art.mat(Cfg.WOOD_DARK), Vector3(0.85, 1.4, 0.1), 0.01); peel.rotation.x = -1.2
	m["oven_glow"] = glow
	m["height"] = 2.3

# ------------------------------------------------------------------ Alışveriş Arabası Parkı (2x1)
static func _cart_park(m: Dictionary) -> void:
	var r: Node3D = m["root"]
	var steel := Art.mat(Color("c3cad2"), 0.3, 0.7)
	var red := Art.mat(Color("d6333a"), 0.5)
	for i in 4:
		var c := Node3D.new(); c.position = Vector3(-0.55 + i * 0.36, 0, 0); c.rotation.y = PI / 2; r.add_child(c)
		Art.box(c, Vector3(0.5, 0.36, 0.62), Art.glass(Color(0.75, 0.8, 0.85), 0.35), Vector3(0, 0.62, 0), 0.02)
		Art.box(c, Vector3(0.52, 0.03, 0.64), steel, Vector3(0, 0.44, 0), 0.01)
		Art.box(c, Vector3(0.52, 0.04, 0.04), red, Vector3(0, 0.95, -0.36), 0.01)
	Art.box(r, Vector3(1.9, 0.06, 0.06), Art.mat(Color("2d3348")), Vector3(0, 0.5, -0.4), 0.01)
	Art.box(r, Vector3(0.8, 0.3, 0.04), Art.mat(Cfg.MUSTARD, 0.5), Vector3(0, 1.45, -0.4), 0.03)
	Art.label(r, "ARABALAR", 40, Cfg.INK, Vector3(0, 1.45, -0.375), 0.0, "display")
	for sx in [-0.35, 0.35]: Art.cyl(r, 0.02, 0.02, 1.4, Art.mat(Color("2d3348")), Vector3(sx, 0.7, -0.42), 6)
	m["height"] = 1.6

# ------------------------------------------------------------------ Yemek Masası (2x2, 4 seats)
static func _table(m: Dictionary) -> void:
	var r: Node3D = m["root"]
	Art.cyl(r, 0.6, 0.6, 0.06, Art.mat(Color("f4f1ea"), 0.35), Vector3(0, 0.74, 0), 28)
	Art.cyl(r, 0.05, 0.08, 0.72, Art.mat(Color("2d3348"), 0.4, 0.4), Vector3(0, 0.36, 0), 10)
	var cols := [Cfg.MUSTARD, Cfg.TEAL, Cfg.TERRA, Color("6c4ab6")]
	var seats := []
	for i in 4:
		var a := i * PI / 2 + PI / 4
		var p := Vector3(cos(a) * 0.85, 0, sin(a) * 0.85)
		var ch := Node3D.new(); ch.position = p; ch.rotation.y = -a - PI / 2; r.add_child(ch)
		Art.box(ch, Vector3(0.4, 0.06, 0.4), Art.mat(cols[i], 0.6), Vector3(0, 0.46, 0), 0.03)
		Art.box(ch, Vector3(0.4, 0.4, 0.06), Art.mat(cols[i], 0.6), Vector3(0, 0.68, -0.18), 0.03)
		for lx in [-0.16, 0.16]:
			for lz in [-0.16, 0.16]: Art.box(ch, Vector3(0.03, 0.44, 0.03), Art.mat(Color("2d3348")), Vector3(lx, 0.22, lz), 0.0)
		seats.append(p)
	var trays := Node3D.new(); r.add_child(trays); trays.visible = false
	for i in 3:
		var tr := Art.box(trays, Vector3(0.34, 0.03, 0.24), Art.mat(Color("d6333a"), 0.5), Vector3(-0.2 + i * 0.2, 0.79, -0.1 + (i % 2) * 0.2), 0.01)
		tr.rotation.y = i * 0.8
		Art.box(trays, Vector3(0.1, 0.02, 0.08), Art.mat(Color("f2f0ea")), Vector3(-0.2 + i * 0.2, 0.81, -0.1 + (i % 2) * 0.2), 0.01)
	m["seats"] = seats
	m["trays"] = trays
	m["height"] = 1.0

# ------------------------------------------------------------------ Çocuk Oyun Alanı (3x3)
static func _play_area(m: Dictionary) -> void:
	var r: Node3D = m["root"]
	Art.box(r, Vector3(2.9, 0.06, 2.9), Art.shader_mat("checker", {"color_a": Color("7fe3c8"), "color_b": Color("ffd166"), "tile": 0.7}), Vector3(0, 0.03, 0), 0.02)
	for i in 12:
		var a := i * TAU / 12
		Art.cyl(r, 0.05, 0.05, 0.6, Art.mat([Cfg.TERRA, Cfg.MUSTARD, Cfg.TEAL][i % 3], 0.5), Vector3(cos(a) * 1.4, 0.3, sin(a) * 1.4), 10)
	# ball pit
	Art.cyl(r, 0.62, 0.62, 0.35, Art.mat(Color("2f6fb5"), 0.5), Vector3(-0.55, 0.2, 0.5), 24)
	var bc := [Color("e5484d"), Color("f2b33d"), Color("2fae7a"), Color("61b3ff"), Color("7a5ae0")]
	for i in 26:
		Art.sphere(r, 0.07, Art.mat(bc[i % 5], 0.4), Vector3(-0.55 + randf_range(-0.45, 0.45), 0.4 + randf() * 0.05, 0.5 + randf_range(-0.45, 0.45)))
	# slide
	Art.box(r, Vector3(0.7, 1.1, 0.7), Art.mat(Cfg.TERRA, 0.5), Vector3(0.6, 0.55, -0.6), 0.06)
	var sl := Art.box(r, Vector3(0.5, 0.05, 1.5), Art.mat(Cfg.MUSTARD, 0.35), Vector3(0.6, 0.62, 0.3), 0.03); sl.rotation.x = -0.72
	var roof := Art.box(r, Vector3(0.9, 0.08, 0.9), Art.mat(Cfg.TEAL, 0.5), Vector3(0.6, 1.8, -0.6), 0.05)
	for sx in [0.3, 0.9]:
		for sz in [-0.9, -0.3]: Art.cyl(r, 0.03, 0.03, 0.7, Art.mat(Color("2d3348")), Vector3(sx, 1.45, sz), 8)
	m["height"] = 2.0

# ------------------------------------------------------------------ Dinlenme Bankı (2x1)
static func _bench(m: Dictionary) -> void:
	var r: Node3D = m["root"]
	var wood := Art.mat(Cfg.WOOD, 0.6)
	for i in 3: Art.box(r, Vector3(1.6, 0.05, 0.12), wood, Vector3(0, 0.45, -0.12 + i * 0.13), 0.02)
	for i in 2:
		var b := Art.box(r, Vector3(1.6, 0.05, 0.12), wood, Vector3(0, 0.7 + i * 0.16, -0.26), 0.02); b.rotation.x = -0.15
	for sx in [-0.7, 0.7]:
		Art.box(r, Vector3(0.06, 0.45, 0.4), Art.mat(Color("2d3348"), 0.4, 0.4), Vector3(sx, 0.22, 0.0), 0.02)
	Art.cyl(r, 0.18, 0.15, 0.4, Art.mat(Color("c8643c")), Vector3(0.95, 0.2, 0.0))
	Art.sphere(r, 0.22, Art.mat(Color("5fa35a")), Vector3(0.95, 0.52, 0.0))
	m["height"] = 1.0

# ------------------------------------------------------------------ Gondol Başı Teşhir (1x1)
static func _endcap(m: Dictionary) -> void:
	var r: Node3D = m["root"]
	var red := Art.mat(Color("d6333a"), 0.5)
	Art.box(r, Vector3(0.92, 0.12, 0.7), Art.mat(Color("2d3348"), 0.5), Vector3(0, 0.06, -0.05), 0.02)
	Art.box(r, Vector3(0.92, 1.35, 0.1), red, Vector3(0, 0.8, -0.36), 0.03)
	for y in [0.42, 0.82]:
		Art.box(r, Vector3(0.9, 0.035, 0.52), Art.mat(Color("f4f1ea"), 0.4), Vector3(0, y, -0.08), 0.01)
	# price burst sign on top
	var top := Node3D.new(); top.position = Vector3(0, 1.72, -0.36); r.add_child(top)
	Art.cyl(top, 0.3, 0.3, 0.04, Art.mat(Cfg.MUSTARD, 0.5), Vector3.ZERO, 12).rotation.x = PI / 2
	Art.label(top, "FIRSAT", 40, Cfg.INK, Vector3(0, 0, 0.03), 0.0, "display")
	var units := []
	for y in [0.46, 0.86]:
		for x in [-0.3, 0.0, 0.3]:
			for z in [-0.2, 0.05]:
				units.append(Transform3D(Basis(), Vector3(x, y, z)))
	# cap 12: six per shelf
	m["slots"].append({"units": units, "tag": Vector3(0, 0.36, 0.2)})
	m["height"] = 2.0

# ------------------------------------------------------------------ rooms (walled, staff only)
## walls on three sides + a front wall with a door in the middle; staff walk in through the door
static func _room(m: Dictionary, def: Dictionary) -> void:
	var r: Node3D = m["root"]
	var W := float(def["w"]); var D := float(def["d"])
	var H := 1.45
	var id: String = def["id"]
	var wall_col: Color = {"depooda": Color("d9cdb8"), "soguk": Color("cfe6ef"), "molaodasi": Color("f0d6c4")}[id]
	var trim: Color = {"depooda": Color("8a5a35"), "soguk": Color("2f6fb5"), "molaodasi": Cfg.TEAL}[id]
	var floor_col: Color = {"depooda": Color("a8a39a"), "soguk": Color("dfe8ec"), "molaodasi": Color("c98b52")}[id]
	var wm := Art.mat(wall_col, 0.8)
	var cap := Art.mat(Color("2d3348"), 0.6)
	Art.box(r, Vector3(W - 0.04, 0.03, D - 0.04), Art.mat(floor_col, 0.8), Vector3(0, 0.015, 0), 0.0)
	var th := 0.12
	# back and sides
	Art.box(r, Vector3(W, H, th), wm, Vector3(0, H * 0.5, -D * 0.5 + th * 0.5), 0.0)
	for sx in [-1.0, 1.0]:
		Art.box(r, Vector3(th, H, D), wm, Vector3(sx * (W * 0.5 - th * 0.5), H * 0.5, 0), 0.0)
	# front with door gap (1.0 m)
	var seg := (W - 1.0) * 0.5
	for sx in [-1.0, 1.0]:
		Art.box(r, Vector3(seg, H, th), wm, Vector3(sx * (0.5 + seg * 0.5), H * 0.5, D * 0.5 - th * 0.5), 0.0)
		Art.box(r, Vector3(seg + 0.02, 0.2, th + 0.02), Art.mat(trim, 0.6), Vector3(sx * (0.5 + seg * 0.5), 0.1, D * 0.5 - th * 0.5), 0.0)
	# caps
	Art.box(r, Vector3(W + 0.04, 0.06, th + 0.06), cap, Vector3(0, H + 0.03, -D * 0.5 + th * 0.5), 0.02)
	for sx in [-1.0, 1.0]:
		Art.box(r, Vector3(th + 0.06, 0.06, D + 0.04), cap, Vector3(sx * (W * 0.5 - th * 0.5), H + 0.03, 0), 0.02)
		Art.box(r, Vector3(seg + 0.04, 0.06, th + 0.06), cap, Vector3(sx * (0.5 + seg * 0.5), H + 0.03, D * 0.5 - th * 0.5), 0.02)
	# door frame + sign
	for sx in [-0.52, 0.52]: Art.box(r, Vector3(0.06, H + 0.35, 0.16), Art.mat(trim, 0.5), Vector3(sx, (H + 0.35) * 0.5, D * 0.5 - th * 0.5), 0.01)
	Art.box(r, Vector3(1.2, 0.34, 0.1), Art.mat(trim, 0.5), Vector3(0, H + 0.3, D * 0.5 - th * 0.5), 0.03)
	Art.label(r, def["room"], 46, Color.WHITE, Vector3(0, H + 0.3, D * 0.5 - th * 0.5 + 0.06), 0.0, "display")
	if id == "soguk":
		# strip curtain in the doorway + frosty walls
		for i in 6:
			Art.box(r, Vector3(0.15, 1.3, 0.01), Art.glass(Color(0.85, 0.95, 1.0), 0.35), Vector3(-0.42 + i * 0.17, 0.7, D * 0.5 - 0.02), 0.0)
		Art.box(r, Vector3(0.6, 0.35, 0.25), Art.mat(Color("c3cad2"), 0.3, 0.7), Vector3(W * 0.5 - 0.5, H - 0.25, -D * 0.5 + 0.25), 0.03)
	# contents
	var inner_d := D - 0.4
	match id:
		"depooda":
			var steel := Art.mat(Color("5d6b7a"), 0.45, 0.6)
			var board := Art.mat(Color("8f9aa6"), 0.5, 0.4)
			var cardboard := [Color("c99a62"), Color("b98b55"), Color("d4a76f")]
			var k := 0
			# U-shaped racking along back and side walls
			var racks := [[Vector3(0, 0, -D * 0.5 + 0.45), 0.0, W - 0.6], [Vector3(-W * 0.5 + 0.45, 0, 0.1), PI / 2, D - 1.4], [Vector3(W * 0.5 - 0.45, 0, 0.1), -PI / 2, D - 1.4]]
			for rk in racks:
				var n := Node3D.new(); n.position = rk[0]; n.rotation.y = rk[1]; r.add_child(n)
				var ln: float = rk[2]
				for y in [0.1, 0.65, 1.2]: Art.box(n, Vector3(ln, 0.04, 0.55), board, Vector3(0, y, 0), 0.01)
				for sx in [-1.0, 1.0]: Art.box(n, Vector3(0.05, 1.3, 0.55), steel, Vector3(sx * ln * 0.5, 0.65, 0), 0.01)
				var x := -ln * 0.5 + 0.3
				while x < ln * 0.5 - 0.2:
					for y in [0.12, 0.67]:
						var b := Node3D.new(); b.position = Vector3(x, y, 0); b.rotation.y = randf_range(-0.1, 0.1); n.add_child(b)
						var h := randf_range(0.3, 0.45)
						Art.box(b, Vector3(0.42, h, 0.44), Art.mat(cardboard[k % 3], 0.9), Vector3(0, h * 0.5, 0), 0.02)
						Art.box(b, Vector3(0.07, 0.005, 0.45), Art.mat(Color("e8d7b5")), Vector3(0, h + 0.003, 0), 0.0)
						m["boxes"].append(b); k += 1
					x += 0.5
			# pallet jack in the middle
			Art.box(r, Vector3(0.5, 0.08, 0.8), Art.mat(Cfg.MUSTARD, 0.5), Vector3(0.2, 0.08, 0.3), 0.02)
			Art.cyl(r, 0.02, 0.02, 0.9, Art.mat(Color("2d3348")), Vector3(0.2, 0.5, -0.15), 6)
		"soguk":
			var steel2 := Art.mat(Color("c3cad2"), 0.3, 0.7)
			var crate_cols := [Color("f7f7f2"), Color("7fc4ea"), Color("d8352c"), Color("faf6e8"), Color("2b7fd8")]
			var k2 := 0
			for sx in [-1.0, 1.0]:
				var n2 := Node3D.new(); n2.position = Vector3(sx * (W * 0.5 - 0.42), 0, -0.1); n2.rotation.y = sx * -PI / 2; r.add_child(n2)
				for y in [0.1, 0.6, 1.1]: Art.box(n2, Vector3(inner_d, 0.03, 0.5), steel2, Vector3(0, y, 0), 0.01)
				var z := -inner_d * 0.5 + 0.25
				while z < inner_d * 0.5 - 0.2:
					for y in [0.12, 0.62]:
						var b2 := Node3D.new(); b2.position = Vector3(z, y, 0); n2.add_child(b2)
						Art.box(b2, Vector3(0.4, 0.28, 0.4), Art.mat(crate_cols[k2 % 5], 0.6), Vector3(0, 0.14, 0), 0.03)
						m["boxes"].append(b2); k2 += 1
					z += 0.48
			Art.box(r, Vector3(W - 1.8, 0.02, 0.02), Art.mat(Color("7fd6ff"), 0.3, 0.0, 2.0), Vector3(0, H - 0.1, -D * 0.5 + 0.2), 0.0)
		"molaodasi":
			# sofa, coffee table, tea corner, lockers, plant
			var sofa := Art.mat(Cfg.TEAL, 0.8)
			Art.box(r, Vector3(1.6, 0.4, 0.7), sofa, Vector3(-0.3, 0.25, -D * 0.5 + 0.5), 0.08)
			Art.box(r, Vector3(1.6, 0.45, 0.18), sofa, Vector3(-0.3, 0.6, -D * 0.5 + 0.22), 0.07)
			for sx in [-1.0, 1.0]: Art.box(r, Vector3(0.18, 0.55, 0.7), sofa, Vector3(-0.3 + sx * 0.8, 0.3, -D * 0.5 + 0.5), 0.07)
			for sx in [-0.55, -0.05]: Art.box(r, Vector3(0.45, 0.12, 0.5), Art.mat(Cfg.MUSTARD, 0.9), Vector3(-0.3 + sx + 0.25, 0.5, -D * 0.5 + 0.5), 0.05)
			Art.cyl(r, 0.32, 0.32, 0.05, Art.mat(Cfg.WOOD, 0.6), Vector3(-0.3, 0.42, 0.15), 20)
			Art.cyl(r, 0.04, 0.04, 0.4, Art.mat(Color("2d3348")), Vector3(-0.3, 0.2, 0.15), 8)
			for i in 2: Art.cyl(r, 0.028, 0.02, 0.08, Art.glass(Color(0.75, 0.3, 0.15), 0.85), Vector3(-0.4 + i * 0.2, 0.49, 0.15))
			var lk := Art.mat(Color("5b6570"), 0.4, 0.5)
			for i in 3:
				Art.box(r, Vector3(0.36, 1.25, 0.4), lk, Vector3(W * 0.5 - 0.35, 0.63, -D * 0.5 + 0.35 + i * 0.4), 0.02)
				Art.box(r, Vector3(0.02, 0.12, 0.02), Art.mat(Cfg.MUSTARD), Vector3(W * 0.5 - 0.54, 0.8, -D * 0.5 + 0.35 + i * 0.4), 0.0)
			Art.cyl(r, 0.18, 0.15, 0.35, Art.mat(Color("c8643c")), Vector3(-W * 0.5 + 0.35, 0.18, D * 0.5 - 0.45))
			Art.sphere(r, 0.26, Art.mat(Color("5fa35a")), Vector3(-W * 0.5 + 0.35, 0.58, D * 0.5 - 0.45))
	m["seat_pt"] = Vector3(-0.3, 0, -D * 0.5 + 0.55)
	m["height"] = H + 0.5

# ------------------------------------------------------------------ AVM Tuvalet (3x2)
static func _wc(m: Dictionary) -> void:
	var r: Node3D = m["root"]
	var W := 3.0; var D := 2.0; var H := 1.6
	var wm := Art.mat(Color("e9eef2"), 0.6)
	var tile := Art.shader_mat("checker", {"color_a": Color("e8f1f5"), "color_b": Color("bcd4df"), "tile": 0.3})
	Art.box(r, Vector3(W - 0.04, 0.03, D - 0.04), tile, Vector3(0, 0.015, 0), 0.0)
	var th := 0.12
	Art.box(r, Vector3(W, H, th), wm, Vector3(0, H * 0.5, -D * 0.5 + th * 0.5), 0.0)
	for sx in [-1.0, 1.0]: Art.box(r, Vector3(th, H, D), wm, Vector3(sx * (W * 0.5 - th * 0.5), H * 0.5, 0), 0.0)
	Art.box(r, Vector3(th, H, D - 0.3), Art.mat(Color("2f6fb5"), 0.5), Vector3(0, H * 0.5, -0.15), 0.0) # divider
	var cap := Art.mat(Color("2d3348"), 0.6)
	for side in [-1.0, 1.0]:
		var cx: float = side * W * 0.25
		# front wall pieces around each door
		Art.box(r, Vector3(0.3, H, th), wm, Vector3(cx - side * 0.52, H * 0.5, D * 0.5 - th * 0.5), 0.0)
		Art.box(r, Vector3(0.3, H, th), wm, Vector3(cx + side * 0.52, H * 0.5, D * 0.5 - th * 0.5), 0.0)
		# stall with toilet, sink
		Art.box(r, Vector3(0.36, 0.4, 0.5), Art.mat(Color("fbfbf8"), 0.2), Vector3(cx - 0.25, 0.2, -D * 0.5 + 0.4), 0.08)
		Art.box(r, Vector3(0.4, 0.45, 0.14), Art.mat(Color("fbfbf8"), 0.2), Vector3(cx - 0.25, 0.55, -D * 0.5 + 0.18), 0.04)
		Art.box(r, Vector3(0.45, 0.1, 0.32), Art.mat(Color("fbfbf8"), 0.2), Vector3(cx + 0.3, 0.8, -D * 0.5 + 0.25), 0.04)
		Art.box(r, Vector3(0.4, 0.5, 0.02), Art.mat(Color("cfe2ea"), 0.05, 0.8), Vector3(cx + 0.3, 1.25, -D * 0.5 + 0.13), 0.0)
		# sign above door
		var col := Color("2f6fb5") if side < 0 else Color("d6333a")
		Art.box(r, Vector3(0.7, 0.34, 0.08), Art.mat(col, 0.5), Vector3(cx, H + 0.25, D * 0.5 - th * 0.5), 0.03)
		Art.label(r, "BAY" if side < 0 else "BAYAN", 40, Color.WHITE, Vector3(cx, H + 0.25, D * 0.5 - th * 0.5 + 0.05), 0.0, "display")
	Art.box(r, Vector3(W + 0.04, 0.06, th + 0.06), cap, Vector3(0, H + 0.03, -D * 0.5 + th * 0.5), 0.02)
	for sx in [-1.0, 1.0]: Art.box(r, Vector3(th + 0.06, 0.06, D + 0.04), cap, Vector3(sx * (W * 0.5 - th * 0.5), H + 0.03, 0), 0.02)
	# dirt marks shown when it needs cleaning
	var dirt := Node3D.new(); dirt.visible = false; r.add_child(dirt)
	for i in 5:
		var q := Art.cyl(dirt, 0.12 + i * 0.02, 0.12 + i * 0.02, 0.01, Art.mat(Color("9a8a5a"), 0.9), Vector3(-1.0 + i * 0.5, 0.035, 0.2 + (i % 2) * 0.3), 12)
		q.scale = Vector3(1, 1, 0.6)
	m["dirt"] = dirt
	m["height"] = H + 0.5

# ------------------------------------------------------------------ Dondurma Dolabı (2x1 chest freezer)
static func _freezer(m: Dictionary) -> void:
	var r: Node3D = m["root"]
	var body := Art.mat(Color("f7f6f2"), 0.35, 0.1)
	Art.box(r, Vector3(1.86, 0.78, 0.8), body, Vector3(0, 0.39, 0), 0.05)
	Art.box(r, Vector3(1.88, 0.12, 0.82), Art.mat(Cfg.STEEL_DARK, 0.5, 0.3), Vector3(0, 0.06, 0), 0.03)
	# colourful band with the brand
	Art.box(r, Vector3(1.87, 0.26, 0.02), Art.mat(Color("61b3ff"), 0.5), Vector3(0, 0.46, 0.405), 0.01)
	for i in 5: Art.sphere(r, 0.06, Art.mat([Color("f7d6e0"), Color("fff1dc"), Color("8a5a35"), Color("86d6b4"), Color("f2b33d")][i], 0.6), Vector3(-0.72 + i * 0.36, 0.46, 0.41), 0.4)
	Art.label(r, "DONDURMA", 54, Color.WHITE, Vector3(0, 0.46, 0.42), 0.0, "display", 8, Color("2f6fb5"))
	# frosty inside and sliding glass lids
	Art.box(r, Vector3(1.7, 0.02, 0.66), Art.mat(Color("e4f4fb"), 0.3, 0.0, 0.2), Vector3(0, 0.62, 0), 0.0)
	for sx in [-1, 1]:
		var lid := Art.box(r, Vector3(0.9, 0.012, 0.7), Art.glass(Color(0.85, 0.95, 1.0), 0.2), Vector3(sx * 0.45, 0.8, 0), 0.0)
		lid.rotation.z = sx * 0.02
	Art.box(r, Vector3(1.86, 0.04, 0.04), Art.mat(Cfg.STEEL, 0.25, 0.8), Vector3(0, 0.8, 0.38), 0.01)
	Art.box(r, Vector3(1.86, 0.04, 0.04), Art.mat(Cfg.STEEL, 0.25, 0.8), Vector3(0, 0.8, -0.38), 0.01)
	for s in 2:
		var cx := -0.45 + s * 0.9
		var units: Array[Transform3D] = []
		for k in 12:
			var x := cx - 0.3 + (k % 4) * 0.2
			var z := -0.18 + (k / 4) * 0.18
			units.append(Transform3D(Basis.from_euler(Vector3(-PI / 2 + 0.25, 0, randf_range(-0.3, 0.3))), Vector3(x, 0.66, z)))
		m["slots"].append({"units": units, "tag": Vector3(cx, 0.72, 0.43)})
	m["height"] = 0.95

# ------------------------------------------------------------------ Şarküteri Tezgâhı (3x1 glass deli counter)
static func _deli(m: Dictionary) -> void:
	var r: Node3D = m["root"]
	var wood := Art.mat(Cfg.WOOD_DARK, 0.7)
	Art.box(r, Vector3(2.9, 0.8, 0.7), Art.mat(Color("8a2f2a"), 0.6), Vector3(0, 0.4, 0.0), 0.04)
	Art.box(r, Vector3(2.92, 0.08, 0.74), wood, Vector3(0, 0.84, 0.0), 0.02)
	Art.box(r, Vector3(2.9, 0.08, 0.5), Art.mat(Color("f4f1ea"), 0.4), Vector3(0, 0.92, -0.05), 0.01) # display bed
	# curved-looking front glass and the top
	var g := Art.box(r, Vector3(2.84, 0.46, 0.012), Art.glass(Color(0.85, 0.95, 1.0), 0.22), Vector3(0, 1.14, 0.22), 0.0)
	g.rotation.x = -0.35
	Art.box(r, Vector3(2.84, 0.012, 0.36), Art.glass(Color(0.85, 0.95, 1.0), 0.2), Vector3(0, 1.36, -0.08), 0.0)
	for sx in [-1, 1]: Art.box(r, Vector3(0.04, 0.5, 0.5), Art.mat(Cfg.STEEL, 0.25, 0.8), Vector3(sx * 1.43, 1.13, -0.03), 0.01)
	Art.box(r, Vector3(2.9, 0.03, 0.03), Art.mat(Color("fff4dc"), 0.2, 0.0, 2.5), Vector3(0, 1.33, -0.1), 0.0)
	# scale on the staff side and a small striped sign
	var sc := Node3D.new(); sc.position = Vector3(1.05, 1.37, -0.18); r.add_child(sc)
	Art.box(sc, Vector3(0.3, 0.06, 0.24), Art.mat(Color("eef0f2"), 0.4, 0.2), Vector3(0, 0.03, 0), 0.02)
	Art.box(sc, Vector3(0.2, 0.12, 0.03), Art.mat(Color("2d3348"), 0.4), Vector3(0, 0.12, -0.1), 0.01)
	Art.box(sc, Vector3(0.12, 0.04, 0.012), Art.mat(Color("7fe3c8"), 0.3, 0.0, 2.0), Vector3(0, 0.13, -0.083), 0.0)
	Art.box(r, Vector3(1.3, 0.3, 0.06), Art.mat(Color("8a2f2a"), 0.5), Vector3(-0.5, 1.72, -0.3), 0.03)
	Art.label(r, "ŞARKÜTERİ", 52, Cfg.CREAM, Vector3(-0.5, 1.72, -0.265), 0.0, "display")
	for sx in [-1, 1]: Art.box(r, Vector3(0.03, 0.4, 0.03), Art.mat(Cfg.STEEL_DARK, 0.4, 0.5), Vector3(-0.5 + sx * 0.55, 1.5, -0.3), 0.0)
	var l := OmniLight3D.new(); l.light_color = Color("fff1dc"); l.light_energy = 0.7; l.omni_range = 2.0; l.position = Vector3(0, 1.4, 0.1)
	r.add_child(l); m["lights"].append(l)
	for s in 2:
		var cx := -0.7 + s * 1.2
		m["slots"].append({"units": _grid(_span(cx, 0.9, 5), [0.965], [0.08, -0.14]), "tag": Vector3(cx, 0.78, 0.36)})
	m["height"] = 1.9
