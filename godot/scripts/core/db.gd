class_name DB
## Data-driven game content (products, fixtures, customers, stages). Everything is fictional/original.

const DISPLAY_LABEL := {"shelf": "Raf", "fridge": "Soğutucu", "basket": "Fırın sepeti", "produce": "Manav tezgâhı", "freezer": "Dondurma dolabı", "deli": "Şarküteri"}

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
	{"id": "makarna", "name": "Makarna", "brand": "BURGU", "display": "shelf", "cost": 11, "base": 22, "color": Color("f2d04b"), "accent": Color("2e5fa8"), "shape": "bag", "stage": 2},
	{"id": "cay", "name": "Çay", "brand": "KARADENİZ", "display": "shelf", "cost": 45, "base": 85, "color": Color("2f7a3a"), "accent": Color("f2b33d"), "shape": "box", "stage": 2},
	{"id": "peynir", "name": "Beyaz Peynir", "brand": "YAYLA", "display": "fridge", "cost": 60, "base": 110, "color": Color("faf6e8"), "accent": Color("3f8f3a"), "shape": "wedge", "stage": 2},
	{"id": "su", "name": "Su", "brand": "PINAR BAŞI", "display": "fridge", "cost": 4, "base": 10, "color": Color("7fc4ea"), "accent": Color("ffffff"), "shape": "bottle", "stage": 2},
	# büfe classics
	{"id": "dondurma", "name": "Dondurma", "brand": "KARLI", "display": "freezer", "cost": 8, "base": 20, "color": Color("f7d6e0"), "accent": Color("8a5a35"), "shape": "cone", "impulse": true, "stage": 0, "season": "yaz"},
	{"id": "gazete", "name": "Gazete", "brand": "SABAH POSTASI", "display": "shelf", "cost": 6, "base": 9, "color": Color("f2efe6"), "accent": Color("d6333a"), "shape": "paper", "stage": 0},
	{"id": "sakiz", "name": "Sakız", "brand": "BALONCUK", "display": "shelf", "cost": 2, "base": 6, "color": Color("7fd6c2"), "accent": Color("ffffff"), "shape": "pack", "impulse": true, "stage": 0},
	{"id": "salep", "name": "Salep", "brand": "KIŞ SICAĞI", "display": "shelf", "cost": 18, "base": 38, "color": Color("c9a27a"), "accent": Color("7a4a2a"), "shape": "box", "stage": 0, "season": "kış"},
	{"id": "defter", "name": "Defter", "brand": "ÇİZGİ", "display": "shelf", "cost": 7, "base": 18, "color": Color("2f6fb5"), "accent": Color("f2b33d"), "shape": "notebook", "stage": 0, "season": "okul"},
	# mahalle marketi
	{"id": "yumurta", "name": "Yumurta", "brand": "KÖY", "display": "shelf", "cost": 30, "base": 55, "color": Color("f3e3c3"), "accent": Color("7a9a3a"), "shape": "eggbox", "stage": 1},
	{"id": "yogurt", "name": "Yoğurt", "brand": "YAYLA", "display": "fridge", "cost": 22, "base": 42, "color": Color("ffffff"), "accent": Color("2f6fb5"), "shape": "tub", "stage": 1},
	{"id": "zeytin", "name": "Zeytin", "brand": "EGE", "display": "shelf", "cost": 40, "base": 75, "color": Color("3d4a2a"), "accent": Color("f2b33d"), "shape": "jar", "stage": 1},
	{"id": "sampuan", "name": "Şampuan", "brand": "KÖPÜKLÜ", "display": "shelf", "cost": 35, "base": 68, "color": Color("e070a0"), "accent": Color("ffffff"), "shape": "bottle2", "stage": 1},
	{"id": "hurma", "name": "Hurma", "brand": "VAHA", "display": "shelf", "cost": 30, "base": 60, "color": Color("6b3a1f"), "accent": Color("f2b33d"), "shape": "tray", "stage": 1, "season": "ramazan"},
	{"id": "semsiye", "name": "Şemsiye", "brand": "DAMLA", "display": "shelf", "cost": 45, "base": 95, "color": Color("1f2a44"), "accent": Color("e0663c"), "shape": "umbrella", "stage": 1, "season": "yağmur"},
	# süpermarket
	{"id": "un", "name": "Un", "brand": "DEĞİRMEN", "display": "shelf", "cost": 28, "base": 48, "color": Color("f7f2e6"), "accent": Color("d6333a"), "shape": "sack", "stage": 2, "staple": true},
	{"id": "seker", "name": "Toz Şeker", "brand": "KRİSTAL", "display": "shelf", "cost": 26, "base": 45, "color": Color("ffffff"), "accent": Color("2f6fb5"), "shape": "bag", "stage": 2, "staple": true},
	{"id": "yag", "name": "Ayçiçek Yağı", "brand": "GÜNEŞLİ", "display": "shelf", "cost": 70, "base": 115, "color": Color("f2d04b"), "accent": Color("2fae7a"), "shape": "jug", "stage": 2, "staple": true},
	{"id": "sucuk", "name": "Sucuk", "brand": "KASAP", "display": "deli", "cost": 90, "base": 170, "color": Color("9a2a1e"), "accent": Color("f2d9a0"), "shape": "sausage", "stage": 2},
	{"id": "kasar", "name": "Kaşar", "brand": "KASAP", "display": "deli", "cost": 80, "base": 150, "color": Color("f2c14e"), "accent": Color("c9803e"), "shape": "wheel", "stage": 2},
	{"id": "pizza", "name": "Donuk Pizza", "brand": "BUZDAĞI", "display": "freezer", "cost": 45, "base": 85, "color": Color("d6333a"), "accent": Color("f2b33d"), "shape": "flatbox", "stage": 2},
	{"id": "bebekbezi", "name": "Bebek Bezi", "brand": "PAMUKÇUK", "display": "shelf", "cost": 120, "base": 210, "color": Color("8ecae6"), "accent": Color("ffffff"), "shape": "bigbox", "stage": 2},
	{"id": "pide", "name": "Ramazan Pidesi", "brand": "FIRIN", "display": "basket", "cost": 8, "base": 20, "color": Color("d99a55"), "accent": Color("7a4a2a"), "shape": "pide", "stage": 1, "season": "ramazan", "only_season": true},
]

