class_name DB
## Data-driven game content (products, fixtures, customers, stages). Everything is fictional/original.

const DISPLAY_LABEL := {"shelf": "Raf", "fridge": "Soğutucu", "basket": "Fırın sepeti", "produce": "Manav tezgâhı"}

const PRODUCTS := [
	{"id": "cips", "name": "Cips", "brand": "ÇITIR", "display": "shelf", "cost": 9, "base": 20, "color": Color("f6b93b"), "accent": Color("d8402b"), "shape": "bag", "stage": 0},
	{"id": "cikolata", "name": "Çikolata", "brand": "KAKAO+", "display": "shelf", "cost": 6, "base": 14, "color": Color("5a2f22"), "accent": Color("f0c35a"), "shape": "bar", "impulse": true, "stage": 0},
	{"id": "biskuvi", "name": "Bisküvi", "brand": "ÇAYYANI", "display": "shelf", "cost": 8, "base": 17, "color": Color("2e6db4"), "accent": Color("f6d67e"), "shape": "box", "stage": 0},
	{"id": "kola", "name": "Kola", "brand": "KÖPÜK", "display": "fridge", "cost": 11, "base": 25, "color": Color("d8352c"), "accent": Color("ffffff"), "shape": "bottle", "stage": 0},
	{"id": "ayran", "name": "Ayran", "brand": "YAYLA", "display": "fridge", "cost": 7, "base": 15, "color": Color("f6f8fb"), "accent": Color("2b7fd8"), "shape": "cup", "stage": 0},
	{"id": "simit", "name": "Simit", "brand": "FIRIN", "display": "basket", "cost": 5, "base": 12, "color": Color("c9803e"), "accent": Color("f3dcae"), "shape": "ring", "stage": 0},
	{"id": "ekmek", "name": "Ekmek", "brand": "FIRIN", "display": "basket", "cost": 6, "base": 12, "color": Color("d99a55"), "accent": Color("f7e2b8"), "shape": "loaf", "stage": 0},
	{"id": "domates", "name": "Domates", "brand": "BAHÇE", "display": "produce", "cost": 14, "base": 26, "color": Color("e2432f"), "accent": Color("3f8f3a"), "shape": "fruit", "stage": 1},
	{"id": "elma", "name": "Elma", "brand": "BAHÇE", "display": "produce", "cost": 12, "base": 22, "color": Color("9ccc3a"), "accent": Color("d6452e"), "shape": "fruit", "stage": 1},
	{"id": "sut", "name": "Süt", "brand": "YAYLA", "display": "fridge", "cost": 18, "base": 32, "color": Color("f7f7f2"), "accent": Color("33a4d8"), "shape": "carton", "stage": 1},
	{"id": "deterjan", "name": "Deterjan", "brand": "PARLAK", "display": "shelf", "cost": 38, "base": 65, "color": Color("3fb6a8"), "accent": Color("ffffff"), "shape": "jug", "stage": 1},
]

