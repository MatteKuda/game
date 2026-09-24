class_name ShopShell
extends Node3D
## The player's shop building: floor, tiled walls, glass shopfront with sliding doors,
## striped awning and the KÖŞEBAŞI sign. Camera-facing walls sink when zoomed in (cut-away).

var layout: Dictionary
var stage := 0
var walls: Array = [] # [{node, normal: Vector3, sink}]
var doors: Array = [] # [{x, left, right, open}]
var sign_letters: Array[Label3D] = []
var sign_sub: Label3D
var neon := false
var tente := false
var cutaway := true
var lamps: Array[OmniLight3D] = []
var lamp_mats: Array[StandardMaterial3D] = []

func build(l: Dictionary, st: int, upgrades: Dictionary) -> void:
	for c in get_children(): c.queue_free()
	walls.clear(); doors.clear(); sign_letters.clear(); lamps.clear()
	layout = l; stage = st
	neon = upgrades.has("neon"); tente = upgrades.has("tente")
	var r: Rect2i = l["interior"]
	var x0 := float(r.position.x); var z0 := float(r.position.y)
	var x1 := float(r.end.x); var z1 := float(r.end.y)
	var W := x1 - x0; var D := z1 - z0
	var H := Cfg.WALL_H
	# floor slab + terrazzo
	var floor_mi := Art.box(self, Vector3(W, 0.12, D), Art.shader_mat("checker"), Vector3((x0 + x1) * 0.5, -0.04, (z0 + z1) * 0.5), 0.0)
	floor_mi.name = "Floor"
	# door mat at each door pair
	var inner_wall := Art.shader_mat("wall_paint")
	var outer := Art.shader_mat("brick", {"brick": Color("c9714f"), "mortar": Color("efe3d2")})
	var cap := Art.mat(Color("2d3348"), 0.6)
	# back wall
	var back := _wall(Vector3((x0 + x1) * 0.5, 0, z0 - 0.15), Vector3(W + 0.6, H, 0.3), Vector3(0, 0, -1), inner_wall, outer, cap)
	# side walls
	_wall(Vector3(x0 - 0.15, 0, (z0 + z1) * 0.5), Vector3(0.3, H, D), Vector3(-1, 0, 0), inner_wall, outer, cap)
	_wall(Vector3(x1 + 0.15, 0, (z0 + z1) * 0.5), Vector3(0.3, H, D), Vector3(1, 0, 0), inner_wall, outer, cap)
	_decor(back, W)
	# front facade: sill, glass, doors, sign band
	_front(x0, x1, z1, H, l["doors"])
	# ceiling lamps
	var n_l := maxi(1, int(W / 4.0))
	for i in n_l:
		var lx := x0 + W * (i + 0.5) / n_l
		for j in maxi(1, int(D / 5.0)):
			var lz := z0 + D * (j + 0.5) / maxi(1, int(D / 5.0))
			var pend := Node3D.new(); pend.position = Vector3(lx, H - 0.05, lz); add_child(pend)
			Art.cyl(pend, 0.01, 0.01, 0.6, Art.mat(Color("2a2233")), Vector3(0, -0.3, 0), 6)
			Art.cyl(pend, 0.08, 0.32, 0.22, Art.mat(Cfg.TEAL, 0.5), Vector3(0, -0.66, 0), 20)
			var bulb_m := StandardMaterial3D.new(); bulb_m.albedo_color = Color("fff3d6"); bulb_m.emission_enabled = true; bulb_m.emission = Color("ffdca0"); bulb_m.emission_energy_multiplier = 2.0
			Art.sphere(pend, 0.09, bulb_m, Vector3(0, -0.78, 0))
			lamp_mats.append(bulb_m)
			var om := OmniLight3D.new(); om.position = Vector3(0, -0.9, 0); om.light_color = Color("ffd9a8"); om.omni_range = 5.5; om.light_energy = 0.7; om.shadow_enabled = false
			pend.add_child(om); lamps.append(om)

