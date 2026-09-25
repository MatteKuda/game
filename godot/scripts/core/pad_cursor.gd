class_name PadCursor
extends Node
## Gamepad play (and Steam Deck without the trackpads): the right stick moves the mouse pointer,
## A clicks, B backs out (like Esc), triggers zoom. Everything else in the game is mouse-driven, so
## turning the pad into a pointer makes every panel and button reachable without special cases.

const SPEED := 1100.0
var _vel := Vector2.ZERO
var active := false # true once a pad has been used; hides nothing, just for hints

func _process(dt: float) -> void:
	if Input.get_connected_joypads().is_empty(): return
	var v := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if v.length() < 0.18: v = Vector2.ZERO
	else: active = true
	# ease-in so small tilts are precise and full tilts cross the screen quickly
	var target := v * v.length() * SPEED
	_vel = _vel.lerp(target, minf(1.0, dt * 14.0))
	if _vel.length() > 1.0 and DisplayServer.get_name() != "headless":
		var vp := get_viewport()
		var p := vp.get_mouse_position() + _vel * dt
		var r := vp.get_visible_rect().size
		p = p.clamp(Vector2.ZERO, r - Vector2.ONE)
		vp.warp_mouse(p)
		var mm := InputEventMouseMotion.new(); mm.position = p; mm.global_position = p; mm.relative = _vel * dt
		Input.parse_input_event(mm)
	var zoom := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) - Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	if absf(zoom) > 0.1:
		var game = get_parent().get("game")
		if game != null and game.rig != null: game.rig.zoom_by(1.0 - zoom * dt * 1.4)

func _input(e: InputEvent) -> void:
	if not e is InputEventJoypadButton: return
	var jb := e as InputEventJoypadButton
	if jb.button_index == JOY_BUTTON_B:
		get_viewport().set_input_as_handled()
		var k := InputEventKey.new(); k.keycode = KEY_ESCAPE; k.physical_keycode = KEY_ESCAPE; k.pressed = jb.pressed
		Input.parse_input_event(k)
		return
	if jb.button_index != JOY_BUTTON_A: return
	active = true
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT; mb.pressed = jb.pressed
	mb.position = get_viewport().get_mouse_position(); mb.global_position = mb.position
	mb.button_mask = MOUSE_BUTTON_MASK_LEFT if jb.pressed else 0
	get_viewport().set_input_as_handled()
	Input.parse_input_event(mb)