## baked in-house at the Fırın Tezgâhı: unit cost of flour & fuel
const BAKED := {"simit": 2.0, "ekmek": 2.5, "pide": 3.0}
const BAKERY := ["simit", "ekmek", "pide"]
## freshness lost per game minute (bread goes stale in ~10 hours)
const STALE_RATE := 1.0 / 600.0
static func is_cold(pid: String) -> bool: return product(pid)["display"] in ["fridge", "freezer", "deli"]

const FIXTURES := [
	{"id": "raf", "name": "Ahşap Raf", "desc": "Kuru gıda için iki bölmeli sıcak ahşap raf.", "kind": "display", "cat": "Teşhir", "w": 2, "d": 1, "cost": 600, "stage": 0, "display": "shelf", "slots": 2, "cap": 12},
	{"id": "dolap", "name": "İçecek Dolabı", "desc": "Işıklı cam kapaklı soğutucu. Soğuk ürünler burada durur.", "kind": "display", "cat": "Teşhir", "w": 1, "d": 1, "cost": 1200, "stage": 0, "display": "fridge", "slots": 2, "cap": 10, "power": 30},
	{"id": "sepet", "name": "Fırın Sepeti", "desc": "İki katlı hasır sepet: simit ve ekmek sabahın yıldızı.", "kind": "display", "cat": "Teşhir", "w": 1, "d": 1, "cost": 350, "stage": 0, "display": "basket", "slots": 2, "cap": 10},
	{"id": "kasa", "name": "Kasa Tezgâhı", "desc": "Müşteriler burada öder. Kasiyer arkasında durur, kuyruk kapıya doğru uzar.", "kind": "register", "cat": "Kasa & Depo", "w": 2, "d": 1, "cost": 1500, "stage": 0, "max": [1, 3, 4, 4]},
	{"id": "depo", "name": "Depo Rafı", "desc": "Yedek stok burada tutulur. +240 birim depo kapasitesi.", "kind": "depot", "cat": "Kasa & Depo", "w": 2, "d": 1, "cost": 800, "stage": 0, "depot": 240},
	{"id": "derin", "name": "Dondurma Dolabı", "desc": "Cam kapaklı derin dondurucu. Yazın kapının yanında altın değerinde; donuk ürünler de burada durur.", "kind": "display", "cat": "Teşhir", "w": 2, "d": 1, "cost": 1600, "stage": 0, "display": "freezer", "slots": 2, "cap": 12, "power": 35},
	{"id": "saksi", "name": "Saksı Bitki", "desc": "Çevresindeki alışverişi daha keyifli yapar, kuyrukta sabrı artırır.", "kind": "plant", "cat": "Ortam", "w": 1, "d": 1, "cost": 150, "stage": 0, "zone": "any"},
	{"id": "cop", "name": "Çöp Kovası", "desc": "Yakınına (3 m) yere çöp atılmaz.", "kind": "bin", "cat": "Ortam", "w": 1, "d": 1, "cost": 120, "stage": 0, "zone": "any"},
	{"id": "gondol", "name": "Orta Gondol", "desc": "Üç bölmeli metal gondol reyon. Market düzeninin omurgası.", "kind": "display", "cat": "Teşhir", "w": 3, "d": 1, "cost": 1400, "stage": 1, "display": "shelf", "slots": 3, "cap": 14},
	{"id": "manav", "name": "Manav Tezgâhı", "desc": "Eğimli kasalarda taze meyve ve sebze.", "kind": "display", "cat": "Teşhir", "w": 2, "d": 1, "cost": 1100, "stage": 1, "display": "produce", "slots": 2, "cap": 16},
	{"id": "acik", "name": "Açık Soğutucu", "desc": "Kapısız, üç bölmeli geniş soğutucu. Hızlı alışveriş.", "kind": "display", "cat": "Teşhir", "w": 3, "d": 1, "cost": 3200, "stage": 1, "display": "fridge", "slots": 3, "cap": 10, "power": 60},
	{"id": "kamera", "name": "Güvenlik Kamerası", "desc": "Tavana asılı dönen kamera. Görüş konisindeki hırsızlar fark edilir (6 m). Yüksek raflar görüşü keser.", "kind": "camera", "cat": "Güvenlik & Personel", "w": 1, "d": 1, "cost": 900, "stage": 1, "zone": "any", "noblock": true, "radius": 6.0},
	{"id": "alarm", "name": "Alarm Kapısı", "desc": "Kapının yanına kurulur. Ödenmemiş ürünle geçenlerde öter (%85).", "kind": "gate", "cat": "Güvenlik & Personel", "w": 1, "d": 1, "cost": 1600, "stage": 1},
	{"id": "cay_ocagi", "name": "Çay Ocağı (Mola)", "desc": "Yorulan personel burada çay içip dinlenir. Molasız personel yavaşlar.", "kind": "break", "cat": "Güvenlik & Personel", "w": 2, "d": 1, "cost": 700, "stage": 0},
	{"id": "bantkasa", "name": "Bantlı Kasa", "desc": "Yürüyen bantlı kasa. Ödeme %35 daha hızlı, uzun kuyruk için ideal.", "kind": "register", "cat": "Kasa & Depo", "w": 3, "d": 1, "cost": 4200, "stage": 2, "service": 0.65, "max": [0, 0, 5, 6]},
	{"id": "selfkasa", "name": "Self-Servis Kasa", "desc": "Kasiyer gerektirmez ama yavaştır ve kayıp riskini artırır.", "kind": "register", "cat": "Kasa & Depo", "w": 1, "d": 1, "cost": 3000, "stage": 2, "service": 1.35, "self": true, "max": [0, 0, 6, 8]},
	{"id": "levha", "name": "Reyon Levhası", "desc": "Tavandan asılı kategori levhası. Yakınındaki (5 m) rafları bulmak kolaylaşır.", "kind": "sign", "cat": "Ortam", "w": 1, "d": 1, "cost": 250, "stage": 2, "noblock": true, "radius": 5.0},
	{"id": "firin", "name": "Fırın Tezgâhı", "desc": "Fırıncı burada sıcak simit ve ekmek pişirir: ucuz maliyet, mutlu müşteri.", "kind": "oven", "cat": "Teşhir", "w": 2, "d": 1, "cost": 5200, "stage": 2, "power": 80},
	{"id": "araba", "name": "Alışveriş Arabası Parkı", "desc": "Haftalık alışverişçiler araba alır; yoksa listeleri kısalır.", "kind": "carts", "cat": "Kasa & Depo", "w": 2, "d": 1, "cost": 1100, "stage": 2},
	{"id": "gondolbasi", "name": "Gondol Başı Teşhir", "desc": "Koridor başında göz alıcı teşhir. Yanından geçen müşteri listesinde olmasa da alabilir.", "kind": "display", "cat": "Teşhir", "w": 1, "d": 1, "cost": 900, "stage": 2, "display": "shelf", "slots": 1, "cap": 12, "endcap": true},
	{"id": "sarkuteri", "name": "Şarküteri Tezgâhı", "desc": "Camlı soğuk tezgâh: sucuk ve kaşar kesilip tartılır. Kârlı ama arkasında bir Şarküteri Ustası durmalı.", "kind": "display", "cat": "Teşhir", "w": 3, "d": 1, "cost": 5600, "stage": 2, "display": "deli", "slots": 2, "cap": 10, "staffed": true, "power": 45},
	{"id": "depooda", "name": "Depo Odası", "desc": "Duvarlı, personele özel depo. +600 birim kapasite; müşteri alanını raflarla doldurmaz.", "kind": "depot", "cat": "Odalar", "w": 3, "d": 3, "cost": 6500, "stage": 2, "depot": 600, "room": "DEPO"},
	{"id": "soguk", "name": "Soğuk Oda", "desc": "Süt, ayran, peynir ve içecekler bozulmaz. Soğuk oda yoksa depodaki soğuk ürünlerin %30'u her gece bozulur. +150 kapasite.", "kind": "depot", "cat": "Odalar", "w": 3, "d": 2, "cost": 7800, "stage": 2, "depot": 150, "cold": true, "room": "SOĞUK ODA", "power": 90},
	{"id": "molaodasi", "name": "Mola Odası", "desc": "Kanepe, çay ve dolap: personel çay ocağından iki kat hızlı dinlenir ve biraz daha hızlı çalışır.", "kind": "break", "cat": "Odalar", "w": 3, "d": 2, "cost": 4200, "stage": 2, "rest": 2.2, "room": "MOLA"},
	{"id": "masa", "name": "Yemek Masası", "desc": "Yemek katı için 4 kişilik masa. Kirlenince temizlik görevlisi toplar.", "kind": "table", "cat": "AVM", "w": 2, "d": 2, "cost": 700, "stage": 3, "zone": "mall", "seats": 4},
	{"id": "oyunalani", "name": "Çocuk Oyun Alanı", "desc": "Kaydırak ve top havuzu. Aileler uzun kalır, oyuncakçı mutlu olur.", "kind": "play", "cat": "AVM", "w": 3, "d": 3, "cost": 6000, "stage": 3, "zone": "mall"},
	{"id": "wc", "name": "Tuvalet", "desc": "Bay ve bayan tuvaleti. Ziyaretçiler ihtiyaç duyar; kirlenince temizlik görevlisi siler. Tuvaletsiz AVM'de herkes söylenir.", "kind": "wc", "cat": "AVM", "w": 3, "d": 2, "cost": 5000, "stage": 3, "zone": "mall"},
	# decoration: all count as greenery/ambiance around them (kind "plant") and raise queue patience
	{"id": "lamba", "name": "Ayaklı Lamba", "desc": "Sıcak sarı ışık. Çevresi daha davetkâr olur, akşamları dükkân yuva gibi görünür.", "kind": "plant", "cat": "Ortam", "w": 1, "d": 1, "cost": 300, "stage": 0, "zone": "any", "deco": true},
	{"id": "cicekstand", "name": "Çiçek Standı", "desc": "Kovalarda mevsim çiçekleri. Kapının yanında herkesin yüzünü güldürür.", "kind": "plant", "cat": "Ortam", "w": 2, "d": 1, "cost": 650, "stage": 1, "zone": "any", "deco": true},
	{"id": "akvaryum", "name": "Akvaryum", "desc": "Kasanın yanında renkli balıklar: kuyrukta bekleyenler oyalanır, çocuklar bayılır.", "kind": "plant", "cat": "Ortam", "w": 2, "d": 1, "cost": 1500, "stage": 2, "zone": "any", "deco": true},
	{"id": "fiskiye", "name": "Süs Havuzu", "desc": "Fıskiyeli küçük havuz. AVM'nin buluşma noktası olur.", "kind": "plant", "cat": "Ortam", "w": 2, "d": 2, "cost": 3800, "stage": 3, "zone": "mall", "deco": true},
	{"id": "bank", "name": "Dinlenme Bankı", "desc": "Yorulan ziyaretçiler oturur, AVM keyfi artar.", "kind": "bench", "cat": "AVM", "w": 2, "d": 1, "cost": 400, "stage": 3, "zone": "mall"},
]

