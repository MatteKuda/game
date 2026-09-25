class_name MallShell
extends Node3D
## Köşebaşı AVM building: marble floors, the floor-1 slab with the escalator well, glass rails,
## per-floor cut-away walls, entrances, the big roof sign, escalators, the glass lift,
## tenant storefronts (brand fascia, furnishing, clerks) and event decorations.

const FH := Cfg.FLOOR_H

var mall
var f0: Node3D
var f1: Node3D
var exterior: Node3D
var sides: Array = [] # [{node, normal, floor, sink, h, extras: [], unit: -1}]
var unit_nodes := {} # idx -> Node3D
var unit_sig := {} # idx -> tenant id ("" = vacant)
var clerks: Array = []
var escalators: Array = [] # [{id, mat, dir, off}]
var lift_cab: Node3D
var lift_y := 0.0
var lift_from := 0.0
var lift_to_y := 0.0
var lift_t := 99.0
var barriers := {}
var decorations: Node3D # floor 0
var decorations1: Node3D # floor 1
var band: Node3D
var performer: CharacterView
var glow_labels: Array = [] # [Label3D, base Color]
var screens: Array = [] # StandardMaterial3D (own instances), flicker
var doors: Array = []
var lamps: Array = []
var _parts: Array = []
var _t := 0.0

# ------------------------------------------------------------------ build
func build(m) -> void:
	mall = m
	f0 = Node3D.new(); f0.name = "Floor0"; add_child(f0)
	f1 = Node3D.new(); f1.name = "Floor1"; add_child(f1)
	exterior = Node3D.new(); exterior.name = "Exterior"; add_child(exterior)
	_floors()
	_walls()
	_exterior()
	_connectors()
	_stage()
	_lights()
	decorations = Node3D.new(); f0.add_child(decorations)
	decorations1 = Node3D.new(); f1.add_child(decorations1)
	sync_units()

func _marble(tint := Color("f3ede4")) -> ShaderMaterial:
	return Art.shader_mat("marble", {"base_color": tint})

func _floors() -> void:
	# ground floor corridors (the supermarket floor is drawn by ShopShell)
	for r in MallDB.F0_CORRIDORS:
		var rr: Rect2i = r
		Art.box(f0, Vector3(rr.size.x, 0.1, rr.size.y), _marble(), Vector3(Cfg.rc(rr).x, -0.03, Cfg.rc(rr).y), 0.0)
	# floor-1 slab: row runs that skip the escalator well and the lift shaft
	var F := MallDB.FOOTPRINT
	var holes := [MallDB.WELL, MallDB.SHAFT, MallDB.STAIR_WELL]
	var runs := {} # "x0,x1" -> [z0, z1]
	var rects := []
	for z in range(F.position.y, F.end.y):
		var row := []
		var x := F.position.x
		while x < F.end.x:
			var inside := false
			for hr in holes: if (hr as Rect2i).has_point(Vector2i(x, z)): inside = true
			if inside: x += 1; continue
			var x0 := x
			while x < F.end.x:
				var hole := false
				for hr in holes: if (hr as Rect2i).has_point(Vector2i(x, z)): hole = true
				if hole: break
				x += 1
			row.append("%d,%d" % [x0, x])
		var next := {}
		for k in row:
			if runs.has(k): next[k] = [runs[k][0], z + 1]
			else: next[k] = [z, z + 1]
		for k in runs: if not next.has(k): rects.append([k, runs[k]])
		runs = next
	for k in runs: rects.append([k, runs[k]])
	var under := Art.mat(Color("e6ddd0"), 0.9)
	for e in rects:
		var xs: PackedStringArray = (e[0] as String).split(",")
		var x0 := float(xs[0]); var x1 := float(xs[1])
		var z0 := float(e[1][0]); var z1 := float(e[1][1])
		var c := Vector3((x0 + x1) * 0.5, 0, (z0 + z1) * 0.5)
		Art.box(f1, Vector3(x1 - x0, 0.3, z1 - z0), under, c + Vector3(0, FH - 0.2, 0), 0.0)
		Art.box(f1, Vector3(x1 - x0, 0.06, z1 - z0), _marble(Color("efe7db")), c + Vector3(0, FH - 0.01, 0), 0.0)
	# recessed ceiling panels under the slab light the ground-floor corridors
	var panel := Art.mat(Color("fff6e2"), 0.5, 0.0, 1.6)
	for r in MallDB.F0_CORRIDORS:
		var rr: Rect2i = r
		for z in range(rr.position.y + 1, rr.end.y, 3):
			for x in range(rr.position.x + 1, rr.end.x, 3):
				if MallDB.WELL.grow(1).has_point(Vector2i(x, z)) or MallDB.SHAFT.grow(1).has_point(Vector2i(x, z)) or MallDB.STAIR_WELL.grow(1).has_point(Vector2i(x, z)): continue
				Art.box(f0, Vector3(0.9, 0.03, 0.9), panel, Vector3(x + 0.5, FH - 0.36, z + 0.5), 0.01)
	# food court: warm terrazzo field between the two food units
	Art.box(f1, Vector3(16, 0.02, 5), Art.shader_mat("terrazzo", {"base_color": Color("ecdcc2")}), Vector3(22, FH + 0.03, 10.5), 0.0)
	# glass railing around the well (the east edge is the escalator landing)
	var W := MallDB.WELL
	var steel := Art.mat(Cfg.STEEL, 0.3, 0.7)
	var gl := Art.glass(Color(0.8, 0.95, 1.0), 0.2)
	var segs := [[W.position.x, W.position.y, W.end.x, W.position.y], [W.position.x, W.end.y, W.end.x, W.end.y], [W.position.x, W.position.y, W.position.x, W.end.y]]
	var SW := MallDB.STAIR_WELL
	segs += [[SW.position.x, SW.position.y, SW.position.x, SW.end.y], [SW.end.x, SW.position.y, SW.end.x, SW.end.y], [SW.position.x, SW.position.y, SW.end.x, SW.position.y]]
	for s in segs:
		var vert: bool = s[0] == s[2]
		var ln := float(absi(s[2] - s[0]) + absi(s[3] - s[1]))
		var c := Vector3((s[0] + s[2]) * 0.5, FH, (s[1] + s[3]) * 0.5)
		var sz := Vector3(0.03, 1.0, ln) if vert else Vector3(ln, 1.0, 0.03)
		Art.box(f1, sz, gl, c + Vector3(0, 0.5, 0), 0.0)
		Art.box(f1, Vector3(0.08, 0.06, ln + 0.08) if vert else Vector3(ln + 0.08, 0.06, 0.08), steel, c + Vector3(0, 1.03, 0), 0.02)
		Art.box(f1, Vector3(0.3, 0.3, ln) if vert else Vector3(ln, 0.3, 0.3), Art.mat(Color("d8cdbd"), 0.8), c + Vector3(0, -0.15, 0), 0.0)

# ------------------------------------------------------------------ walls
func _side(normal: Vector3, fl: int, unit := -1, parent: Node3D = null) -> Dictionary:
	var n := Node3D.new(); n.position.y = fl * FH
	(parent if parent else (f1 if fl == 1 else f0)).add_child(n)
	# mode: "front" sinks when its outer face looks at the camera (perimeter), "both" whenever it
	# stands across the view (unit partitions), "back" when the camera is on its inner side (storefronts)
	var s := {"node": n, "normal": normal, "floor": fl, "sink": 0.0, "h": FH - 0.05, "extras": [], "unit": unit, "mode": "front" if unit < 0 else "both"}
	sides.append(s)
	return s

## wall segment in the side's local space (y from the floor)
func _seg(parent: Node3D, x0: float, z0: float, x1: float, z1: float, y0: float, h: float, m: Material, th := 0.22) -> MeshInstance3D:
	var vert := is_equal_approx(x0, x1)
	var ln := absf(x1 - x0) + absf(z1 - z0)
	var sz := Vector3(th, h, ln + th) if vert else Vector3(ln + th, h, th)
	return Art.box(parent, sz, m, Vector3((x0 + x1) * 0.5, y0 + h * 0.5, (z0 + z1) * 0.5), 0.0)

func _wall2(s: Dictionary, x0: float, z0: float, x1: float, z1: float, h: float, inner: Material, outer: Material) -> void:
	# two skins: painted inside, cladding outside, plus a dark cap
	var nrm: Vector3 = s["normal"]
	var n: Node3D = s["node"]
	var o := nrm * 0.07
	var m1 := _seg(n, x0, z0, x1, z1, 0.0, h, inner, 0.14)
	m1.position -= o
	var m2 := _seg(n, x0, z0, x1, z1, 0.0, h, outer, 0.14)
	m2.position += o
	var cap := _seg(n, x0, z0, x1, z1, h, 0.12, Art.mat(Color("2d3348"), 0.6), 0.32)
	cap.position.y = h + 0.06

