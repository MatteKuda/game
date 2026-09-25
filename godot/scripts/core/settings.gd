class_name Settings
## Player settings stored in user://ayarlar.cfg and applied to the running game.

const FILE := "user://ayarlar.cfg"
const QUALITY := ["Düşük", "Orta", "Yüksek"]
const UI_SCALES := [0.9, 1.0, 1.15, 1.3]

static var quality := 2
static var fullscreen := false
static var ui_scale := 1.0
static var cutaway := true
static var edge_pan := false
static var vol := {"Master": 0.8, "Music": 0.55, "SFX": 0.8, "Ambience": 0.6}
static var _loaded := false

static func load_settings() -> void:
	if _loaded: return
	_loaded = true
	var c := ConfigFile.new()
	if c.load(FILE) != OK: return
	quality = int(c.get_value("video", "quality", quality))
	fullscreen = bool(c.get_value("video", "fullscreen", fullscreen))
	ui_scale = float(c.get_value("video", "ui_scale", ui_scale))
	cutaway = bool(c.get_value("game", "cutaway", cutaway))
	for k in vol: vol[k] = float(c.get_value("audio", k, vol[k]))

static func save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("video", "quality", quality)
	c.set_value("video", "fullscreen", fullscreen)
	c.set_value("video", "ui_scale", ui_scale)
	c.set_value("game", "cutaway", cutaway)
	for k in vol: c.set_value("audio", k, vol[k])
	c.save(FILE)

## audio buses are created at runtime so the project needs no bus layout file
static func ensure_buses() -> void:
	for name in ["Music", "SFX", "Ambience"]:
		if AudioServer.get_bus_index(name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, name)
			AudioServer.set_bus_send(i, "Master")

static func apply_audio() -> void:
	ensure_buses()
	for k in vol:
		var i := AudioServer.get_bus_index(k)
		if i < 0: continue
		var v: float = vol[k]
		AudioServer.set_bus_mute(i, v <= 0.001)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))

static func apply(game, tree: SceneTree) -> void:
	apply_audio()
	var win := tree.root
	win.content_scale_factor = ui_scale
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() != mode: DisplayServer.window_set_mode(mode)
	if game == null: return
	game.shop.cutaway = cutaway
	var env: Environment = game.sky.env
	env.ssao_enabled = quality >= 1
	env.ssil_enabled = quality >= 2
	env.glow_enabled = quality >= 1
	env.sdfgi_enabled = false
	game.sky.sun.shadow_enabled = true
	win.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][quality]
	win.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	RenderingServer.directional_shadow_atlas_set_size([2048, 4096, 4096][quality], true)
