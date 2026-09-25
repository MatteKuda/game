class_name Art
## Shared look: materials, fonts, rounded-box meshes and helpers.
## The whole world goes through here so palette, softness and outlines stay consistent.

static var _mats := {}
static var _meshes := {}
static var _shaders := {}
static var _fonts := {}
static var outline_mat: StandardMaterial3D
static var _styled := {}

# ------------------------------------------------------------------ fonts
static func font(kind := "display") -> Font:
	# display = Fredoka (rounded, chunky game lettering); body = Nunito
	match kind:
		"display": return _ff("fredoka", 700)
		"display700": return _ff("fredoka", 600)
		_: return _ff("nunito", 700)

static func body_font(weight := 700) -> Font:
	var w := 600 if weight < 650 else (700 if weight < 750 else (800 if weight < 850 else 900))
	return _ff("nunito", w)

static func _ff(fam: String, w: int) -> Font:
	var key := "%s%d" % [fam, w]
	if _fonts.has(key): return _fonts[key]
	var f: FontFile = load("res://assets/fonts/%s-latin-%d-normal.woff2" % [fam, w])
	f.fallbacks = [load("res://assets/fonts/%s-latin-ext-%d-normal.woff2" % [fam, w])]
	_fonts[key] = f
	return f

# ------------------------------------------------------------------ materials
static func mat(c: Color, rough := 0.75, metal := 0.0, emissive := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [c.to_html(), rough, metal, emissive]
	if _mats.has(key): return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emissive
	_mats[key] = m
	return m

static func glass(tint := Color(0.75, 0.9, 1.0), alpha := 0.22) -> StandardMaterial3D:
	var key := "glass%s%.2f" % [tint.to_html(), alpha]
	if _mats.has(key): return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(tint, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic_specular = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m

static func unshaded(c: Color, alpha := 1.0, on_top := false) -> StandardMaterial3D:
	var key := "un%s%.2f%s" % [c.to_html(), alpha, on_top]
	if _mats.has(key): return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c, alpha)
	if alpha < 1.0: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = on_top
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m

static func shader_mat(name: String, params := {}) -> ShaderMaterial:
	var key := name + str(params)
	if _mats.has(key): return _mats[key]
	if not _shaders.has(name): _shaders[name] = load("res://shaders/%s.gdshader" % name)
	var m := ShaderMaterial.new()
	m.shader = _shaders[name]
	for k in params: m.set_shader_parameter(k, params[k])
	_mats[key] = m
	return m

static func outline() -> StandardMaterial3D:
	if outline_mat: return outline_mat
	outline_mat = StandardMaterial3D.new()
	outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_mat.albedo_color = Color("2a2233")
	outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	outline_mat.grow = true
	outline_mat.grow_amount = 0.012
	return outline_mat

## Make imported models match our lighting: softer wrap diffuse, less plastic shine, ink outline.
static func stylize(root: Node, with_outline := true, tint := Color.WHITE) -> void:
	for n in _all(root):
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var cnt := mi.mesh.get_surface_count() if mi.mesh else 0
			if mi.material_override != null: continue # our own primitives already use the house materials
			for s in cnt:
				var src := mi.get_active_material(s)
				if src is StandardMaterial3D:
					# styled copies are cached per source material: freeing per-model copies makes the
					# renderer complain about dangling materials whenever a model is removed
					var key := "%d|%s|%s" % [src.get_instance_id(), tint.to_html(), with_outline]
					var m: StandardMaterial3D = _styled.get(key)
					if m == null:
						m = src.duplicate()
						m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
						m.roughness = maxf(m.roughness, 0.6)
						m.metallic = minf(m.metallic, 0.2)
						if tint != Color.WHITE: m.albedo_color = m.albedo_color * tint
						if with_outline: m.next_pass = outline()
						_styled[key] = m
					mi.set_surface_override_material(s, m)

static func _all(n: Node) -> Array:
	var out := [n]
	for c in n.get_children(): out.append_array(_all(c))
	return out

# ------------------------------------------------------------------ meshes
## Rounded box (RoundedBoxGeometry-style): every face is a grid bent around the edges.
static func rbox_mesh(size: Vector3, r := 0.04, seg := 2) -> ArrayMesh:
	var key := "%s|%.3f|%d" % [size, r, seg]
	if _meshes.has(key): return _meshes[key]
	r = minf(r, minf(size.x, minf(size.y, size.z)) * 0.5 - 0.001)
	var he := size * 0.5
	var inner := he - Vector3(r, r, r)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ts := []
	for i in seg + 1: ts.append(-1.0 + (1.0 - cos(PI * 0.5 * i / seg)))
	# face axes: normal, u, v
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)], [Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)], [Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)], [Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	]
	for f in faces:
		var nrm: Vector3 = f[0]
		var U: Vector3 = f[1]
		var V: Vector3 = f[2]
		var cu := _coords(ts, absf((U * he).length()), r)
		var cv := _coords(ts, absf((V * he).length()), r)
		var hn := absf((nrm * he).length())
		var grid := []
		for j in cv.size():
			var row := []
			for i in cu.size():
				var p: Vector3 = nrm * hn + U * float(cu[i]) + V * float(cv[j])
				var c := Vector3(clampf(p.x, -inner.x, inner.x), clampf(p.y, -inner.y, inner.y), clampf(p.z, -inner.z, inner.z))
				var d := p - c
				var n := nrm if d.length() < 1e-5 else d.normalized()
				var q := c + n * r
				row.append([q, n, Vector2(float(i) / (cu.size() - 1), 1.0 - float(j) / (cv.size() - 1))])
			grid.append(row)
		for j in cv.size() - 1:
			for i in cu.size() - 1:
				var a: Array = grid[j][i]
				var b: Array = grid[j][i + 1]
				var c2: Array = grid[j + 1][i + 1]
				var d2: Array = grid[j + 1][i]
				for v in [a, c2, b, a, d2, c2]:
					st.set_normal(v[1]); st.set_uv(v[2]); st.add_vertex(v[0])
	var m := st.commit()
	_meshes[key] = m
	return m