func _walls() -> void:
	var F := MallDB.FOOTPRINT
	var clad := Art.mat(Color("34405a"), 0.5, 0.2)
	var clad_light := Art.mat(Color("e9e1d4"), 0.8)
	var frame := Art.mat(Color("27303f"), 0.4, 0.5)
	var gl := Art.glass(Color(0.78, 0.92, 1.0), 0.2)
	var x0 := float(F.position.x); var x1 := float(F.end.x)
	var z0 := float(F.position.y); var z1 := float(F.end.y)
	for fl in [0, 1]:
		var inner := Art.shader_mat("wall_paint", {"paint": Color("f1e7d6") if fl == 0 else Color("e8d9c1"), "wood": Color("8a5a35"), "rail": Color("1f8a86"), "base_y": fl * FH, "wainscot": 1.0})
		var H := FH - 0.05 if fl == 0 else FH - 0.6
		var back := _side(Vector3(0, 0, -1), fl); back["h"] = H
		_wall2(back, x0, z0 - 0.15, x1, z0 - 0.15, H, inner, clad_light)
		var left := _side(Vector3(-1, 0, 0), fl); left["h"] = H
		_wall2(left, x0 - 0.15, z0, x0 - 0.15, z1, H, inner, clad_light)
		var right := _side(Vector3(1, 0, 0), fl); right["h"] = H
		_wall2(right, x1 + 0.15, z0, x1 + 0.15, z1, H, inner, clad_light)
		var front := _side(Vector3(0, 0, 1), fl); front["h"] = H
		var fn: Node3D = front["node"]
		if fl == 0:
			# wing fronts: glass bays with a dark cladding sill; the supermarket fills x10..34
			for w in [[x0, 10.0], [34.0, x1]]:
				var x := int(w[0])
				while x < int(w[1]):
					if MallDB.ENTRANCES.has(x): x += 1; continue
					_seg(fn, x, z1, x + 1, z1, 0.0, 0.5, clad, 0.24)
					Art.box(fn, Vector3(0.96, 2.4, 0.02), gl, Vector3(x + 0.5, 1.7, z1), 0.0)
					Art.box(fn, Vector3(0.07, 2.5, 0.1), frame, Vector3(x + 1.0, 1.7, z1), 0.01)
					x += 1
				_seg(fn, w[0], z1, w[1], z1, 2.9, H - 2.9, clad, 0.26)
				Art.box(fn, Vector3(w[1] - w[0], 0.08, 0.12), frame, Vector3((w[0] + w[1]) * 0.5, 2.92, z1 + 0.02), 0.01)
			for ex in [MallDB.ENTRANCES[0], MallDB.ENTRANCES[2]]:
				_entrance(front, float(ex) + 1.0, z1)
		else:
			# floor-1 glass curtain wall
			for x in range(F.position.x, F.end.x):
				_seg(fn, x, z1, x + 1, z1, 0.0, 0.9, clad, 0.24)
				Art.box(fn, Vector3(0.97, H - 1.3, 0.02), gl, Vector3(x + 0.5, 0.9 + (H - 1.3) * 0.5, z1), 0.0)
				Art.box(fn, Vector3(0.06, H - 1.3, 0.1), frame, Vector3(x + 1.0, 0.9 + (H - 1.3) * 0.5, z1), 0.01)
			_seg(fn, x0, z1, x1, z1, H - 0.4, 0.4, clad, 0.26)

func _entrance(front: Dictionary, x: float, z: float) -> void:
	var fn: Node3D = front["node"]
	var frame := Art.mat(Color("27303f"), 0.4, 0.5)
	Art.box(fn, Vector3(2.1, 0.12, 0.2), frame, Vector3(x, 2.6, z), 0.02)
	var left := Node3D.new(); fn.add_child(left)
	var right := Node3D.new(); fn.add_child(right)
	for p in [left, right]:
		Art.box(p, Vector3(0.98, 2.5, 0.03), Art.glass(Color(0.8, 0.95, 1.0), 0.2), Vector3(0, 1.28, 0), 0.0)
		Art.box(p, Vector3(0.98, 0.06, 0.05), frame, Vector3(0, 0.03, 0), 0.01)
		Art.box(p, Vector3(0.05, 2.5, 0.05), frame, Vector3(0.47, 1.28, 0), 0.01)
		Art.box(p, Vector3(0.05, 2.5, 0.05), frame, Vector3(-0.47, 1.28, 0), 0.01)
		p.position.z = z
	doors.append({"x": x, "left": left, "right": right, "open": 0.0})
	Art.box(fn, Vector3(1.9, 0.02, 1.2), Art.mat(Color("3a3f48"), 0.95), Vector3(x, 0.03, z - 0.7), 0.01)
	# canopy + sign (hidden while the wall is cut away)
	var up := Node3D.new(); fn.add_child(up)
	Art.box(up, Vector3(3.2, 0.14, 1.7), Art.mat(Cfg.TEAL, 0.5), Vector3(x, 3.05, z + 0.85), 0.05)
	Art.box(up, Vector3(3.2, 0.05, 0.05), Art.mat(Cfg.MUSTARD, 0.5), Vector3(x, 3.0, z + 1.7), 0.01)
	for sx in [-1.45, 1.45]:
		Art.cyl(up, 0.02, 0.02, 1.0, frame, Vector3(x + sx, 3.5, z + 1.2), 6).rotation.x = 0.9
	Art.box(up, Vector3(2.7, 0.6, 0.1), Art.mat(Cfg.INK, 0.5), Vector3(x, 3.5, z + 0.1), 0.05)
	var lb := Art.label(up, "AVM GİRİŞİ", 64, Cfg.CREAM, Vector3(x, 3.5, z + 0.16), 0.0, "display", 8, Cfg.INK)
	glow_labels.append([lb, Cfg.CREAM])
	front["extras"].append(up)

func _exterior() -> void:
	var F := MallDB.FOOTPRINT
	var top := 2.0 * FH - 0.6
	var clad := Art.mat(Color("34405a"), 0.5, 0.2)
	var cx := (F.position.x + F.end.x) * 0.5
	Art.box(exterior, Vector3(F.size.x + 0.5, 0.5, 0.4), clad, Vector3(cx, top + 0.25, F.end.y), 0.05)
	Art.box(exterior, Vector3(F.size.x + 0.5, 0.5, 0.4), clad, Vector3(cx, top + 0.25, F.position.y - 0.15), 0.05)
	for x in [F.position.x - 0.15, F.end.x + 0.15]:
		Art.box(exterior, Vector3(0.4, 0.5, F.size.y), clad, Vector3(x, top + 0.25, Cfg.rc(F).y), 0.05)
	# big roof sign
	# sits on the front parapet, leaning back slightly so it reads from the street camera
	var s := Node3D.new(); s.position = Vector3(cx, top + 1.45, F.end.y + 0.05); s.rotation.x = -0.18; exterior.add_child(s)
	for sx in [-3.6, 3.6]: Art.box(s, Vector3(0.14, 1.2, 0.14), Art.mat(Cfg.STEEL_DARK, 0.4, 0.5), Vector3(sx, -0.9, -0.12), 0.02)
	Art.box(s, Vector3(10.0, 1.9, 0.3), Art.mat(Cfg.TEAL_DARK, 0.5), Vector3.ZERO, 0.08)
	Art.box(s, Vector3(9.7, 1.6, 0.1), Art.mat(Cfg.CREAM, 0.6), Vector3(0, 0, 0.12), 0.05)
	var l1 := Art.label(s, "KÖŞEBAŞI AVM", 190, Cfg.TERRA, Vector3(0, 0.18, 0.19), 0.0, "display", 20, Cfg.TERRA_DARK)
	var l2 := Art.label(s, "ALIŞVERİŞ · YEMEK · EĞLENCE", 64, Cfg.TEAL, Vector3(0, -0.52, 0.19), 0.0, "display700")
	glow_labels.append([l1, Cfg.TERRA]); glow_labels.append([l2, Cfg.TEAL])

