class_name MallDB
## AVM (stage 4) layout, tenants, visitor archetypes and events. All brands are fictional.

const FOOTPRINT := Rect2i(2, 0, 40, 16) # x 2..42, z 0..16
## floor-0 common corridors (the supermarket sits in the middle: x10..34, z4..16)
const F0_CORRIDORS := [Rect2i(6, 0, 4, 16), Rect2i(34, 0, 4, 16), Rect2i(10, 0, 24, 4)]
const ENTRANCES := [7, 8, 35, 36] # door x on the front edge (z15 <-> z16)

## rect x/z/w/d; door tiles inside the unit; dir points to the corridor
const UNITS := [
	{"id": "L1", "floor": 0, "rect": Rect2i(2, 0, 4, 8), "door": [Vector2i(5, 3), Vector2i(5, 4)], "dir": Vector2i(1, 0)},
	{"id": "L2", "floor": 0, "rect": Rect2i(2, 8, 4, 8), "door": [Vector2i(5, 11), Vector2i(5, 12)], "dir": Vector2i(1, 0)},
	{"id": "R1", "floor": 0, "rect": Rect2i(38, 0, 4, 8), "door": [Vector2i(38, 3), Vector2i(38, 4)], "dir": Vector2i(-1, 0)},
	{"id": "R2", "floor": 0, "rect": Rect2i(38, 8, 4, 8), "door": [Vector2i(38, 11), Vector2i(38, 12)], "dir": Vector2i(-1, 0)},
	{"id": "U1", "floor": 1, "rect": Rect2i(2, 0, 8, 5), "door": [Vector2i(5, 4), Vector2i(6, 4)], "dir": Vector2i(0, 1)},
	{"id": "U2", "floor": 1, "rect": Rect2i(19, 0, 8, 5), "door": [Vector2i(22, 4), Vector2i(23, 4)], "dir": Vector2i(0, 1)},
	{"id": "U3", "floor": 1, "rect": Rect2i(31, 0, 11, 5), "door": [Vector2i(35, 4), Vector2i(36, 4)], "dir": Vector2i(0, 1)},
	{"id": "U4", "floor": 1, "rect": Rect2i(2, 7, 6, 9), "door": [Vector2i(7, 10), Vector2i(7, 11)], "dir": Vector2i(1, 0)},
	{"id": "U5", "floor": 1, "rect": Rect2i(36, 7, 6, 9), "door": [Vector2i(36, 10), Vector2i(36, 11)], "dir": Vector2i(-1, 0)},
	{"id": "U6", "floor": 1, "rect": Rect2i(12, 13, 8, 3), "door": [Vector2i(15, 13), Vector2i(16, 13)], "dir": Vector2i(0, -1), "food": true},
	{"id": "U7", "floor": 1, "rect": Rect2i(24, 13, 8, 3), "door": [Vector2i(27, 13), Vector2i(28, 13)], "dir": Vector2i(0, -1), "food": true},
]

const CONNECTORS := [
	{"id": "escUp", "kind": "escalator", "name": "Yürüyen Merdiven (yukarı)", "blocked": Rect2i(13, 1, 5, 1), "from": [0, Vector2i(12, 1)], "to": [1, Vector2i(18, 1)], "time": 5.5},
	{"id": "escDown", "kind": "escalator", "name": "Yürüyen Merdiven (aşağı)", "blocked": Rect2i(13, 2, 5, 1), "from": [1, Vector2i(18, 2)], "to": [0, Vector2i(12, 2)], "time": 5.5},
	{"id": "lift", "kind": "elevator", "name": "Cam Asansör", "blocked": Rect2i(28, 0, 2, 2), "from": [0, Vector2i(28, 2)], "to": [1, Vector2i(28, 2)], "bidir": true, "time": 4.0},
	{"id": "stairs", "kind": "stairs", "name": "Merdiven", "blocked": Rect2i(9, 6, 1, 5), "from": [0, Vector2i(9, 5)], "to": [1, Vector2i(9, 11)], "bidir": true, "time": 7.0},
]
## opening in the floor-1 slab above the escalators
const WELL := Rect2i(12, 1, 6, 2)
## built-in stage niche at the food court (floor 1), never walkable
const STAGE := Rect2i(20, 14, 4, 2)
## glass lift shaft (cut out of the floor-1 slab)
const SHAFT := Rect2i(28, 0, 2, 2)
## opening in the floor-1 slab above the stairs
const STAIR_WELL := Rect2i(9, 6, 1, 5)