static func zone(d: Dictionary) -> String: return d.get("zone", "store")

static func bell(h: float, c: float, w: float) -> float:
	return exp(-((h - c) * (h - c)) / (2.0 * w * w))

## hour curve = base + sum(amp * bell(h, c, w))
const ARCHETYPES := [
	{"id": "ogrenci", "name": "Öğrenci", "blurb": "Az parası var, atıştırmalık ve soğuk içecek peşinde. Sabırsız.", "stage": 0,
		"budget": [25, 60], "wants": {"cips": 5, "cikolata": 4, "kola": 5, "biskuvi": 2, "simit": 2, "su": 2, "dondurma": 4, "sakiz": 3, "defter": 2}, "list": [1, 2],
		"patience": 22.0, "tol": 0.12, "speed": 1.55, "litter": 0.012, "impulse": 0.45, "body": "rogue",
		"tops": [Color("6c63ff"), Color("2ec4b6"), Color("ff6b6b"), Color("ffb400")], "bottoms": [Color("2b3a67"), Color("3d405b"), Color("264653")],
		"curve": [0.25, [8.0, 0.8, 0.8], [16.0, 1.4, 1.6]]},
	{"id": "emekli", "name": "Emekli", "blurb": "Fiyata çok duyarlı. Sabah ekmeğini ve ayranını alır, beklemeye razıdır.", "stage": 0,
		"budget": [30, 90], "wants": {"ekmek": 6, "simit": 3, "ayran": 4, "biskuvi": 3, "sut": 3, "domates": 3, "cay": 2, "peynir": 2, "gazete": 5, "salep": 2, "yumurta": 2, "yogurt": 3, "zeytin": 2, "hurma": 1, "pide": 4}, "list": [1, 3],
		"patience": 48.0, "tol": 0.06, "speed": 0.95, "litter": 0.0, "impulse": 0.12, "body": "mage",
		"tops": [Color("9c6644"), Color("6b705c"), Color("a5a58d"), Color("7f5539")], "bottoms": [Color("4a4e69"), Color("5e503f")],
		"curve": [0.2, [8.5, 1.4, 1.6], [13.0, 1.5, 0.5]]},
	{"id": "calisan", "name": "Beyaz Yaka", "blurb": "Aceleci ama cömert. Kuyrukta beklemeyi hiç sevmez.", "stage": 0,
		"budget": [60, 180], "wants": {"kola": 4, "ayran": 3, "simit": 4, "cips": 2, "cikolata": 2, "biskuvi": 1, "su": 3, "gazete": 2, "sakiz": 2, "dondurma": 2, "semsiye": 1}, "list": [1, 3],
		"patience": 16.0, "tol": 0.35, "speed": 1.45, "litter": 0.002, "impulse": 0.3, "body": "rogue",
		"tops": [Color("f1faee"), Color("a8dadc"), Color("e9ecef"), Color("cdb4db")], "bottoms": [Color("1d3557"), Color("343a40"), Color("22223b")],
		"curve": [0.15, [8.0, 0.7, 1.4], [12.5, 0.8, 1.0], [18.5, 1.0, 1.5]]},
	{"id": "aile", "name": "Aile Alışverişçisi", "blurb": "Uzun listeyle gelir, sepeti doldurur. Taze ürün ve temiz mağaza ister.", "stage": 1,
		"budget": [120, 320], "wants": {"ekmek": 3, "sut": 4, "domates": 4, "elma": 4, "deterjan": 2, "biskuvi": 2, "ayran": 2, "cikolata": 1, "makarna": 2, "peynir": 2, "yumurta": 3, "yogurt": 3, "zeytin": 2, "sampuan": 2, "dondurma": 2, "defter": 2, "un": 1, "seker": 1, "yag": 1, "kasar": 2, "sucuk": 2, "pizza": 2, "bebekbezi": 2, "semsiye": 1, "pide": 2, "hurma": 1}, "list": [3, 5],
		"patience": 34.0, "tol": 0.15, "speed": 1.1, "litter": 0.001, "impulse": 0.35, "body": "barbarian",
		"tops": [Color("e76f51"), Color("f4a261"), Color("8ecae6"), Color("b5838d")], "bottoms": [Color("3a5a40"), Color("6d597a"), Color("1d3557")],
		"curve": [0.2, [11.0, 1.8, 1.0], [18.0, 1.5, 1.3]]},
	{"id": "firsatci", "name": "Fırsatçı", "blurb": "Kimse bakmıyorsa cebine bir şey atar ve kapıya yönelir. Kamera, alarm ve güvenlik onu caydırır.", "stage": 1,
		"budget": [0, 10], "wants": {"deterjan": 4, "cikolata": 3, "kola": 2, "peynir": 4, "cay": 3, "cips": 2, "sampuan": 3, "kasar": 3, "sucuk": 3, "bebekbezi": 2, "zeytin": 2}, "list": [1, 3],
		"patience": 30.0, "tol": 0.0, "speed": 1.35, "litter": 0.004, "impulse": 0.0, "body": "hooded", "thief": true,
		"tops": [Color("2f3440"), Color("3d3a4a"), Color("4a4f3a")], "bottoms": [Color("22252c"), Color("2b3a55")],
		"curve": [0.06, [20.0, 2.0, 0.1]]},
	{"id": "haftalik", "name": "Haftalık Alışverişçi", "blurb": "Arabayla gelir, 5–8 kalemlik uzun liste. Reyon levhası ve araba parkı ister.", "stage": 2,
		"budget": [250, 600], "wants": {"makarna": 3, "cay": 2, "peynir": 3, "su": 3, "sut": 3, "ekmek": 2, "deterjan": 2, "domates": 2, "elma": 2, "biskuvi": 1, "ayran": 1, "un": 3, "seker": 3, "yag": 3, "kasar": 2, "sucuk": 2, "pizza": 2, "bebekbezi": 2, "yumurta": 2, "yogurt": 2, "zeytin": 2, "sampuan": 2, "hurma": 1}, "list": [5, 8],
		"patience": 40.0, "tol": 0.12, "speed": 1.1, "litter": 0.001, "impulse": 0.4, "body": "mage", "cart": true,
		"tops": [Color("5a7d9a"), Color("c97b63"), Color("8a9a5b"), Color("e0c38c")], "bottoms": [Color("2b3a55"), Color("4a4e69")],
		"curve": [0.1, [11.0, 2.0, 0.9], [18.5, 1.5, 1.1]]},
]

