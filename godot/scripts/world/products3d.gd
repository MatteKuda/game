class_name Products3D
## One small, readable model per product (single vertex-coloured mesh each).

static var _cache := {}

static func mesh(pid: String) -> ArrayMesh:
	if _cache.has(pid): return _cache[pid]
	var p: Dictionary = DB.product(pid)
	var c: Color = p["color"]
	var a: Color = p["accent"]
	var parts := []
	var T := func(x: float, y: float, z: float, rx := 0.0, ry := 0.0, rz := 0.0, s := Vector3.ONE) -> Transform3D:
		return Transform3D(Basis.from_euler(Vector3(rx, ry, rz)).scaled(s), Vector3(x, y, z))
	match p["shape"]:
		"bag": # puffy crisp bag with a crimped top and a label band
			parts.append([Art.prim("box", 0.16, 0.2, 0.07), T.call(0, 0.1, 0, 0, 0, 0, Vector3(1, 1, 1.25)), c])
			parts.append([Art.prim("box", 0.165, 0.02, 0.05), T.call(0, 0.205, 0), c.darkened(0.25)])
			parts.append([Art.prim("box", 0.1, 0.07, 0.02), T.call(0, 0.1, 0.045), a])
		"bar":
			parts.append([Art.prim("box", 0.17, 0.05, 0.08), T.call(0, 0.025, 0), c])
			parts.append([Art.prim("box", 0.06, 0.052, 0.082), T.call(0.02, 0.025, 0), a])
		"box":
			parts.append([Art.prim("box", 0.15, 0.2, 0.06), T.call(0, 0.1, 0), c])
			parts.append([Art.prim("box", 0.152, 0.05, 0.062), T.call(0, 0.13, 0), a])
		"bottle":
			parts.append([Art.prim("cyl", 0.04, 0.045, 0.16), T.call(0, 0.08, 0), c])
			parts.append([Art.prim("cyl", 0.018, 0.038, 0.06), T.call(0, 0.19, 0), c.lightened(0.1)])
			parts.append([Art.prim("cyl", 0.02, 0.02, 0.02), T.call(0, 0.23, 0), a])
			parts.append([Art.prim("cyl", 0.047, 0.047, 0.05), T.call(0, 0.09, 0), a])
		"cup":
			parts.append([Art.prim("cyl", 0.05, 0.042, 0.12), T.call(0, 0.06, 0), c])
			parts.append([Art.prim("cyl", 0.052, 0.052, 0.012), T.call(0, 0.124, 0), a])
			parts.append([Art.prim("cyl", 0.051, 0.046, 0.035), T.call(0, 0.06, 0), a.lightened(0.2)])
		"ring": # simit with sesame speckle tone
			parts.append([Art.prim("tor", 0.045, 0.1), T.call(0, 0.03, 0, 0, 0, 0, Vector3(1, 0.9, 1)), c])
			parts.append([Art.prim("tor", 0.05, 0.095), T.call(0, 0.045, 0, 0, 0, 0, Vector3(1, 0.4, 1)), a])
		"loaf":
			parts.append([Art.prim("box", 0.26, 0.12, 0.12), T.call(0, 0.06, 0, 0, 0, 0, Vector3(1, 1, 1)), c])
			for i in 3: parts.append([Art.prim("box", 0.02, 0.02, 0.1), T.call(-0.07 + i * 0.07, 0.122, 0, 0, 0.5, 0), a])
		"fruit":
			parts.append([Art.prim("sph", 0.055), T.call(0, 0.05, 0, 0, 0, 0, Vector3(1, 0.9, 1)), c])
			parts.append([Art.prim("box", 0.04, 0.012, 0.02), T.call(0.015, 0.105, 0, 0, 0, 0.5), a])
		"carton":
			parts.append([Art.prim("box", 0.09, 0.18, 0.09), T.call(0, 0.09, 0), c])
			parts.append([Art.prim("prism", 0.09, 0.05, 0.09), T.call(0, 0.205, 0), c])
			parts.append([Art.prim("box", 0.092, 0.06, 0.092), T.call(0, 0.1, 0), a])
		"wedge": # white cheese block in brine paper
			parts.append([Art.prim("box", 0.16, 0.09, 0.11), T.call(0, 0.045, 0), c])
			parts.append([Art.prim("box", 0.165, 0.03, 0.115), T.call(0, 0.02, 0), a])
			parts.append([Art.prim("box", 0.08, 0.04, 0.005), T.call(0, 0.055, 0.058), Color("ffffff")])
		"jug":
			parts.append([Art.prim("box", 0.13, 0.22, 0.09), T.call(0, 0.11, 0), c])
			parts.append([Art.prim("cyl", 0.025, 0.025, 0.04), T.call(-0.03, 0.24, 0), a])
			parts.append([Art.prim("box", 0.035, 0.1, 0.03), T.call(0.05, 0.17, 0), c.darkened(0.15)])
		_:
			parts.append([Art.prim("box", 0.12, 0.12, 0.12), T.call(0, 0.06, 0), c])
	var m := Art.merge(parts)
	_cache[pid] = m
	return m

## small 3/4 portrait of a product for the UI (rendered once in a SubViewport by the HUD)
static func footprint_height(pid: String) -> float:
	match DB.product(pid)["shape"]:
		"ring": return 0.07
		"bar": return 0.05
		"fruit": return 0.11
		_: return 0.22