# ------------------------------------------------------------------ escalators & lift
func _connectors() -> void:
	var dark := Art.mat(Color("3a3f48"), 0.5, 0.4)
	var steel := Art.mat(Cfg.STEEL, 0.3, 0.7)
	var rail := Art.mat(Color("1b1d22"), 0.5)
	var gl := Art.glass(Color(0.8, 0.95, 1.0), 0.22)
	var xa := 13.1; var xb := 17.9
	var run := xb - xa
	var ln := Vector2(run, FH).length()
	var ang := atan2(FH, run)
	for row in [[1, "escUp", 1.0], [2, "escDown", -1.0]]:
		var z: float = row[0] + 0.5
		var g := Node3D.new(); f0.add_child(g)
		var body := Node3D.new(); body.position = Vector3((xa + xb) * 0.5, FH * 0.5 + 0.02, z); body.rotation.z = ang; g.add_child(body)
		var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/escalator.gdshader")
		var q := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(ln, 0.86); q.mesh = qm
		q.material_override = sm; q.rotation.x = -PI / 2; q.position.y = 0.01; body.add_child(q)
		escalators.append({"id": row[1], "mat": sm, "dir": row[2], "off": 0.0})
		Art.box(body, Vector3(ln + 0.3, 0.42, 1.0), dark, Vector3(0, -0.22, 0), 0.04)
		for sd in [-1.0, 1.0]:
			Art.box(body, Vector3(ln, 0.85, 0.03), gl, Vector3(0, 0.55, sd * 0.47), 0.0)
			Art.box(body, Vector3(ln + 0.2, 0.08, 0.1), rail, Vector3(0, 1.0, sd * 0.47), 0.03)
			Art.box(body, Vector3(ln, 0.14, 0.08), steel, Vector3(0, 0.08, sd * 0.47), 0.02)
		# flat landings with comb plates and handrail newels
		for e in [[12.5, 0.0], [18.5, FH]]:
			var lx: float = e[0]; var ly: float = e[1]
			Art.box(g, Vector3(1.2, 0.05, 0.9), steel, Vector3(lx + (0.1 if lx < 15 else -0.1), ly + 0.03, z), 0.01)
			for sd in [-1.0, 1.0]:
				Art.box(g, Vector3(1.0, 0.1, 0.1), rail, Vector3(lx + (0.35 if lx < 15 else -0.35), ly + 1.0, z + sd * 0.47), 0.04)
				Art.box(g, Vector3(0.9, 0.9, 0.05), Art.mat(Color("d9dde2"), 0.4, 0.5), Vector3(lx + (0.4 if lx < 15 else -0.4), ly + 0.5, z + sd * 0.47), 0.02)
		var up: bool = row[2] > 0.0
		var ar := Art.mat(Cfg.GOOD if up else Cfg.MUSTARD, 0.5, 0.0, 1.4)
		var arrow := MeshInstance3D.new(); var pm := PrismMesh.new(); pm.size = Vector3(0.4, 0.4, 0.02); arrow.mesh = pm
		arrow.material_override = ar
		arrow.rotation = Vector3(-PI / 2, 0, -PI / 2 if up else PI / 2)
		arrow.position = Vector3(12.3 if up else 18.7, (0.0 if up else FH) + 0.07, z)
		g.add_child(arrow)
		var bx := 12.1 if up else 18.9
		var bar := _barrier(Vector3(bx, 0.0 if up else FH, z))
		barriers[row[1]] = bar
		(f0 if up else f1).add_child(bar)
	_stairs()
	# glass lift in its shaft
	var L := MallDB.SHAFT
	var lc := Vector3(Cfg.rc(L).x, 0, Cfg.rc(L).y)
	var lg := Node3D.new(); f0.add_child(lg)
	var shaft := Art.box(lg, Vector3(1.9, 2.0 * FH, 1.9), Art.glass(Color(0.8, 0.95, 0.96), 0.14), lc + Vector3(0, FH, 0), 0.0)
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in [Vector2(-0.95, -0.95), Vector2(0.95, -0.95), Vector2(-0.95, 0.95), Vector2(0.95, 0.95)]:
		Art.box(lg, Vector3(0.1, 2.0 * FH, 0.1), steel, lc + Vector3(c.x, FH, c.y), 0.02)
	for yy in [0.05, FH, 2.0 * FH - 0.6]:
		Art.box(lg, Vector3(2.0, 0.1, 2.0), Art.mat(Cfg.STEEL_DARK, 0.4, 0.5), lc + Vector3(0, yy, 0), 0.02)
	lift_cab = Node3D.new(); lift_cab.position = lc; lg.add_child(lift_cab)
	Art.box(lift_cab, Vector3(1.7, 0.1, 1.7), Art.mat(Cfg.STEEL_DARK, 0.4, 0.5), Vector3(0, 0.05, 0), 0.03)
	Art.box(lift_cab, Vector3(1.7, 0.08, 1.7), Art.mat(Cfg.STEEL_DARK, 0.4, 0.5), Vector3(0, 2.4, 0), 0.03)
	Art.box(lift_cab, Vector3(1.6, 2.3, 0.05), Art.mat(Color("f6efe3"), 0.5), Vector3(0, 1.2, -0.8), 0.02)
	Art.box(lift_cab, Vector3(1.6, 0.05, 0.06), steel, Vector3(0, 1.0, -0.75), 0.02)
	Art.box(lift_cab, Vector3(1.2, 0.02, 1.2), Art.mat(Color("fff1d0"), 0.5, 0.0, 2.0), Vector3(0, 2.35, 0), 0.01)
	var lb := _barrier(Vector3(lc.x - 0.5, 0.0, L.end.y + 0.4))
	lb.rotation.y = PI / 2
	barriers["lift"] = lb; f0.add_child(lb)
	for k in barriers: (barriers[k] as Node3D).visible = false

## straight stair run along +z through the slab opening: timber treads on steel stringers
func _stairs() -> void:
	var W := MallDB.STAIR_WELL
	var g := Node3D.new(); f0.add_child(g)
	var z0 := float(W.position.y); var z1 := float(W.end.y)
	var x0 := float(W.position.x); var x1 := float(W.end.x)
	var cx := (x0 + x1) * 0.5
	var n := 14
	var run := (z1 - z0) / n
	var rise := FH / n
	var tread := Art.mat(Cfg.WOOD, 0.6)
	var nose := Art.mat(Cfg.MUSTARD, 0.5)
	var steel := Art.mat(Color("34405a"), 0.45, 0.5)
	for i in n:
		var y := rise * (i + 1)
		var z := z0 + run * (i + 0.5)
		Art.box(g, Vector3(x1 - x0 - 0.1, 0.05, run + 0.04), tread, Vector3(cx, y - 0.025, z), 0.01)
		Art.box(g, Vector3(x1 - x0 - 0.1, 0.02, 0.05), nose, Vector3(cx, y - 0.01, z + run * 0.5 - 0.02), 0.0)
		Art.box(g, Vector3(x1 - x0 - 0.1, rise, 0.03), Art.mat(Color("e9e1d4"), 0.8), Vector3(cx, y - rise * 0.5, z - run * 0.5 + 0.015), 0.0)
	var ln := Vector2(z1 - z0, FH).length()
	var ang := atan2(FH, z1 - z0)
	for sx in [x0 + 0.04, x1 - 0.04]:
		var st := Node3D.new(); st.position = Vector3(sx, FH * 0.5 - 0.12, (z0 + z1) * 0.5); st.rotation.x = -ang; g.add_child(st)
		Art.box(st, Vector3(0.08, 0.3, ln), steel, Vector3.ZERO, 0.02)
		Art.box(st, Vector3(0.03, 0.85, ln), Art.glass(Color(0.8, 0.95, 1.0), 0.2), Vector3(0, 0.62, 0), 0.0)
		Art.box(st, Vector3(0.07, 0.06, ln + 0.2), Art.mat(Color("1b1d22"), 0.5), Vector3(0, 1.06, 0), 0.02)
	# bottom landing mat
	Art.box(g, Vector3(x1 - x0, 0.02, 0.9), Art.mat(Color("3a3f48"), 0.9), Vector3(cx, 0.02, z0 - 0.5), 0.0)

func _barrier(p: Vector3) -> Node3D:
	var b := Node3D.new(); b.position = p
	var dk := Art.mat(Cfg.STEEL_DARK, 0.4, 0.5)
	for sz in [-0.55, 0.55]:
		Art.cyl(b, 0.04, 0.04, 1.0, dk, Vector3(0, 0.5, sz), 8)
		Art.cyl(b, 0.14, 0.16, 0.05, dk, Vector3(0, 0.025, sz), 12)
	var tape := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.04, 0.16, 1.1); tape.mesh = bm
	var st := Art.shader_mat("stripes", {"color_a": Cfg.INK, "color_b": Cfg.MUSTARD, "count": 7.0})
	tape.material_override = st; tape.position.y = 0.85; tape.rotation.x = 0.0
	b.add_child(tape)
	Art.box(b, Vector3(0.06, 0.34, 0.8), Art.mat(Cfg.BAD, 0.5), Vector3(0, 1.28, 0), 0.03)
	var l := Art.label(b, "ARIZALI", 44, Color.WHITE, Vector3(0.04, 1.28, 0), 0.0, "display")
	l.rotation.y = PI / 2
	var l2 := Art.label(b, "ARIZALI", 44, Color.WHITE, Vector3(-0.04, 1.28, 0), 0.0, "display")
	l2.rotation.y = -PI / 2
	return b

