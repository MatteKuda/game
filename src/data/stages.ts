export interface StageDef {
  index: number;
  name: string;
  short: string;
  rent: number; // per day
  storeName: string;
  pitch: string;
}

export const STAGES: StageDef[] = [
  { index: 0, name: 'Mahalle Büfesi', short: 'Büfe', rent: 250, storeName: 'KÖŞEBAŞI', pitch: 'Tek kasa, dar tezgâh, sadık müdavimler.' },
  { index: 1, name: 'Mahalle Marketi', short: 'Market', rent: 700, storeName: 'KÖŞEBAŞI', pitch: 'Yan dükkân birleşti: manav, gondollar, aile alışverişi.' },
  { index: 2, name: 'Süpermarket', short: 'Süpermarket', rent: 2400, storeName: 'KÖŞEBAŞI', pitch: 'Henüz uygulanmadı — yol haritasına bakın.' },
  { index: 3, name: 'Çok Katlı AVM', short: 'AVM', rent: 9000, storeName: 'KÖŞEBAŞI', pitch: 'Henüz uygulanmadı — yol haritasına bakın.' },
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
  { id: 'tente', name: 'Yeni Tente & Vitrin', desc: 'Çizgili tente ve dolu vitrin; dükkân daha davetkâr görünür.', cost: 1200, stage: 0, effect: '+0.2 ortam puanı, +%10 çekim' },
];

export interface ExpansionGoal {
  id: string;
  label: string;
  target: number;
  unit: string;
}

export const EXPANSION = {
  toStage: 1,
  cost: 12000,
  title: 'Yan Dükkânı Devral',
  pitch: 'Soldaki kapalı dükkânın kepengi aylardır inik. Duvarı yıkıp büfeyi Mahalle Marketi\'ne dönüştür: iki kat alan, ikinci kapı, manav tezgâhı, gondol reyonlar ve aile alışverişçileri.',
  goals: [
    { id: 'rating', label: 'Mağaza puanı', target: 3.6, unit: '★' },
    { id: 'served', label: 'Mutlu ayrılan müşteri', target: 200, unit: '' },
    { id: 'cash', label: 'Kasada nakit', target: 12000, unit: '₺' },
  ] as ExpansionGoal[],
};