const TENANTS := [
	{"id": "giyim", "name": "Giyim", "brand": "KUMAŞ & KO", "color": Color("1f8a86"), "accent": Color("f2b33d"), "rent": 900, "share": 0.08, "spend": [120, 420], "buy": 0.45, "rule": "Zemin katı ve girişe yakınlığı sever"},
	{"id": "elektronik", "name": "Elektronik", "brand": "VOLTAJ", "color": Color("2f3a8a"), "accent": Color("61d4ff"), "rent": 1400, "share": 0.06, "spend": [300, 1600], "buy": 0.25, "rule": "Yürüyen merdiven / asansöre yakın olmak ister"},
	{"id": "kitap", "name": "Kitabevi", "brand": "SAYFA", "color": Color("7a4a2a"), "accent": Color("f6e7c8"), "rent": 500, "share": 0.1, "spend": [60, 220], "buy": 0.5, "rule": "Gürültülü komşu (oyun salonu) istemez"},
	{"id": "oyuncak", "name": "Oyuncakçı", "brand": "ZIPZIP", "color": Color("e0663c"), "accent": Color("ffe066"), "rent": 700, "share": 0.1, "spend": [80, 350], "buy": 0.5, "rule": "Çocuk oyun alanına yakın olmayı sever"},
	{"id": "kuafor", "name": "Kuaför", "brand": "MAKAS", "color": Color("b0546a"), "accent": Color("ffd6e0"), "rent": 600, "share": 0.12, "spend": [150, 400], "buy": 0.6, "rule": "Sakin köşeler ve temiz koridor ister"},
	{"id": "oyun", "name": "Oyun Salonu", "brand": "JETON", "color": Color("6c4ab6"), "accent": Color("7fe3c8"), "rent": 1100, "share": 0.1, "spend": [40, 160], "buy": 0.8, "noisy": true, "rule": "Gürültülüdür: yanındaki kiracıları rahatsız eder"},
	{"id": "spor", "name": "Spor", "brand": "KOŞU", "color": Color("d6333a"), "accent": Color("ffffff"), "rent": 1000, "share": 0.07, "spend": [150, 700], "buy": 0.35, "rule": "Kalabalık koridor ve üst katta vitrin sever"},
	{"id": "sinema", "name": "Sinema", "brand": "KARE SİNEMA", "color": Color("1f2a44"), "accent": Color("f2b33d"), "rent": 1700, "share": 0.1, "spend": [120, 260], "buy": 0.95, "big": true, "movie": true, "rule": "Büyük birim ister (45 m² üstü). Yemek katında en az iki restoran olunca daha çok seyirci gelir"},
	{"id": "kafe", "name": "Kahveci", "brand": "DEMLİK", "color": Color("5b3a24"), "accent": Color("f2b33d"), "rent": 800, "share": 0.12, "spend": [45, 120], "buy": 0.9, "food": true, "rule": "Yemek katında yeterli masa (≥8 koltuk) ister"},
	{"id": "burger", "name": "Burgerci", "brand": "TOMBUL", "color": Color("f2b33d"), "accent": Color("d6333a"), "rent": 950, "share": 0.12, "spend": [90, 200], "buy": 0.9, "food": true, "rule": "Yemek katında yeterli masa ve temiz masalar ister"},
	{"id": "pide", "name": "Pideci", "brand": "NAZLI PİDE", "color": Color("3f8f3a"), "accent": Color("fff1dc"), "rent": 850, "share": 0.12, "spend": [80, 180], "buy": 0.9, "food": true, "rule": "Temiz masa ve aile ziyaretçileri sever"},
]

