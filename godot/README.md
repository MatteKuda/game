# Tezgâh — Godot sürümü

Oyunun yeni ana sürümü. Masaüstünde normal bir oyun gibi çalışır; tarayıcı, `npm` ya da Node.js gerekmez.

![Köşebaşı AVM](docs/avm.jpg)

| Süpermarket | AVM 1. kat: yemek katı ve bayram süsü |
|---|---|
| ![Süpermarket](docs/supermarket.jpg) | ![AVM 1. kat](docs/avm-kat1.jpg) |
| **AVM paneli: kiracılar** | **Kiracı kartı: memnuniyetin gerekçeleri** |
| ![AVM paneli](docs/avm-panel.jpg) | ![Kiracı](docs/kiraci.jpg) |
| **Kampanyalar** | **Vardiya ve enerji** |
| ![Kampanya](docs/kampanya.jpg) | ![Vardiya](docs/vardiya.jpg) |
| **Güvenlik katmanı (G): kırmızı = kör nokta** | **Mahalle Marketi** |
| ![Güvenlik](docs/guvenlik.jpg) | ![Mahalle Marketi](docs/market.jpg) |

| Gece | Rafa ürün atama |
|---|---|
| ![Gece](docs/gece.jpg) | ![Raf](docs/raf-inceleme.jpg) |
| **Müşteri kartı: liste ve düşünceler** | **Ürün & Fiyat** |
| ![Müşteri](docs/musteri.jpg) | ![Ürün](docs/urun-fiyat.jpg) |

---

## Nasıl çalıştırırım? (Windows)

1. **Godot'yu indir.** https://godotengine.org/download/archive/4.4.1-stable/ adresine git ve **Windows 64-bit** (standart sürüm, *.NET değil*) dosyasını indir.
   - Kurulum yok: ZIP'i bir klasöre çıkar, içindeki `Godot_v4.4.1-stable_win64.exe` dosyası programın kendisidir.
2. **Oyunu indir.** Bu depoyu GitHub'dan ZIP olarak indirip çıkar. Doğru dalı seçmeyi unutma: `claude/inspiring-brahmagupta-85rsvx`.
3. `Godot_v4.4.1-stable_win64.exe`'yi çalıştır. Açılan **Proje Yöneticisi**'nde **İçe Aktar** (Import) düğmesine bas.
4. İndirdiğin klasörün içindeki **`godot/project.godot`** dosyasını seç ve **İçe Aktar ve Düzenle**'ye tıkla.
   - İlk açılışta Godot modelleri ve fontları hazırlar. Bu 1–2 dakika sürebilir.
5. Editör açılınca sağ üstteki **▶ (Oynat)** düğmesine ya da **F5** tuşuna bas. Oyun kendi penceresinde açılır.

Mac ve Linux için de aynı adımları izle; 2. adımda kendi işletim sisteminin Godot dosyasını indir.

**Görüntü açılmazsa ya da ekran kararırsa** (eski ekran kartı sürücüsü): Proje Yöneticisi'nde projeyi seç, sağ tıkla, **Düzenle** de. Üstteki menüden sağ üst köşedeki **Forward+** yazısına tıklayıp **Compatibility**'yi seç, sonra tekrar F5'e bas.

## Kontroller

| Girdi | İşlev |
|---|---|
| Sol tık | Seç (müşteri, personel, raf). Yerdeki çöpe tıklarsan temizlenir |
| Sağ tık + sürükle / `WASD` | Kamerayı kaydır |
| Orta tık + sürükle / `Q` `E` | Kamerayı döndür |
| Tekerlek | Yakınlaş / uzaklaş. Uzaklaşınca cephe, tente ve tabela görünür |
| `B` `P` `T` `H` `F` `U` | İnşa · Ürün & Fiyat · Tedarik · Personel · Finans · Gelişim |
| `K` `V` | Kampanyalar · AVM paneli (kiracılar, etkinlikler, tesis) |
| `M` · `G` | Akış ısı haritası · Güvenlik katmanı (kamera ve güvenlik görevlisinin görmediği kör noktalar kırmızı) |
| `PageUp` `PageDown` (ya da `]` `[`) | AVM'de kat değiştir. Dock'taki kat düğmesi de aynı işi yapar |
| `R` | Yerleştirirken döndür. `Shift`+tık: arka arkaya yerleştir. Sağ tık / `Esc`: iptal |
| `Boşluk` · `1` `2` `3` | Duraklat · 1× / 2× / 4× hız |
| `C` | Kesik duvar görünümünü aç/kapat |
| Dokunmatik ekran | Tek parmakla kaydır, iki parmakla yakınlaştır ve döndür |

## Görsel yön

Hedef: Two Point serisinin sıcak, okunaklı "oyuncak ev" havası, ama kendi kimliğimizle. **Mahalle Pop** diyoruz: bir Türk mahallesi, bakkal ve market.

