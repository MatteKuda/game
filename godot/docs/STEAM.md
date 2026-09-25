# Steam, Steam Deck ve oyun kolu

Oyun Steam olmadan da aynen çalışır. Steam desteği isteğe bağlı bir eklentiyle açılır; kod
`scripts/core/steam_bridge.gd` içinde ve eklenti yoksa hiçbir şey yapmaz.

## Steam'i açmak

1. Godot 4.4 için **GodotSteam GDExtension** eklentisini indir (Asset Library → "GodotSteam GDExtension 4.4",
   ya da github.com/GodotSteam/GodotSteam sürümleri) ve `addons/godotsteam/` altına koy.
2. `scripts/core/steam_bridge.gd` içindeki `APP_ID` değerini Steamworks'teki uygulama numarasıyla değiştir
   (şu an Valve'ın test uygulaması 480).
3. Geliştirirken proje klasörüne ve dışa aktarılan exe'nin yanına içinde yalnızca app id yazan
   `steam_appid.txt` koy. Steam'den dağıtılan sürümde bu dosyaya gerek yok.
4. Steamworks → Stats & Achievements'ta aşağıdaki başarımları **aynı API adlarıyla** oluştur.
   Oyun çevrimdışı kazanılanları da Steam açıldığında eşitler.
5. Rich Presence için Steamworks'e bir `#Status` belirteci ekle: `"#Status" "%status%"` (her dil için).
   Arkadaş listesinde "Süpermarket · Gün 12" gibi görünür.

## Başarımlar

| API adı | Ad (TR) | Ad (EN) | Açıklama (TR) | Açıklama (EN) |
|---|---|---|---|---|
| `ACH_ILK_GUN` | İlk Kepenk | First Shutter | İlk günü kapat. | Close your first day. |
| `ACH_MARKET` | Mahallenin Marketi | The Local Market | Mahalle Marketi'ne büyü. | Grow into the Neighbourhood Market. |
| `ACH_SUPER` | Süper! | Super! | Süpermarket aç. | Open the Supermarket. |
| `ACH_AVM` | AVM Patronu | Mall Boss | Köşebaşı AVM'yi aç. | Open Köşebaşı Mall. |
| `ACH_BIN_MUTLU` | Bin Tebessüm | A Thousand Smiles | Toplam 1.000 mutlu müşteri. | 1,000 happy customers in total. |
| `ACH_ON_BIN_MUTLU` | Mahallenin Gözbebeği | Apple of the Neighbourhood's Eye | Toplam 10.000 mutlu müşteri. | 10,000 happy customers in total. |
| `ACH_ZENGIN` | Kasa Dolu | Full Till | Kasada ₺100.000. | ₺100,000 in the till. |
| `ACH_YILDIZ` | Dört Buçuk Yıldız | Four and a Half Stars | Mağaza puanı 4,5. | A 4.5 shop rating. |
| `ACH_KEDI` | Kedili Dükkân | Shop with a Cat | Mahallenin kedisini sahiplen. | Adopt the neighbourhood cat. |
| `ACH_DEFTER` | Defter Kabarık | A Thick Veresiye Book | Toplam ₺1.000 veresiye yaz. | Put ₺1,000 on veresiye in total. |
| `ACH_HELAL` | Hakkını Helal Et | Consider It Forgiven | Bir komşunun borcunu sil. | Wipe a neighbour's debt. |
| `ACH_RAKIP` | Kepenk İndirttin | Shutters Down | UCUZA'yı kapattır ya da satın al. | Close or buy out UCUZA. |
| `ACH_GOREV10` | Görev Avcısı | Quest Hunter | 10 görev tamamla. | Complete 10 quests. |
| `ACH_HIRSIZ` | Yakaladım! | Gotcha! | 10 hırsız yakala. | Catch 10 thieves. |
| `ACH_DENETIM` | Pırıl Pırıl | Spotless | Zabıta denetiminden tam not al. | Pass an inspection with full marks. |
| `ACH_DERBI` | Derbi Gecesi | Derby Night | Bir maç gününde 60 kola sat. | Sell 60 colas on a match day. |
| `ACH_IFTAR` | İftara Yetiştir | In Time for Iftar | Ramazan'da bir günde 40 pide sat. | Sell 40 pide in one day during Ramadan. |
| `ACH_BORCSUZ` | Borçsuz Esnaf | Debt-free Shopkeeper | Bir krediyi tamamen öde. | Pay off a loan in full. |
| `ACH_SADIK` | Mahalle Bizimle | The Neighbourhood's With Us | 10 müdavimin sadakati 80+ olsun. | Get 10 regulars to 80+ loyalty. |
| `ACH_ISTEK` | Sen İste | Just Ask | Müdavimlerin 5 isteğini karşıla. | Fulfil 5 requests from regulars. |
| `ACH_MODA` | Moda'yı Kurtardın | Saved Moda | Moda Sahili senaryosunu kazan. | Win the Moda Seaside scenario. |
| `ACH_KAMPUS` | Kampüs Efsanesi | Campus Legend | Kampüs Yolu senaryosunu kazan. | Win the Campus Road scenario. |
| `ACH_CARSI` | Çarşının Hakimi | Ruler of the Bazaar | Çarşı senaryosunu kazan. | Win the Bazaar scenario. |

Simge önerisi: 256×256, oyunun terracotta/krem paleti; kilitli sürüm gri tonlu.

## Steam Deck

- İlk açılışta Deck algılanırsa (`SteamDeck=1` ortam değişkeni ya da Steam API) arayüz %115, yazı
  "Büyük" ve tam ekran olarak başlar. Oyuncu Ayarlar'dan değiştirebilir.
- 1280×800'de ayarlar ve kontroller sayfası kaydırılabilir.
- Dokunmatik ekran zaten çalışır (sürükle = kaydır, iki parmak = yakınlaş/çevir).
- Önerilen Steam Input şablonu: **"Gamepad with Mouse Trackpad"**. Sağ trackpad fare olur, oyunun kendi
  kol desteği de açık kalır.

## Oyun kolu

Oyunda her şey fareyle yapıldığı için kol, sağ çubukla yönetilen bir imleç olarak çalışır
(`scripts/core/pad_cursor.gd`). Tuşlar `scripts/core/keys.gd` içinde tanımlı.

| Kol | İş |
|---|---|
| Sol çubuk | Kamerayı kaydır |
| Sağ çubuk | İmleç |
| A | Tıkla |
| B | Geri / iptal (Esc) |
| X | İnşa paneli |
| Y | Ürünler |
| LB / RB | Kamerayı çevir |
| LT / RT | Uzaklaş / yakınlaş |
| Yön ↑ / ↓ | Hızlandır / yavaşlat |
| Yön → | Eşyayı döndür |
| Yön ← | Duvarları indir |
| Start | Menü |
| Select / Back | Duraklat |

Klavye tuşlarının hepsi Ayarlar → Kontroller'den yeniden atanabilir (`user://ayarlar.cfg`, `[keys]`).

## Doğrulanmayanlar

Bu ortamda Steam, GodotSteam, gerçek bir oyun kolu ya da Steam Deck yok. Köprü kodu yalnızca
derleniyor ve eklenti yokken sessiz kaldığı doğrulandı. Gerçek Steam girişi, başarım eşitleme,
Rich Presence ve kolla oynanış bir makinede denenmeli.
