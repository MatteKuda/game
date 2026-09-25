class_name SteamBridge
## Optional Steam support. The game runs the same with or without Steam: when the GodotSteam
## GDExtension is installed (addons/godotsteam, see docs/STEAM.md) and Steam is running, achievements
## unlock on Steam too and the friends list shows what the player is doing. Everything goes through
## Engine.get_singleton so the project compiles and runs without the extension.

const APP_ID := 480 # Valve's test app ("Spacewar"); replace with the real app id from Steamworks
## our achievement ids map 1:1 to Steam API names (upper-case, prefixed) set up in Steamworks
static func api_name(id: String) -> String: return "ACH_" + id.to_upper()

static var steam: Object = null
static var ok := false

static func init() -> void:
	if not Engine.has_singleton("Steam"): return
	steam = Engine.get_singleton("Steam")
	var r = steam.call("steamInitEx", false, APP_ID) if steam.has_method("steamInitEx") else steam.call("steamInit")
	var status: int = int(r.get("status", 1)) if r is Dictionary else (0 if r else 1)
	ok = status == 0
	if not ok:
		push_warning("Steam not available: %s" % str(r))
		return
	# sync achievements earned while offline
	Progress.load_data()
	for id in Progress.data["ach"]: _unlock(id)
	_store()

## called every frame from main so Steam callbacks are delivered
static func tick() -> void:
	if ok: steam.call("run_callbacks")

static func achievement(id: String) -> void:
	if not ok: return
	_unlock(id); _store()

static func _unlock(id: String) -> void:
	steam.call("setAchievement", api_name(id))

static func _store() -> void:
	steam.call("storeStats")

## "Köşebaşı Market · Day 12" in the friends list
static func presence(text: String) -> void:
	if not ok: return
	steam.call("setRichPresence", "steam_display", "#Status")
	steam.call("setRichPresence", "status", text)

static func is_deck() -> bool:
	if OS.get_environment("SteamDeck") == "1": return true
	if ok and steam.has_method("isSteamRunningOnSteamDeck"): return bool(steam.call("isSteamRunningOnSteamDeck"))
	return false