const FIXTURES := [
	{"id": "raf", "name": "Ahşap Raf", "desc": "Kuru gıda için iki bölmeli sıcak ahşap raf.", "kind": "display", "cat": "Teşhir", "w": 2, "d": 1, "cost": 600, "stage": 0, "display": "shelf", "slots": 2, "cap": 12},
	{"id": "dolap", "name": "İçecek Dolabı", "desc": "Işıklı cam kapaklı soğutucu. Soğuk ürünler burada durur.", "kind": "display", "cat": "Teşhir", "w": 1, "d": 1, "cost": 1200, "stage": 0, "display": "fridge", "slots": 2, "cap": 10},
	{"id": "sepet", "name": "Fırın Sepeti", "desc": "İki katlı hasır sepet: simit ve ekmek sabahın yıldızı.", "kind": "display", "cat": "Teşhir", "w": 1, "d": 1, "cost": 350, "stage": 0, "display": "basket", "slots": 2, "cap": 10},
	{"id": "kasa", "name": "Kasa Tezgâhı", "desc": "Müşteriler burada öder. Kasiyer arkasında durur, kuyruk kapıya doğru uzar.", "kind": "register", "cat": "Kasa & Depo", "w": 2, "d": 1, "cost": 1500, "stage": 0, "max": [1, 3]},
	{"id": "depo", "name": "Depo Rafı", "desc": "Yedek stok burada tutulur. +80 birim depo kapasitesi.", "kind": "depot", "cat": "Kasa & Depo", "w": 2, "d": 1, "cost": 800, "stage": 0, "depot": 80},
	{"id": "saksi", "name": "Saksı Bitki", "desc": "Çevresindeki alışverişi daha keyifli yapar, kuyrukta sabrı artırır.", "kind": "plant", "cat": "Ortam", "w": 1, "d": 1, "cost": 150, "stage": 0},
	{"id": "cop", "name": "Çöp Kovası", "desc": "Yakınına (3 m) yere çöp atılmaz.", "kind": "bin", "cat": "Ortam", "w": 1, "d": 1, "cost": 120, "stage": 0},
	{"id": "gondol", "name": "Orta Gondol", "desc": "Üç bölmeli metal gondol reyon. Market düzeninin omurgası.", "kind": "display", "cat": "Teşhir", "w": 3, "d": 1, "cost": 1400, "stage": 1, "display": "shelf", "slots": 3, "cap": 14},
	{"id": "manav", "name": "Manav Tezgâhı", "desc": "Eğimli kasalarda taze meyve ve sebze.", "kind": "display", "cat": "Teşhir", "w": 2, "d": 1, "cost": 1100, "stage": 1, "display": "produce", "slots": 2, "cap": 16},
	{"id": "acik", "name": "Açık Soğutucu", "desc": "Kapısız, üç bölmeli geniş soğutucu. Hızlı alışveriş.", "kind": "display", "cat": "Teşhir", "w": 3, "d": 1, "cost": 3200, "stage": 1, "display": "fridge", "slots": 3, "cap": 10},
]

static func bell(h: float, c: float, w: float) -> float:
	return exp(-((h - c) * (h - c)) / (2.0 * w * w))

## hour curve = base + sum(amp * bell(h, c, w))
const ARCHETYPES := [
	{"id": "ogrenci", "name": "Öğrenci", "blurb": "Az parası var, atıştırmalık ve soğuk içecek peşinde. Sabırsız.", "stage": 0,
		"budget": [25, 60], "wants": {"cips": 5, "cikolata": 4, "kola": 5, "biskuvi": 2, "simit": 2}, "list": [1, 2],
		"patience": 22.0, "tol": 0.12, "speed": 1.55, "litter": 0.012, "impulse": 0.45, "body": "rogue",
		"tops": [Color("6c63ff"), Color("2ec4b6"), Color("ff6b6b"), Color("ffb400")], "bottoms": [Color("2b3a67"), Color("3d405b"), Color("264653")],
		"curve": [0.25, [8.0, 0.8, 0.8], [16.0, 1.4, 1.6]]},
	{"id": "emekli", "name": "Emekli", "blurb": "Fiyata çok duyarlı. Sabah ekmeğini ve ayranını alır, beklemeye razıdır.", "stage": 0,
		"budget": [30, 90], "wants": {"ekmek": 6, "simit": 3, "ayran": 4, "biskuvi": 3, "sut": 3, "domates": 3}, "list": [1, 3],
		"patience": 48.0, "tol": 0.06, "speed": 0.95, "litter": 0.0, "impulse": 0.12, "body": "mage",
		"tops": [Color("9c6644"), Color("6b705c"), Color("a5a58d"), Color("7f5539")], "bottoms": [Color("4a4e69"), Color("5e503f")],
		"curve": [0.2, [8.5, 1.4, 1.6], [13.0, 1.5, 0.5]]},
	{"id": "calisan", "name": "Beyaz Yaka", "blurb": "Aceleci ama cömert. Kuyrukta beklemeyi hiç sevmez.", "stage": 0,
		"budget": [60, 180], "wants": {"kola": 4, "ayran": 3, "simit": 4, "cips": 2, "cikolata": 2, "biskuvi": 1}, "list": [1, 3],
		"patience": 16.0, "tol": 0.35, "speed": 1.45, "litter": 0.002, "impulse": 0.3, "body": "rogue",
		"tops": [Color("f1faee"), Color("a8dadc"), Color("e9ecef"), Color("cdb4db")], "bottoms": [Color("1d3557"), Color("343a40"), Color("22223b")],
		"curve": [0.15, [8.0, 0.7, 1.4], [12.5, 0.8, 1.0], [18.5, 1.0, 1.5]]},
	{"id": "aile", "name": "Aile Alışverişçisi", "blurb": "Uzun listeyle gelir, sepeti doldurur. Taze ürün ve temiz mağaza ister.", "stage": 1,
		"budget": [120, 320], "wants": {"ekmek": 3, "sut": 4, "domates": 4, "elma": 4, "deterjan": 2, "biskuvi": 2, "ayran": 2, "cikolata": 1}, "list": [3, 5],
		"patience": 34.0, "tol": 0.15, "speed": 1.1, "litter": 0.001, "impulse": 0.35, "body": "barbarian",
		"tops": [Color("e76f51"), Color("f4a261"), Color("8ecae6"), Color("b5838d")], "bottoms": [Color("3a5a40"), Color("6d597a"), Color("1d3557")],
		"curve": [0.2, [11.0, 1.8, 1.0], [18.0, 1.5, 1.3]]},
]

