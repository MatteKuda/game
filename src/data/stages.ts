export interface StageDef {
  index: number;
  name: string;
  short: string;
  rent: number; // per day
  utilities: number; // electricity, water, maintenance per day
  storeName: string;
  pitch: string;
  maxInside: number;
}

export const STAGES: StageDef[] = [
  { index: 0, name: 'Mahalle Büfesi', short: 'Büfe', rent: 250, utilities: 0, storeName: 'KÖŞEBAŞI', pitch: 'Tek kasa, dar tezgâh, sadık müdavimler.', maxInside: 11 },
  { index: 1, name: 'Mahalle Marketi', short: 'Market', rent: 700, utilities: 150, storeName: 'KÖŞEBAŞI', pitch: 'Yan dükkân birleşti: manav, gondollar, aile alışverişi.', maxInside: 28 },
  { index: 2, name: 'Süpermarket', short: 'Süpermarket', rent: 1800, utilities: 500, storeName: 'KÖŞEBAŞI', pitch: 'Bantlı kasalar, fırın, reyon levhaları, haftalık alışveriş.', maxInside: 48 },
  { index: 3, name: 'Köşebaşı AVM', short: 'AVM', rent: 0, utilities: 2600, storeName: 'KÖŞEBAŞI', pitch: 'İki kat, kiracı mağazalar, yemek katı ve etkinlikler.', maxInside: 52 },
];

export interface UpgradeDef {
  id: string;
  name: string;
  desc: string;
  cost: number;
  stage: number;
  effect: string;
}

export const UPGRADES: UpgradeDef[] = [
  { id: 'neon', name: 'Neon Tabela', desc: 'Gece parlayan tabela; yoldan geçenlerin dikkatini çeker.', cost: 1800, stage: 0, effect: '+%25 müşteri çekimi, gece ışıltısı' },
  { id: 'pos', name: 'Temassız POS', desc: 'Kartla hızlı ödeme. Kasa işlemleri kısalır.', cost: 2400, stage: 0, effect: 'Kasa süresi −%35' },
  { id: 'tente', name: 'Yeni Tente & Vitrin', desc: 'Çizgili tente ve dolu vitrin; dükkân daha davetkâr görünür.', cost: 1200, stage: 0, effect: '+%10 çekim' },
  { id: 'etiket', name: 'Elektronik Raf Etiketi', desc: 'Fiyatlar raflarda anında güncellenir, müşteri fiyata güvenir.', cost: 3500, stage: 1, effect: 'Fiyat toleransı +%5' },
  { id: 'isik', name: 'Sıcak Raf Aydınlatması', desc: 'Ürünler parlar, reyonlar davetkâr olur.', cost: 2800, stage: 1, effect: 'Ortam +, anlık alım +%20' },
  { id: 'otopark', name: 'Otopark Anlaşması', desc: 'Karşı otoparkla anlaşma: arabalı haftalık alışverişçiler gelir.', cost: 9000, stage: 2, effect: 'Haftalık alışverişçi ×1.6' },
  { id: 'sadakat', name: 'Sadakat Kartı', desc: 'Puan kazanan müşteri sadık kalır, kuyrukta daha sabırlıdır.', cost: 7500, stage: 2, effect: 'Sabır +%20, puan dalgalanması azalır' },
  { id: 'klima', name: 'Merkezi Klima', desc: 'AVM içi serin ve ferah. Ziyaretçiler daha uzun kalır.', cost: 18000, stage: 3, effect: 'AVM keyfi +, ziyaret süresi +' },
  { id: 'dijital', name: 'Dijital Yönlendirme Ekranları', desc: 'Kiracıların reklamı her katta.', cost: 14000, stage: 3, effect: 'Kiracı satışları +%15' },
];

export interface ExpansionGoal { id: string; label: string; target: number; unit: string }

export interface ExpansionDef {
  toStage: number;
  cost: number;
  title: string;
  pitch: string;
  goals: ExpansionGoal[];
  unlocks: string;
}

