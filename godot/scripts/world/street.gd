class_name Street
extends Node3D
## The neighbourhood: street, sidewalks, apartment blocks with balconies, the tea garden
## across the road, traffic and the wholesaler's van. All facades face the street (+Z).

var night_windows: Array[StandardMaterial3D] = []
var street_lights: Array[OmniLight3D] = []
var lamp_mats: Array[StandardMaterial3D] = []
var cars: Array = [] # [{node, lane_z, dir, speed, x}]
var van: Node3D
var neighbor: Node3D # closed shop to the left of the büfe (removed on expansion)
var backyard: Node3D # yard behind the büfe (removed on expansion)
var blocked: Array[Vector2i] = [] # street tiles occupied by props
var right_a: Node3D # eczane/berber block (removed for the Süpermarket)
var right_b: Node3D # kırtasiye block (removed for the AVM)
var left_a: Node3D # çay ocağı block (removed for the AVM)

func build() -> void:
	# ground & street
	var base := Art.box(self, Vector3(120, 0.2, 90), Art.mat(Color("9fbb6c"), 0.95), Vector3(22, -0.16, 14), 0.0)
	base.name = "Ground"
	Art.box(self, Vector3(120, 0.06, 3.0), Art.shader_mat("paving"), Vector3(22, -0.02, 17.5), 0.0)
	Art.box(self, Vector3(120, 0.2, 0.25), Art.mat(Cfg.CURB, 0.8), Vector3(22, -0.02, 19.05), 0.02)
	Art.box(self, Vector3(120, 0.06, 6.0), Art.shader_mat("asphalt"), Vector3(22, -0.06, 22.0), 0.0)
	Art.box(self, Vector3(120, 0.2, 0.25), Art.mat(Cfg.CURB, 0.8), Vector3(22, -0.02, 24.95), 0.02)
	Art.box(self, Vector3(120, 0.06, 2.0), Art.shader_mat("paving", {"color_a": Color("d9cfc2"), "color_b": Color("c7bcae")}), Vector3(22, -0.02, 26.0), 0.0)
	var lane := Art.mat(Color("f3efe4"), 0.7)
	for i in 40:
		Art.box(self, Vector3(1.4, 0.02, 0.12), lane, Vector3(-30 + i * 3.0, -0.02, 22.0), 0.0)
	# zebra crossing in front of the shop
	for i in 7:
		Art.box(self, Vector3(0.45, 0.02, 5.4), lane, Vector3(30.0 + i * 0.8, -0.02, 22.0), 0.0)
	_back_row()
	_right_block()
	_left_block()
	_tea_garden()
	_street_furniture()
	_neighbor_shop()
	_backyard()
	_traffic()
	_van()

