# Tezgâh — Büfeden AVM'ye

Sıcak, esprili ve okunaklı bir **3D perakende yönetim oyunu**. Köşedeki küçük bir büfeyle başlarsın; rafları dizer, fiyatları ayarlar, stoku yönetir, personel alırsın. Yan dükkânı devralıp **Mahalle Marketi**'ne dönüşürsün. Yol haritası süpermarkete ve çok katlı bir AVM'ye uzanır.

> Bu depo oyunun **oynanabilir dikey kesitidir** (Aşama 1 Büfe + Aşama 2 Market genişlemesi). Süpermarket ve AVM aşamaları henüz **uygulanmadı**. Onları nasıl kuracağımız [`docs/ROADMAP.md`](docs/ROADMAP.md) dosyasında somut olarak yazıyor.

![Oyun ekranı](docs/screenshot-main.png)

---

## Hızlı başlangıç

```bash
npm install
npm run dev        # http://localhost:5173
# veya üretim derlemesi:
npm run build && npm run preview
```

Gereksinim: Node 18+ ve WebGL2 destekleyen güncel bir tarayıcı (Chrome, Edge, Firefox, Safari 17+).

URL parametreleri (test için):

| Parametre | Etki |
|---|---|
| `?q=balanced` / `?q=low` | Grafik kalitesi (varsayılan `high`: GTAO + bloom + 2K gölge) |
| `?para=20000` | Başlangıç nakdini değiştirir (genişlemeyi hızlı görmek için) |

## Kontroller

| Girdi | İşlev |
|---|---|
| Sol tık | Seç (müşteri, personel, raf) · yerde çöpe tıkla: temizle |
| Sağ tık + sürükle / `WASD` | Kamerayı kaydır |
| Orta tık + sürükle / `Alt`+sol / `Q` `E` | Kamerayı döndür |
| Tekerlek / `+` `-` | Yakınlaş / uzaklaş (çok uzaklaşınca duvarlar yükselir, dış cephe görünür) |
| `B` `P` `T` `H` `F` `U` | İnşa · Ürün & Fiyat · Tedarik · Personel · Finans · Gelişim |
| `M` | Akış (müşteri trafiği) ısı haritası |
| `R` | Yerleştirirken döndür · `Shift`+tık: arka arkaya yerleştir · `Esc`: iptal |
| `Boşluk` · `1` `2` `3` | Duraklat · 1× / 2× / 4× hız |
| `C` | Kesik duvar görünümünü aç/kapat |

---

## Dikey kesitte neler var (uygulandı)

**1. Kurulabilir, düzenlenebilir büfe**
- 8×6 m iç mekân, hazır bir başlangıç düzeniyle açılır. Her eşya taşınabilir, döndürülebilir, satılabilir (%50 iade).
- Yerleştirme kuralları gerçek zamanlı doğrulanır: eşya dükkânın içinde olmalı, kapı girişi boş kalmalı, rafın önü (müşteri erişimi) açık olmalı, kasanın arkasında kasiyere yer olmalı. **Hiçbir raf, kasa ya da kapı ulaşılamaz hâle gelmemeli.** Bunu, yerleştirmeden önce yol bulma testi (BFS) denetler. Hayalet model yeşil ya da kırmızı olur, sebebi alt çubukta yazar.

**2. Raf, soğutucu, kasa, depo ve 7 ürün**
- Ahşap raf (kuru gıda), cam kapaklı içecek dolabı, iki katlı fırın sepeti, kasa tezgâhı, depo rafı, saksı bitki, çöp kovası.
- Ürünler: Cips, Çikolata (anlık alım ürünü), Bisküvi, Kola, Ayran, Simit, Ekmek. Her ürünün teşhir tipi (raf, soğutucu, sepet), toptan maliyeti ve beklenen fiyatı var.
- Raflardaki ürünler tek tek 3D olarak görünür, satıldıkça gözle görülür biçimde azalır. Her bölmenin önünde fiyat etiketi durur; stok azalınca etiket turuncuya, bitince kırmızıya döner.
- Depo rafındaki koliler yedek stok miktarına göre azalır. Toptancı minibüsü sokağa gelip teslimatı yapar.