const VISITORS := [
	{"id": "genc", "name": "Genç", "interests": {"giyim": 3, "elektronik": 2, "oyun": 3, "burger": 2, "spor": 2, "kafe": 1, "sinema": 3}, "stops": [2, 4], "speed": 1.45, "hunger": 0.5, "body": "rogue",
		"curve": [0.3, [16.0, 2.0, 1.2], [20.0, 1.5, 0.8]], "tops": [Color("6c63ff"), Color("2ec4b6"), Color("ff6b6b")], "bottoms": [Color("2b3a67"), Color("3d405b")]},
	{"id": "aile", "name": "Aile", "interests": {"oyuncak": 3, "giyim": 2, "play": 4, "pide": 2, "burger": 1, "kafe": 1, "bench": 1, "sinema": 2}, "stops": [2, 4], "speed": 1.05, "hunger": 0.7, "child": true, "body": "barbarian",
		"curve": [0.2, [12.0, 2.0, 0.8], [18.0, 2.0, 1.2]], "tops": [Color("e76f51"), Color("f4a261"), Color("8ecae6")], "bottoms": [Color("3a5a40"), Color("6d597a")]},
	{"id": "profesyonel", "name": "Profesyonel", "interests": {"elektronik": 3, "kitap": 2, "kafe": 3, "kuafor": 1, "spor": 1, "sinema": 2}, "stops": [1, 3], "speed": 1.4, "hunger": 0.4, "body": "rogue",
		"curve": [0.2, [12.5, 1.0, 1.0], [18.5, 1.2, 1.1]], "tops": [Color("f1faee"), Color("a8dadc"), Color("cdb4db")], "bottoms": [Color("1d3557"), Color("343a40")]},
	{"id": "emekliz", "name": "Emekli Çift", "interests": {"kitap": 2, "kafe": 3, "kuafor": 2, "pide": 1, "bench": 3, "sinema": 1}, "stops": [1, 3], "speed": 0.9, "hunger": 0.5, "lift": true, "body": "mage",
		"curve": [0.3, [11.0, 2.0, 1.0]], "tops": [Color("9c6644"), Color("6b705c"), Color("a5a58d")], "bottoms": [Color("4a4e69"), Color("5e503f")]},
]

const EVENTS := [
	{"id": "konser", "name": "Akşam Konseri", "desc": "Yemek katında sahne kurulur, akşam kalabalık gelir. Gürültülüdür.", "cost": 4000, "visitors": 1.7, "tenants": 1.1, "store": 1.1, "noisy": true},
	{"id": "imza", "name": "İmza Günü", "desc": "Sevilen bir yazar kitabevinde. Kitabevi satışları üç katına çıkar.", "cost": 1500, "visitors": 1.25, "tenants": 1.0, "store": 1.0, "boost": "kitap", "needs": "kitap"},
	{"id": "bayram", "name": "Bayram İndirimleri", "desc": "Her yer süslenir, herkes alışverişte. Süpermarket de kazanır.", "cost": 2500, "visitors": 1.4, "tenants": 1.5, "store": 1.3},
	{"id": "cocuk", "name": "Çocuk Şenliği", "desc": "Balonlar, palyaço, oyun alanında etkinlik. Aileler akın eder.", "cost": 2000, "visitors": 1.3, "tenants": 1.1, "store": 1.05, "family": 2.2, "boost": "oyuncak", "needs": "play"},
]

static func tenant(id: String) -> Dictionary:
	for t in TENANTS: if t["id"] == id: return t
	return {}

static func event(id: String) -> Dictionary:
	for e in EVENTS: if e["id"] == id: return e
	return {}

static func unit_area(u: Dictionary) -> int:
	var r: Rect2i = u["def"]["rect"]
	return r.size.x * r.size.y