# ------------------------------------------------------------------ building kit
func _apartment(origin: Vector3, w: float, d: float, floors: int, wall: Color, ground_h := 0.0, seed := 1) -> Node3D:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var root := Node3D.new(); root.position = origin; add_child(root)
	var P := []
	var G := [] # glass
	var L := [] # lit windows
	var fh := 3.0
	var total := ground_h + floors * fh
	var T := func(x: float, y: float, z: float) -> Transform3D: return Transform3D(Basis(), Vector3(x, y, z))
	P.append([Art.rbox_mesh(Vector3(w, total, d), 0.05), T.call(0, total * 0.5, -d * 0.5), wall])
	# floor bands
	for f in floors + 1:
		P.append([Art.rbox_mesh(Vector3(w + 0.1, 0.14, 0.1), 0.02), T.call(0, ground_h + f * fh, 0.03), wall.darkened(0.12)])
	# roof parapet, water tank, solar panel, satellite dishes
	P.append([Art.rbox_mesh(Vector3(w + 0.2, 0.45, d + 0.2), 0.04), T.call(0, total + 0.2, -d * 0.5), wall.lightened(0.15)])
	P.append([Art.rbox_mesh(Vector3(w - 0.2, 0.05, d - 0.2), 0.0), T.call(0, total + 0.43, -d * 0.5), Color("9a8f86")])
	var tx := rng.randf_range(-w * 0.3, w * 0.3)
	P.append([Art.prim("cyl", 0.45, 0.45, 1.3), Transform3D(Basis(Vector3(0, 0, 1), PI / 2), Vector3(tx, total + 1.25, -d * 0.4)), Color("e8e6e0")])
	P.append([Art.rbox_mesh(Vector3(1.8, 0.08, 1.2), 0.02), Transform3D(Basis(Vector3(1, 0, 0), -0.6), Vector3(tx, total + 0.95, -d * 0.4 + 1.0)), Color("233a5e")])
	for s in rng.randi_range(1, 3):
		var dx := rng.randf_range(-w * 0.4, w * 0.4)
		P.append([Art.prim("sph", 0.32), Transform3D(Basis(Vector3(1, 0, 0), -1.1).scaled(Vector3(1, 0.35, 1)), Vector3(dx, total + 1.2, -0.6)), Color("f2f0ea")])
	# facade windows + balconies
	var cols := maxi(2, int(w / 2.4))
	for f in floors:
		var y := ground_h + f * fh + 1.55
		for c in cols:
			var x := -w * 0.5 + w * (c + 0.5) / cols
			P.append([Art.rbox_mesh(Vector3(1.15, 1.45, 0.12), 0.03), T.call(x, y, 0.02), Color("fbf4e8")])
			var lit := rng.randf() < 0.45
			(L if lit else G).append([Art.rbox_mesh(Vector3(0.9, 1.2, 0.04), 0.0), T.call(x, y, 0.06), Color("ffd89a") if lit else Color("35506e")])
			P.append([Art.rbox_mesh(Vector3(0.05, 1.2, 0.05), 0.0), T.call(x, y, 0.09), Color("fbf4e8")])
			# shutters on some
			if rng.randf() < 0.35:
				for sx in [-1, 1]: P.append([Art.rbox_mesh(Vector3(0.4, 1.4, 0.05), 0.01), T.call(x + sx * 0.8, y, 0.06), Color("4f7a57")])
			if (c + f) % 2 == 0:
				var by := ground_h + f * fh + 0.4
				P.append([Art.rbox_mesh(Vector3(1.9, 0.14, 1.0), 0.03), T.call(x, by, 0.55), wall.lightened(0.2)])
				P.append([Art.rbox_mesh(Vector3(1.9, 0.05, 0.05), 0.0), T.call(x, by + 0.95, 1.02), Color("3a3f4a")])
				for b in 11:
					P.append([Art.rbox_mesh(Vector3(0.03, 0.9, 0.03), 0.0), T.call(x - 0.9 + b * 0.18, by + 0.5, 1.02), Color("3a3f4a")])
				if rng.randf() < 0.5: # potted geraniums
					for pp in 3:
						P.append([Art.prim("cyl", 0.09, 0.07, 0.16), T.call(x - 0.6 + pp * 0.3, by + 0.15, 0.85), Color("c8643c")])
						P.append([Art.prim("sph", 0.12), T.call(x - 0.6 + pp * 0.3, by + 0.3, 0.85), Color("d6333a") if pp % 2 == 0 else Color("5fa35a")])
				if rng.randf() < 0.3: # laundry line
					for q in 4:
						P.append([Art.rbox_mesh(Vector3(0.3, 0.4, 0.02), 0.0), T.call(x - 0.6 + q * 0.4, by + 1.4, 0.95), [Color("f2f0ea"), Color("6c9bd2"), Color("e0663c"), Color("f2b33d")][q]])
			# AC unit
			if rng.randf() < 0.25:
				P.append([Art.rbox_mesh(Vector3(0.7, 0.45, 0.3), 0.04), T.call(x + 0.9, y - 0.7, 0.15), Color("eeeeea")])
	var mi := MeshInstance3D.new(); mi.mesh = Art.merge(P); mi.material_override = Art.vcol_mat(0.85); root.add_child(mi)
	if not G.is_empty():
		var gm := MeshInstance3D.new(); gm.mesh = Art.merge(G)
		var gmat := StandardMaterial3D.new(); gmat.vertex_color_use_as_albedo = true; gmat.roughness = 0.12; gmat.metallic = 0.3
		gm.material_override = gmat; root.add_child(gm)
	if not L.is_empty():
		var lm := MeshInstance3D.new(); lm.mesh = Art.merge(L)
		var lmat := StandardMaterial3D.new(); lmat.vertex_color_use_as_albedo = true; lmat.roughness = 0.3
		lmat.emission_enabled = true; lmat.emission = Color("ffcf80"); lmat.emission_energy_multiplier = 0.0
		lm.material_override = lmat; root.add_child(lm)
		night_windows.append(lmat)
	return root

