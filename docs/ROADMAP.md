# Yol Haritası: Büfeden AVM'ye

Her aşama sadece daha büyük bir bina değildir. Her biri **yeni bir müşteri davranışı**, **yeni bir karar türü**, **yeni bir sorun sınıfı** ve **yeni bir görsel imza** ekler.

Durum etiketleri: ✅ uygulandı · 🟡 kısmen · ⬜ planlandı

> Ana sürüm artık Godot (`godot/`). Aşağıdaki tablolar Godot sürümünün durumunu gösterir; eski web sürümünde olmayan birkaç sistem (odalar, tazelik, sinema, tuvalet, teknisyen, fiziksel otopark) yalnızca Godot sürümünde var.

---

## Aşama 1: Mahalle Büfesi ✅

| Katman | İçerik |
|---|---|
| Alan | 8×6 m, tek kapı, tek kasa |
| Müşteri | Öğrenci, Emekli, Beyaz Yaka. Saatlik talep eğrileri: sabah ekmek ve simit, öğleden sonra atıştırmalık |
| Kararlar | Raf yerleşimi, ürün atama, fiyat (arketipe göre kabul), sipariş ve oto-sipariş, reyon görevlisi almak, 3 yükseltme, ucuz kampanyalar (broşür, kasa önü standı) |
| Sorunlar | Boş raf, sahibin kasayı bırakması, kapıdan taşan kuyruk, çöp, "çok pahalı" tepkisi |
| Görsel imza | Çizgili tente, el yazısı tahta pano, kapıdan sokağa taşan kuyruk |

## Aşama 2: Mahalle Marketi ✅

| Katman | İçerik |
|---|---|
| Alan | 16×10 m. Komşu dükkân ve avlu kalkar, 2. kapı açılır |
| Müşteri | **Aile Alışverişçisi** (3–5 kalem), **Fırsatçı** (hırsız) |
| Kararlar | 3 kasaya kadar kasa, manav ve süt reyonu, gondollarla koridor tasarımı, kamera ve alarm kapısı yerleşimi, vardiya planı |
| Sorunlar | Kasalar arası yük dengesi, koridor sıkışması, depo kapasitesi, **hırsızlık ve kör noktalar**, **ıslak zemin ve kayma** |
| Yükseltmeler | Elektronik Raf Etiketi, Sıcak Raf Aydınlatması |
| Görsel imza | Manav kasaları, açık soğutucu ışığı, iki kapılı cephe, tavan kameraları, sarı ıslak zemin levhası |

## Aşama 3: Süpermarket ✅

**Hedef his:** "Artık tek başına her şeye yetişemiyorum; sistem kurmam lazım."

| Sistem | Durum | Not |
|---|---|---|
| Reyon levhaları | ✅ | Levhanın 5 m yakınındaki raflar daha hızlı bulunur. Levhasız reyonda arama uzar |
| Bantlı ve self-servis kasa | ✅ | Bant %35 hızlı. Self-servis kasiyer istemez ama yavaş ve kayıp riski taşır |
| Güvenlik ve hırsızlık | ✅ | Fırsatçı, kamera (görüş konisi, yüksek raflar görüşü keser), alarm kapısı, güvenlik görevlisi, `G` katmanı |
| Fırın ve fırıncı | ✅ | Ucuz üretim ve "sıcacık" moral bonusu. Tazelik, bayatlama, gece çöpe giden ekmek, akşam indirimi |
| Vardiya ve yorgunluk | ✅ | Tam, sabah ve akşam vardiyası. Enerji barı, çay ocağında mola |
| Alışveriş arabası | ✅ | Haftalık Alışverişçi araba iter. Park yoksa listesi kısalır |
| Kampanyalar | ✅ | Broşür, Günün İndirimleri, 3 Al 2 Öde, Kasa Önü Standı, Tadım Günü. Gondol başı teşhir eşyası |
| Oda sistemi | ✅ | Depo odası, soğuk oda (yoksa soğuk stok bozulur), mola odası. Personel kapıdan girip çıkar |
| Otopark | ✅ | Yolun karşısında otopark; arabayla gelen haftalık alışverişçi yaya geçidinden geçer, arabalar yayaya yol verir |

**Görsel imza:** tavandan asılı kategori levhaları, bantlı kasaların dönen bandı, parlayan fırın ağzı, kampanya günü kapıda tanıtımcı.

## Aşama 4: Köşebaşı AVM ✅

**Hedef his:** "Dükkân işletmiyorum, bir mekân işletiyorum; kiracılarım ve etkinliklerim var."

| Sistem | Durum | Not |
|---|---|---|
| Katlar | ✅ | Kat başına `Grid`. Kat seçici (`PageUp`/`PageDown`). Görünmeyen kat gizlenir, uzaktan bakınca tüm bina görünür |
| Katlar arası ulaşım | ✅ | Yukarı / aşağı yürüyen merdiven, cam asansör. Ajanlar "yürü + bin" bacaklarıyla katlar arası yol bulur. Normal merdiven de var, hiç bozulmaz |
| Kiracılar | ✅ | 11 birim, 10 kurgusal marka, günlük teklifler, kira + ciro payı, gerekçeli memnuniyet, mutsuz kiracı çıkar |
| Yemek katı | ✅ | İki yemek standı, masa ve koltuk, masa kirlenmesi, ayakta kalan ziyaretçi |
| Eğlence | ✅ | Çocuk oyun alanı, oyun salonu (gürültülü kiracı), sinema (büyük birim, seyirci salona girer) |
| Etkinlikler | ✅ | Konser, İmza Günü, Bayram İndirimleri, Çocuk Şenliği. Bugüne veya yarına planlanır, süslemeler görünür, güvenliksiz kalabalıkta arbede |
| Tesis yönetimi | ✅ | Arıza ve tamir, teknisyen (ücretsiz tamir, arızayı yarıya indirir), tuvalet ihtiyacı ve temizliği, Merkezi Klima. 🟡 Tahliye yok |