func _wall(center: Vector3, size: Vector3, normal: Vector3, inner: Material, outer: Material, cap: Material) -> Node3D:
	var n := Node3D.new(); n.position = center; add_child(n)
	# two skins so the inside shows tiles and the outside shows brick
	var off := normal * size.dot(normal.abs()) * 0.25
	var s2 := size - normal.abs() * size.dot(normal.abs()) * 0.5
	Art.box(n, s2, inner, Vector3(0, size.y * 0.5, 0) - off, 0.0)
	Art.box(n, s2, outer, Vector3(0, size.y * 0.5, 0) + off, 0.0)
	Art.box(n, Vector3(size.x + 0.06, 0.14, size.z + 0.06), cap, Vector3(0, size.y + 0.07, 0), 0.03)
	walls.append({"node": n, "normal": normal, "sink": 0.0, "h": size.y})
	return n

## posters, a clock and a chalk price board on the back wall (local: wall centre, inner face at +z 0.15)
func _decor(wall: Node3D, W: float) -> void:
	var z := 0.17
	var items := []
	# poster: taze simit
	var p1 := Node3D.new(); p1.position = Vector3(-W * 0.3, 1.95, z); wall.add_child(p1)
	Art.box(p1, Vector3(0.9, 0.62, 0.03), Art.mat(Color("3a2a24"), 0.6), Vector3.ZERO, 0.02)
	Art.box(p1, Vector3(0.82, 0.54, 0.02), Art.mat(Cfg.TERRA, 0.7), Vector3(0, 0, 0.015), 0.0)
	var sm := Art.torus(p1, 0.06, 0.13, Art.mat(Color("c9803e"), 0.8), Vector3(-0.22, 0.02, 0.05))
	sm.rotation.x = PI / 2
	Art.label(p1, "TAZE\nSİMİT", 56, Cfg.CREAM, Vector3(0.12, 0.0, 0.03), 0.0, "display")
	# chalkboard price list
	var cb := Node3D.new(); cb.position = Vector3(W * 0.05, 1.9, z); wall.add_child(cb)
	Art.box(cb, Vector3(1.1, 0.8, 0.04), Art.mat(Cfg.WOOD, 0.6), Vector3.ZERO, 0.03)
	Art.box(cb, Vector3(1.0, 0.7, 0.02), Art.mat(Color("2c3a33"), 0.95), Vector3(0, 0, 0.02), 0.0)
	Art.label(cb, "GÜNÜN FİYATLARI", 34, Color("fff4d6"), Vector3(0, 0.24, 0.035), 0.0, "display700")
	var rows := ["Simit ........ 12", "Ayran ........ 15", "Kola .......... 25"]
	for i in rows.size():
		Art.label(cb, rows[i], 28, Color(1, 1, 1, 0.85), Vector3(0, 0.06 - i * 0.14, 0.035), 0.0, "display700")
	# clock
	var ck := Node3D.new(); ck.position = Vector3(W * 0.33, 2.25, z); wall.add_child(ck)
	var face := Art.cyl(ck, 0.22, 0.22, 0.05, Art.mat(Color("fbf6ee"), 0.4), Vector3.ZERO, 28); face.rotation.x = PI / 2
	var rim := Art.torus(ck, 0.2, 0.24, Art.mat(Cfg.TERRA_DARK, 0.5), Vector3.ZERO); rim.rotation.x = PI / 2
	Art.box(ck, Vector3(0.02, 0.14, 0.01), Art.mat(Cfg.INK), Vector3(0, 0.06, 0.035), 0.0)
	var hand := Art.box(ck, Vector3(0.02, 0.1, 0.01), Art.mat(Cfg.INK), Vector3(0.035, 0.02, 0.04), 0.0); hand.rotation.z = -1.2
	# small wall shelf with jars
	var sh := Node3D.new(); sh.position = Vector3(W * 0.33, 1.45, z + 0.1); wall.add_child(sh)
	Art.box(sh, Vector3(0.8, 0.04, 0.22), Art.mat(Cfg.WOOD_DARK, 0.6), Vector3.ZERO, 0.01)
	var jar_cols := [Color("f2b33d"), Color("d6333a"), Color("5fa35a")]
	for i in 3:
		Art.cyl(sh, 0.06, 0.06, 0.16, Art.glass(jar_cols[i].lightened(0.3), 0.6), Vector3(-0.25 + i * 0.25, 0.1, 0))
		Art.cyl(sh, 0.065, 0.065, 0.03, Art.mat(jar_cols[i], 0.5), Vector3(-0.25 + i * 0.25, 0.19, 0))