func _shopfront(parent: Node3D, x: float, w: float, name: String, band: Color, awning: Color) -> void:
	var f := Node3D.new(); f.position = Vector3(x, 0, 0.05); parent.add_child(f)
	Art.box(f, Vector3(w, 0.5, 0.15), Art.mat(Color("d8cfc2")), Vector3(0, 0.25, 0), 0.02)
	Art.box(f, Vector3(w - 0.3, 1.9, 0.04), Art.glass(Color(0.8, 0.92, 1.0), 0.3), Vector3(0, 1.45, 0), 0.0)
	Art.box(f, Vector3(w, 0.7, 0.2), Art.mat(band, 0.6), Vector3(0, 2.75, 0.03), 0.03)
	Art.label(f, name, 110, Cfg.CREAM, Vector3(0, 2.76, 0.15), 0.0, "display", 8, band.darkened(0.3))
	var aw := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(w, 0.9); aw.mesh = pm
	aw.material_override = Art.shader_mat("stripes", {"color_a": awning, "color_b": Color("fbf4e8"), "count": w * 2.0})
	aw.position = Vector3(0, 2.25, 0.45); aw.rotation.x = 0.45; f.add_child(aw)

# ------------------------------------------------------------------ blocks
func _back_row() -> void:
	var cols := [Color("e0a878"), Color("c9785c"), Color("e8bf6a"), Color("8fb39a"), Color("d98f66"), Color("a98fc9")]
	var x := -18.0
	var i := 0
	while x < 60.0:
		var w: float = [8.0, 10.0, 9.0, 11.0][i % 4]
		_apartment(Vector3(x + w * 0.5, 0, 0.0), w - 0.4, 9.0, 4 + i % 3, cols[i % cols.size()], 0.0, 10 + i)
		x += w; i += 1

func _right_block() -> void:
	var a := _apartment(Vector3(31.2, 0, 16.0), 9.6, 10.0, 3, Color("e8bf6a"), 3.2, 3)
	right_a = a
	_shopfront(a, -2.3, 4.6, "ECZANE", Color("2fae7a"), Color("2fae7a"))
	_shopfront(a, 2.4, 4.4, "BERBER", Color("2f6fb5"), Color("d6333a"))
	# barber pole
	var pole := Art.cyl(a, 0.08, 0.08, 0.9, Art.shader_mat("stripes", {"color_a": Color("d6333a"), "color_b": Color("ffffff"), "count": 6.0}), Vector3(0.1, 1.6, 0.25))
	pole.rotation.z = 0.0
	var b := _apartment(Vector3(41.0, 0, 16.0), 9.6, 10.0, 4, Color("c9785c"), 3.2, 4)
	right_b = b
	_shopfront(b, 0.0, 8.0, "KIRTASİYE", Color("7a5ae0"), Color("f2b33d"))

func _left_block() -> void:
	var a := _apartment(Vector3(4.6, 0, 16.0), 8.8, 10.0, 2, Color("7fae9c"), 3.2, 5)
	left_a = a
	_shopfront(a, -1.6, 5.0, "ÇAY OCAĞI", Color("8a5a35"), Color("c9714f"))
	_shopfront(a, 2.6, 3.4, "TERZİ", Color("b0546a"), Color("fbf4e8"))