static func curve(a: Dictionary, h: float) -> float:
	var c: Array = a["curve"]
	var v: float = c[0]
	for i in range(1, c.size()):
		v += c[i][2] * bell(h, c[i][0], c[i][1])
	return v

const STAGES := [
	{"name": "Mahalle Büfesi", "short": "Büfe", "rent": 250, "utilities": 0, "max_inside": 11},
	{"name": "Mahalle Marketi", "short": "Market", "rent": 700, "utilities": 150, "max_inside": 28},
]

const UPGRADES := [
	{"id": "neon", "name": "Neon Tabela", "desc": "Gece parlayan tabela; yoldan geçenlerin dikkatini çeker.", "cost": 1800, "stage": 0, "effect": "+%25 müşteri çekimi, gece ışıltısı"},
	{"id": "pos", "name": "Temassız POS", "desc": "Kartla hızlı ödeme. Kasa işlemleri kısalır.", "cost": 2400, "stage": 0, "effect": "Kasa süresi −%35"},
	{"id": "tente", "name": "Yeni Tente & Vitrin", "desc": "Çizgili tente ve dolu vitrin; dükkân daha davetkâr görünür.", "cost": 1200, "stage": 0, "effect": "+%10 çekim"},
	{"id": "etiket", "name": "Elektronik Raf Etiketi", "desc": "Fiyatlar raflarda anında güncellenir, müşteri fiyata güvenir.", "cost": 3500, "stage": 1, "effect": "Fiyat toleransı +%5"},
	{"id": "isik", "name": "Sıcak Raf Aydınlatması", "desc": "Ürünler parlar, reyonlar davetkâr olur.", "cost": 2800, "stage": 1, "effect": "Ortam +, anlık alım +%20"},
]

const EXPANSIONS := [
	{"to": 1, "cost": 12000, "title": "Yan Dükkânı Devral",
		"pitch": "Soldaki kapalı dükkânın kepengi aylardır inik. Duvarı yıkıp büfeyi Mahalle Marketi'ne dönüştür: iki kat alan, ikinci kapı, manav tezgâhı, gondol reyonlar ve aile alışverişçileri.",
		"goals": [["rating", "Mağaza puanı", 3.6], ["served", "Mutlu ayrılan müşteri", 200], ["cash", "Kasada nakit", 12000]],
		"unlocks": "Manav tezgâhı · Orta gondol · Açık soğutucu · 3 kasa · Süt, deterjan, domates, elma · Aile alışverişçileri · 2. kapı"},
]

const ROLE_LABEL := {"owner": "Dükkân Sahibi", "cashier": "Kasiyer", "stocker": "Reyon Görevlisi"}
const ROLE_DESC := {
	"owner": "Kasaya bakar. Kuyruk yokken ve yardımcı yoksa rafları kendisi doldurur; o sırada kasa boş kalır.",
	"cashier": "Boştaki kasaya geçer ve ödemeleri alır.",
	"stocker": "Depodan koli taşıyıp azalan rafları doldurur, boşta kalınca çöp toplar.",
}
const ROLE_WAGE := {"owner": 0, "cashier": 300, "stocker": 260}

static var _pmap := {}
static var _fmap := {}

static func product(id: String) -> Dictionary:
	if _pmap.is_empty():
		for p in PRODUCTS: _pmap[p["id"]] = p
	return _pmap[id]

static func fixture(id: String) -> Dictionary:
	if _fmap.is_empty():
		for f in FIXTURES: _fmap[f["id"]] = f
	return _fmap[id]
