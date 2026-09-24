# Yol Haritası: Büfeden AVM'ye

Her aşama sadece daha büyük bir bina değildir. Her biri **yeni bir müşteri davranışı**, **yeni bir karar türü**, **yeni bir sorun sınıfı** ve **yeni bir görsel imza** ekler. Aşağıdaki tablo, mevcut kod tabanındaki hangi sistemin nasıl genişleyeceğini somut olarak gösterir.

Durum etiketleri: ✅ uygulandı · 🟡 kısmen · ⬜ planlandı

---

## Aşama 1: Mahalle Büfesi ✅

| Katman | İçerik |
|---|---|
| Alan | 8×6 m, tek kapı, tek kasa |
| Müşteri | Öğrenci, Emekli, Beyaz Yaka. Saatlik talep eğrileri: sabah ekmek ve simit, öğleden sonra atıştırmalık |
| Kararlar | Raf yerleşimi, ürün atama, fiyat (arketipe göre kabul), sipariş ve oto-sipariş, reyon görevlisi almak, 3 yükseltme |
| Sorunlar | Boş raf, sahibin kasayı bırakması, kapıdan taşan kuyruk, çöp, "çok pahalı" tepkisi |
| Görsel imza | Çizgili tente, el yazısı tahta pano, kapıdan sokağa taşan kuyruk |

## Aşama 2: Mahalle Marketi ✅ (ilk genişleme)

| Katman | İçerik |
|---|---|
| Alan | 16×10 m. Komşu dükkân ve avlu kalkar, 2. kapı açılır |
| Müşteri | **Aile Alışverişçisi**: 3–5 kalem, ikişer adet, taze ürün ve temizlik ister |
| Kararlar | 3 kasaya kadar kasa ve kasiyer ataması, manav ve süt reyonu, gondollarla koridor tasarımı |
| Sorunlar | Kasalar arası yük dengesi, koridor sıkışması, daha büyük depo ihtiyacı |
| Görsel imza | Manav kasaları, açık soğutucu ışığı, iki kapılı cephe |
| 🟡 Eksik | Temizlik görevlisi rolü var ama "ıslak zemin" gibi görsel olaylar yok. Market'e özel yükseltmeler (etiket yazıcı, raf aydınlatması) yok |

## Aşama 3: Süpermarket ⬜

**Hedef his:** "Artık tek başına her şeye yetişemiyorum; sistem kurmam lazım."

