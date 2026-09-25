class_name Tutorial
extends RefCounted
## "Rehber": the first ten minutes as a short checklist. Each step watches the game and ticks
## itself off when the player has done it; the matching dock button pulses meanwhile.

const STEPS := [
	{"id": "select", "title": "Bir rafa tıkla", "text": "Dükkândaki ahşap rafa tıkla: sağda bölmeleri, stoğu ve fiyat etiketlerini gösteren kart açılır.", "dock": ""},
	{"id": "assign", "title": "Boş bölmeye ürün ata", "text": "Raf kartında \"Boş bölme\" satırına tıkla, bir ürün seç. Rafta ne varsa o satılır.", "dock": ""},
	{"id": "prices", "title": "Fiyatlara bak (P)", "text": "Ürün & Fiyat panelinde her ürünün kârını ve kimin alacağını gör. Pahalı ürün rafta kalır.", "dock": "products"},
	{"id": "order", "title": "Sipariş ver (T)", "text": "Tedarik panelinden bir ürüne +12 sipariş ver. Toptancı sabah gelir; \"Acil\" 1 saatte getirir.", "dock": "supply"},
	{"id": "hire", "title": "Reyon görevlisi al (H)", "text": "Kemal Usta hem kasaya hem rafa yetişemez. Personel panelinden bir reyon görevlisi al.", "dock": "staff"},
	{"id": "build", "title": "Bir eşya kur (B)", "text": "İnşa panelinden bir eşya seç (ör. saksı bitki ya da dondurma dolabı), dükkânda yerine tıkla. R ile döndür.", "dock": "build"},
	{"id": "hood", "title": "Mahalleyi tanı (N)", "text": "Mahalle panelinde müdavimler, veresiye defteri ve görevler var. Görevler sana her gün yapacak bir şey verir.", "dock": "hood"},
	{"id": "speed", "title": "Zamanı hızlandır (2–5)", "text": "Dükkân kendi kendine dönmeye başlayınca hızı artır. Sorun çıkınca uyarılar sol altta belirir.", "dock": ""},
]

var step := 0
var active := false
var _base := {}

func start(g) -> void:
	active = true; step = 0
	_base = {"fixtures": g.fixtures.size(), "staff": g.staff.size(), "orders": g.orders.size(), "assigned": _assigned(g)}

func _assigned(g) -> int:
	var n := 0
	for f in g.fixtures:
		for s in f.slots: if s["pid"] != "": n += 1
	return n

func current() -> Dictionary: return STEPS[step] if active and step < STEPS.size() else {}

## returns true when a step was just completed
func check(h) -> bool:
	if not active or step >= STEPS.size(): return false
	var g = h.game
	var ok := false
	match STEPS[step]["id"]:
		"select": ok = g.selection.get("obj") is Fixture and (g.selection["obj"] as Fixture).is_display()
		"assign": ok = _assigned(g) > int(_base["assigned"])
		"prices": ok = h.panel_id == "products"
		"order": ok = g.manual_orders > 0
		"hire": ok = g.staff.size() > int(_base["staff"])
		"build": ok = g.fixtures.size() > int(_base["fixtures"])
		"hood": ok = h.panel_id == "hood"
		"speed": ok = not g.paused and g.speed >= 2.0
	if ok:
		step += 1
		if step >= STEPS.size(): active = false
		return true
	return false
