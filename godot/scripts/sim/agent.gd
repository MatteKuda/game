class_name Agent
extends Node3D
## Anything that walks the tile grid: movement, path following, thought bubbles.

static var _next_id := 1
static var _bubble_tex := {}

var id := 0
var view: CharacterView
var path: Array[Vector2i] = []
var path_idx := 0
var goal := Vector2i(-1, -1)
var has_goal := false
var grid_version := -1
var speed := 1.4
var speed_mul := 1.0
var facing := 0.0
var moving := 0.0
var jitter := Vector2(randf_range(-0.08, 0.08), randf_range(-0.08, 0.08))
var bubble: Sprite3D
var bubble_t := 0.0
var bubble_kind := ""
var look_at_pt = null # Vector3 or null
var removed := false
var crowd_t := 0.0
var person_name := ""

func init_agent(look: Dictionary, nm: String) -> void:
	id = _next_id; _next_id += 1
	person_name = nm
	view = CharacterView.new()
	add_child(view)
	view.setup(look)
	bubble = Sprite3D.new()
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true
	bubble.pixel_size = 0.0036
	bubble.render_priority = 11
	bubble.position.y = view.head_y + 0.35
	bubble.visible = false
	add_child(bubble)

func tile() -> Vector2i: return Vector2i(floori(position.x), floori(position.z))

func think(kind: String, dur := 2.2) -> void:
	bubble_kind = kind; bubble_t = dur
	if not _bubble_tex.has(kind): _bubble_tex[kind] = load("res://assets/icons/badge/%s.svg" % kind)
	bubble.texture = _bubble_tex[kind]
	bubble.visible = true

func go_to(game, t: Vector2i) -> bool:
	var g: Grid = game.grid
	var from := tile()
	if not g.walkable(from.x, from.y): unstick(game)
	var p := g.find_path(tile(), t, true)
	goal = t; has_goal = true
	grid_version = g.version
	if p.is_empty():
		path = []; path_idx = 0
		return false
	path = p
	path_idx = 1 if p.size() > 1 else 0
	return true

func same_goal(t: Vector2i) -> bool: return has_goal and goal == t

func unstick(game) -> void:
	var g: Grid = game.grid
	var t := tile()
	if not g.in_bounds(t.x, t.y): return
	for r in range(1, 6):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if g.walkable(t.x + dx, t.y + dz) and g.region[g.idx(t.x + dx, t.y + dz)] == g.region[g.idx(t.x, t.y)]:
					position = Vector3(t.x + dx + 0.5, position.y, t.y + dz + 0.5)
					return

## returns true when the final goal is reached
func move(dt: float, game) -> bool:
	if not has_goal: return true
	var g: Grid = game.grid
	if grid_version != g.version: go_to(game, goal)
	if path.is_empty():
		moving = 0.0
		return false
	if path_idx >= path.size():
		moving = 0.0
		return true
	var wp: Vector2i = path[path_idx]
	var last := path_idx == path.size() - 1
	var j := jitter * (0.5 if last else 1.0)
	var tx := wp.x + 0.5 + j.x
	var tz := wp.y + 0.5 + j.y
	var dx := tx - position.x
	var dz := tz - position.z
	var d := sqrt(dx * dx + dz * dz)
	var sp := speed * speed_mul
	var occ := g.occupancy[g.idx(wp.x, wp.y)]
	if occ >= 2 and g.is_interior(wp.x, wp.y):
		sp *= 0.5; crowd_t += dt
	var step := sp * dt
	if d <= step or d < 0.02:
		position.x = tx; position.z = tz
		path_idx += 1
		if path_idx >= path.size():
			moving = 0.0
			return true
	else:
		position.x += dx / d * step
		position.z += dz / d * step
		facing = lerp_angle(facing, atan2(dx, dz), minf(1.0, dt * 12.0))
	moving = sp / 1.4
	return false

func sync_view(dt: float, t: float) -> void:
	if look_at_pt != null and moving == 0.0:
		var p: Vector3 = look_at_pt
		facing = lerp_angle(facing, atan2(p.x - position.x, p.z - position.z), minf(1.0, dt * 8.0))
	view.rotation.y = facing
	view.set_walk_rate(speed * speed_mul / 1.25)
	if bubble_t > 0.0:
		bubble_t -= dt
		var k := minf(1.0, (2.2 - maxf(0.0, bubble_t)) * 6.0)
		var s := (0.6 + 0.4 * k) * (bubble_t / 0.25 if bubble_t < 0.25 else 1.0)
		bubble.scale = Vector3.ONE * s
		bubble.position.y = view.head_y + 0.35 + sin(t * 4.0 + id) * 0.03
		if bubble_t <= 0.0:
			bubble.visible = false; bubble_kind = ""