static func curve(a: Dictionary, h: float) -> float:
	var c: Array = a["curve"]
	var v: float = c[0]
	for i in range(1, c.size()):
		v += c[i][2] * bell(h, c[i][0], c[i][1])
	return v

const STAGES := [
	{"name": "Mahalle Büfesi", "short": "Büfe", "rent": 250, "utilities": 20, "max_inside": 11},
	{"name": "Mahalle Marketi", "short": "Market", "rent": 700, "utilities": 90, "max_inside": 28},
	{"name": "Süpermarket", "short": "Süpermarket", "rent": 1800, "utilities": 300, "max_inside": 48},
	{"name": "Köşebaşı AVM", "short": "AVM", "rent": 0, "utilities": 2200, "max_inside": 52},
]

const UPGRADES := [
	{"id": "neon", "name": "Neon Tabela", "desc": "Gece parlayan tabela; yoldan geçenlerin dikkatini çeker.", "cost": 1800, "stage": 0, "effect": "+%25 müşteri çekimi, gece ışıltısı"},
	{"id": "pos", "name": "Temassız POS", "desc": "Kartla hızlı ödeme. Kasa işlemleri kısalır.", "cost": 2400, "stage": 0, "effect": "Kasa süresi −%35"},
	{"id": "tente", "name": "Yeni Tente & Vitrin", "desc": "Çizgili tente ve dolu vitrin; dükkân daha davetkâr görünür.", "cost": 1200, "stage": 0, "effect": "+%10 çekim"},
	{"id": "etiket", "name": "Elektronik Raf Etiketi", "desc": "Fiyatlar raflarda anında güncellenir, müşteri fiyata güvenir.", "cost": 3500, "stage": 1, "effect": "Fiyat toleransı +%5"},
	{"id": "isik", "name": "Sıcak Raf Aydınlatması", "desc": "Ürünler parlar, reyonlar davetkâr olur.", "cost": 2800, "stage": 1, "effect": "Ortam +, anlık alım +%20"},
	{"id": "otopark", "name": "Otopark Anlaşması", "desc": "Karşı otoparkla anlaşma: arabalı haftalık alışverişçiler gelir.", "cost": 9000, "stage": 2, "effect": "Haftalık alışverişçi ×1.6"},
	{"id": "ozelmarka", "name": "Köşebaşı Markası", "desc": "Un, şeker, yağ, makarna, deterjan ve peynir kendi markanla gelir; toptancıya aracı olmadan.", "cost": 12000, "stage": 2, "effect": "Temel ürünlerde maliyet −%20"},
	{"id": "gunes", "name": "Çatıya Güneş Paneli", "desc": "Dolapların, fırının ve soğuk odanın elektriğini güneş karşılar.", "cost": 6500, "stage": 1, "effect": "Elektrik faturası −%40"},
	{"id": "sadakat", "name": "Sadakat Kartı", "desc": "Puan kazanan müşteri sadık kalır, kuyrukta daha sabırlıdır.", "cost": 7500, "stage": 2, "effect": "Sabır +%20, puan dalgalanması azalır"},
	{"id": "klima", "name": "Merkezi Klima", "desc": "AVM içi serin ve ferah. Ziyaretçiler daha uzun kalır.", "cost": 18000, "stage": 3, "effect": "AVM ziyaretçisi +%10, keyif +"},
	{"id": "dijital", "name": "Dijital Yönlendirme Ekranları", "desc": "Kiracıların reklamı her katta.", "cost": 14000, "stage": 3, "effect": "Kiracı satışları +%15"},
]

