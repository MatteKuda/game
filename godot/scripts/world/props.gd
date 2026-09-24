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
