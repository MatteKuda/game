class_name Cfg
## Global tuning + world layout. Tile = 1 m; tile (x, z) has its centre at (x + 0.5, z + 0.5).

const MAP_W := 44
const MAP_H := 34

const SIDEWALK_Z0 := 16 # near sidewalk rows 16..18
const SIDEWALK_Z1 := 19
const ROAD_Z0 := 19 # road rows 19..24
const ROAD_Z1 := 25
const FAR_WALK_Z0 := 25 # far sidewalk rows 25..26
const FAR_WALK_Z1 := 27

const WALL_H := 3.1

## game minutes per real second at 1x
const MIN_PER_SEC := 2.0
const DAY_OPEN := 7 * 60
const DAY_CLOSE := 22 * 60

## x1/z1 exclusive
const STAGE_LAYOUTS := [
	{"interior": Rect2i(18, 10, 8, 6), "doors": [22, 23]},
	{"interior": Rect2i(10, 6, 16, 10), "doors": [13, 14, 22, 23]},
]

const NAMES := [
	"Ayşe", "Mehmet", "Zeynep", "Emre", "Elif", "Can", "Fatma", "Hasan", "Deniz", "Selin",
	"Burak", "Hatice", "Mustafa", "Ece", "Kerem", "Gül", "Oğuz", "Seda", "Tarık", "Nermin",
	"Yusuf", "Melek", "Cem", "Derya", "Kaan", "Sibel", "Levent", "Pınar", "Tuncay", "Aslı",
	"Halil", "Esra", "Onur", "Filiz", "Serkan", "Nazlı", "İlker", "Songül", "Barış", "Dilek",
]

# "Mahalle Pop" palette — shared by world and UI
const CREAM := Color("fff1dc")
const PAPER := Color("fbf6ee")
const TERRA := Color("e0663c")
const TERRA_DARK := Color("b44a28")
const TEAL := Color("1f8a86")
const TEAL_DARK := Color("136361")
const MUSTARD := Color("f2b33d")
const INK := Color("1f2a44")
const INK2 := Color("4a5570")
const INK3 := Color("8a93a8")
const MINT := Color("86d6b4")
const ROSE := Color("f08f86")
const WOOD := Color("c98b52")
const WOOD_DARK := Color("8a5a35")
const STEEL := Color("c3cad2")
const STEEL_DARK := Color("5b6570")
const ASPHALT := Color("4a4f58")
const CURB := Color("c9c2b6")
const GOOD := Color("2fae7a")
const WARN := Color("e8962c")
const BAD := Color("e5484d")
const VIOLET := Color("7a5ae0")
const BLUE := Color("2f6fb5")

static func fmt_money(v: float) -> String:
	var n := int(round(v))
	var neg := n < 0
	var s := str(abs(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("−" if neg else "") + "₺" + s + out

static func clock_str(minutes: float) -> String:
	var m := int(minutes)
	return "%02d:%02d" % [m / 60, m % 60]
