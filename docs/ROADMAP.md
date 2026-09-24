# Yol Haritası: Büfeden AVM'ye

Her aşama sadece daha büyük bir bina değildir. Her biri **yeni bir müşteri davranışı**, **yeni bir karar türü**, **yeni bir sorun sınıfı** ve **yeni bir görsel imza** ekler.

Durum etiketleri: ✅ uygulandı · 🟡 kısmen · ⬜ planlandı

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
| Fırın ve fırıncı | ✅ | Ucuz üretim ve "sıcacık" moral bonusu. 🟡 Tazelik ve bayatlama yok |
| Vardiya ve yorgunluk | ✅ | Tam, sabah ve akşam vardiyası. Enerji barı, çay ocağında mola |
| Alışveriş arabası | ✅ | Haftalık Alışverişçi araba iter. Park yoksa listesi kısalır |
| Kampanyalar | ✅ | Broşür, Günün İndirimleri, Kasa Önü Standı, Tadım Günü. 🟡 "3 al 2 öde" ve gondol başı teşhir yok |
| Oda sistemi | ⬜ | Personel-only depo odası, soğuk oda, mola odası. `doorEdges` altyapısı hazır |
| Otopark | 🟡 | Yükseltme olarak var (müşteri artışı). Fiziksel otopark alanı yok |

**Görsel imza:** tavandan asılı kategori levhaları, bantlı kasaların dönen bandı, parlayan fırın ağzı, kampanya günü kapıda tanıtımcı.

## Aşama 4: Köşebaşı AVM ✅

**Hedef his:** "Dükkân işletmiyorum, bir mekân işletiyorum; kiracılarım ve etkinliklerim var."

| Sistem | Durum | Not |
|---|---|---|
| Katlar | ✅ | Kat başına `Grid`. Kat seçici (`PageUp`/`PageDown`). Görünmeyen kat gizlenir, uzaktan bakınca tüm bina görünür |
| Katlar arası ulaşım | ✅ | Yukarı / aşağı yürüyen merdiven, cam asansör. Ajanlar "yürü + bin" bacaklarıyla katlar arası yol bulur. 🟡 Merdiven yok |
| Kiracılar | ✅ | 11 birim, 10 kurgusal marka, günlük teklifler, kira + ciro payı, gerekçeli memnuniyet, mutsuz kiracı çıkar |
| Yemek katı | ✅ | İki yemek standı, masa ve koltuk, masa kirlenmesi, ayakta kalan ziyaretçi |
| Eğlence | 🟡 | Çocuk oyun alanı, oyun salonu (gürültülü kiracı). Sinema yok |
| Etkinlikler | ✅ | Konser, İmza Günü, Bayram İndirimleri, Çocuk Şenliği. Bugüne veya yarına planlanır, süslemeler görünür, güvenliksiz kalabalıkta arbede |
| Tesis yönetimi | 🟡 | Yürüyen merdiven arızası ve tamir, elektrik ve bakım gideri, Merkezi Klima yükseltmesi. Tuvalet, bakım ekibi, tahliye yok |

**Görsel imza:** cam korkuluklu galeri ve kayan yürüyen merdiven bantları, cam asansör kabini, kiracı vitrinlerinin marka renkleri, konser sahnesi ve balonlar, gece yanan dev AVM tabelası.

---

## Teknik durum

| Konu | Durum | Sonra |
|---|---|---|
| Kayıt ve yükleme | ✅ Günlük otomatik kayıt + 3 yuva (`localStorage`) | Dosyaya dışa aktarma, kayıt sürümleme ve göç |
| Ayarlar | ✅ Kalite, ses kanalları, arayüz ölçeği, kesik duvar | Tuş atama, renk körlüğü paleti |
| Ses | ✅ Üretken müzik + ortam, 4 kanal | Kiracıya özel vitrin sesleri, etkinlik müziği |
| Dokunmatik | ✅ Kaydır, kıstır, çevir, dokunarak yerleştir, alttan açılan paneller | Dikey telefon düzeni, dokunmatik için büyük tablo görünümleri |
| Varlık hattı | Prosedürel (kod) | Aynı `FixtureModel` arayüzüyle glTF yükleyici |
| Performans | Statik birleştirme, AVM'de ~120 ajan akıcı | `InstancedMesh` karakterler, uzak ajanlar için LOD, görünmeyen katta soyut sim |
| Test | Başsız tarayıcıda senaryolu simülasyon (elle) | Vitest ile sim birim testleri, CI'da gece dengesi raporu |

## Sıradaki 5 iş (öneri)

1. **Oda sistemi:** personel-only depo odası ve soğuk oda. Depo raflarını satış alanından çıkarmak yerleşim bulmacasını derinleştirir.
2. **Tazelik:** fırın ürünlerinde yaş, akşam indirim rafı, bayat ürün kaybı.
3. **AVM tesisleri:** tuvalet ve temizlik ihtiyacı, bakım ekibi (arızaları oyuncu yerine çözer), merdiven.
4. **Rakip dükkân:** karşı köşeye açılan zincir market. Fiyat savaşı ve sadakat kartının anlamı.
5. **Oyun testi ve denge:** hedef süreler (Büfe → Market ~45 dk, Market → Süpermarket ~2 saat, Süpermarket → AVM ~3 saat), otomatik denge raporu.
