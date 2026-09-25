class_name Branches
extends RefCounted
## Şubeler (post-game): once Köşebaşı is a mall, open branches in the other neighbourhoods. They are
## run at a distance — the player picks a focus, a manager and upgrades, and each evening the branch
## reports its takings. Winning a neighbourhood's scenario makes the branch cheaper and busier there.

const SITES := [
	{"id": "kampus", "name": "Kampüs Yolu", "icon": "school", "cost": 45000, "base": 1500,
		"blurb": "Öğrenciler: çok müşteri, küçük sepet. Ucuzluk burada iyi gider."},
	{"id": "moda", "name": "Moda Sahili", "icon": "chart", "cost": 60000, "base": 1900,
		"blurb": "Sahil ve kafeler: kaliteye para veren, seçici bir mahalle."},
	{"id": "carsi", "name": "Çarşı", "icon": "rival", "cost": 90000, "base": 2800,
		"blurb": "Kalabalık çarşı: en yüksek ciro, en sert rekabet."},
]
## focus: [name, income ×, rating it drifts to]
const FOCUS := {
	"ucuz": ["Ucuzluk", 1.15, 3.3],
	"denge": ["Denge", 1.0, 3.8],
	"kalite": ["Kalite", 0.9, 4.4],
}
## which focus each neighbourhood likes (+15% income)
const LIKES := {"kampus": "ucuz", "moda": "kalite", "carsi": "denge"}
const LEVEL_MUL := [0.0, 1.0, 1.6, 2.3]
const MANAGER_WAGE := 450

var list: Array = [] # [{id, opened, focus, level, manager, rating, last, total}]

func unlocked(g) -> bool: return g.stage >= 3 or g.scenario.get("id", "") == "serbest"

func site(id: String) -> Dictionary:
	for s in SITES:
		if s["id"] == id: return s
	return {}

func get_branch(id: String) -> Dictionary:
	for b in list:
		if b["id"] == id: return b
	return {}

## a won scenario means the neighbourhood already knows you
func known(id: String) -> bool: return Progress.medal(id)

func open_cost(id: String) -> int:
	return int(site(id)["cost"] * (0.75 if known(id) else 1.0))

func level_cost(b: Dictionary) -> int: return 30000 * int(b["level"])

func open_branch(g, id: String) -> bool:
	var c := open_cost(id)
	if not get_branch(id).is_empty() or g.money < c: return false
	g.money -= c; g.stats["other"] += c
	list.append({"id": id, "opened": g.day, "focus": "denge", "level": 1, "manager": false, "rating": 3.4 if not known(id) else 3.8, "last": 0, "total": 0})
	g.alert("branch_" + id, "store", "%s şubesi açıldı! Her akşam kasasını buraya bildirecek." % site(id)["name"], "good", null, 0.0)
	GameAudio.play("levelup", -6.0)
	return true

func upgrade(g, id: String) -> void:
	var b := get_branch(id)
	if b.is_empty() or int(b["level"]) >= 3 or g.money < level_cost(b): return
	g.money -= level_cost(b); g.stats["other"] += level_cost(b)
	b["level"] = int(b["level"]) + 1

func set_focus(id: String, f: String) -> void:
	var b := get_branch(id)
	if not b.is_empty(): b["focus"] = f

func set_manager(id: String, on: bool) -> void:
	var b := get_branch(id)
	if not b.is_empty(): b["manager"] = on

## one line per branch for the day summary; money is added here
func end_day(g) -> int:
	var total := 0
	for b in list:
		var s := site(b["id"])
		var fo: Array = FOCUS[b["focus"]]
		# rating drifts toward what the focus (and a manager) can deliver
		var target: float = float(fo[2]) + (0.2 if b["manager"] else -0.1)
		b["rating"] = clampf(float(b["rating"]) + (target - float(b["rating"])) * 0.25 + randf_range(-0.05, 0.05), 1.5, 5.0)
		var mul: float = LEVEL_MUL[int(b["level"])] * float(fo[1]) * (0.55 + float(b["rating"]) / 5.0 * 0.8)
		if LIKES.get(b["id"], "") == b["focus"]: mul *= 1.15
		if known(b["id"]): mul *= 1.15
		if b["manager"]: mul *= 1.1
		var net := int(float(s["base"]) * mul * randf_range(0.85, 1.15))
		if b["manager"]: net -= MANAGER_WAGE
		# small surprises: an unmanaged branch has more of the bad ones
		var r := randf()
		if r < (0.12 if not b["manager"] else 0.05):
			var loss := int(randf_range(400, 1200) * int(b["level"]))
			net -= loss
			g.alert("branch_news", "alert", "%s şubesinde dolap bozuldu, mal çöpe gitti: −₺%d.%s" % [s["name"], loss, "" if b["manager"] else " Bir şube müdürü bunları azaltır."], "warn", null, 0.0)
		elif r > 0.92:
			var gain := int(randf_range(500, 1500) * int(b["level"]))
			net += gain
			g.alert("branch_news", "sparkle", "%s şubesi rekor kırdı: +₺%d." % [s["name"], gain], "good", null, 0.0)
		b["last"] = net
		b["total"] = int(b["total"]) + net
		total += net
	g.money += total
	return total

func serialize() -> Array: return list.duplicate(true)

func apply(d) -> void:
	list = []
	if not d is Array: return
	for b in d:
		if b is Dictionary and SITES.any(func(s): return s["id"] == b.get("id", "")):
			list.append({"id": b["id"], "opened": int(b.get("opened", 1)), "focus": str(b.get("focus", "denge")), "level": clampi(int(b.get("level", 1)), 1, 3),
				"manager": bool(b.get("manager", false)), "rating": float(b.get("rating", 3.5)), "last": int(b.get("last", 0)), "total": int(b.get("total", 0))})