# ------------------------------------------------------------------ food-court stage
func _stage() -> void:
	var S := MallDB.STAGE
	var s := Node3D.new(); s.position = Vector3(Cfg.rc(S).x, FH, Cfg.rc(S).y); f1.add_child(s)
	var w := float(S.size.x); var d := float(S.size.y)
	Art.box(s, Vector3(w - 0.1, 0.4, d - 0.1), Art.mat(Cfg.INK, 0.5), Vector3(0, 0.2, 0), 0.06)
	Art.box(s, Vector3(w - 0.05, 0.05, d - 0.05), Art.mat(Cfg.TERRA, 0.6), Vector3(0, 0.42, 0), 0.02)
	# low backdrop so the band stays visible from the default (street-side) camera
	Art.box(s, Vector3(w - 0.3, 1.1, 0.08), Art.mat(Color("6c4ab6"), 0.7), Vector3(0, 1.0, d * 0.5 - 0.15), 0.03)
	for i in 9:
		Art.sphere(s, 0.05, Art.mat(Color("ffe7a8"), 0.3, 0.0, 2.5), Vector3(-w * 0.5 + 0.4 + i * (w - 0.8) / 8.0, 1.6, d * 0.5 - 0.15))
	var lb := Art.label(s, "SAHNE", 60, Cfg.CREAM, Vector3(0, 1.0, d * 0.5 - 0.2), 0.0, "display", 8, Color("3b2670"))
	lb.rotation.y = PI
	glow_labels.append([lb, Cfg.CREAM])
	for sx in [-1.0, 1.0]:
		Art.cyl(s, 0.28, 0.24, 0.5, Art.mat(Cfg.TERRA_DARK), Vector3(sx * (w * 0.5 - 0.3), 0.67, -d * 0.5 + 0.3), 16)
		Art.sphere(s, 0.34, Art.mat(Color("4f9a57"), 0.8), Vector3(sx * (w * 0.5 - 0.3), 1.1, -d * 0.5 + 0.3), 0.9)
	# band gear appears for concerts
	band = Node3D.new(); s.add_child(band); band.visible = false
	for sx in [-1.0, 1.0]:
		Art.box(band, Vector3(0.5, 0.9, 0.45), Art.mat(Color("1b1d22"), 0.6), Vector3(sx * 1.25, 0.87, 0.3), 0.04)
		Art.cyl(band, 0.14, 0.14, 0.02, Art.mat(Color("3a3f48")), Vector3(sx * 1.25, 1.0, 0.075), 16).rotation.x = PI / 2
		Art.cyl(band, 0.02, 0.02, 3.0, Art.mat(Cfg.STEEL_DARK), Vector3(sx * (w * 0.5 - 0.15), 1.9, 0.6), 6)
	Art.box(band, Vector3(w - 0.3, 0.1, 0.1), Art.mat(Cfg.STEEL_DARK), Vector3(0, 3.4, 0.6), 0.02)
	for i in 4:
		var m := StandardMaterial3D.new()
		m.albedo_color = [Color("ff5fa2"), Color("61d4ff"), Color("f2b33d"), Color("7fe3c8")][i]
		m.emission_enabled = true; m.emission = m.albedo_color; m.emission_energy_multiplier = 3.0
		var sp := Art.cyl(band, 0.1, 0.14, 0.22, m, Vector3(-1.2 + i * 0.8, 3.25, 0.6), 10)
		sp.rotation.x = -0.6
		screens.append(m)
	var mic := Node3D.new(); mic.position = Vector3(0, 0.45, -0.35); band.add_child(mic)
	Art.cyl(mic, 0.015, 0.015, 1.3, Art.mat(Color("1b1d22")), Vector3(0, 0.65, 0), 6)
	Art.sphere(mic, 0.04, Art.mat(Color("3a3f48")), Vector3(0, 1.32, 0))
	performer = CharacterView.new()
	band.add_child(performer)
	var look := Customer.random_look(null)
	look["top"] = Color("d6333a"); look["accent"] = Cfg.MUSTARD
	performer.setup(look)
	performer.position = Vector3(0, 0.45, 0.05)
	performer.rotation.y = PI # face the food court (-z)

func _lights() -> void:
	var spots := [Vector3(8, 3.3, 3), Vector3(8, 3.3, 11), Vector3(36, 3.3, 3), Vector3(36, 3.3, 11), Vector3(22, 3.3, 2)]
	for p in spots: _lamp(f0, p, 7.0)
	var up := [Vector3(8, FH + 3.2, 6), Vector3(22, FH + 3.2, 6), Vector3(36, FH + 3.2, 6), Vector3(16, FH + 3.2, 10.5), Vector3(28, FH + 3.2, 10.5), Vector3(22, FH + 3.0, 13)]
	for p in up: _lamp(f1, p, 8.0)

func _lamp(parent: Node3D, p: Vector3, rng: float) -> void:
	var om := OmniLight3D.new(); om.position = p; om.light_color = Color("ffe2b8"); om.omni_range = rng; om.light_energy = 0.8
	om.shadow_enabled = false
	parent.add_child(om); lamps.append(om)

# ------------------------------------------------------------------ units
func sync_units() -> void:
	for u in mall.units:
		var sig: String = "" if u["tenant"].is_empty() else u["tenant"]["def"]["id"]
		if unit_sig.get(u["idx"], "-") == sig: continue
		unit_sig[u["idx"]] = sig
		_rebuild_unit(u)

func _rebuild_unit(u: Dictionary) -> void:
	var idx: int = u["idx"]
	if unit_nodes.has(idx):
		var old: Node3D = unit_nodes[idx]
		clerks = clerks.filter(func(c): return is_instance_valid(c) and not old.is_ancestor_of(c))
		sides = sides.filter(func(s): return s["unit"] != idx)
		glow_labels = glow_labels.filter(func(g): return is_instance_valid(g[0]) and not old.is_ancestor_of(g[0]))
		screens = screens.filter(func(m): return not (m in old.get_meta("screens", [])))
		old.queue_free()
	var d: Dictionary = u["def"]
	var fl: int = d["floor"]
	var g := Node3D.new(); g.name = "Unit%s" % d["id"]
	(f1 if fl == 1 else f0).add_child(g)
	unit_nodes[idx] = g
	var r: Rect2i = d["rect"]
	var y0 := fl * FH
	var H := FH - 0.6
	var t: Dictionary = u["tenant"]["def"] if not u["tenant"].is_empty() else {}
	var col: Color = t.get("color", Color("cfc6b8"))
	# floor
	var fcol: Color = Color("efe7dc").lerp(col, 0.22) if not t.is_empty() else Color("dcd4c8")
	var ft := Art.shader_mat("checker", {"color_a": fcol, "color_b": fcol.darkened(0.08), "grout": fcol.darkened(0.25), "tile": 0.6})
	if fl == 0: Art.box(g, Vector3(r.size.x, 0.1, r.size.y), ft, Vector3(Cfg.rc(r).x, -0.03, Cfg.rc(r).y), 0.0)
	else: Art.box(g, Vector3(r.size.x - 0.02, 0.02, r.size.y - 0.02), ft, Vector3(Cfg.rc(r).x, y0 + 0.025, Cfg.rc(r).y), 0.0)
	var F := MallDB.FOOTPRINT
	var dir: Vector2i = d["dir"]
	var edges := [
		[r.position.x, r.position.y, r.end.x, r.position.y, Vector2i(0, -1)],
		[r.position.x, r.end.y, r.end.x, r.end.y, Vector2i(0, 1)],
		[r.position.x, r.position.y, r.position.x, r.end.y, Vector2i(-1, 0)],
		[r.end.x, r.position.y, r.end.x, r.end.y, Vector2i(1, 0)],
	]
	var wall_m := Art.shader_mat("wall_paint", {"paint": Color("f0e9dd").lerp(col, 0.35) if not t.is_empty() else Color("ece4d6"), "wood": col.darkened(0.45) if not t.is_empty() else Color("8a7a66"), "rail": t.get("accent", Cfg.CREAM), "base_y": y0, "wainscot": 0.9})
	var outer_m := Art.mat(Color("ece4d6"), 0.85)
	for e in edges:
		var perimeter: bool = (e[0] == e[2] and (e[0] == F.position.x or e[0] == F.end.x)) or (e[1] == e[3] and (e[1] == F.position.y or e[1] == F.end.y))
		if perimeter: continue
		var n: Vector2i = e[4]
		if n == dir:
			var sf := _side(Vector3(n.x, 0, n.y), fl, idx, g)
			sf["h"] = H; sf["mode"] = "back"
			_storefront(sf, u, e, H)
		else:
			var s := _side(Vector3(n.x, 0, n.y), fl, idx, g)
			s["h"] = H
			_wall2(s, e[0], e[1], e[2], e[3], H, wall_m, outer_m)
	var before := screens.size()
	if not t.is_empty(): _furnish(g, u, t, y0)
	g.set_meta("screens", screens.slice(before))