func _neighbor_shop() -> void:
	# the closed, dusty shop to the left of the büfe (x 10..18, z 6..16), open-top like our own
	neighbor = Node3D.new(); add_child(neighbor)
	var brick := Art.shader_mat("brick", {"brick": Color("b9876a"), "mortar": Color("e6dccd")})
	var cap := Art.mat(Color("d9ccb8"), 0.85)
	Art.box(neighbor, Vector3(7.9, 0.1, 9.8), Art.shader_mat("paving", {"color_a": Color("b8ab99"), "color_b": Color("a89a88"), "scale": 1.4}), Vector3(14.0, 0.0, 11.0), 0.0)
	Art.box(neighbor, Vector3(8.0, 3.0, 0.2), brick, Vector3(14.0, 1.5, 6.1), 0.0)
	Art.box(neighbor, Vector3(0.2, 3.0, 9.8), brick, Vector3(10.1, 1.5, 11.0), 0.0)
	for zz in [6.1]: Art.box(neighbor, Vector3(8.1, 0.08, 0.3), cap, Vector3(14.0, 3.04, zz), 0.02)
	Art.box(neighbor, Vector3(0.3, 0.08, 9.9), cap, Vector3(10.1, 3.04, 11.0), 0.02)
	# front: low wall + half-closed rolling shutter
	Art.box(neighbor, Vector3(7.8, 0.5, 0.22), Art.mat(Color("cfc4b4")), Vector3(14.0, 0.25, 15.95), 0.02)
	var shm := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(0.9, 7.2); shm.mesh = qm
	shm.material_override = Art.shader_mat("stripes", {"color_a": Color("8e979f"), "color_b": Color("b3bbc2"), "count": 9.0})
	shm.position = Vector3(14.0, 2.75, 16.0); shm.rotation.z = PI / 2; neighbor.add_child(shm)
	Art.box(neighbor, Vector3(7.6, 0.5, 0.4), Art.mat(Color("8e979f"), 0.5, 0.4), Vector3(14.0, 3.35, 15.95), 0.08)
	Art.box(neighbor, Vector3(3.0, 0.9, 0.05), Art.mat(Color("f7f1e3"), 0.9), Vector3(14.0, 1.35, 16.1), 0.02)
	Art.label(neighbor, "KİRALIK", 110, Cfg.BAD, Vector3(14.0, 1.45, 16.14), 0.0, "display")
	Art.label(neighbor, "0 532 ··· ·· ··", 40, Cfg.INK, Vector3(14.0, 1.08, 16.14), 0.0, "display700")
	# dusty leftovers inside
	var bits := [["restaurant/crate", Vector3(11.2, 0.05, 7.2), 0.3], ["restaurant/crate", Vector3(11.9, 0.05, 7.0), -0.2],
		["restaurant/crate_lid", Vector3(11.5, 0.6, 7.1), 0.5], ["furniture/shelf_B_small", Vector3(16.8, 0.05, 6.6), 0.0],
		["furniture/chair_B_wood", Vector3(13.4, 0.05, 9.4), 1.2], ["restaurant/kitchentable_A", Vector3(15.8, 0.05, 11.0), 0.3],
		["furniture/cabinet_small", Vector3(10.8, 0.05, 12.5), PI / 2]]
	for b in bits:
		var m := Art.model("res://assets/models/%s.gltf" % b[0])
		m.position = b[1]; m.rotation.y = b[2]; m.scale = Vector3.ONE * 0.55
		neighbor.add_child(m)
		Art.stylize(m, true, Color(0.82, 0.8, 0.78))
	for i in 6: # dust sheets / paper
		var q := Art.box(neighbor, Vector3(randf_range(0.3, 0.7), 0.01, randf_range(0.2, 0.5)), Art.mat(Color("e8e1d4"), 1.0), Vector3(randf_range(11, 17), 0.06, randf_range(7.5, 15)), 0.0)
		q.rotation.y = randf() * TAU

