import type { Display } from './products';

export type FixtureKind = 'display' | 'register' | 'depot' | 'plant' | 'bin';

export interface FixtureDef {
  id: string;
  name: string;
  desc: string;
  kind: FixtureKind;
  w: number; // footprint along local x
  d: number; // footprint along local z (front faces +z)
  cost: number;
  stage: number;
  display?: Display;
  slots?: number;
  slotCapacity?: number;
  depotCapacity?: number;
  ambiance?: number; // pleasantness radius bonus
  binRadius?: number;
  maxCount?: number[]; // per stage limit
  category: 'Teşhir' | 'Kasa & Depo' | 'Ortam';
}

export const FIXTURES: FixtureDef[] = [
  {
    id: 'raf', name: 'Ahşap Raf', desc: 'Kuru gıda için iki bölmeli sıcak ahşap raf.', kind: 'display', category: 'Teşhir',
    w: 2, d: 1, cost: 600, stage: 0, display: 'shelf', slots: 2, slotCapacity: 12,
  },
  {
    id: 'dolap', name: 'İçecek Dolabı', desc: 'Işıklı cam kapaklı soğutucu. Soğuk ürünler burada durur.', kind: 'display', category: 'Teşhir',
    w: 1, d: 1, cost: 1200, stage: 0, display: 'fridge', slots: 2, slotCapacity: 10,
  },
  {
    id: 'sepet', name: 'Fırın Sepeti', desc: 'İki katlı hasır sepet: simit ve ekmek sabahın yıldızı.', kind: 'display', category: 'Teşhir',
    w: 1, d: 1, cost: 350, stage: 0, display: 'basket', slots: 2, slotCapacity: 10,
  },
  {
    id: 'kasa', name: 'Kasa Tezgâhı', desc: 'Müşteriler burada öder. Kasiyer arkasında durur, kuyruk kapıya doğru uzar.', kind: 'register', category: 'Kasa & Depo',
    w: 2, d: 1, cost: 1500, stage: 0, maxCount: [1, 3],
  },
  {
    id: 'depo', name: 'Depo Rafı', desc: 'Yedek stok burada tutulur. +80 birim depo kapasitesi.', kind: 'depot', category: 'Kasa & Depo',
    w: 2, d: 1, cost: 800, stage: 0, depotCapacity: 80,
  },
  {
    id: 'saksi', name: 'Saksı Bitki', desc: 'Çevresindeki alışverişi daha keyifli yapar.', kind: 'plant', category: 'Ortam',
    w: 1, d: 1, cost: 150, stage: 0, ambiance: 3,
  },
  {
    id: 'cop', name: 'Çöp Kovası', desc: 'Yakınında yere çöp atılmaz (3 m).', kind: 'bin', category: 'Ortam',
    w: 1, d: 1, cost: 120, stage: 0, binRadius: 3,
  },
  // Stage 1 — Mahalle Marketi
  {
    id: 'gondol', name: 'Orta Gondol', desc: 'Üç bölmeli metal gondol reyon. Market düzeninin omurgası.', kind: 'display', category: 'Teşhir',
    w: 3, d: 1, cost: 1400, stage: 1, display: 'shelf', slots: 3, slotCapacity: 14,
  },
  {
    id: 'manav', name: 'Manav Tezgâhı', desc: 'Eğimli kasalarda taze meyve ve sebze.', kind: 'display', category: 'Teşhir',
    w: 2, d: 1, cost: 1100, stage: 1, display: 'produce', slots: 2, slotCapacity: 16,
  },
  {
    id: 'acik', name: 'Açık Soğutucu', desc: 'Kapısız, üç bölmeli geniş soğutucu. Hızlı alışveriş.', kind: 'display', category: 'Teşhir',
    w: 3, d: 1, cost: 3200, stage: 1, display: 'fridge', slots: 3, slotCapacity: 10,
  },
];

export const FIXTURE_MAP: Record<string, FixtureDef> = Object.fromEntries(FIXTURES.map((f) => [f.id, f]));