func _storefront(side: Dictionary, u: Dictionary, e: Array, H: float) -> void:
	var g: Node3D = side["node"]
	var y0 := 0.0
	var t: Dictionary = u["tenant"]["def"] if not u["tenant"].is_empty() else {}
	var horiz: bool = e[1] == e[3]
	var ln: int = (e[2] - e[0]) if horiz else (e[3] - e[1])
	var door_set := {}
	for dt in u["def"]["door"]: door_set[dt.x if horiz else dt.y] = true
	var frame := Art.mat(Color("27303f"), 0.4, 0.5)
	var col: Color = t.get("color", Color("b9b0a2"))
	var acc: Color = t.get("accent", Cfg.CREAM)
	var gl := Art.glass(Color(0.82, 0.95, 1.0), 0.18)
	var shutter := Art.shader_mat("shutter")
	for i in ln:
		var a: int = (e[0] if horiz else e[1]) + i
		var cx: float = a + 0.5 if horiz else float(e[0])
		var cz: float = float(e[1]) if horiz else a + 0.5
		var along := Vector3(1, 0, 0) if horiz else Vector3(0, 0, 1)
		var thin := func(w: float, h: float, dpt: float) -> Vector3:
			return Vector3(w, h, dpt) if horiz else Vector3(dpt, h, w)
		if door_set.has(a):
			if t.is_empty():
				Art.box(g, thin.call(0.98, 2.6, 0.06), shutter, Vector3(cx, y0 + 1.3, cz), 0.0)
			continue
		if not t.is_empty():
			Art.box(g, thin.call(0.96, 2.3, 0.02), gl, Vector3(cx, y0 + 1.45, cz), 0.0)
			Art.box(g, thin.call(0.98, 0.3, 0.16), Art.mat(col, 0.5), Vector3(cx, y0 + 0.15, cz), 0.02)
		else:
			Art.box(g, thin.call(0.98, 2.6, 0.06), shutter, Vector3(cx, y0 + 1.3, cz), 0.0)
		var fp := Vector3(cx, y0 + 1.3, cz) + along * 0.5
		Art.box(g, thin.call(0.06, 2.6, 0.1), frame, fp, 0.01)
	var c := Vector3((e[0] + e[2]) * 0.5, 0, (e[1] + e[3]) * 0.5)
	var bh := H - 2.6
	var dir: Vector2i = u["def"]["dir"]
	var nrm := Vector3(dir.x, 0, dir.y)
	Art.box(g, (Vector3(ln + 0.2, bh, 0.24) if horiz else Vector3(0.24, bh, ln + 0.2)), Art.mat(col.darkened(0.15) if not t.is_empty() else Color("cfc6b8"), 0.6), c + Vector3(0, y0 + 2.6 + bh * 0.5, 0), 0.03)
	# sign panel on the fascia
	var sg := Node3D.new(); sg.position = c + Vector3(0, y0 + 2.6 + bh * 0.5, 0) + nrm * 0.14
	sg.rotation.y = atan2(nrm.x, nrm.z)
	g.add_child(sg)
	side["extras"].append(sg)
	var sw := minf(4.2, ln * 0.8)
	if not t.is_empty():
		Art.box(sg, Vector3(sw, 0.86, 0.06), Art.mat(acc, 0.5), Vector3.ZERO, 0.06)
		Art.box(sg, Vector3(sw - 0.12, 0.74, 0.04), Art.mat(col, 0.5), Vector3(0, 0, 0.02), 0.05)
		var brand: String = t["brand"]
		var fs := clampi(int(sw * 190.0 / maxf(4.0, brand.length() * 0.62)), 60, 120)
		var lb := Art.label(sg, brand, fs, Color.WHITE, Vector3(0, 0.07, 0.05), 0.0, "display", 10, col.darkened(0.45))
		var sub := Art.label(sg, (t["name"] as String).to_upper(), 40, acc, Vector3(0, -0.25, 0.05), 0.0, "display700")
		glow_labels.append([lb, Color.WHITE]); glow_labels.append([sub, acc])
	else:
		Art.box(sg, Vector3(sw, 0.86, 0.06), Art.mat(Cfg.TEAL, 0.5), Vector3.ZERO, 0.06)
		Art.box(sg, Vector3(sw - 0.12, 0.74, 0.04), Art.mat(Cfg.CREAM, 0.6), Vector3(0, 0, 0.02), 0.05)
		Art.label(sg, "KİRALIK", 110, Cfg.TERRA, Vector3(0, 0.07, 0.05), 0.0, "display", 8, Cfg.TERRA_DARK)
		Art.label(sg, "AVM PANELİ · V", 36, Cfg.TEAL_DARK, Vector3(0, -0.26, 0.05), 0.0, "display700")

# ------------------------------------------------------------------ furnishing (merged vertex-colour kit)
func _pb(xf: Transform3D, size: Vector3, col: Color, pos: Vector3, rot_y := 0.0, r := 0.02) -> void:
	_parts.append([Art.rbox_mesh(size, maxf(r, 0.004)), xf * Transform3D(Basis(Vector3.UP, rot_y), pos), col])

func _pm(xf: Transform3D, mesh: Mesh, col: Color, pos: Vector3, basis := Basis()) -> void:
	_parts.append([mesh, xf * Transform3D(basis, pos), col])

func _flush(parent: Node3D) -> void:
	if _parts.is_empty(): return
	var mi := MeshInstance3D.new()
	mi.mesh = Art.merge(_parts)
	mi.material_override = Art.vcol_mat(0.6)
	parent.add_child(mi)
	_parts = []

func _clerk(g: Node3D, p: Vector3, face: float, top: Color) -> void:
	var c := CharacterView.new()
	g.add_child(c)
	var look := Customer.random_look(null)
	look["top"] = top; look["accent"] = top.lightened(0.3)
	c.setup(look)
	c.position = p
	c.rotation.y = face
	c.set_meta("t", randf() * 6.0)
	clerks.append(c)

func _screen(parent: Node3D, size: Vector2, col: Color, pos: Vector3, rot_y: float, energy := 1.6) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col.darkened(0.3); m.emission_enabled = true; m.emission = col; m.emission_energy_multiplier = energy
	var mi := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = size; mi.mesh = q
	mi.material_override = m; mi.position = pos; mi.rotation.y = rot_y
	parent.add_child(mi)
	screens.append(m)
	return mi