**3. Müşteriler (sadece dolaşan figürler değil)**
- Dört arketip: **Öğrenci**, **Emekli**, **Beyaz Yaka** ve Market'te açılan **Aile Alışverişçisi**. Her birinin bütçesi, alışveriş listesi, fiyat toleransı, sabrı, yürüme hızı, çöp atma eğilimi ve saatlik talep eğrisi farklı. Sabahları emekliler ekmek ve simit, öğleden sonra öğrenciler cips ve kola ister.
- Davranış döngüsü: kaldırımdan gelir, kapıda kalabalığı tartar (çok kalabalıksa döner), listedeki ürünleri en yakın raftan arar, fiyatı ve bütçesini kontrol eder, en kısa kuyruğa girer, öder ya da sabrı biterse sepeti bırakıp gider.
- Okunabilir tepkiler: başın üstünde vektör ikonlu baloncuklar (boş raf, çok pahalı, bulamadım, bekliyorum, kirli, kalabalık, mutlu). Yüz ifadesi (kaş ve ağız) ve animasyon (sinirlenme, sevinme, uzanma, ödeme) ruh hâline göre değişir. Müşteriye tıklayınca portresi, listesi, sepeti, sabır barı ve **"aklından geçenler"** günlüğü görünür.

**4. Çalışan oyun döngüsü**
- Stok, satış, kâr ve memnuniyet birbirine bağlı: boş raf ve pahalı fiyat ruh hâlini düşürür, ruh hâli mağaza puanını, puan da gelen müşteri sayısını belirler.
- Personel: Kemal Usta (sahibi) kasaya bakar. Kuyruk boşsa ve reyon görevlisi yoksa rafları kendisi doldurur, o sırada **kasa boş kalır**. Reyon görevlisi depodan koli taşır ve çöp toplar.
- Tedarik: elle sipariş (+6/+12/+24) ya da ürün başına otomatik sipariş. Depo kapasitesi sınırlı.
- Gün döngüsü 07:00–22:00 arası. Gün batımı, gece ışıkları, sokak lambaları ve vitrin ışıkları gerçek zamanlı değişir. Gün sonunda kira ve maaş ödenir, bir **gün sonu raporu** çıkar ve rapor otomatik çıkarımlar içerir ("simit 26 kez bulunamadı" gibi).

**5. Yerleşim kararlarının görünür etkisi**
- Kuyruk, kasanın müşteri tarafından en yakın kapıya uzanan gerçek bir yol boyunca dizilir. Kasa kapıya yakınsa kuyruk kaldırıma taşar. Kasa seçiliyken bu yol sarı kesikli çizgiyle gösterilir.
- **Anlık alım:** kuyruk yolunun hemen yanındaki raflardaki çikolata ödeme öncesi sepete eklenir.
- Dar koridorlarda müşteriler yavaşlar ve "sıkıştım" tepkisi verir. Bitkiler ortam puanı ve sabır kazandırır. Çöp kovası yakınına çöp atılmaz.
- **Akış haritası (`M`):** müşterilerin gerçekte nereden geçtiğini gösteren ısı haritası.

**6. İlk genişleme ve yükseltme kararları**
- Yükseltmeler: **Neon Tabela** (daha fazla müşteri, gece parıltısı), **Temassız POS** (ödeme süresi −%35, kasada terminal belirir), **Yeni Tente & Vitrin**.
- **Yan dükkânı devral:** puan ≥ 3,6★, 200 mutlu müşteri ve ₺12.000 nakit hedefleri tamamlanınca kepengi inik komşu dükkân ve arka avlu kalkar. İç mekân 16×10 m olur, ikinci kapı açılır. Kira artar. Orta gondol, manav tezgâhı, açık soğutucu, 3 kasaya kadar kasa, süt / deterjan / domates / elma, aile alışverişçileri ve temizlik görevlisi açılır.

**7. Ana oyun ekranı**
- Tek bir 3D sahne, soldan sağa sıcak bir mahalle: eczane, berber, çay ocağı, kırtasiye, fırın, balkonlu apartmanlar, trafikte arabalar, uyuyan kedi, çamaşır ipi. Dükkânın içini kapatan binalar ve duvarlar kameraya göre otomatik olarak saydamlaşır ya da alçalır.
- Arayüz, dünyayı kapatmayan kompakt kartlardan oluşur. Sorun önce dünyada görünür (raf rozetleri, baloncuklar, kuyruk, çöp); ayrıntı için tıklanır.

## Henüz uygulanmayanlar (açıkça)

- **Süpermarket ve AVM aşamaları**: yalnızca yol haritasında ([docs/ROADMAP.md](docs/ROADMAP.md)).
- **Güvenlik ve hırsızlık**, vardiya ve yorgunluk sistemi, kampanya ve indirim günleri, rakip dükkânlar.
- **Kayıt ve yükleme** (save/load): her sayfa yenilemede oyun baştan başlar.
- **Müzik**: yalnızca sentezlenmiş kısa ses efektleri var. Ortam sesi yok.
- Dış 3D model veya doku dosyası kullanılmadı. Tüm modeller ve dokular kod içinde prosedürel üretiliyor (bkz. görsel yön). Sanatçı elinden çıkmış modellerle değiştirmek için boru hattı hazır (bkz. mimari).
- Mobil ve dokunmatik kontroller desteklenmiyor.
- Oyun dengesi ilk ayar düzeyinde. İyi oynanışta genişlemeye ~4–6 oyun günü sürüyor.