export const EXPANSIONS: ExpansionDef[] = [
  {
    toStage: 1, cost: 12000, title: 'Yan Dükkânı Devral',
    pitch: 'Soldaki kapalı dükkânın kepengi aylardır inik. Duvarı yıkıp büfeyi Mahalle Marketi\'ne dönüştür: iki kat alan, ikinci kapı, manav tezgâhı, gondol reyonlar ve aile alışverişçileri.',
    goals: [
      { id: 'rating', label: 'Mağaza puanı', target: 3.6, unit: '★' },
      { id: 'served', label: 'Mutlu ayrılan müşteri', target: 200, unit: '' },
      { id: 'cash', label: 'Kasada nakit', target: 10000, unit: '₺' },
    ],
    unlocks: 'Manav tezgâhı · Orta gondol · Açık soğutucu · 3 kasa · Süt, deterjan, domates, elma · Aile alışverişçileri · Temizlik & güvenlik personeli · Kamera ve alarm kapısı · 2. kapı',
  },
  {
    toStage: 2, cost: 38000, title: 'Fırını Satın Al: Süpermarket',
    pitch: 'Sağdaki fırın emekli oluyor. Binayı al, arka depoyu aç: 24×12 m\'lik bir süpermarket. Bantlı kasalar, kendi fırının, reyon levhaları ve arabalı haftalık alışveriş.',
    goals: [
      { id: 'rating', label: 'Mağaza puanı', target: 3.8, unit: '★' },
      { id: 'served', label: 'Mutlu ayrılan müşteri', target: 700, unit: '' },
      { id: 'cash', label: 'Kasada nakit', target: 38000, unit: '₺' },
    ],
    unlocks: 'Bantlı kasa · Self-servis kasa · Fırın tezgâhı & fırıncı · Reyon levhası · Araba parkı · Makarna, çay, peynir, su · Haftalık alışverişçi · 3. kapı',
  },
  {
    toStage: 3, cost: 90000, title: 'Bütün Bloğu Al: Köşebaşı AVM',
    pitch: 'Bloğun tamamı satılık. Süpermarket zemin katta kalsın; etrafına iki katlı bir alışveriş merkezi kur: kiracı mağazalar, yürüyen merdivenler, yemek katı, çocuk oyun alanı ve etkinlik takvimi.',
    goals: [
      { id: 'rating', label: 'Mağaza puanı', target: 4.0, unit: '★' },
      { id: 'served', label: 'Mutlu ayrılan müşteri', target: 1800, unit: '' },
      { id: 'cash', label: 'Kasada nakit', target: 90000, unit: '₺' },
    ],
    unlocks: '11 kiracı birimi · 2 kat · Yürüyen merdiven & cam asansör · Yemek katı & masalar · Çocuk oyun alanı · Etkinlik takvimi · Tesis arızaları',
  },
];

// kept for older imports
export const EXPANSION = EXPANSIONS[0];

export interface CampaignDef {
  id: string;
  name: string;
  desc: string;
  cost: number;
  stage: number;
  effect: string;
}

export const CAMPAIGNS: CampaignDef[] = [
  { id: 'brosur', name: 'Broşür Dağıtımı', desc: 'Kapının önünde bir tanıtımcı gün boyu broşür dağıtır.', cost: 500, stage: 0, effect: 'Bugün +%35 müşteri' },
  { id: 'indirim', name: 'Günün İndirimleri', desc: 'Seçtiğin en fazla 3 üründe %15 indirim. Rafta kırmızı etiket, daha çok talep.', cost: 0, stage: 0, effect: 'Seçili ürünlere talep ×1.8, fiyat −%15' },
  { id: 'kasaonu', name: 'Kasa Önü Standı', desc: 'Kasaların yanına renkli şekerleme standı.', cost: 300, stage: 0, effect: 'Anlık alım ×2' },
  { id: 'tadim', name: 'Tadım Günü', desc: 'Fırın ve şarküteri önünde ücretsiz tadım masası.', cost: 1200, stage: 2, effect: 'Memnuniyet +, fırın ürünleri talebi ×1.5' },
];