func _furnish(g: Node3D, u: Dictionary, t: Dictionary, y0: float) -> void:
	var d: Dictionary = u["def"]
	var r: Rect2i = d["rect"]
	var dir: Vector2i = d["dir"]
	var along_x := dir.x == 0
	var span := float(r.size.x if along_x else r.size.y)
	var band := float(Mall.furniture_band(u))
	var col: Color = t["color"]
	var acc: Color = t["accent"]
	var face := atan2(float(dir.x), float(dir.y))
	# frame: origin at the back wall on the first span tile edge; local +z = toward the door, +x = along span
	var back := Vector3(Cfg.rc(r).x, y0 + 0.05, Cfg.rc(r).y) - Vector3(dir.x, 0, dir.y) * ((r.size.x if dir.x != 0 else r.size.y) * 0.5)
	var ax := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	var origin := back - ax * span * 0.5
	var zv := Vector3(dir.x, 0, dir.y)
	var basis := Basis(ax, Vector3.UP, zv)
	if basis.determinant() < 0.0: basis = Basis(-ax, Vector3.UP, zv); origin = back + ax * span * 0.5
	var xf := Transform3D(basis, origin)
	var P := func(a: float, depth: float, h: float) -> Vector3: return xf * Vector3(a, h, depth)
	var ink := Color("27303f")
	var steel := Color("c3cad2")
	var rnd := RandomNumberGenerator.new(); rnd.seed = int(u["idx"]) * 31 + 7
	match t["id"]:
		"giyim", "spor":
			var shirts: Array = [Color("e0663c"), Color("f2b33d"), Color("1f8a86"), Color("f6efe3"), Color("6c4ab6"), Color("2f6fb5")] if t["id"] == "giyim" else [Color("d6333a"), Color("1f2a44"), Color("ffffff"), Color("2fae7a"), Color("f2b33d")]
			# wall rails with hanging clothes along the back wall
			var n := int((span - 0.6) / 1.6)
			for i in n:
				var a := 0.5 + (i + 0.5) * (span - 1.0) / n
				_pb(xf, Vector3(1.4, 0.04, 0.04), steel, Vector3(a, 1.55, 0.3))
				for k in 7:
					var sc: Color = shirts[(k + i) % shirts.size()]
					_pb(xf, Vector3(0.05, 0.62, 0.4), sc, Vector3(a - 0.6 + k * 0.2, 1.2, 0.32), rnd.randf_range(-0.08, 0.08))
				_pb(xf, Vector3(1.4, 0.03, 0.34), col.lightened(0.2), Vector3(a, 0.35, 0.25))
				for k in 4: _pb(xf, Vector3(0.28, 0.08, 0.26), shirts[(k + i + 2) % shirts.size()], Vector3(a - 0.5 + k * 0.33, 0.41, 0.25))
			if band >= 2.0:
				# folding table + mannequins in the second band row
				_pb(xf, Vector3(1.3, 0.72, 0.7), Cfg.WOOD, Vector3(span * 0.5, 0.36, 1.35), 0.0, 0.03)
				for k in 6: _pb(xf, Vector3(0.3, 0.06, 0.26), shirts[k % shirts.size()], Vector3(span * 0.5 - 0.4 + (k % 3) * 0.4, 0.75 + (k / 3) * 0.06, 1.2 + (k / 3) * 0.28))
				for mi in [0.9, span - 0.9]:
					_pm(xf, Art.prim("cyl", 0.02, 0.02, 0.8), steel, Vector3(mi, 0.4, 1.4))
					_pm(xf, Art.prim("box", 0.42, 0.55, 0.26), col, Vector3(mi, 1.1, 1.4))
					_pm(xf, Art.prim("sph", 0.13), Color("f6efe3"), Vector3(mi, 1.55, 1.4))
				_clerk(g, P.call(span * 0.5 + 1.2, 1.55, 0.0), face, col)
			else:
				_pb(xf, Vector3(0.9, 0.95, 0.5), col.darkened(0.2), Vector3(span - 0.7, 0.48, 0.55), 0.0, 0.03)
				_clerk(g, P.call(span - 1.5, 0.7, 0.0), face, col)
		"elektronik":
			var tvs := int((span - 0.8) / 1.3)
			for k in tvs:
				var a := 0.6 + (k + 0.5) * (span - 1.2) / tvs
				_pb(xf, Vector3(1.15, 0.7, 0.06), Color("15171c"), Vector3(a, 1.95, 0.08), 0.0, 0.02)
				_screen(g, Vector2(1.05, 0.6), [Color("2f6fb5"), Color("6c4ab6"), Color("1f8a86"), Color("e0663c")][k % 4], P.call(a, 0.115, 1.95), face)
			var tables := maxi(1, int(span / 2.6))
			for i in tables:
				var a := (i + 0.5) * span / tables
				_pb(xf, Vector3(1.6, 0.9, 0.7), Color("f4f4f2"), Vector3(a, 0.45, band - 0.5), 0.0, 0.04)
				_pb(xf, Vector3(1.64, 0.04, 0.74), acc, Vector3(a, 0.9, band - 0.5), 0.0, 0.01)
				for k in 3:
					_pb(xf, Vector3(0.34, 0.02, 0.24), steel, Vector3(a - 0.5 + k * 0.5, 0.93, band - 0.45))
					var scr := Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(a - 0.5 + k * 0.5, 1.04, band - 0.58))
					_parts.append([Art.rbox_mesh(Vector3(0.34, 0.22, 0.015), 0.004), xf * scr, Color("1b1f2a")])
					_screen(g, Vector2(0.3, 0.18), [Color("61d4ff"), Color("7fe3c8"), Color("f2b33d")][k], xf * Vector3(a - 0.5 + k * 0.5, 1.045, band - 0.57), face, 1.0)
			_clerk(g, P.call(span - 0.5, 0.45 if band < 2.0 else 1.4, 0.0), face, col)
		"kitap":
			var books := [Color("e0663c"), Color("1f8a86"), Color("f2b33d"), Color("6c4ab6"), Color("2f6fb5"), Color("d6333a"), Color("f6efe3"), Color("3f8f3a")]
			_pb(xf, Vector3(span - 0.4, 2.4, 0.42), Cfg.WOOD_DARK, Vector3(span * 0.5, 1.2, 0.22), 0.0, 0.02)
			for row in 5:
				var yy := 0.25 + row * 0.44
				_pb(xf, Vector3(span - 0.5, 0.03, 0.36), Cfg.WOOD, Vector3(span * 0.5, yy, 0.26))
				var x := 0.35
				while x < span - 0.45:
					var bw := rnd.randf_range(0.05, 0.1)
					var bh := rnd.randf_range(0.24, 0.34)
					_pb(xf, Vector3(bw - 0.008, bh, 0.26), books[rnd.randi() % books.size()], Vector3(x + bw * 0.5, yy + 0.015 + bh * 0.5, 0.3), 0.0, 0.004)
					x += bw
			if band >= 2.0:
				_pb(xf, Vector3(1.4, 0.8, 0.8), Cfg.WOOD, Vector3(span * 0.5, 0.4, 1.3), 0.0, 0.03)
				for k in 5: _pb(xf, Vector3(0.22, 0.05, 0.3), books[k], Vector3(span * 0.5 - 0.5 + k * 0.25, 0.83 + (k % 2) * 0.05, 1.3), rnd.randf())
			_pm(xf, Art.prim("cyl", 0.25, 0.22, 0.5), Cfg.TERRA_DARK, Vector3(0.45, 0.25, band - 0.4))
			_pm(xf, Art.prim("sph", 0.32), Color("4f9a57"), Vector3(0.45, 0.72, band - 0.4))
			_clerk(g, P.call(span - 0.6, band - 0.45, 0.0), face, col)
		"oyuncak":
			var blocks := [Color("e5484d"), Color("f2b33d"), Color("2fae7a"), Color("61b3ff"), Color("6c4ab6")]
			_pb(xf, Vector3(span - 0.4, 0.05, 0.45), Cfg.WOOD, Vector3(span * 0.5, 1.1, 0.25))
			_pb(xf, Vector3(span - 0.4, 0.05, 0.45), Cfg.WOOD, Vector3(span * 0.5, 1.7, 0.25))
			var x := 0.4
			var k := 0
			while x < span - 0.5:
				for yy in [0.2, 1.28, 1.88]:
					_pb(xf, Vector3(0.3, 0.3, 0.3), blocks[(k + int(yy * 3)) % 5], Vector3(x, yy, 0.25), rnd.randf_range(-0.2, 0.2), 0.05)
				x += 0.42; k += 1
			var bear := Vector3(span - 0.7, 0.0, band - 0.5)
			var fur := Color("b07a4a")
			_pm(xf, Art.prim("sph", 0.36), fur, bear + Vector3(0, 0.4, 0))
			_pm(xf, Art.prim("sph", 0.24), fur, bear + Vector3(0, 0.9, 0))
			for sd in [-1.0, 1.0]:
				_pm(xf, Art.prim("sph", 0.08), fur, bear + Vector3(sd * 0.17, 1.1, 0))
				_pm(xf, Art.prim("sph", 0.11), fur, bear + Vector3(sd * 0.34, 0.45, 0.12))
			_pm(xf, Art.prim("sph", 0.08), Color("e9cfa8"), bear + Vector3(0, 0.86, 0.2))
			_pb(xf, Vector3(0.26, 0.08, 0.05), Cfg.BAD, bear + Vector3(0, 0.7, 0.19))
			for b in 3:
				_pm(xf, Art.prim("sph", 0.17), blocks[b], Vector3(0.9 + b * 0.35, 2.3 + b * 0.15, band - 0.5))
				_pm(xf, Art.prim("cyl", 0.004, 0.004, 1.6), Color.WHITE, Vector3(0.9 + b * 0.35, 1.4 + b * 0.07, band - 0.5))
			_clerk(g, P.call(1.1, band - 0.45, 0.0), face, col)
		"kuafor":
			var n := maxi(1, int(span / 2.2))
			for i in n:
				var a := (i + 0.5) * span / n
				_pb(xf, Vector3(0.95, 1.25, 0.04), acc, Vector3(a, 1.55, 0.06), 0.0, 0.03)
				_pb(xf, Vector3(0.82, 1.1, 0.02), Color("cfe2ea"), Vector3(a, 1.55, 0.09), 0.0, 0.01)
				_pb(xf, Vector3(0.9, 0.06, 0.28), Color("f4f1ea"), Vector3(a, 0.95, 0.18))
				_pm(xf, Art.prim("cyl", 0.2, 0.25, 0.08), steel, Vector3(a, 0.04, 0.62))
				_pm(xf, Art.prim("cyl", 0.05, 0.05, 0.42), steel, Vector3(a, 0.28, 0.62))
				_pb(xf, Vector3(0.55, 0.14, 0.5), Color("1b1d22"), Vector3(a, 0.52, 0.62), 0.0, 0.05)
				_pb(xf, Vector3(0.55, 0.6, 0.12), Color("1b1d22"), Vector3(a, 0.88, 0.84), 0.0, 0.05)
			_clerk(g, P.call(span * 0.5 / n + 0.55, 0.6, 0.0), face, col)
		"oyun":
			var n := maxi(2, int((span - 0.4) / 1.1))
			for i in n:
				var a := 0.2 + (i + 0.5) * (span - 0.4) / n
				var cc: Color = [Color("6c4ab6"), Color("e0663c"), Color("1f8a86")][i % 3]
				_pb(xf, Vector3(0.8, 1.8, 0.7), cc, Vector3(a, 0.9, 0.4), 0.0, 0.05)
				_pb(xf, Vector3(0.7, 0.08, 0.3), Color("1b1d22"), Vector3(a, 0.98, 0.82), 0.0, 0.03)
				_screen(g, Vector2(0.6, 0.45), [Color("7fe3c8"), Color("ff5fa2"), Color("f2b33d")][i % 3], P.call(a, 0.76, 1.35), face, 2.2)
				_screen(g, Vector2(0.7, 0.18), Color.WHITE, P.call(a, 0.76, 1.7), face, 1.2)
			if band >= 2.0:
				_pb(xf, Vector3(0.9, 0.8, 0.9), Cfg.BAD, Vector3(span - 0.8, 0.4, 1.4), 0.0, 0.04)
				Art.box(g, Vector3(0.86, 0.9, 0.86), Art.glass(Color(0.85, 0.95, 1.0), 0.2), P.call(span - 0.8, 1.4, 1.25), 0.0, face)
				for k in 8:
					_pm(xf, Art.prim("sph", 0.1), [Color("f2b33d"), Color("61b3ff"), Color("2fae7a"), Color("f08f86")][k % 4], Vector3(span - 0.8 + (k % 3 - 1) * 0.22, 0.9, 1.4 + (k / 3 - 1) * 0.22))
			_clerk(g, P.call(span - 0.4, band - 0.45, 0.0) if band < 2.0 else P.call(0.6, 1.5, 0.0), face, col)
		"sinema":
			# back wall: two hall doors under a glowing marquee, film posters; ticket + popcorn counter in front
			var posters := [Color("d6333a"), Color("2f6fb5"), Color("6c4ab6"), Color("1f8a86")]
			_pb(xf, Vector3(span - 0.3, 2.9, 0.1), Color("141a2e"), Vector3(span * 0.5, 1.45, 0.06), 0.0, 0.01)
			for dd in [span * 0.28, span * 0.72]:
				_pb(xf, Vector3(1.1, 2.1, 0.06), Color("5a1f28"), Vector3(dd, 1.05, 0.13), 0.0, 0.02)
				_pb(xf, Vector3(0.05, 0.3, 0.05), Cfg.MUSTARD, Vector3(dd - 0.12, 1.05, 0.18))
				_pb(xf, Vector3(0.05, 0.3, 0.05), Cfg.MUSTARD, Vector3(dd + 0.12, 1.05, 0.18))
				_screen(g, Vector2(1.2, 0.32), Cfg.MUSTARD, P.call(dd, 0.17, 2.4), face, 2.4)
			for k in 4:
				var px := 0.5 + k * (span - 1.0) / 3.0
				if absf(px - span * 0.28) < 0.8 or absf(px - span * 0.72) < 0.8: continue
				_pb(xf, Vector3(0.62, 0.9, 0.04), Color("f6efe3"), Vector3(px, 1.55, 0.13), 0.0, 0.01)
				_pb(xf, Vector3(0.56, 0.84, 0.03), posters[k % 4], Vector3(px, 1.55, 0.15), 0.0, 0.01)
			# counter
			_pb(xf, Vector3(minf(3.4, span - 1.5), 1.0, 0.6), Color("1f2a44"), Vector3(span * 0.5, 0.5, band - 0.4), 0.0, 0.03)
			_pb(xf, Vector3(minf(3.4, span - 1.5) + 0.1, 0.06, 0.68), Cfg.MUSTARD, Vector3(span * 0.5, 1.03, band - 0.4), 0.0, 0.02)
			var pop := Vector3(span * 0.5 - 1.1, 1.06, band - 0.45)
			_pb(xf, Vector3(0.55, 0.7, 0.45), Color("d6333a"), pop + Vector3(0, 0.35, 0), 0.0, 0.03)
			Art.box(g, Vector3(0.45, 0.45, 0.38), Art.glass(Color(1, 0.95, 0.8), 0.35), P.call(pop.x, pop.z, pop.y + 0.4), 0.0, face)
			for k in 10: _pm(xf, Art.prim("sph", 0.05), Color("fff3c4"), pop + Vector3(randf_range(-0.16, 0.16), 0.25 + randf() * 0.15, randf_range(-0.12, 0.12)))
			var mb2 := Node3D.new(); mb2.position = P.call(span * 0.5, 0.2, 3.05); mb2.rotation.y = face; g.add_child(mb2)
			var l0 := Art.label(mb2, "VİZYONDA", 60, Cfg.MUSTARD, Vector3.ZERO, 0.0, "display", 8, Color("141a2e"))
			glow_labels.append([l0, Cfg.MUSTARD])
			_clerk(g, P.call(span * 0.5 + 0.6, band - 0.95, 0.0), face, col)
		"kafe", "burger", "pide":
			var cw := span - 1.4
			var cz := band - 0.3
			var top_col: Color = Color("5b3a24") if t["id"] == "kafe" else Color("f6efe3")
			_pb(xf, Vector3(cw, 1.0, 0.55), top_col, Vector3(span * 0.5, 0.5, cz), 0.0, 0.03)
			_pb(xf, Vector3(cw + 0.1, 0.06, 0.62), col, Vector3(span * 0.5, 1.03, cz), 0.0, 0.02)
			_pb(xf, Vector3(cw, 0.12, 0.04), acc, Vector3(span * 0.5, 0.8, cz + 0.28))
			var mx := span * 0.5 - cw * 0.5 + 0.5
			match t["id"]:
				"kafe":
					_pb(xf, Vector3(0.6, 0.45, 0.4), steel, Vector3(mx, 1.28, cz - 0.05), 0.0, 0.04)
					for k in 4: _pm(xf, Art.prim("cyl", 0.045, 0.035, 0.1), Color.WHITE, Vector3(mx + 0.7 + k * 0.2, 1.11, cz + 0.12))
					_pm(xf, Art.prim("cyl", 0.16, 0.16, 0.3), Color("f4e1c1"), Vector3(mx + 1.8, 1.2, cz))
				"burger":
					_pb(xf, Vector3(0.7, 0.3, 0.45), steel, Vector3(mx, 1.2, cz - 0.05), 0.0, 0.03)
					for k in 3:
						var bp := Vector3(mx + 0.7 + k * 0.35, 1.1, cz + 0.12)
						_pm(xf, Art.prim("cyl", 0.1, 0.1, 0.05), Color("d99a55"), bp)
						_pm(xf, Art.prim("cyl", 0.105, 0.105, 0.03), Color("6b3b2a"), bp + Vector3(0, 0.04, 0))
						_pm(xf, Art.prim("sph", 0.1), Color("d99a55"), bp + Vector3(0, 0.07, 0), Basis().scaled(Vector3(1, 0.5, 1)))
				"pide":
					_pm(xf, Art.prim("sph", 0.5), Color("b44a28"), Vector3(mx + 0.1, 1.06, cz - 0.05), Basis().scaled(Vector3(1, 0.75, 0.55)))
					_screen(g, Vector2(0.3, 0.16), Color("ff7a2a"), P.call(mx + 0.1, cz + 0.24, 1.15), face, 2.5)
					for k in 3: _pb(xf, Vector3(0.45, 0.05, 0.14), Color("e0a860"), Vector3(mx + 0.9 + k * 0.5, 1.1, cz + 0.12), 0.2)
			# menu board on the back wall
			var mb := Node3D.new(); mb.position = P.call(span * 0.5, 0.06, 2.35); mb.rotation.y = face; g.add_child(mb)
			Art.box(mb, Vector3(2.4, 0.95, 0.05), Art.mat(Cfg.INK, 0.5), Vector3.ZERO, 0.05)
			var lb := Art.label(mb, t["brand"], 70, acc, Vector3(0, 0.28, 0.04), 0.0, "display")
			glow_labels.append([lb, acc])
			var items: Array = {"kafe": ["Türk Kahvesi  ₺45", "Latte  ₺70", "Cheesecake  ₺90"], "burger": ["Klasik  ₺140", "Tombul Menü  ₺195", "Patates  ₺60"], "pide": ["Kıymalı  ₺120", "Kaşarlı  ₺110", "Ayran  ₺25"]}[t["id"]]
			for i in items.size():
				Art.label(mb, items[i], 30, Color(1, 1, 1, 0.92), Vector3(0, 0.02 - i * 0.14, 0.04), 0.0, "body")
			_clerk(g, P.call(span * 0.5 - 0.8, band - 0.8, 0.0), face, col)
			if span > 6.0: _clerk(g, P.call(span * 0.5 + 1.0, band - 0.8, 0.0), face, col)
	_flush(g)

