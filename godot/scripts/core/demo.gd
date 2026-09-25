class_name Demo
## The free demo is the same game with a "demo" export feature (export preset "Windows Demo") or
## --demo on the command line: the career stops at the Neighbourhood Market, and of the other
## neighbourhoods only Moda can be played. Saves carry over to the full game.

const MAX_STAGE := 1
const SCENARIOS := ["kariyer", "moda"]
const STORE_URL := "https://store.steampowered.com/" # replace with the game's store page

static var _forced := false

static func active() -> bool:
	return _forced or OS.has_feature("demo") or OS.get_cmdline_user_args().has("--demo")

static func force(on: bool) -> void: _forced = on

## true when the demo stops the player from growing further
static func stage_locked(stage: int) -> bool: return active() and stage >= MAX_STAGE

static func scenario_locked(id: String) -> bool: return active() and not SCENARIOS.has(id)

static func wishlist() -> void: OS.shell_open(STORE_URL)