static func _coords(ts: Array, h: float, r: float) -> Array:
	var out := []
	for t in ts: out.append(-h + r * (1.0 + float(t)))
	out.append_array([])
	for i in range(ts.size() - 1, -1, -1): out.append(h - r * (1.0 + float(ts[i])))
	# de-duplicate the two middle points when the face has no flat part
	var res := []
	for v in out:
		if res.is_empty() or absf(float(v) - float(res[-1])) > 1e-5: res.append(v)
	return res

static func box(parent: Node3D, size: Vector3, m: Material, pos := Vector3.ZERO, r := 0.03, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = rbox_mesh(size, r) if r > 0.0 else _plain_box(size)
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi

static func _plain_box(size: Vector3) -> BoxMesh:
	var key := "plain%s" % size
	if _meshes.has(key): return _meshes[key]
	var b := BoxMesh.new(); b.size = size
	_meshes[key] = b
	return b

static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, m: Material, pos := Vector3.ZERO, seg := 20) -> MeshInstance3D:
	var key := "cyl%.3f|%.3f|%.3f|%d" % [r_top, r_bot, h, seg]
	if not _meshes.has(key):
		var c := CylinderMesh.new(); c.top_radius = r_top; c.bottom_radius = r_bot; c.height = h; c.radial_segments = seg; c.rings = 1
		_meshes[key] = c
	var mi := MeshInstance3D.new(); mi.mesh = _meshes[key]; mi.material_override = m; mi.position = pos
	parent.add_child(mi)
	return mi

static func sphere(parent: Node3D, r: float, m: Material, pos := Vector3.ZERO, squash := 1.0) -> MeshInstance3D:
	var key := "sph%.3f" % r
	if not _meshes.has(key):
		var s := SphereMesh.new(); s.radius = r; s.height = r * 2.0; s.radial_segments = 18; s.rings = 10
		_meshes[key] = s
	var mi := MeshInstance3D.new(); mi.mesh = _meshes[key]; mi.material_override = m; mi.position = pos
	mi.scale = Vector3(1, squash, 1)
	parent.add_child(mi)
	return mi

