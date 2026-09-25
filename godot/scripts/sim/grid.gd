class_name Grid
extends RefCounted
## Region grid (street / interior / door edges), A* with soft costs, BFS reachability.

const R_VOID := 0
const R_OUT := 1 # near sidewalk
const R_IN := 2 # shop interior
const R_FAR := 3 # far sidewalk (ambient walkers)
const R_MALL := 4 # AVM corridors / food court
const R_UNIT0 := 10 # AVM tenant units: R_UNIT0 + unit index

var w := Cfg.MAP_W
var h := Cfg.MAP_H
var region := PackedByteArray()
var fixture := PackedInt32Array() # fixture uid on tile (0 = none)
var reserved := PackedByteArray() # must stay free (door approach)
var traffic := PackedFloat32Array() # decaying heat
var occupancy := PackedByteArray() # agents per tile (rebuilt each tick)
var extra_cost := PackedFloat32Array()
var door_edges := {}
var version := 0
var layout: Dictionary
var lvl := 0 # AVM floor index

func _init(f := 0) -> void:
	lvl = f
	var n := w * h
	region.resize(n); fixture.resize(n); reserved.resize(n); traffic.resize(n); occupancy.resize(n); extra_cost.resize(n)

func idx(x: int, z: int) -> int: return z * w + x
func in_bounds(x: int, z: int) -> bool: return x >= 0 and z >= 0 and x < w and z < h

func edge_key(ax: int, az: int, bx: int, bz: int) -> int:
	return mini(idx(ax, az), idx(bx, bz)) * 2 + (0 if az == bz else 1)

func add_door(ax: int, az: int, bx: int, bz: int) -> void:
	door_edges[edge_key(ax, az, bx, bz)] = true

func apply_layout(l: Dictionary) -> void:
	layout = l
	region.fill(R_VOID)
	for z in range(Cfg.SIDEWALK_Z0, Cfg.SIDEWALK_Z1):
		for x in w: region[idx(x, z)] = R_OUT
	for z in range(Cfg.FAR_WALK_Z0, Cfg.FAR_WALK_Z1):
		for x in w: region[idx(x, z)] = R_FAR
	var r: Rect2i = l["interior"]
	for z in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x): region[idx(x, z)] = R_IN
	door_edges.clear()
	reserved.fill(0)
	for dx in l["doors"]:
		door_edges[edge_key(dx, r.end.y - 1, dx, r.end.y)] = true
		reserved[idx(dx, r.end.y - 1)] = 1
	for dx in l.get("back_doors", []):
		door_edges[edge_key(dx, r.position.y, dx, r.position.y - 1)] = true
		reserved[idx(dx, r.position.y)] = 1
	version += 1

## floor-1 grid of the AVM: everything void until the mall carves its regions
func clear_all() -> void:
	region.fill(R_VOID); door_edges.clear(); reserved.fill(0); fixture.fill(0)
	version += 1

func is_mall(x: int, z: int) -> bool: return in_bounds(x, z) and region[idx(x, z)] == R_MALL

func interior() -> Rect2i: return layout["interior"]
func front_z() -> int: return interior().end.y - 1
func is_interior(x: int, z: int) -> bool: return in_bounds(x, z) and region[idx(x, z)] == R_IN

func walkable(x: int, z: int) -> bool:
	if not in_bounds(x, z): return false
	var i := idx(x, z)
	return region[i] != R_VOID and fixture[i] == 0

func _orth_ok(ax: int, az: int, bx: int, bz: int) -> bool:
	if not walkable(bx, bz): return false
	if region[idx(ax, az)] == region[idx(bx, bz)]: return true
	return door_edges.has(edge_key(ax, az, bx, bz))

func can_step(ax: int, az: int, bx: int, bz: int) -> bool:
	var dx := bx - ax
	var dz := bz - az
	if dx == 0 or dz == 0: return _orth_ok(ax, az, bx, bz)
	if not walkable(bx, bz): return false
	var r := region[idx(ax, az)]
	if region[idx(bx, bz)] != r: return false
	return _orth_ok(ax, az, ax + dx, az) and _orth_ok(ax, az, ax, az + dz) \
		and region[idx(ax + dx, az)] == r and region[idx(ax, az + dz)] == r

