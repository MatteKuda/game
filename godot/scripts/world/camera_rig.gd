class_name CameraRig
extends Node3D
## Management camera: smooth orbit around a ground target. Right-drag pans, middle-drag
## (or Alt+left) rotates, wheel zooms; WASD / arrows pan, Q/E rotate. Touch: drag / pinch / twist.

var cam: Camera3D
var target := Vector3(22, 0, 13)
var yaw := -0.3
var pitch := 0.9
var dist := 24.0
var g_target := Vector3(22, 0, 13)
var g_yaw := -0.3
var g_pitch := 0.9
var g_dist := 24.0
var bounds := Rect2(4, 2, 36, 26)
var min_dist := 8.0
var max_dist := 60.0
var dragging := ""
var touches := {}
var touch_moved := false
var _pinch := {}

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 38.0
	cam.near = 0.3
	cam.far = 400.0
	add_child(cam)
	snap()

func pan_by(right: float, fwd: float) -> void:
	var f := Vector3(-sin(g_yaw), 0, -cos(g_yaw))
	var r := Vector3(-f.z, 0, f.x)
	g_target += r * right + f * fwd
	_clamp()

func zoom_by(f: float) -> void: g_dist = clampf(g_dist * f, min_dist, max_dist)

func focus(x: float, z: float, d := -1.0) -> void:
	g_target = Vector3(x, g_target.y, z)
	if d > 0.0: g_dist = d
	_clamp()

func set_floor_y(y: float) -> void: g_target.y = y

func _clamp() -> void:
	g_target.x = clampf(g_target.x, bounds.position.x, bounds.end.x)
	g_target.z = clampf(g_target.z, bounds.position.y, bounds.end.y)

func snap() -> void:
	target = g_target; yaw = g_yaw; pitch = g_pitch; dist = g_dist
	_apply()

func far_factor() -> float: return clampf((dist - 38.0) / 9.0, 0.0, 1.0)
func is_dragging() -> bool: return dragging != "" or touch_moved

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed: g_dist = clampf(g_dist * 0.9, min_dist, max_dist)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed: g_dist = clampf(g_dist * 1.1, min_dist, max_dist)
		elif mb.button_index == MOUSE_BUTTON_RIGHT: dragging = "pan" if mb.pressed else ""
		elif mb.button_index == MOUSE_BUTTON_MIDDLE or (mb.button_index == MOUSE_BUTTON_LEFT and mb.alt_pressed): dragging = "rotate" if mb.pressed else ""
	elif e is InputEventMouseMotion and dragging != "":
		var mm := e as InputEventMouseMotion
		if dragging == "pan": pan_by(-mm.relative.x * g_dist * 0.0016, mm.relative.y * g_dist * 0.0022)
		else:
			g_yaw -= mm.relative.x * 0.006
			g_pitch = clampf(g_pitch + mm.relative.y * 0.004, 0.45, 1.3)
	elif e is InputEventScreenTouch:
		var st := e as InputEventScreenTouch
		if st.pressed: touches[st.index] = st.position
		else: touches.erase(st.index)
		_pinch = {}
		if touches.is_empty(): call_deferred("_clear_touch")
	elif e is InputEventScreenDrag:
		var sd := e as InputEventScreenDrag
		touches[sd.index] = sd.position
		if touches.size() == 1:
			touch_moved = touch_moved or sd.relative.length() > 2.0
			if touch_moved: pan_by(-sd.relative.x * g_dist * 0.0022, sd.relative.y * g_dist * 0.003)
		elif touches.size() >= 2:
			touch_moved = true
			var ks := touches.keys()
			var a: Vector2 = touches[ks[0]]
			var b: Vector2 = touches[ks[1]]
			var d := a.distance_to(b)
			var ang := (b - a).angle()
			if not _pinch.is_empty():
				g_dist = clampf(g_dist * (_pinch["d"] / maxf(d, 10.0)), min_dist, max_dist)
				g_yaw += wrapf(ang - _pinch["a"], -PI, PI)
			_pinch = {"d": d, "a": ang}

func _clear_touch() -> void: touch_moved = false

func _process(dt: float) -> void:
	var sp := g_dist * 0.9 * dt
	var px := 0.0
	var pz := 0.0
	if not _typing():
		# actions (Keys): keyboard keys are rebindable, the left stick gives analogue strength
		pz += sp * (Input.get_action_strength("cam_up") - Input.get_action_strength("cam_down"))
		px += sp * (Input.get_action_strength("cam_right") - Input.get_action_strength("cam_left"))
		g_yaw += dt * 1.6 * (Input.get_action_strength("cam_rot_l") - Input.get_action_strength("cam_rot_r"))
	if px != 0.0 or pz != 0.0: pan_by(px, pz)
	var a := 1.0 - exp(-dt * 8.0)
	target = target.lerp(g_target, a)
	yaw += (g_yaw - yaw) * a
	pitch += (g_pitch - pitch) * a
	dist += (g_dist - dist) * a
	_apply()

func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit

func _apply() -> void:
	var cp := cos(pitch)
	cam.position = target + Vector3(sin(yaw) * cp * dist, sin(pitch) * dist, cos(yaw) * cp * dist)
	cam.look_at(target, Vector3.UP)