**Görsel imza:** cam korkuluklu galeri ve kayan yürüyen merdiven bantları, cam asansör kabini, kiracı vitrinlerinin marka renkleri, konser sahnesi ve balonlar, gece yanan dev AVM tabelası.

---

## Mahalle hayatı (tüm aşamalar) ✅

**Hedef his:** "Otomatiğe bağladım ama dükkân hâlâ canlı; her gün küçük bir karar var."

| Sistem | Durum | Not |
|---|---|---|
| Ürün çeşidi | ✅ | 15'ten 34 ürüne: büfe klasikleri (gazete, sakız, dondurma, salep, defter), market (yumurta, yoğurt, zeytin, şampuan, hurma, şemsiye), süpermarket (un, şeker, yağ, donuk pizza, bebek bezi, sucuk, kaşar) |
| Dondurma dolabı, şarküteri | ✅ | Şarküteri tezgâhı bir ustayla çalışır; usta yoksa müşteri bekler ve vazgeçer |
| Ürün analizi | ✅ | 7 günlük satış, kâr, kaçan satış, rafta boş kalma süresi, alıcı tipi, öneri |
| Müdavimler | ✅ | İsimli sakinler, alışkanlık saati, sevdiği ürünler, sadakat, istekler |
| Veresiye defteri | ✅ | Politika + limit, geç ödeyen / hiç ödemeyen, hatırlat / sil |
| Takvim ve hava | ✅ | Hafta sonu, mevsim, okul açılışı, Ramazan, iki bayram, arife; güneşli/sıcak/bulutlu/yağmurlu/karlı, yarının tahmini, yağmur ve kar efekti |
| Görevler | ✅ | Aynı anda 3 görev, günlük ve çok günlük, ödüller: nakit, puan, bedava eşya |
| Rakip (UCUZA) | ✅ | Karşı kaldırımda açılır, müşteri karşıya geçer, fiyat eşleme, afiş, dayanışma, satın alma, 7 gün %75 pay ile kapanır |
| Ekonomi | ✅ | Eşyaya göre elektrik faturası, güneş paneli, haftalık toptancı zammı, toplu fiyat güncelleme, 3 kredi seçeneği, kendi markan |
| Personel | ✅ | Kişilikler (7 huy), deneyim, eğitim, moral, zam talebi, istifa |
| Mahalle kedisi | ✅ | Kapıda belirir, sahiplenilir; gezinir, uyur, müşteriyi sevindirir, raftan ürün düşürür |
| Radyo Köşebaşı | ✅ | Bağlama göre espriler ve duyurular |
| Mahalleler (senaryolar) | ✅ | Moda Sahili, Kampüs Yolu, Çarşı, Serbest Mod; madalyalar |
| Başarımlar | ✅ | 23 başarım, oyunlar arası kalıcı |
| İnşa kolaylıkları | ✅ | Geri al (Ctrl+Z), kopyala (Ctrl+D) |
| Rehber | ✅ | 8 adımlık kontrol listesi, dock düğmesini gösterir |
| İngilizce | 🟡 | Arayüz, veriler, uyarılar, düşünceler ve radyo çevrildi; 3B tabelalar Türkçe kalıyor |

---

## Teknik durum

| Konu | Durum | Sonra |
|---|---|---|
| Kayıt ve yükleme | ✅ Günlük otomatik kayıt + 3 yuva (Godot: `user://` içinde JSON) | Dosyaya dışa aktarma, kayıt sürümleme ve göç |
| Ayarlar | ✅ Kalite, ses kanalları, arayüz ölçeği, kesik duvar | Tuş atama, renk körlüğü paleti |
| Ses | ✅ Üretken müzik + ortam, 4 kanal | Kiracıya özel vitrin sesleri, etkinlik müziği |
| Dokunmatik | ✅ Kaydır, kıstır, çevir, dokunarak yerleştir, alttan açılan paneller | Dikey telefon düzeni, dokunmatik için büyük tablo görünümleri |
| Varlık hattı | Prosedürel (kod) | Aynı `FixtureModel` arayüzüyle glTF yükleyici |
| Performans | Statik birleştirme, AVM'de ~120 ajan akıcı | `InstancedMesh` karakterler, uzak ajanlar için LOD, görünmeyen katta soyut sim |
| Test | Başsız tarayıcıda senaryolu simülasyon (elle) | Vitest ile sim birim testleri, CI'da gece dengesi raporu |

## Sıradaki işler (öneri)

Oda sistemi, tazelik ve AVM tesisleri (tuvalet, teknisyen, merdiven) Godot sürümünde tamamlandı. Sırada:

1. **Oyun testi ve denge:** gerçek oyuncularla hedef süreler (Büfe → Market ~45 dk, Market → Süpermarket ~2 saat, Süpermarket → AVM ~3 saat).
2. **AVM tahliye tatbikatı / yangın alarmı:** güvenlik ve kapı düzeninin sınavı.
3. **Kiracıya özel sesler ve etkinlik müziği.**
4. **Aynı oyunda birden çok şube** (şu an her mahalle ayrı oyun).
5. **Windows için hazır `.exe` sürümü** (GitHub Releases üzerinden).