---

## Teknoloji seçimi ve gerekçesi

| Seçim | Neden |
|---|---|
| **Three.js (WebGL2)** | Yönetim oyunu kamerası, çok sayıda küçük animasyonlu nesne ve post-processing (GTAO ambient occlusion, bloom, renk düzeltme) için olgun ve hızlı. Kurulum gerektirmeden tarayıcıda açılır, yinelemesi hızlı. |
| **TypeScript + Vite** | Simülasyon sistemleri büyüdükçe tip güvenliği şart. Vite anlık yeniden yükleme sağlar, tek komutla statik derleme verir. |
| **Prosedürel varlıklar** | Tutarlı bir stilize görsel dil (yuvarlatılmış kenarlar, sınırlı palet, canvas ile çizilen etiketler ve tabelalar) ve sıfır lisans riski. Her şey kodda olduğu için renk ve oran değişikliği tüm dünyaya bir anda yayılır. |
| **Motor yok, sade ECS benzeri yapı** | Sim (grid, ajanlar, ekonomi) ile görünüm (Three.js grupları) aynı nesnelerde ama ayrı katmanlarda. İleride Godot veya Unity'ye taşımak gerekirse sim mantığı bağımsız kalır. |

Neden Unity veya Godot değil? Bu ortamda editör yok. Tarayıcıda çalışan, hemen denenebilen ve kodla doğrulanabilen bir dikey kesit, hem görsel hem mekanik yinelemeyi hızlandırıyor. Ticari sürümde aynı tasarım Godot 4'e (Forward+) taşınabilir. Bunun planı yol haritasında.

## Görsel yön: "Mahalle Pop"

- **Palet:** krem `#FFF1DC`, kiremit `#E0663C`, petrol yeşili `#1F8A86`, hardal `#F2B33D`, gece mavisi `#1F2A44`. Arayüz ve dünya aynı paleti paylaşır.
- **Biçim dili:** yuvarlatılmış kutular, tombul ve büyük kafalı karakterler, abartılı ama okunaklı siluetler (sırt çantası, kasket, evrak çantası, bez çanta, önlük).
- **Işık:** güneşin gün boyu açısı ve rengi değişir, gökyüzü gradyanı var, GTAO temas gölgeleri verir, bloom yalnızca parlak ışık kaynaklarında (neon, soğutucu, sokak lambası) çalışır. Nötr ton eşleme renkleri korur.
- **Malzemeler:** terrazzo zemin, metro fayans lambri, ahşap damar, hasır sepet, oluklu kepenk, parke taşı, asfalt çatlakları. Hepsi canvas dokusu.
- **Okunabilirlik:** uzaktan bina ve tabela, orta mesafeden raf rozetleri ve kuyruk, yakından yüz ifadeleri, fiyat etiketleri ve sepetteki ürünler görünür.
- **Arayüz:** koyu dock, krem kartlar, Baloo 2 başlıklar ve Inter metin, elle çizilmiş tutarlı SVG ikon seti (emoji yok).

## Mimari

```
src/
  config.ts            harita düzeni, zaman, palet
  data/                ürünler, eşyalar, müşteri arketipleri, aşamalar ve yükseltmeler (veri odaklı)
  sim/grid.ts          bölge ızgarası (sokak / iç mekân / kapı kenarları), A*, erişim BFS
  sim/fixture.ts       eşya: kapladığı alan, erişim ve arka karo, bölmeler, fiyat etiketleri, durum rozeti
  sim/agents.ts        Agent → Customer (durum makinesi, ihtiyaçlar, tepkiler), Staff (kasa, reyon, temizlik)
  game.ts              orkestrasyon: spawn, ekonomi, tedarik minibüsü, yerleştirme doğrulama, gün döngüsü, genişleme
  world/               renderer (post-FX, gün ışığı), kamera, çevre, dükkân kabuğu (kesik duvar, kapılar),
                       prosedürel eşya, ürün ve karakter modelleri, ikonlar, overlay'ler (ısı haritası, kuyruk çizgisi)
  ui/                  HUD, paneller, inspector, SVG ikonlar, 3D küçük resimler, sentez ses
```

Sim adımı sabittir (1/30 s alt adım), render'dan bağımsızdır. Bu sayede 4× hızda da tutarlı çalışır ve başsız (headless) testte günlerce ileri sarılabilir.

## Lisans ve özgünlük

Tüm kod, model, doku ve arayüz bu proje için sıfırdan yazıldı. Başka bir oyunun görseli, karakteri, arayüzü veya mekaniği kopyalanmadı. Fontlar: Baloo 2 ve Inter (SIL OFL, `@fontsource` üzerinden).
