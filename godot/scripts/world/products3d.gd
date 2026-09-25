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
		"cone": # ice cream on a stick, wrapped in a bright paper sleeve
			parts.append([Art.prim("box", 0.08, 0.16, 0.05), T.call(0, 0.09, 0, 0, 0, 0.0), c])
			parts.append([Art.prim("box", 0.082, 0.05, 0.052), T.call(0, 0.13, 0), a])
			parts.append([Art.prim("box", 0.018, 0.05, 0.012), T.call(0, 0.0, 0), Color("e9d3a6")])
		"paper": # folded newspaper, red masthead
			parts.append([Art.prim("box", 0.2, 0.03, 0.14), T.call(0, 0.015, 0), c])
			parts.append([Art.prim("box", 0.2, 0.032, 0.035), T.call(0, 0.016, -0.045), a])
			for i in 3: parts.append([Art.prim("box", 0.14, 0.033, 0.006), T.call(0.02, 0.016, 0.0 + i * 0.022), Color("9aa0a8")])
		"pack": # small gum pack
			parts.append([Art.prim("box", 0.09, 0.03, 0.05), T.call(0, 0.015, 0), c])
			parts.append([Art.prim("box", 0.04, 0.032, 0.052), T.call(-0.02, 0.015, 0), a])
		"notebook":
			parts.append([Art.prim("box", 0.15, 0.2, 0.025), T.call(0, 0.1, 0), c])
			parts.append([Art.prim("box", 0.1, 0.05, 0.027), T.call(0, 0.14, 0), a])
			parts.append([Art.prim("box", 0.012, 0.2, 0.03), T.call(-0.07, 0.1, 0), Color("e8e4dc")])
		"eggbox": # six-egg carton with the domes showing
			parts.append([Art.prim("box", 0.2, 0.05, 0.1), T.call(0, 0.025, 0), Color("c9b28a")])
			for i in 6: parts.append([Art.prim("sph", 0.026), T.call(-0.065 + (i % 3) * 0.065, 0.058, -0.024 + (i / 3) * 0.048, 0, 0, 0, Vector3(1, 1.25, 1)), c])
			parts.append([Art.prim("box", 0.08, 0.012, 0.04), T.call(0, 0.052, 0), a])
		"tub": # yoghurt bucket
			parts.append([Art.prim("cyl", 0.07, 0.06, 0.1), T.call(0, 0.05, 0), c])
			parts.append([Art.prim("cyl", 0.074, 0.074, 0.015), T.call(0, 0.105, 0), a])
			parts.append([Art.prim("cyl", 0.071, 0.064, 0.04), T.call(0, 0.05, 0), a.lightened(0.35)])
		"jar": # olive jar with a gold lid
			parts.append([Art.prim("cyl", 0.055, 0.055, 0.13), T.call(0, 0.065, 0), c])
			parts.append([Art.prim("cyl", 0.05, 0.05, 0.03), T.call(0, 0.145, 0), a])
			parts.append([Art.prim("cyl", 0.057, 0.057, 0.05), T.call(0, 0.07, 0), Color("f3ead2")])
		"bottle2": # shampoo bottle, flip cap
			parts.append([Art.prim("box", 0.09, 0.18, 0.05), T.call(0, 0.09, 0), c])
			parts.append([Art.prim("cyl", 0.022, 0.03, 0.04), T.call(0, 0.2, 0), a])
			parts.append([Art.prim("box", 0.06, 0.06, 0.052), T.call(0, 0.09, 0), a])
		"tray": # dates in a clear tray
			parts.append([Art.prim("box", 0.18, 0.04, 0.12), T.call(0, 0.02, 0), Color("f2e6c8")])
			for i in 6: parts.append([Art.prim("sph", 0.024), T.call(-0.055 + (i % 3) * 0.055, 0.05, -0.025 + (i / 3) * 0.05, 0, 0, 0, Vector3(1.4, 0.8, 0.8)), c])
			parts.append([Art.prim("box", 0.05, 0.01, 0.03), T.call(0.06, 0.042, 0.04), a])
		"umbrella": # folded umbrella with a hooked handle
			parts.append([Art.prim("cyl", 0.012, 0.035, 0.24), T.call(0, 0.16, 0), c])
			parts.append([Art.prim("cyl", 0.008, 0.008, 0.06), T.call(0, 0.02, 0), Color("5b4a3a")])
			parts.append([Art.prim("tor", 0.012, 0.03), T.call(0.02, -0.01, 0, PI / 2, 0, 0), Color("5b4a3a")])
			parts.append([Art.prim("box", 0.02, 0.03, 0.075), T.call(0, 0.17, 0), a])
		"sack": # paper flour sack
			parts.append([Art.prim("box", 0.14, 0.2, 0.08), T.call(0, 0.1, 0), c])
			parts.append([Art.prim("box", 0.145, 0.02, 0.06), T.call(0, 0.205, 0), c.darkened(0.1)])
			parts.append([Art.prim("box", 0.1, 0.06, 0.082), T.call(0, 0.1, 0), a])
		"sausage": # horseshoe sucuk
			parts.append([Art.prim("tor", 0.035, 0.1), T.call(0, 0.03, 0, 0, 0, 0, Vector3(1, 1.2, 1)), c])
			parts.append([Art.prim("box", 0.07, 0.03, 0.04), T.call(0, 0.03, -0.08), a])
		"wheel": # kaşar wheel wedge
			parts.append([Art.prim("cyl", 0.09, 0.09, 0.07), T.call(0, 0.035, 0), c])
			parts.append([Art.prim("cyl", 0.092, 0.092, 0.012), T.call(0, 0.07, 0), a])
		"flatbox": # frozen pizza box
			parts.append([Art.prim("box", 0.2, 0.035, 0.2), T.call(0, 0.018, 0), c])
			parts.append([Art.prim("cyl", 0.06, 0.06, 0.037), T.call(0, 0.018, 0), a])
		"bigbox": # nappies: a big soft pack
			parts.append([Art.prim("box", 0.2, 0.22, 0.12), T.call(0, 0.11, 0), c])
			parts.append([Art.prim("sph", 0.045), T.call(0, 0.12, 0.058, 0, 0, 0, Vector3(1, 1, 0.25)), a])
			parts.append([Art.prim("box", 0.08, 0.02, 0.02), T.call(0, 0.225, 0), c.darkened(0.2)])
		"pide": # round Ramadan pide with the sesame grid
			parts.append([Art.prim("cyl", 0.12, 0.12, 0.05), T.call(0, 0.025, 0, 0, 0, 0, Vector3(1, 1, 0.8)), c])
			for i in 3: parts.append([Art.prim("box", 0.16, 0.012, 0.012), T.call(0, 0.052, -0.04 + i * 0.04), a])
		_:
			parts.append([Art.prim("box", 0.12, 0.12, 0.12), T.call(0, 0.06, 0), c])
	var m := Art.merge(parts)
	_cache[pid] = m
	return m

## small 3/4 portrait of a product for the UI (rendered once in a SubViewport by the HUD)
static func footprint_height(pid: String) -> float:
	match DB.product(pid)["shape"]:
		"ring", "sausage", "pide": return 0.07
		"bar", "paper", "pack", "flatbox", "tray": return 0.05
		"fruit": return 0.11
		_: return 0.22
