class_name Keys
## Rebindable controls. Every shortcut is an InputMap action created at start-up from ACTIONS, with
## the player's own keys (Settings.keys) layered over the defaults. Gamepad buttons are added to the
## same actions, so the HUD and camera only ever ask "was this action pressed".

## [action, label, default key(s), gamepad button (-1 none)]
const ACTIONS := [
	["pause", "Duraklat / devam", [KEY_SPACE], JOY_BUTTON_BACK],
	["speed_1", "Hız ×1", [KEY_1], -1],
	["speed_2", "Hız ×2", [KEY_2], -1],
	["speed_4", "Hız ×4", [KEY_3], -1],
	["speed_8", "Hız ×8", [KEY_4], -1],
	["speed_16", "Hız ×16", [KEY_5], -1],
	["faster", "Hızlandır", [], JOY_BUTTON_DPAD_UP],
	["slower", "Yavaşlat", [], JOY_BUTTON_DPAD_DOWN],
	["build", "İnşa paneli", [KEY_B], JOY_BUTTON_X],
	["products", "Ürünler", [KEY_P], JOY_BUTTON_Y],
	["supply", "Tedarik", [KEY_T], -1],
	["staff", "Personel", [KEY_H], -1],
	["finance", "Finans", [KEY_F], -1],
	["growth", "Büyüme", [KEY_U], -1],
	["campaign", "Kampanyalar", [KEY_K], -1],
	["hood", "Mahalle", [KEY_N], -1],
	["mall", "AVM", [KEY_V], -1],
	["heat", "Trafik haritası", [KEY_M], -1],
	["security", "Güvenlik görünümü", [KEY_G], -1],
	["floor_up", "Üst kat", [KEY_PAGEUP, KEY_BRACKETRIGHT], -1],
	["floor_down", "Alt kat", [KEY_PAGEDOWN, KEY_BRACKETLEFT], -1],
	["rotate", "Eşyayı döndür", [KEY_R], JOY_BUTTON_DPAD_RIGHT],
	["cutaway", "Duvarları indir", [KEY_C], JOY_BUTTON_DPAD_LEFT],
	["cam_up", "Kamera ileri", [KEY_W, KEY_UP], -1],
	["cam_down", "Kamera geri", [KEY_S, KEY_DOWN], -1],
	["cam_left", "Kamera sola", [KEY_A, KEY_LEFT], -1],
	["cam_right", "Kamera sağa", [KEY_D, KEY_RIGHT], -1],
	["cam_rot_l", "Kamerayı çevir (sol)", [KEY_Q], JOY_BUTTON_LEFT_SHOULDER],
	["cam_rot_r", "Kamerayı çevir (sağ)", [KEY_E], JOY_BUTTON_RIGHT_SHOULDER],
	["menu", "Menü / geri", [KEY_ESCAPE], JOY_BUTTON_START],
]
## the ones shown on the settings page (camera keys are rebindable too, speed keys are obvious)
const SHOWN := ["pause", "build", "products", "supply", "staff", "finance", "growth", "campaign", "hood", "mall", "heat", "security", "rotate", "cutaway", "floor_up", "floor_down", "cam_up", "cam_down", "cam_left", "cam_right", "cam_rot_l", "cam_rot_r"]

static func setup() -> void:
	for a in ACTIONS:
		var id: String = a[0]
		if InputMap.has_action(id): InputMap.action_erase_events(id)
		else: InputMap.add_action(id, 0.3)
		var keys: Array = a[2]
		if Settings.keys.has(id): keys = [int(Settings.keys[id])]
		for k in keys:
			var ev := InputEventKey.new(); ev.physical_keycode = k
			InputMap.action_add_event(id, ev)
		if int(a[3]) >= 0:
			var jb := InputEventJoypadButton.new(); jb.button_index = a[3]
			InputMap.action_add_event(id, jb)
	# left stick pans the camera
	for m in [["cam_up", JOY_AXIS_LEFT_Y, -1.0], ["cam_down", JOY_AXIS_LEFT_Y, 1.0], ["cam_left", JOY_AXIS_LEFT_X, -1.0], ["cam_right", JOY_AXIS_LEFT_X, 1.0]]:
		var jm := InputEventJoypadMotion.new(); jm.axis = m[1]; jm.axis_value = m[2]
		InputMap.action_add_event(m[0], jm)

static func label_of(id: String) -> String:
	for a in ACTIONS:
		if a[0] == id: return a[1]
	return id

## the first keyboard key bound to an action, as text ("Space", "B"…)
static func key_text(id: String) -> String:
	if not InputMap.has_action(id): return ""
	for ev in InputMap.action_get_events(id):
		if ev is InputEventKey:
			var k: int = (ev as InputEventKey).physical_keycode
			return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(k) if DisplayServer.get_name() != "headless" else k)
	return "—"

## bind a new key; a key already used by another shown action is taken away from it (swap)
static func rebind(id: String, physical: int) -> String:
	var clash := ""
	for a in ACTIONS:
		var other: String = a[0]
		if other == id: continue
		for ev in InputMap.action_get_events(other):
			if ev is InputEventKey and (ev as InputEventKey).physical_keycode == physical: clash = other
	if clash != "":
		var mine: int = _first_key(id)
		if mine != 0: Settings.keys[clash] = mine
		else: Settings.keys.erase(clash)
	Settings.keys[id] = physical
	Settings.save_settings()
	setup()
	return clash

static func _first_key(id: String) -> int:
	for ev in InputMap.action_get_events(id):
		if ev is InputEventKey: return (ev as InputEventKey).physical_keycode
	return 0

static func reset() -> void:
	Settings.keys.clear()
	Settings.save_settings()
	setup()