# ------------------------------------------------------------------ events
func set_event(id: String) -> void:
	for c in decorations.get_children() + decorations1.get_children(): c.queue_free()
	band.visible = id == "konser"
	if id == "": return
	var cols := [Color("e0663c"), Color("f2b33d"), Color("1f8a86"), Color("6c4ab6"), Color("d6333a"), Color("61b3ff")]
	var by_floor := [[], []]
	var parts: Array
	# bunting over the corridors: [floor, z, x0, x1]
	for b in [[0, 3.5, 6.5, 37.5], [1, 6.0, 3.0, 41.0], [1, 12.5, 8.5, 35.5]]:
		var y: float = b[0] * FH + 3.5
		parts = by_floor[b[0]]
		var n := int((b[3] - b[2]) / 0.5)
		for i in n:
			var x: float = b[2] + i * 0.5
			var sag := sin(float(i) / n * PI) * 0.45
			var xfm := Transform3D(Basis(Vector3.RIGHT, PI) * Basis(Vector3.UP, PI / 6), Vector3(x, y - sag - 0.17, b[1]))
			parts.append([Art.prim("prism", 0.3, 0.34, 0.02), xfm, cols[i % cols.size()]])
		for i in n - 1:
			var xa: float = b[2] + i * 0.5
			var s1 := sin(float(i) / n * PI) * 0.45
			var s2 := sin(float(i + 1) / n * PI) * 0.45
			var mid := Vector3(xa + 0.25, y - (s1 + s2) * 0.5, b[1])
			var tilt := atan2(s1 - s2, 0.5)
			parts.append([Art.rbox_mesh(Vector3(0.5, 0.012, 0.012), 0.004), Transform3D(Basis(Vector3.BACK, tilt), mid), Color.WHITE])
	if id == "cocuk" or id == "bayram":
		# balloon bunches tied to the well rail, the stage and the lift shaft (never on walkable floor)
		parts = by_floor[1]
		var anchors := [Vector3(12.1, FH + 1.05, 1.1), Vector3(12.1, FH + 1.05, 2.9), Vector3(17.5, FH + 1.05, 3.05), Vector3(20.3, FH + 0.45, 14.2), Vector3(23.7, FH + 0.45, 14.2)]
		for k in anchors.size():
			var a: Vector3 = anchors[k]
			for bb in 4:
				var off := Vector3((bb % 2) * 0.28 - 0.14, 0.9 + bb * 0.16, (bb / 2) * 0.28 - 0.14)
				parts.append([Art.prim("sph", 0.2), Transform3D(Basis().scaled(Vector3(1, 1.18, 1)), a + off), cols[(k + bb) % cols.size()]])
				parts.append([Art.prim("cyl", 0.004, 0.004, off.y), Transform3D(Basis(), a + Vector3(off.x * 0.5, off.y * 0.5, off.z * 0.5)), Color.WHITE])
	for fl in 2:
		var mi := MeshInstance3D.new(); mi.mesh = Art.merge(by_floor[fl]); mi.material_override = Art.vcol_mat(0.45)
		(decorations1 if fl == 1 else decorations).add_child(mi)
	if id == "bayram" or id == "imza":
		var txt := "BAYRAM İNDİRİMLERİ" if id == "bayram" else "İMZA GÜNÜ · SAYFA"
		for b in [[Vector3(22, 3.0, 0.1), decorations], [Vector3(15, FH + 2.6, 0.1), decorations1]]:
			var ban := Node3D.new(); ban.position = b[0]; (b[1] as Node3D).add_child(ban)
			Art.box(ban, Vector3(4.6, 0.9, 0.05), Art.mat(Color("d6333a"), 0.6), Vector3.ZERO, 0.05)
			Art.box(ban, Vector3(4.4, 0.05, 0.06), Art.mat(Cfg.MUSTARD, 0.5), Vector3(0, -0.36, 0.01), 0.01)
			Art.label(ban, txt, 76, Color.WHITE, Vector3(0, 0.04, 0.04), 0.0, "display", 8, Color("8f1f25"))