static func torus(parent: Node3D, inner: float, outer: float, m: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var key := "tor%.3f|%.3f" % [inner, outer]
	if not _meshes.has(key):
		var t := TorusMesh.new(); t.inner_radius = inner; t.outer_radius = outer; t.rings = 18; t.ring_segments = 10
		_meshes[key] = t
	var mi := MeshInstance3D.new(); mi.mesh = _meshes[key]; mi.material_override = m; mi.position = pos
	parent.add_child(mi)
	return mi

static func quad(parent: Node3D, size: Vector2, m: Material, pos := Vector3.ZERO, face_up := false) -> MeshInstance3D:
	var key := "quad%s" % size
	if not _meshes.has(key):
		var q := QuadMesh.new(); q.size = size
		_meshes[key] = q
	var mi := MeshInstance3D.new(); mi.mesh = _meshes[key]; mi.material_override = m; mi.position = pos
	if face_up: mi.rotation.x = -PI / 2
	parent.add_child(mi)
	return mi

## Sign / label text rendered as geometry-free Label3D using our display font.
static func label(parent: Node3D, text: String, size_px: int, col: Color, pos := Vector3.ZERO, width := 0.0, kind := "display", outline_px := 0, outline_col := Color.BLACK) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font(kind)
	l.font_size = size_px
	l.pixel_size = 0.004
	l.modulate = col
	l.outline_size = outline_px
	l.outline_modulate = outline_col
	l.position = pos
	l.shaded = false
	l.double_sided = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = width / l.pixel_size
	parent.add_child(l)
	return l

static func model(path: String) -> Node3D:
	var ps: PackedScene = load(path)
	return ps.instantiate()

## Merge primitive parts into one vertex-coloured mesh (cheap to instance hundreds of times).
## parts: Array of [Mesh, Transform3D, Color]
static func merge(parts: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idxs := PackedInt32Array()
	for p in parts:
		var mesh: Mesh = p[0]
		var xf: Transform3D = p[1]
		var col: Color = p[2]
		for s in mesh.get_surface_count():
			var a := mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var base := verts.size()
			var nb := xf.basis.inverse().transposed()
			for i in v.size():
				verts.append(xf * v[i])
				norms.append((nb * n[i]).normalized() if n.size() > i else Vector3.UP)
				cols.append(col)
			var ix = a[Mesh.ARRAY_INDEX]
			if ix == null or (ix as PackedInt32Array).is_empty():
				for i in v.size(): idxs.append(base + i)
			else:
				for i in (ix as PackedInt32Array): idxs.append(base + i)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idxs
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

static func vcol_mat(rough := 0.6) -> StandardMaterial3D:
	var key := "vcol%.2f" % rough
	if _mats.has(key): return _mats[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	_mats[key] = m
	return m

static func prim(kind: String, a := 1.0, b := 1.0, c := 1.0) -> Mesh:
	var key := "prim%s%.3f%.3f%.3f" % [kind, a, b, c]
	if _meshes.has(key): return _meshes[key]
	var m: Mesh
	match kind:
		"box": m = rbox_mesh(Vector3(a, b, c), minf(a, minf(b, c)) * 0.22)
		"cyl":
			var cy := CylinderMesh.new(); cy.top_radius = a; cy.bottom_radius = b; cy.height = c; cy.radial_segments = 14; cy.rings = 1; m = cy
		"sph":
			var sp := SphereMesh.new(); sp.radius = a; sp.height = a * 2.0; sp.radial_segments = 14; sp.rings = 8; m = sp
		"tor":
			var t := TorusMesh.new(); t.inner_radius = a; t.outer_radius = b; t.rings = 16; t.ring_segments = 8; m = t
		"prism":
			var pr := PrismMesh.new(); pr.size = Vector3(a, b, c); m = pr
	_meshes[key] = m
	return m