const CAMPAIGNS := [
	{"id": "brosur", "name": "Broşür Dağıtımı", "desc": "Kapının önünde bir tanıtımcı gün boyu broşür dağıtır.", "cost": 500, "stage": 0, "effect": "Bugün +%35 müşteri", "icon": "megaphone"},
	{"id": "indirim", "name": "Günün İndirimleri", "desc": "Seçtiğin en fazla 3 üründe %15 indirim. Rafta kırmızı etiket, daha çok talep.", "cost": 0, "stage": 0, "effect": "Seçili ürünlere talep ×1.8, fiyat −%15", "icon": "tag"},
	{"id": "kasaonu", "name": "Kasa Önü Standı", "desc": "Kasaların yanına renkli şekerleme standı.", "cost": 300, "stage": 0, "effect": "Anlık alım ×2", "icon": "cart"},
	{"id": "ucal", "name": "3 Al 2 Öde", "desc": "Seçtiğin en fazla 3 üründe üçüncüsü bedava. Rafta sarı etiket; müşteri üçlü alır.", "cost": 400, "stage": 2, "effect": "Seçili ürünlerde talep ×1.5, sepette 3 adet", "icon": "box"},
	{"id": "tadim", "name": "Tadım Günü", "desc": "Fırın önünde ücretsiz tadım masası.", "cost": 1200, "stage": 2, "effect": "Memnuniyet +, fırın ürünleri talebi ×1.5", "icon": "food"},
]