## A* from a to b; returns Array[Vector2i] (including start) or [] when unreachable.
func find_path(a: Vector2i, b: Vector2i, avoid_crowd := false) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not in_bounds(a.x, a.y) or not in_bounds(b.x, b.y): return out
	if not walkable(b.x, b.y): return out
	var start := idx(a.x, a.y)
	var goal := idx(b.x, b.y)
	if start == goal:
		out.append(a); return out
	var n := w * h
	var g := PackedFloat32Array(); g.resize(n); g.fill(1e20)
	var came := PackedInt32Array(); came.resize(n); came.fill(-1)
	var closed := PackedByteArray(); closed.resize(n)
	var heap_i := PackedInt32Array()
	var heap_p := PackedFloat32Array()
	g[start] = 0.0
	_push(heap_i, heap_p, start, _h(start, b))
	while heap_i.size() > 0:
		var cur := _pop(heap_i, heap_p)
		if cur == goal: break
		if closed[cur]: continue
		closed[cur] = 1
		var cx := cur % w
		var cz := cur / w
		for dz in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dz == 0: continue
				var nx: int = cx + dx
				var nz: int = cz + dz
				if not in_bounds(nx, nz): continue
				var ni := idx(nx, nz)
				if closed[ni]: continue
				if not can_step(cx, cz, nx, nz): continue
				var cost := 1.4142 if (dx != 0 and dz != 0) else 1.0
				if avoid_crowd: cost += occupancy[ni] * 0.6
				cost += extra_cost[ni]
				var ng := g[cur] + cost
				if ng < g[ni]:
					g[ni] = ng; came[ni] = cur
					_push(heap_i, heap_p, ni, ng + _h(ni, b))
	if came[goal] == -1: return out
	var c := goal
	while c != -1:
		out.append(Vector2i(c % w, c / w))
		if c == start: break
		c = came[c]
	out.reverse()
	return out

func _h(i: int, b: Vector2i) -> float:
	var dx := absi(i % w - b.x)
	var dz := absi(i / w - b.y)
	return maxi(dx, dz) + 0.4142 * mini(dx, dz)

static func _push(items: PackedInt32Array, prio: PackedFloat32Array, v: int, p: float) -> void:
	items.append(v); prio.append(p)
	var i := items.size() - 1
	while i > 0:
		var pa := (i - 1) >> 1
		if prio[pa] <= prio[i]: break
		var ti := items[pa]; items[pa] = items[i]; items[i] = ti
		var tp := prio[pa]; prio[pa] = prio[i]; prio[i] = tp
		i = pa

static func _pop(items: PackedInt32Array, prio: PackedFloat32Array) -> int:
	var top := items[0]
	var last := items.size() - 1
	items[0] = items[last]; prio[0] = prio[last]
	items.resize(last); prio.resize(last)
	var i := 0
	var n := items.size()
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var m := i
		if l < n and prio[l] < prio[m]: m = l
		if r < n and prio[r] < prio[m]: m = r
		if m == i: break
		var ti := items[m]; items[m] = items[i]; items[i] = ti
		var tp := prio[m]; prio[m] = prio[i]; prio[i] = tp
		i = m
	return top

## BFS flood (4-neighbour) used to validate that placements keep everything reachable.
func reachable_from(a: Vector2i) -> PackedByteArray:
	var seen := PackedByteArray(); seen.resize(w * h)
	if not walkable(a.x, a.y): return seen
	var q := [idx(a.x, a.y)]
	seen[q[0]] = 1
	var head := 0
	while head < q.size():
		var cur: int = q[head]; head += 1
		var cx := cur % w
		var cz := cur / w
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = cx + d.x
			var nz: int = cz + d.y
			if not in_bounds(nx, nz): continue
			var ni := idx(nx, nz)
			if seen[ni]: continue
			if not can_step(cx, cz, nx, nz): continue
			seen[ni] = 1; q.append(ni)
	return seen