func _front(x0: float, x1: float, z1: float, H: float, door_xs: Array) -> void:
	var base := Node3D.new(); base.position = Vector3(0, 0, z1); add_child(base)
	var n := base # glass, frames and doors always stay
	var up := Node3D.new(); base.add_child(up) # sign band + awning fade in the cut-away view
	var frame := Art.mat(Color("2a3a4a"), 0.4, 0.5)
	var band := Art.mat(Cfg.TERRA, 0.6)
	var sill := Art.mat(Color("d8cfc2"), 0.8)
	var W := x1 - x0
	var cx := (x0 + x1) * 0.5
	# segments between doors
	var cuts := []
	for d in door_xs: cuts.append(float(d))
	var x := x0
	var i := 0
	while x < x1 - 0.01:
		var is_door := cuts.has(x) and cuts.has(x + 1.0)
		if is_door:
			_door(n, x + 1.0)
			x += 2.0
			continue
		var nx := x + 1.0
		Art.box(base, Vector3(1.0, 0.55, 0.22), sill, Vector3(x + 0.5, 0.275, 0), 0.02)
		Art.box(n, Vector3(0.96, 1.9, 0.02), Art.glass(Color(0.85, 0.95, 1.0), 0.16), Vector3(x + 0.5, 1.5, 0), 0.0)
		Art.box(n, Vector3(0.06, 2.0, 0.1), frame, Vector3(x, 1.5, 0), 0.01)
		# vitrin stickers on some panes
		if i % 3 == 1:
			Art.label(n, "TAZE\nEKMEK" if i % 2 == 1 else "SOĞUK\nİÇECEK", 44, Color(1, 1, 1, 0.92), Vector3(x + 0.5, 1.35, 0.02), 0.0, "display")
		x = nx; i += 1
	Art.box(n, Vector3(0.08, 2.0, 0.1), frame, Vector3(x1, 1.5, 0), 0.01)
	Art.box(n, Vector3(W + 0.2, 0.08, 0.14), frame, Vector3(cx, 2.48, 0), 0.01)
	# sign band
	var bh := H - 2.5
	n = up
	Art.box(n, Vector3(W + 0.4, bh + 0.12, 0.3), band, Vector3(cx, 2.5 + bh * 0.5, 0.02), 0.03)
	var name := "KÖŞEBAŞI"
	var sub := "BÜFE" if stage == 0 else "MARKET"
	var col := Color(3.2, 2.9, 2.2) if neon else Cfg.CREAM
	var lb := Art.label(n, name, 150 if stage == 0 else 170, col, Vector3(cx - 0.35, 2.52 + bh * 0.5, 0.18), 0.0, "display", 18, Cfg.TERRA_DARK)
	sign_letters.append(lb)
	sign_sub = Art.label(n, sub, 70, Cfg.MUSTARD, Vector3(cx + W * 0.28 + 0.2, 2.5 + bh * 0.5, 0.18), 0.0, "display", 10, Cfg.TERRA_DARK)
	# awning
	var aw := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(W + 0.3, 1.5 if tente else 1.15); pm.subdivide_depth = 6
	aw.mesh = pm
	var ca := Color("1f8a86") if tente else Cfg.TERRA
	aw.material_override = Art.shader_mat("stripes", {"color_a": ca, "color_b": Color("fff1dc"), "count": (W + 0.3) * 2.2})
	aw.position = Vector3(cx, 2.35, 0.62 if tente else 0.5)
	aw.rotation.x = 0.42
	n.add_child(aw)
	# scalloped valance
	var val := Node3D.new(); val.position = Vector3(cx, 2.05 if tente else 2.12, 1.26 if tente else 1.0); n.add_child(val)
	var k := int((W + 0.3) / 0.3)
	for j in k:
		var c := ca if j % 2 == 0 else Color("fff1dc")
		var s := Art.cyl(val, 0.15, 0.15, 0.02, Art.mat(c, 0.9), Vector3(-(W + 0.3) * 0.5 + 0.15 + j * 0.3, 0, 0), 14)
		s.rotation.x = PI / 2
		s.scale = Vector3(1, 1, 0.8)
	walls.append({"node": base, "upper": up, "normal": Vector3(0, 0, 1), "sink": 0.0, "h": H, "front": true})