## the wholesaler's own-brand line (Köşebaşı Markası upgrade)
const PRIVATE := ["un", "seker", "yag", "makarna", "deterjan", "peynir"]
## bank loans: amount, days to pay back, interest
const LOANS := [
	{"amount": 5000, "days": 10, "rate": 0.10, "stage": 0},
	{"amount": 15000, "days": 15, "rate": 0.14, "stage": 1},
	{"amount": 40000, "days": 20, "rate": 0.18, "stage": 2},
]

const EXPANSIONS := [
	{"to": 1, "cost": 12000, "title": "Yan Dükkânı Devral",
		"pitch": "Soldaki kapalı dükkânın kepengi aylardır inik. Duvarı yıkıp büfeyi Mahalle Marketi'ne dönüştür: iki kat alan, ikinci kapı, manav tezgâhı, gondol reyonlar ve aile alışverişçileri.",
		"goals": [["rating", "Mağaza puanı", 3.6], ["served", "Mutlu ayrılan müşteri", 200], ["cash", "Kasada nakit", 10000]],
		"unlocks": "Manav tezgâhı · Orta gondol · Açık soğutucu · 3 kasa · Süt, deterjan, domates, elma, yumurta, yoğurt, zeytin, şampuan, şemsiye · Aile alışverişçileri · Temizlik & güvenlik personeli · Kamera ve alarm kapısı · 2. kapı"},
	{"to": 2, "cost": 38000, "title": "Eczane Bloğunu Al: Süpermarket",
		"pitch": "Sağdaki eczane ve berber taşınıyor. Binayı al, arka depoyu aç: 24×12 m'lik bir süpermarket. Bantlı kasalar, kendi fırının, reyon levhaları ve arabalı haftalık alışveriş.",
		"goals": [["rating", "Mağaza puanı", 3.8], ["served", "Mutlu ayrılan müşteri", 700], ["cash", "Kasada nakit", 38000]],
		"unlocks": "Bantlı kasa · Self-servis kasa · Fırın tezgâhı & fırıncı · Reyon levhası · Araba parkı · Şarküteri tezgâhı & usta · Makarna, çay, peynir, su, un, şeker, yağ, sucuk, kaşar, donuk pizza, bebek bezi · Haftalık alışverişçi · 3. kapı"},
	{"to": 3, "cost": 90000, "title": "Bütün Bloğu Al: Köşebaşı AVM",
		"pitch": "Bloğun tamamı satılık. Süpermarket zemin katta kalsın; etrafına iki katlı bir alışveriş merkezi kur: kiracı mağazalar, yürüyen merdivenler, yemek katı, çocuk oyun alanı ve etkinlik takvimi.",
		"goals": [["rating", "Mağaza puanı", 4.0], ["served", "Mutlu ayrılan müşteri", 1800], ["cash", "Kasada nakit", 90000]],
		"unlocks": "11 kiracı birimi · 2 kat · Yürüyen merdiven & cam asansör · Yemek katı & masalar · Çocuk oyun alanı · Etkinlik takvimi · Tesis arızaları"},
]