# ------------------------------------------------------------------ lift
func lift_to(from_lvl: int, to_lvl: int) -> void:
	lift_from = from_lvl * FH
	lift_to_y = to_lvl * FH
	lift_t = 0.0

# ------------------------------------------------------------------ per frame
func update(dt: float, view_dt: float, cam_dir: Vector3, view_floor: int, far: float, cutaway: bool, night: float, agent_pos: Array) -> void:
	_t += dt
	f1.visible = far > 0.5 or view_floor >= 1
	exterior.visible = far > 0.55 or not cutaway
	var flat := Vector3(cam_dir.x, 0, cam_dir.z).normalized()
	for s in sides:
		var dp := flat.dot(s["normal"])
		var faces := false
		match s["mode"]:
			"front": faces = -dp > 0.2
			"back": faces = dp > 0.35
			_: faces = absf(dp) > 0.35
		var target := 0.0
		if cutaway and faces and far < 0.5 and s["floor"] == view_floor: target = 1.0
		s["sink"] = clampf(s["sink"] + (target - s["sink"]) * minf(1.0, dt * 6.0), 0.0, 1.0)
		var n: Node3D = s["node"]
		n.scale.y = lerpf(1.0, 0.4 / s["h"], s["sink"])
		for e in s["extras"]: (e as Node3D).visible = s["sink"] < 0.4
	for e in escalators:
		if not mall.connector_working(e["id"]): continue
		e["off"] += view_dt * 0.9 * e["dir"]
		(e["mat"] as ShaderMaterial).set_shader_parameter("offset", e["off"])
	# lift: wait at the boarding floor while the rider steps in, then travel
	if lift_t < 10.0:
		lift_t += view_dt
		var k := smoothstep(0.6, 3.4, lift_t)
		lift_y = lerpf(lift_from, lift_to_y, k) if lift_t > 0.0 else lift_y
	lift_cab.position.y = lift_y
	for c in mall.connectors:
		var b = barriers.get(c["def"]["id"])
		if b: (b as Node3D).visible = c["broken"]
	for d in doors:
		var near := false
		for p in agent_pos:
			if p.y < 1.0 and absf(p.x - d["x"]) < 1.8 and absf(p.z - 16.0) < 1.6: near = true; break
		d["open"] = clampf(d["open"] + ((1.0 if near else 0.0) - d["open"]) * minf(1.0, dt * 6.0), 0.0, 1.0)
		d["left"].position.x = d["x"] - 0.5 - d["open"] * 0.48
		d["right"].position.x = d["x"] + 0.5 + d["open"] * 0.48
	var boost := 1.0 + night * 1.6
	for gl in glow_labels:
		if is_instance_valid(gl[0]):
			var c: Color = gl[1]
			(gl[0] as Label3D).modulate = Color(c.r * boost, c.g * boost, c.b * boost, c.a)
	for i in screens.size():
		var m: StandardMaterial3D = screens[i]
		m.emission_energy_multiplier = 1.4 + sin(_t * 3.0 + i * 1.7) * 0.5
	for l in lamps: (l as OmniLight3D).light_energy = lerpf(0.55, 1.2, night)
	for c in clerks:
		if not is_instance_valid(c): continue
		var tt: float = c.get_meta("t") - dt
		if tt <= 0.0:
			tt = randf_range(3.0, 8.0)
			(c as CharacterView).play("work" if randf() < 0.4 else "idle")
		c.set_meta("t", tt)
	if band.visible:
		var ph := fmod(_t, 6.0)
		performer.play("happy" if ph < 3.5 else "pay")