func _backyard() -> void:
	# courtyard behind the büfe (x 18..26, z 6..10) — crates, a clothesline, a sleeping cat
	backyard = Node3D.new(); add_child(backyard)
	Art.box(backyard, Vector3(8, 0.06, 4), Art.shader_mat("paving", {"scale": 2.0}), Vector3(22, 0.0, 8.0), 0.0)
	Art.box(backyard, Vector3(8.2, 1.4, 0.2), Art.shader_mat("brick"), Vector3(22, 0.7, 5.9), 0.0)
	for i in 3:
		var c := Art.model("res://assets/models/restaurant/crate.gltf")
		c.scale = Vector3.ONE * 0.55
		c.position = Vector3(19.2 + i * 0.7, 0.0, 7.0); backyard.add_child(c); Art.stylize(c)
	var c2 := Art.model("res://assets/models/restaurant/crate_tomatoes.gltf"); c2.scale = Vector3.ONE * 0.55; c2.position = Vector3(19.5, 0.3, 7.0); backyard.add_child(c2); Art.stylize(c2)
	for sx in [20.5, 24.5]: Art.cyl(backyard, 0.04, 0.04, 2.0, Art.mat(Color("5b6570")), Vector3(sx, 1.0, 8.5))
	for q in 5: Art.box(backyard, Vector3(0.45, 0.6, 0.02), Art.mat([Color("f2f0ea"), Color("6c9bd2"), Color("e0663c"), Color("f2b33d"), Color("7fc4a8")][q], 0.9), Vector3(21.0 + q * 0.75, 1.55, 8.5), 0.0)
	# cat
	var cat := Node3D.new(); cat.position = Vector3(25.0, 1.4, 5.95); backyard.add_child(cat)
	Art.sphere(cat, 0.2, Art.mat(Color("e39a4f")), Vector3.ZERO, 0.6).scale = Vector3(1.4, 0.6, 1.0)
	Art.sphere(cat, 0.11, Art.mat(Color("e39a4f")), Vector3(0.28, 0.02, 0.02))
	for sx in [-1, 1]: Art.box(cat, Vector3(0.05, 0.08, 0.04), Art.mat(Color("c47a35")), Vector3(0.3, 0.12, sx * 0.05), 0.01)

func _tea_garden() -> void:
	# across the road: a low hedge, plane trees, tables with tea glasses
	var g := Node3D.new(); add_child(g)
	Art.box(g, Vector3(34, 0.05, 6), Art.mat(Color("cdb896"), 0.95), Vector3(22, -0.03, 30.0), 0.0)
	for i in 16:
		Art.box(g, Vector3(2.0, 0.55, 0.5), Art.mat(Color("5c9c55"), 0.9), Vector3(6.0 + i * 2.1, 0.27, 27.4), 0.2)
	for i in 5: _tree(g, Vector3(7.0 + i * 7.0, 0, 31.5), 1.2 + (i % 2) * 0.3)
	for i in 6:
		var t := Node3D.new(); t.position = Vector3(9.0 + i * 5.0, 0, 29.5 + (i % 2) * 1.6); g.add_child(t)
		Art.cyl(t, 0.35, 0.35, 0.04, Art.mat(Color("f2f0ea"), 0.5), Vector3(0, 0.72, 0))
		Art.cyl(t, 0.03, 0.03, 0.72, Art.mat(Color("3a3f4a")), Vector3(0, 0.36, 0))
		for k in 2:
			Art.cyl(t, 0.035, 0.03, 0.09, Art.glass(Color(0.85, 0.35, 0.2), 0.8), Vector3(-0.1 + k * 0.2, 0.79, 0.05))
		for a in 3:
			var ang := a * TAU / 3.0
			var s := Node3D.new(); s.position = Vector3(cos(ang) * 0.65, 0, sin(ang) * 0.65); t.add_child(s)
			Art.box(s, Vector3(0.38, 0.05, 0.38), Art.mat([Color("d6333a"), Color("2f6fb5"), Color("f2b33d")][a], 0.7), Vector3(0, 0.45, 0), 0.02)
			for lx in [-1, 1]:
				for lz in [-1, 1]: Art.box(s, Vector3(0.03, 0.45, 0.03), Art.mat(Color("3a3f4a")), Vector3(lx * 0.16, 0.22, lz * 0.16), 0.0)