- **Dükkân:** terrakota-krem damalı karo, turkuaz boyalı duvarlar, ahşap lambri ve kalın koyu duvar başlıkları. Kameraya bakan duvarlar yakınlaşınca iner. Uzaklaşınca cam vitrin, çizgili tente ve "KÖŞEBAŞI" tabelası görünür, tabela gece neonla yanar.
- **Mahalle:** balkonlu apartmanlar (çatıda su deposu, güneş paneli, çanak anten, balkonda sardunya ve çamaşır ipi), eczane, berber, çay ocağı, kırtasiye. Karşı kaldırımda çay bahçesi ve otobüs durağı var. Yolda taksiler ve öteki arabalar geçiyor, toptancı minibüsü teslimat yapıyor. Gece pencereler ve sokak lambaları yanıyor.
- **Karakterler:** tek tek boyanmış, animasyonlu insanlar. Öğrenci, beyaz yaka, emekli ve aile arketiplerinin her birinin kendi kıyafet paleti var. Ten ve saç rengi rastgele seçiliyor. Yürüme, uzanma, ödeme ve kutu taşıma animasyonları var.
- **Işık:** güneş gün boyu döner, sıcak gün ışığıyla soğuk gölgeler çalışır. Ortam gölgesi (SSAO + SSIL) ve parlak ışıklarda bloom var.
- **Tipografi ve arayüz:** başlıklarda Fredoka, metinlerde Nunito. Renkli başlık bantlı paneller, kalın rakamlar ve koyu bir dock var. İkonlar oyuna özel, elle çizilmiş SVG'ler; emoji yok.

## Bu sürümde neler var

Dört aşamanın dördü de oynanabilir: **Büfe → Mahalle Marketi → Süpermarket → Köşebaşı AVM.** Her genişleme hedeflere bağlı (puan, mutlu müşteri, nakit) ve Gelişim panelinden (`U`) yapılır.

- **Büfe ve Mahalle Marketi:** 8×6 m'lik büfe, genişleyince 16×10 m'lik iki kapılı market. Yandaki kapalı dükkân yıkılır.
- **Süpermarket (24×12 m, üç kapı):** eczane bloğu kalkar.
  - **Bantlı kasa:** bant döner, ödeme %35 daha hızlı.
  - **Self-servis kasa:** kasiyer istemez ama yavaş ve kayıp riski var.
  - **Fırın tezgâhı ve fırıncı:** ucuz simit ve ekmek; "sıcacık" moral bonusu, fırın ağzı parlar.
  - **Reyon levhaları:** levhasız reyonda müşteri rafı daha geç bulur.
  - **Alışveriş arabası parkı:** haftalık alışverişçi araba iter; park yoksa listesi kısalır.
- **Güvenlik ve hırsızlık:**
  - Fırsatçı müşteri kimse bakmıyorsa ürünü cebine atar.
  - Dönen tavan kamerasının görüş konisini yüksek raflar keser.
  - Alarm kapısı kapıda öter, güvenlik görevlisi şüphelinin peşine düşer.
  - `G` katmanı kör noktaları kırmızıyla gösterir.
- **Islak zemin:** soğutucu sızdırır, müşteri içeceğini döker, üstünden geçen kayar. Temizlik görevlisi sarı uyarı levhası koyup paspaslar. Su birikintisine tıklayınca durumu görünür.
- **Vardiya ve yorgunluk:**
  - Vardiyalar: tam gün, sabah ya da akşam. Yarım vardiya %60 maaş alır.
  - Enerji barı: yorgun personel yavaşlar ve çay ocağında mola verir.
  - Personel panelinde her kişi için vardiya düğmeleri ve enerji çubuğu var.
- **Kampanyalar (`K`):**
  - Broşür Dağıtımı: kapıda tanıtımcı durur.
  - Günün İndirimleri: en fazla 3 ürün seçilir, rafta kırmızı etiket çıkar.
  - Kasa Önü Standı ve Tadım Günü.
- **Köşebaşı AVM (iki kat):** süpermarket zemin katta kalır, bloğun tamamı alışveriş merkezi olur.
  - **11 kiracı birimi, 10 kurgusal marka:** giyim, elektronik, kitabevi, oyuncakçı, kuaför, oyun salonu, spor ve üç yemek standı.
  - **Teklifler ve sözleşme:** her sabah yeni teklifler gelir. Kira artı ciro payı alırsın.
  - **Kiracı memnuniyeti gerekçeli:** "yürüyen merdivene uzak", "yanında gürültülü oyun salonu", "sadece 4 koltuk var" gibi. İki gün mutsuz kalan kiracı çıkar.
  - **Kiracı vitrinleri:** marka renginde vitrin, tabela, kendi mobilyası ve tezgâhta çalışan personel. Boş birimde kepenk ve "KİRALIK" levhası var.
  - **Katlar arası ulaşım:** yukarı ve aşağı yürüyen merdiven ile cam asansör. Ziyaretçiler katlar arasında yol bulur.
  - **Arızalar:** merdiven ya da asansör arızalanabilir. Önüne "ARIZALI" bariyeri gelir; tıklayıp tamir ettirirsin.
  - **Yemek katı:** masalar, sahne, çocuk oyun alanı ve banklar. Masalar kirlenir, temizlik görevlisi toplar.
  - **4 etkinlik:** Akşam Konseri (sahnede grup çalar), İmza Günü, Bayram İndirimleri, Çocuk Şenliği. Her birinin kendi süslemesi var (bayrak dizisi, balonlar, pankart). Güvenliksiz kalabalıkta arbede çıkar.
  - **Ziyaretçiler:** 4 arketip (genç, aile, profesyonel, emekli çift). Aileler çocuklarıyla gelir. Ziyaretçiye tıklayınca aklından geçenler görünür.
  - **Görünüm:** kamera kat değiştirince üst kat gizlenir, uzaklaşınca tüm bina ve çatıdaki "KÖŞEBAŞI AVM" tabelası görünür. Kameraya bakan duvarlar ve vitrinler yakınlaşınca iner.
