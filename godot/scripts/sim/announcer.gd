class_name Announcer
## "Radyo Köşebaşı": a line from the shop's crackly speaker every couple of game hours.
## Mostly jokes, but it also reacts to the weather, the match, the cat, the rival and empty shelves.

const GENERAL := [
	"Sayın müşterilerimiz, 3 numaralı reyondaki domatesler kendini salata sandı; lütfen onları hayal kırıklığına uğratmayın.",
	"Kasadaki sıra bir yere kaçmıyor. Ama siz kaçarsanız Kemal Usta çok üzülür.",
	"Bugünün sorusu: Simit mi, poğaça mı? Cevabınızı kasaya iletin, ödülü yok ama sohbet var.",
	"Kayıp ilanı: mavi bir alışveriş sepeti, en son bisküvi rafının önünde görüldü. Bulan kasaya getirsin.",
	"Mahalle bülteni: 5 numaranın kedisi yine balkondan balkona geçti. Herkes sağ salim.",
	"Hatırlatma: Çay ocağındaki bardaklar dükkânın malıdır, eve götürmeyiniz. Götürdüyseniz yarın getiriniz.",
	"Bugün de gülümseyerek alışveriş yapan her müşteriye Kemal Usta'dan bir 'Allah razı olsun'.",
	"Ekmekler taze, simitler sıcak, fiyatlar mahalleli. Radyo Köşebaşı'nı dinliyorsunuz.",
	"Arabasını kaldırımın üstüne park eden beyefendi, lütfen... tamam, gitmişsiniz. Teşekkürler.",
	"Dikkat! Bisküvi rafında bir çocuk kendi ağırlığınca bisküvi seçmeye çalışıyor. Annesi kasaya.",
	"Kasiyerimize 'para üstü şeker olsun mu' diye sormayınız, şekerlerimiz bitti. Yarın gelecek.",
	"Muhtarlıktan duyuru: Su kesintisi yoktur. Bu duyuru sadece içiniz rahat etsin diye yapılmıştır.",
	"Günün şarkısı: 'Bakkal amca, veresiye yaz' — birinci kıta, nakarat yok.",
	"Hava durumu: Dükkân içi 22 derece, kalpler sıcak, dolaplar soğuk.",
]
const RAIN := ["Dışarısı sağanak! Şemsiyesini unutan komşularımız için rafta şemsiye var. Tesadüf mü? Değil.", "Yağmurda kapıdaki paspasa ayağınızı silerseniz temizlik görevlimiz size ömür boyu minnettar kalır."]
const SNOW := ["Kar yağıyor, salep hazır. Kaymamak için yavaş yürüyün, sepetleri yavaş doldurun.", "Kardan adam yapan çocuklara duyurulur: havuç manav tezgâhında değil, sadece domates var."]
const HOT := ["Sıcak hava uyarısı: Dondurma dolabının kapağını açık bırakmayınız, dondurmalar ağlıyor.", "Bugün hava o kadar sıcak ki ayranlar kendi kendine köpürüyor."]
const MATCH := ["Derbi akşamı! Kola ve cips kasanın hemen yanında. Gol sesi duyarsanız panik yapmayın, çay ocağındakiler.", "Maç öncesi son çağrı: çekirdek yok, cips var. Kimse bize kızmasın."]
const CAT := ["%s şu an depo rafının üstünde uyuyor. Lütfen sessiz olalım, rüyasında fare kovalıyor.", "%s'e mama vermeyiniz, kendisi diyette. Tamam, bir tane verebilirsiniz.", "Kayıp bulundu: %s'in oyuncak faresi. Kasada teslim alınabilir, sahibi pek ilgilenmiyor."]
const RIVAL := ["Karşıdaki UCUZA'da ucuz olabilir ama orada seni adınla selamlayan var mı? Yok.", "Hatırlatma: Veresiye defteri sadece Köşebaşı'nda. UCUZA'da defter yok, sadece kasa var."]
const RAMAZAN := ["Hayırlı Ramazanlar! İftar pideleri 17:30'dan itibaren fırından çıkıyor, sıcacık.", "İftara az kaldı; hurmalar reyonda, sabır kasada."]
const BAYRAM := ["Bayramınız mübarek olsun! Bayram şekerleri ve çikolatalar ön rafta.", "Bayramda büyükleri ziyaret etmeyi unutmayın, eli boş gitmeyin: çikolata reyonu solunuzda."]
const EMPTY := ["%s rafı boş görünüyor ama kalbimiz dolu. Reyon görevlimiz yolda.", "Sayın müşterilerimiz, %s biraz sonra rafta olacak. Bu arada bisküvilere bir göz atın."]
const QUEUE := ["Kuyrukta bekleyen komşularımıza sabırları için teşekkür ederiz. Bu sırada birbirinizle tanışabilirsiniz."]

static func pick(g) -> String:
	var pools := [GENERAL, GENERAL]
	match g.calendar.weather:
		"yagmur": pools += [RAIN, RAIN]
		"kar": pools += [SNOW, SNOW]
		"sicak": pools += [HOT, HOT]
	if g.is_match_time() or g.match_night.get("day", -1) == g.day: pools += [MATCH, MATCH]
	if g.cat != null and g.cat.adopted: pools.append(CAT)
	if g.rival.active: pools.append(RIVAL)
	if g.calendar.is_ramazan(g.day): pools += [RAMAZAN, RAMAZAN]
	if g.calendar.is_bayram(g.day): pools += [BAYRAM, BAYRAM]
	var empty := ""
	for f in g.fixtures:
		for s in f.slots:
			if s["pid"] != "" and int(s["stock"]) == 0: empty = DB.product(s["pid"])["name"]
	if empty != "": pools.append(EMPTY)
	var q := 0
	for f in g.fixtures: q += f.queue.size()
	if q >= 5: pools.append(QUEUE)
	var pool: Array = pools.pick_random()
	var line: String = pool.pick_random()
	if pool == CAT: line = line % g.cat.cat_name
	elif pool == EMPTY: line = line % empty
	return line
