export type Accessory = 'backpack' | 'flatcap' | 'briefcase' | 'totebag' | 'cane' | 'hood';

export interface Archetype {
  id: string;
  name: string;
  blurb: string;
  stage: number;
  budget: [number, number];
  wants: Record<string, number>; // productId -> weight
  listSize: [number, number];
  patience: number; // seconds willing to wait in queue (real seconds @1x)
  priceTolerance: number; // accepted fraction above base price
  speed: number; // m/s
  litter: number; // chance per second to drop litter
  impulse: number; // chance to grab an impulse item near checkout
  accessory: Accessory;
  palette: { tops: number[]; bottoms: number[] };
  thief?: boolean; // shoplifter: takes items and heads for the door
  cart?: boolean; // wants an alışveriş arabası (big list)
  // demand by hour of day (7..22) - returns multiplier
  hourCurve: (h: number) => number;
}

const bell = (h: number, c: number, w: number) => Math.exp(-((h - c) * (h - c)) / (2 * w * w));

export const ARCHETYPES: Archetype[] = [
  {
    id: 'ogrenci', name: 'Öğrenci', blurb: 'Az parası var, atıştırmalık ve soğuk içecek peşinde. Sabırsız.', stage: 0,
    budget: [25, 60], wants: { cips: 5, cikolata: 4, kola: 5, biskuvi: 2, simit: 2, su: 2 }, listSize: [1, 2],
    patience: 22, priceTolerance: 0.12, speed: 1.55, litter: 0.012, impulse: 0.45, accessory: 'backpack',
    palette: { tops: [0x6c63ff, 0x2ec4b6, 0xff6b6b, 0xffb400], bottoms: [0x2b3a67, 0x3d405b, 0x264653] },
    hourCurve: (h) => 0.25 + bell(h, 8, 0.8) * 0.8 + bell(h, 16, 1.4) * 1.6,
  },
  {
    id: 'emekli', name: 'Emekli', blurb: 'Fiyata çok duyarlı. Sabah ekmeğini ve ayranını alır, beklemeye razıdır.', stage: 0,
    budget: [30, 90], wants: { ekmek: 6, simit: 3, ayran: 4, biskuvi: 3, sut: 3, domates: 3, cay: 2, peynir: 2 }, listSize: [1, 3],
    patience: 48, priceTolerance: 0.06, speed: 0.95, litter: 0.0, impulse: 0.12, accessory: 'flatcap',
    palette: { tops: [0x9c6644, 0x6b705c, 0xa5a58d, 0x7f5539], bottoms: [0x4a4e69, 0x5e503f] },
    hourCurve: (h) => 0.2 + bell(h, 8.5, 1.4) * 1.6 + bell(h, 13, 1.5) * 0.5,
  },
  {
    id: 'calisan', name: 'Beyaz Yaka', blurb: 'Aceleci ama cömert. Kuyrukta beklemeyi hiç sevmez.', stage: 0,
    budget: [60, 180], wants: { kola: 4, ayran: 3, simit: 4, cips: 2, cikolata: 2, biskuvi: 1, su: 3 }, listSize: [1, 3],
    patience: 16, priceTolerance: 0.35, speed: 1.45, litter: 0.002, impulse: 0.3, accessory: 'briefcase',
    palette: { tops: [0xf1faee, 0xa8dadc, 0xe9ecef, 0xcdb4db], bottoms: [0x1d3557, 0x343a40, 0x22223b] },
    hourCurve: (h) => 0.15 + bell(h, 8, 0.7) * 1.4 + bell(h, 12.5, 0.8) * 1.0 + bell(h, 18.5, 1.0) * 1.5,
  },
  {
    id: 'aile', name: 'Aile Alışverişçisi', blurb: 'Uzun listeyle gelir, sepeti doldurur. Taze ürün ve temiz mağaza ister.', stage: 1,
    budget: [120, 320], wants: { ekmek: 3, sut: 4, domates: 4, elma: 4, deterjan: 2, biskuvi: 2, ayran: 2, cikolata: 1, makarna: 2, peynir: 2 }, listSize: [3, 5],
    patience: 34, priceTolerance: 0.15, speed: 1.1, litter: 0.001, impulse: 0.35, accessory: 'totebag',
    palette: { tops: [0xe76f51, 0xf4a261, 0x8ecae6, 0xb5838d], bottoms: [0x3a5a40, 0x6d597a, 0x1d3557] },
    hourCurve: (h) => 0.2 + bell(h, 11, 1.8) * 1.0 + bell(h, 18, 1.5) * 1.3,
  },
  {
    id: 'firsatci', name: 'Fırsatçı', blurb: 'Kimse bakmıyorsa cebine bir şey atar ve kapıya yönelir. Kamera, alarm ve güvenlik onu caydırır.', stage: 1,
    budget: [0, 10], wants: { deterjan: 4, cikolata: 3, kola: 2, peynir: 4, cay: 3, cips: 2 }, listSize: [1, 3],
    patience: 30, priceTolerance: 0, speed: 1.35, litter: 0.004, impulse: 0, accessory: 'hood', thief: true,
    palette: { tops: [0x2f3440, 0x3d3a4a, 0x4a4f3a], bottoms: [0x22252c, 0x2b3a55] },
    hourCurve: (h) => 0.06 + bell(h, 20, 2) * 0.1,
  },
  {
    id: 'haftalik', name: 'Haftalık Alışverişçi', blurb: 'Arabayla gelir, 5–8 kalemlik uzun liste. Reyon levhası ve araba parkı ister.', stage: 2,
    budget: [250, 600], wants: { makarna: 3, cay: 2, peynir: 3, su: 3, sut: 3, ekmek: 2, deterjan: 2, domates: 2, elma: 2, biskuvi: 1, ayran: 1 }, listSize: [5, 8],
    patience: 40, priceTolerance: 0.12, speed: 1.1, litter: 0.001, impulse: 0.4, accessory: 'totebag', cart: true,
    palette: { tops: [0x5a7d9a, 0xc97b63, 0x8a9a5b, 0xe0c38c], bottoms: [0x2b3a55, 0x4a4e69] },
    hourCurve: (h) => 0.1 + bell(h, 11, 2) * 0.9 + bell(h, 18.5, 1.5) * 1.1,
  },
];

export const ARCHETYPE_MAP: Record<string, Archetype> = Object.fromEntries(ARCHETYPES.map((a) => [a.id, a]));

export const SKIN_TONES = [0xf6d2b8, 0xe8b894, 0xd29a74, 0xb57b55, 0x8d5a3b, 0xf1c7a5];
export const HAIR_COLORS = [0x2b1d16, 0x4a2f1f, 0x7a4b2a, 0xb88a4a, 0x1a1a1a, 0x8e3b24];
export const GREY_HAIR = [0xd9d6d0, 0xbcb7ae, 0xe8e4dc];