| Sistem | Mevcut koddaki karşılığı | Genişleme |
|---|---|---|
| **Kategori reyonları** | `FixtureDef.display` + `Slot` | Reyonlara kategori etiketi (Kahvaltılık, Temizlik, İçecek…). Müşteri önce kategori levhasını arar. Levhası olmayan reyonda arama süresi uzar (`nextWant` ağırlığı). |
| **Kasa bantları ve self-servis** | `register` kind, `queueSlots` | Bantlı kasa (2 müşteri aynı anda), hızlı kasa ("10 ürün altı" kuralı, müşteri sepet boyuna göre seçer), self-servis kiosk (kasiyer gerektirmez ama hırsızlık riski artar). |
| **Güvenlik ve hırsızlık** | `Customer` durum makinesi | Yeni arketip **Fırsatçı**: kamera ve görevli görüş alanı dışındaki raflardan ürün alıp ödemeden çıkmaya çalışır. Güvenlik kamerası (görüş konisi overlay'i), alarm kapısı, güvenlik görevlisi rolü. Görsel sinyal: kaçan müşterinin başında kırmızı çanta ikonu, kapıda alarm ışığı. |
| **Taze üretim: fırın ve şarküteri** | `Staff` görev sistemi (`Task`) | Üretim tezgâhı hammaddeyi mala çevirir (un → ekmek). Personel rolü "Fırıncı". Fırın ürününün bir tazelik süresi olur. Bayat ürün indirim rafına ya da çöpe gider (yeni `Slot.age`). |
| **Vardiya ve yorgunluk** | `Staff.skill`, `wage` | Sabah ve akşam vardiyası, yorgunluk barı, mola odası (yeni oda tipi). Yorgun personel yavaşlar. |
| **Otopark ve alışveriş arabası** | `Environment`, `CharacterView.ensureBasket` | Otoparktan gelen müşteri araba iter (daha geniş koridor ister, 2 karo). Araba toplama görevi. |
| **Kampanyalar** | `prices`, `ARCHETYPES.priceTolerance` | "3 al 2 öde", haftalık broşür. Kampanya günü talep artar, marj düşer. Gondol başı teşhir (end-cap) anlık alımı artırır. |
| **Oda sistemi** | `Grid.region` (R_IN) | Bölgeler: satış alanı, depo odası (sadece personel), mola odası, soğuk oda. `region` kodları genişler, kapı kenarları (`doorEdges`) odalar arasında da kullanılır. |

**Görsel imza:** Tavandan asılı kategori levhaları, bantlı kasaların ritmik hareketi, otoparkta arabalar, gece parlayan büyük pano.
**Genişleme kararı:** "Arsayı al" (otopark) ya da "üst katı kirala" (depo ve personel). İki farklı yol, iki farklı yerleşim oyunu.

## Aşama 4: Çok Katlı AVM ⬜

**Hedef his:** "Dükkân işletmiyorum, bir mekân işletiyorum; kiracılarım ve etkinliklerim var."

| Sistem | Genişleme |
|---|---|
| **Katlar** | `Grid` kat başına bir örnek (`Grid[]`). Kamera kat seçici; üst katlar yarı saydam olur. A* katlar arası "bağlantı düğümleri" (yürüyen merdiven ve asansör) üzerinden hiyerarşik çalışır. |
| **Katlar arası ulaşım** | Yürüyen merdiven (yönlü, yüksek kapasite), asansör (kuyruklu, engelli ve bebek arabalı aileler tercih eder), merdiven (ucuz, yaşlılar kaçınır). Akış ısı haritası kat başına gösterilir. |
| **Kiracı mağazalar** | Oyuncu kendi süpermarketini işletmeye devam eder. Diğer birimleri kiraya verir (giyim, elektronik, kafe). Her kiracının kira, ciro payı ve memnuniyet ihtiyaçları vardır ("yanımda rakip istemem", "yürüyen merdivene yakın olayım"). Kiracı yerleşimi yeni bir bulmaca olur. |
| **Yemek katı** | Ortak oturma alanı, masa temizliği, yoğun saatler (öğle ve akşam). Müşteri alışveriş sonrası "açlık" ihtiyacı kazanır. Yeni ihtiyaç barları: açlık, yorgunluk, tuvalet. |
| **Eğlence alanları** | Çocuk oyun alanı, sinema, oyun salonu. Aileler kalış süresini uzatır, harcama artar. Gürültü komşu kiracıların memnuniyetini düşürür. |
| **Etkinlik yönetimi** | Takvim: bayram alışverişi, okul dönemi, konser, imza günü. Etkinlik öncesi stok ve personel planlaması. Aşırı kalabalıkta güvenlik ve tahliye. |
| **Tesis yönetimi** | Tuvaletler, klima, aydınlatma giderleri, bakım ekibi, arızalar (yürüyen merdiven arızası). Görsel sinyal: dururken kırmızı şerit ve toplanan kalabalık. |

**Görsel imza:** Cam tavanlı atrium, katlar arası boşluktan görünen insan akışı, kiracı vitrinlerinin farklı marka renkleri (hepsi özgün, kurgusal), etkinlik günü süslemeleri.

---

## Teknik yol haritası

| Konu | Şimdi | Sonra |
|---|---|---|
| Kayıt ve yükleme | ⬜ Yok | Tüm sim durumu (`Game`, `Fixture`, ajanlar) düz JSON'a serileştirilir. Ajan görselleri kimlik tohumundan (`Look`) yeniden kurulur. |
| Varlık hattı | Prosedürel (kod) | Aynı `FixtureModel` arayüzüyle glTF yükleyici. Sanatçı modeli gelince `buildFixtureModel` yalnızca yükleyiciye yönlenir. `slots.units` bağlantı noktaları glTF'teki boş nesnelerden okunur. |
| Performans | Statik birleştirme (~1,1K draw call, 40 ajan) | Karakterlerde tek skinned mesh ve `InstancedMesh`, uzak ajanlar için düşük LOD, büyük alanlarda sim LOD (görünmeyen katlarda soyut sim). |
| Motor | Three.js | Ticari PC sürümü için Godot 4 portu değerlendirilir. `sim/` katmanı motordan bağımsız tutulduğu için mantık doğrudan taşınır. |
| Ses | Sentez efektler | Katmanlı ortam sesi (sokak, dükkân uğultusu, gece), aşamaya göre değişen müzik. |
| Erişilebilirlik | ⬜ | Renk körlüğü paleti (ikonlar zaten şekille de ayrışıyor), arayüz ölçeği, tuş atama. |

## Dikey kesitten sonraki ilk 5 iş (öneri)

1. Kayıt ve yükleme, hemen ardından ayarlar menüsü (kalite, ses, arayüz ölçeği).
2. Market'e özel 2 yükseltme ve "ıslak zemin" temizlik olayı. Böylece temizlik görevlisi anlamlı olur.
3. Kategori levhaları ve kampanya sistemi (Süpermarket'in çekirdeği, Market'te denenebilir).
4. Hırsızlık ve güvenlik prototipi: Fırsatçı arketipi, kamera görüş konisi.
5. Oyun testi ve denge: hedef süreler (Büfe → Market ~45 dk, Market → Süpermarket ~2 saat).