const ROLE_LABEL := {"owner": "Dükkân Sahibi", "cashier": "Kasiyer", "stocker": "Reyon Görevlisi", "cleaner": "Temizlik Görevlisi", "security": "Güvenlik Görevlisi", "baker": "Fırıncı", "technician": "Teknisyen", "deli": "Şarküteri Ustası"}
const ROLE_DESC := {
	"owner": "Kasaya bakar. Kuyruk yokken ve yardımcı yoksa rafları kendisi doldurur; o sırada kasa boş kalır.",
	"cashier": "Boştaki kasaya geçer ve ödemeleri alır.",
	"stocker": "Depodan koli taşıyıp azalan rafları doldurur, boşta kalınca çöp toplar.",
	"cleaner": "Islak zemini paspaslayıp uyarı levhası koyar, çöpleri ve AVM'de kirli masaları toplar.",
	"security": "Devriye gezer. Şüpheliyi gördüğünde peşine düşer, alarm çalınca kapıda yakalar.",
	"baker": "Fırın tezgâhında sıcak simit ve ekmek pişirir; toptancıdan almaktan ucuzdur.",
	"deli": "Şarküteri tezgâhının arkasında durur; sucuk ve kaşarı keser, tartar, tezgâhı doldurur. O yokken şarküteriden alışveriş yapılamaz.",
	"technician": "AVM'de arızalanan yürüyen merdiven ve asansörü ücretsiz tamir eder, düzenli bakımla arızaları yarıya indirir.",
}
const ROLE_WAGE := {"owner": 0, "cashier": 300, "stocker": 260, "cleaner": 230, "security": 340, "baker": 380, "technician": 360, "deli": 360}
const ROLE_STAGE := {"owner": 0, "cashier": 0, "stocker": 0, "cleaner": 1, "security": 1, "baker": 2, "technician": 3, "deli": 2}
## personalities: most people have one; they change how someone works
const TRAITS := {
	"geveze": {"name": "Geveze", "desc": "Kasada sohbet eder: ödeme %15 yavaş ama müşteri keyfi +5.", "good": true},
	"titiz": {"name": "Titiz", "desc": "Rafı ve yeri özenle yapar: doldurma ve temizlik %25 hızlı.", "good": true},
	"cevik": {"name": "Çevik", "desc": "Hızlı yürür: +%15 hız.", "good": true},
	"guleryuz": {"name": "Güler yüzlü", "desc": "Hizmet ettiği her müşterinin keyfi +6.", "good": true},
	"dikkatli": {"name": "Dikkatli", "desc": "Hırsızı %40 daha uzaktan fark eder.", "good": true},
	"keyfi": {"name": "Keyfine düşkün", "desc": "%30 çabuk yorulur ama %15 ucuza çalışır.", "good": false},
	"dalgin": {"name": "Dalgın", "desc": "Arada bir durup telefonuna bakar: %10 yavaş, ama %10 ucuz.", "good": false},
}
const SHIFT_LABEL := {"full": "Tam gün 07–22", "morning": "Sabah 07–15", "evening": "Akşam 14–22"}
const SHIFT_SHORT := {"full": "Tam", "morning": "Sabah", "evening": "Akşam"}
const SHIFT_HOURS := {"full": [420, 1320], "morning": [420, 900], "evening": [840, 1320]}
const SHIFT_WAGE := {"full": 1.0, "morning": 0.6, "evening": 0.6}

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