- **Ortak sistemler:**
  - 15 ürün, 21 eşya ve 6 müşteri arketipi.
  - Personel rolleri: kasiyer, reyon görevlisi, temizlik, güvenlik ve fırıncı.
  - Tedarik ve toptancı minibüsü.
  - Gün sonu raporu: hırsızlık, kayma, yorgunluk ve AVM satırlarıyla, tavsiyelerle birlikte.
  - 9 yükseltme; uyarılar, ısı haritası, fare üstü bilgiler.

## Henüz olmayanlar (açıkça)

- **Kayıt / yükleme** ve **ayarlar menüsü** yok. Oyun her açılışta baştan başlar. Web sürümünde vardı, Godot'ya taşınmadı.
- **Müzik ve ses efektleri** yok.
- Web sürümünde de olmayan, planlanan işler:
  - AVM: merdiven, sinema, tuvalet ve bakım ekibi.
  - Süpermarket: personel-only oda / soğuk oda, fırın ürünlerinde tazelik, "3 al 2 öde", fiziksel otopark alanı.
- Depoda hazır bir `.exe` yok. Oyun editörden F5 ile çalışır.
  - Tek dosyalık `.exe` istersen: editörde **Proje → Dışa Aktar** (Project → Export) menüsüne gir. Godot bir kez "Export Templates" indirmeni isteyecek, kabul et. Ardından hazır **Windows** ayarıyla **Proje Dışa Aktar**'a bas; `export/Tezgah.exe` oluşur.
  - Dışa aktarma ayarı depoda hazır, ancak bu adımı kendi ortamımda deneyemedim. Editörden F5 ile çalıştırmayı test ettim.
- Süpermarket ve AVM, betikli başsız simülasyonlarla ve ekran görüntüleriyle test edildi. Uzun oyun dengesi (kaç günde genişlenir, kira/etkinlik fiyatları) gerçek oyuncularla henüz denenmedi.

## Varlıklar ve lisanslar

- **Kendi yaptıklarımız** (kodla üretilen): dükkân, raflar, dolaplar, kasa, manav, ürünler, apartmanlar, sokak, minibüs, tabelalar, tüm shader'lar (damalı karo, boyalı duvar, tuğla, kilit parke, asfalt, tente kumaşı) ve ikonlar.
- **KayKit** (Kay Lousberg, CC0): karakter gövdeleri ve animasyonları (Adventurers paketi; silahları, pelerinleri ve şapkaları çıkarıp kıyafetleri kendi paletimizle yeniden boyuyoruz), birkaç küçük eşya (kasalar, sandalye, dolap), şehir paketinden arabalar ve yangın musluğu. Lisans dosyaları `assets/` klasöründe.
- **Fontlar:** Fredoka ve Nunito (SIL Open Font License), lisansları `assets/fonts/` klasöründe.

## Kod yapısı

```
godot/
  project.godot          ana sahne: scenes/main.tscn
  scripts/core/          cfg.gd (sabitler, palet), db.gd (ürünler, eşyalar, arketipler, aşamalar, kampanyalar),
                         mall_db.gd (AVM birimleri, kiracılar, ziyaretçiler, etkinlikler, merdiven/asansör)
  scripts/sim/           grid.gd (A*, kapı kenarları, katlar), fixture.gd, agent.gd (katlar arası bacaklar),
                         customer.gd, staff.gd (vardiya, görevler), mall.gd (kiracı, etkinlik, arıza), visitor.gd
  scripts/game.gd        simülasyon döngüsü (1/30 s sabit adım), ekonomi, yerleştirme, gün, genişleme
  scripts/world/         art.gd (malzemeler, fontlar, yuvarlatılmış kutu), props.gd (eşya modelleri),
                         products3d.gd, character.gd, shop.gd, street.gd, sky.gd, camera_rig.gd, overlays.gd,
                         mall_shell.gd (AVM binası: katlar, vitrinler, yürüyen merdiven, asansör, sahne, süslemeler)
  scripts/ui/            ui_kit.gd (tema), thumbs.gd (3D küçük resimler), hud.gd
  shaders/               checker, wall_paint, brick, paving, asphalt, stripes, terrazzo, marble, escalator,
                         belt, shutter, character (yeniden boyama)
```