func _door(parent: Node3D, x: float) -> void:
	var frame := Art.mat(Color("2a3a4a"), 0.4, 0.5)
	Art.box(parent, Vector3(2.0, 0.1, 0.16), frame, Vector3(x, 2.35, 0), 0.01)
	var left := Node3D.new(); parent.add_child(left)
	var right := Node3D.new(); parent.add_child(right)
	for p in [left, right]:
		Art.box(p, Vector3(0.98, 2.28, 0.03), Art.glass(Color(0.8, 0.95, 1.0), 0.2), Vector3(0, 1.15, 0), 0.0)
		Art.box(p, Vector3(0.98, 0.06, 0.05), frame, Vector3(0, 0.03, 0), 0.01)
		Art.box(p, Vector3(0.05, 2.28, 0.05), frame, Vector3(0.47, 1.15, 0), 0.01)
		Art.box(p, Vector3(0.05, 2.28, 0.05), frame, Vector3(-0.47, 1.15, 0), 0.01)
	var mat := Art.box(parent, Vector3(1.8, 0.02, 1.0), Art.mat(Color("5b4032"), 0.95), Vector3(x, 0.02, -0.6), 0.01)
	mat.name = "DoorMat"
	doors.append({"x": x, "left": left, "right": right, "open": 0.0})

func update(dt: float, cam_dir: Vector3, far: float, agents: Array, night: float) -> void:
	var flat := Vector3(cam_dir.x, 0, cam_dir.z).normalized()
	for w in walls:
		var faces := -flat.dot(w["normal"]) > 0.2
		var target := 1.0 if (cutaway and faces and far < 0.5) else 0.0
		w["sink"] = clampf(w["sink"] + (target - w["sink"]) * minf(1.0, dt * 6.0), 0.0, 1.0)
		var node: Node3D = w["node"]
		var h: float = w["h"]
		if w.has("upper"):
			var up: Node3D = w["upper"]
			up.visible = w["sink"] < 0.5
			up.position.y = -w["sink"] * 1.5
		else:
			node.scale.y = lerpf(1.0, 0.45 / h, w["sink"])
	for d in doors:
		var near := false
		for p in agents:
			if absf(p.x - d["x"]) < 1.6 and absf(p.z - float(layout["interior"].end.y)) < 1.4: near = true; break
		d["open"] = clampf(d["open"] + ((1.0 if near else 0.0) - d["open"]) * minf(1.0, dt * 6.0), 0.0, 1.0)
		d["left"].position.x = d["x"] - 0.5 - d["open"] * 0.46
		d["right"].position.x = d["x"] + 0.5 + d["open"] * 0.46
	for l in lamps: l.light_energy = lerpf(0.45, 1.3, night)
	for m in lamp_mats: m.emission_energy_multiplier = lerpf(1.2, 4.0, night)
	var glow := neon and night > 0.2
	for lb in sign_letters: lb.modulate = Color(2.6 + night * 2.0, 2.2 + night * 1.6, 1.6 + night) if glow else Cfg.CREAM