func _tree(parent: Node3D, pos: Vector3, s := 1.0) -> void:
	var t := Node3D.new(); t.position = pos; t.scale = Vector3.ONE * s; parent.add_child(t)
	Art.cyl(t, 0.12, 0.18, 2.4, Art.mat(Color("7a5a3f"), 0.9), Vector3(0, 1.2, 0))
	var greens := [Color("5fa35a"), Color("6fb562"), Color("4f934f")]
	for i in 6:
		var a := i * 1.05
		var r := 0.9 if i > 0 else 0.0
		var leaf := Art.sphere(t, 1.0 - i * 0.05, Art.mat(greens[i % 3], 0.85), Vector3(cos(a) * r * 0.8, 2.9 + (i % 3) * 0.35, sin(a) * r * 0.6))
		leaf.scale = Vector3(1.0, 0.8, 1.0)

func _street_furniture() -> void:
	var pole_m := Art.mat(Color("2f4a3f"), 0.5, 0.4)
	for x in [8.0, 20.0, 32.0, 44.0]:
		var l := Node3D.new(); l.position = Vector3(x, 0, 18.7); add_child(l)
		Art.cyl(l, 0.06, 0.09, 4.2, pole_m, Vector3(0, 2.1, 0))
		Art.box(l, Vector3(0.05, 0.05, 0.9), pole_m, Vector3(0, 4.15, 0.4), 0.01)
		Art.cyl(l, 0.08, 0.26, 0.3, pole_m, Vector3(0, 4.0, 0.8))
		var bm := StandardMaterial3D.new(); bm.albedo_color = Color("fff1d0"); bm.emission_enabled = true; bm.emission = Color("ffcf80"); bm.emission_energy_multiplier = 0.0
		Art.sphere(l, 0.12, bm, Vector3(0, 3.85, 0.8)); lamp_mats.append(bm)
		var om := OmniLight3D.new(); om.position = Vector3(0, 3.7, 0.8); om.light_color = Color("ffc98a"); om.omni_range = 8.0; om.light_energy = 0.0
		l.add_child(om); street_lights.append(om)
		blocked.append(Vector2i(int(x), 18))
	for x in [12.0, 28.5, 38.0]:
		_tree(self, Vector3(x, 0, 18.4), 0.85)
		Art.box(self, Vector3(1.0, 0.25, 1.0), Art.mat(Color("b8aa98")), Vector3(x, 0.1, 18.4), 0.05)
		blocked.append(Vector2i(int(x), 18))
	# bus stop (DURAK) on the far sidewalk
	var bs := Node3D.new(); bs.position = Vector3(16.0, 0, 26.3); add_child(bs)
	Art.box(bs, Vector3(3.2, 0.1, 1.2), Art.mat(Cfg.TEAL_DARK, 0.5), Vector3(0, 2.4, 0), 0.03)
	for sx in [-1.5, 1.5]: Art.box(bs, Vector3(0.08, 2.4, 0.08), Art.mat(Cfg.STEEL_DARK, 0.4, 0.5), Vector3(sx, 1.2, -0.4), 0.01)
	Art.box(bs, Vector3(3.0, 1.6, 0.03), Art.glass(Color(0.8, 0.95, 1.0), 0.25), Vector3(0, 1.4, -0.5), 0.0)
	Art.box(bs, Vector3(2.4, 0.08, 0.4), Art.mat(Cfg.WOOD), Vector3(0, 0.5, -0.25), 0.02)
	Art.box(bs, Vector3(0.9, 0.3, 0.05), Art.mat(Cfg.MUSTARD), Vector3(1.1, 2.1, 0.2), 0.02)
	Art.label(bs, "DURAK", 50, Cfg.INK, Vector3(1.1, 2.1, 0.23), 0.0, "display")
	var hyd := Art.model("res://assets/models/city/firehydrant.gltf"); hyd.position = Vector3(26.6, 0, 18.6); hyd.scale = Vector3.ONE * 0.6; add_child(hyd); Art.stylize(hyd)

