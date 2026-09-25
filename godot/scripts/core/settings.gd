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
static var lang := "tr"
static var tutorial := true
static var colorblind := false
static var text_scale := 1.0
static var vsync := true
static var fps_cap := 0 # 0 = unlimited
static var resolution := "" # windowed size "1600x900"; "" = leave as is
static var keys := {} # action -> physical keycode (only the ones the player changed)
const TEXT_SCALES := [1.0, 1.12, 1.25]
const FPS_CAPS := [30, 60, 120, 0]
const RESOLUTIONS := ["1280x720", "1600x900", "1920x1080", "2560x1440"]
static var vol := {"Master": 0.8, "Music": 0.55, "SFX": 0.8, "Ambience": 0.6}
static var _loaded := false
static var first_run := false

## Steam Deck (1280×800, 7"): bigger UI and text, fullscreen — only on the very first launch
static func deck_defaults() -> void:
	if not first_run or not SteamBridge.is_deck(): return
	ui_scale = 1.15; text_scale = 1.12; fullscreen = true
	save_settings()

static func load_settings() -> void:
	if _loaded: return
	_loaded = true
	var c := ConfigFile.new()
	if c.load(FILE) != OK:
		first_run = true
		return
	quality = int(c.get_value("video", "quality", quality))
	fullscreen = bool(c.get_value("video", "fullscreen", fullscreen))
	ui_scale = float(c.get_value("video", "ui_scale", ui_scale))
	cutaway = bool(c.get_value("game", "cutaway", cutaway))
	lang = str(c.get_value("game", "lang", lang))
	tutorial = bool(c.get_value("game", "tutorial", tutorial))
	colorblind = bool(c.get_value("access", "colorblind", colorblind))
	text_scale = float(c.get_value("access", "text_scale", text_scale))
	vsync = bool(c.get_value("video", "vsync", vsync))
	fps_cap = int(c.get_value("video", "fps_cap", fps_cap))
	resolution = str(c.get_value("video", "resolution", resolution))
	keys = c.get_value("keys", "map", {})
	Cfg.set_palette(colorblind)
	Loc.set_lang(lang)
	for k in vol: vol[k] = float(c.get_value("audio", k, vol[k]))

static func save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("video", "quality", quality)
	c.set_value("video", "fullscreen", fullscreen)
	c.set_value("video", "ui_scale", ui_scale)
	c.set_value("game", "cutaway", cutaway)
	c.set_value("game", "lang", lang)
	c.set_value("game", "tutorial", tutorial)
	c.set_value("access", "colorblind", colorblind)
	c.set_value("access", "text_scale", text_scale)
	c.set_value("video", "vsync", vsync)
	c.set_value("video", "fps_cap", fps_cap)
	c.set_value("video", "resolution", resolution)
	c.set_value("keys", "map", keys)
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
	if DisplayServer.get_name() != "headless":
		if DisplayServer.window_get_mode() != mode: DisplayServer.window_set_mode(mode)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
		if not fullscreen and resolution != "":
			var p := resolution.split("x")
			var sz := Vector2i(int(p[0]), int(p[1]))
			var scr := DisplayServer.screen_get_usable_rect()
			sz = sz.min(scr.size)
			if DisplayServer.window_get_size() != sz:
				DisplayServer.window_set_size(sz)
				DisplayServer.window_set_position(scr.position + (scr.size - sz) / 2)
	Engine.max_fps = fps_cap
	Cfg.set_palette(colorblind)
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
