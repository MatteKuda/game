class_name Overlays
extends Node3D
## World-space feedback: floating texts, litter, hover/selection rings, queue path,
## traffic heat map and placement tiles.

var floaters: Array = []
var hover_ring: MeshInstance3D
var select_ring: MeshInstance3D
var queue_line: Node3D
var heat: MultiMeshInstance3D
var marks: Node3D

func _ready() -> void:
	hover_ring = _ring(Color(1, 1, 1, 0.8), 0.42)
	select_ring = _ring(Cfg.MUSTARD, 0.55)
	queue_line = Node3D.new(); add_child(queue_line)
	marks = Node3D.new(); add_child(marks)
	heat = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q := PlaneMesh.new(); q.size = Vector2(0.96, 0.96)
	mm.mesh = q
	heat.multimesh = mm
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.vertex_color_use_as_albedo = true
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.no_depth_test = true
	heat.material_override = hm
	heat.visible = false
	add_child(heat)

func _ring(c: Color, r: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new(); t.inner_radius = r - 0.05; t.outer_radius = r; t.rings = 40; t.ring_segments = 6
	mi.mesh = t
	mi.material_override = Art.unshaded(c, c.a, false)
	mi.scale = Vector3(1, 0.2, 1)
	mi.visible = false
	add_child(mi)
	return mi

func float_text(pos: Vector3, text: String, col: Color, life := 1.6) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = Art.font("display")
	l.font_size = 64
	l.pixel_size = 0.004
	l.modulate = col
	l.outline_size = 14
	l.outline_modulate = Color(1, 1, 1, 0.95)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 12
	l.position = pos
	add_child(l)
	floaters.append({"node": l, "t": 0.0, "life": life, "vy": 0.7})

func litter_mesh() -> Node3D:
	var n := Node3D.new()
	var c: Color = [Color("f6b93b"), Color("d8352c"), Color("f2f0ea"), Color("2e6db4")].pick_random()
	var m := Art.box(n, Vector3(0.16, 0.05, 0.1), Art.mat(c, 0.8), Vector3(0, 0.03, 0), 0.02)
	m.rotation = Vector3(randf() * 0.4, randf() * TAU, randf() * 0.4)
	var m2 := Art.box(n, Vector3(0.09, 0.03, 0.07), Art.mat(Color("f2f0ea"), 0.8), Vector3(0.12, 0.02, 0.06), 0.015)
	m2.rotation.y = randf() * TAU
	add_child(n)
	return n

func set_queue_line(tiles: Array) -> void:
	for c in queue_line.get_children(): c.queue_free()
	for i in tiles.size():
		var t: Vector2i = tiles[i]
		var d := Art.cyl(queue_line, 0.09, 0.09, 0.02, Art.unshaded(Cfg.MUSTARD, 0.9), Vector3(t.x + 0.5, 0.06, t.y + 0.5), 12)
		if i == 0: d.scale = Vector3(1.8, 1, 1.8)

func set_marks(tiles: Array) -> void:
	# tiles: [[Vector2i, Color]]
	for c in marks.get_children(): c.queue_free()
	for e in tiles:
		var t: Vector2i = e[0]
		var c: Color = e[1]
		Art.quad(marks, Vector2(0.94, 0.94), Art.unshaded(c, c.a, true), Vector3(t.x + 0.5, 0.05, t.y + 0.5), true)

func update_heat(g: Grid) -> void:
	var cells := []
	var mx := 4.0
	for i in g.traffic.size():
		if g.region[i] == Grid.R_IN and g.traffic[i] > mx: mx = g.traffic[i]
	for i in g.traffic.size():
		if g.region[i] == Grid.R_IN and g.traffic[i] > 0.3: cells.append(i)
	var mm := heat.multimesh
	mm.instance_count = cells.size()
	for k in cells.size():
		var i: int = cells[k]
		var v := sqrt(g.traffic[i] / mx)
		mm.set_instance_transform(k, Transform3D(Basis(), Vector3(i % g.w + 0.5, 0.07, i / g.w + 0.5)))
		var c := Color("3aa6d9").lerp(Color("f2b33d"), clampf(v * 1.6, 0, 1)).lerp(Color("e5484d"), clampf(v * 2.0 - 1.0, 0, 1))
		c.a = 0.25 + v * 0.45
		mm.set_instance_color(k, c)

func _process(dt: float) -> void:
	for i in range(floaters.size() - 1, -1, -1):
		var f: Dictionary = floaters[i]
		f["t"] += dt
		var l: Label3D = f["node"]
		l.position.y += f["vy"] * dt
		f["vy"] *= 0.97
		var k: float = f["t"] / f["life"]
		l.modulate.a = 1.0 if k < 0.7 else 1.0 - (k - 0.7) / 0.3
		l.outline_modulate.a = l.modulate.a
		if f["t"] >= f["life"]:
			l.queue_free(); floaters.remove_at(i)
	var t := Time.get_ticks_msec() * 0.001
	if select_ring.visible: select_ring.rotation.y = t * 0.6