func _traffic() -> void:
	var models := ["car_taxi", "car_sedan", "car_hatchback", "car_taxi", "car_stationwagon"]
	for i in 5:
		var c := Art.model("res://assets/models/city/%s.gltf" % models[i])
		Art.stylize(c)
		var holder := Node3D.new(); holder.add_child(c); add_child(holder)
		var bb := AABB()
		var inv := c.global_transform.affine_inverse()
		for mi in c.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = (inv * mi.global_transform) * mi.get_aabb()
			bb = box if bb.size == Vector3.ZERO else bb.merge(box)
		c.scale = Vector3.ONE * (3.3 / maxf(0.01, maxf(bb.size.x, bb.size.z)))
		var dir := 1 if i % 2 == 0 else -1
		c.rotation.y = PI / 2 if dir == 1 else -PI / 2
		cars.append({"node": holder, "z": 20.6 if dir == 1 else 23.4, "dir": dir, "speed": randf_range(4.0, 6.5), "x": -20.0 + i * 17.0})

func _van() -> void:
	van = Node3D.new(); add_child(van)
	var body := Art.mat(Color("f4efe4"), 0.45)
	Art.box(van, Vector3(4.2, 1.9, 1.9), body, Vector3(0.2, 1.35, 0), 0.18)
	Art.box(van, Vector3(1.3, 1.25, 1.85), body, Vector3(2.7, 1.05, 0), 0.2)
	Art.box(van, Vector3(0.05, 0.6, 1.5), Art.glass(Color(0.3, 0.45, 0.6), 0.85), Vector3(3.36, 1.35, 0), 0.0)
	Art.box(van, Vector3(4.22, 0.35, 1.92), Art.mat(Cfg.TERRA, 0.5), Vector3(0.2, 0.95, 0), 0.05)
	for sz in [-1, 1]:
		var lb := Art.label(van, "TOPTANCI", 110, Cfg.TERRA, Vector3(0.1, 1.75, sz * 0.97), 0.0, "display", 8, Color.WHITE)
		if sz == -1: lb.rotation.y = PI
		var lb2 := Art.label(van, "HIZLI TESLİMAT", 44, Cfg.INK2, Vector3(0.1, 1.4, sz * 0.97), 0.0, "display700")
		if sz == -1: lb2.rotation.y = PI
	for x in [-1.2, 2.4]:
		for sz in [-1, 1]:
			var wh := Art.cyl(van, 0.36, 0.36, 0.26, Art.mat(Color("22252c"), 0.8), Vector3(x, 0.36, sz * 0.9), 16)
			wh.rotation.x = PI / 2
	Art.stylize(van, true)
	van.visible = false

func update(dt: float, night: float, van_x: float, van_visible: bool) -> void:
	for m in night_windows: m.emission_energy_multiplier = night * 2.2
	for l in street_lights: l.light_energy = night * 2.2
	for m in lamp_mats: m.emission_energy_multiplier = night * 5.0
	for c in cars:
		c["x"] += c["dir"] * c["speed"] * dt
		if c["x"] > 70.0: c["x"] = -26.0
		if c["x"] < -26.0: c["x"] = 70.0
		c["node"].position = Vector3(c["x"], 0.0, c["z"])
	van.visible = van_visible
	van.position = Vector3(van_x, 0.0, 20.7)

func remove_for_stage(n: int) -> void:
	if n >= 1:
		if neighbor: neighbor.queue_free(); neighbor = null
		if backyard: backyard.queue_free(); backyard = null
	if n >= 2 and right_a: right_a.queue_free(); right_a = null
	if n >= 3:
		if right_b: right_b.queue_free(); right_b = null
		if left_a: left_a.queue_free(); left_a = null
