import type { Display } from './products';

export type FixtureKind =
  | 'display' | 'register' | 'depot' | 'plant' | 'bin'
  | 'camera' | 'gate' | 'break' | 'oven' | 'carts' | 'sign'
  | 'table' | 'play' | 'bench';

/** where a fixture may be placed: player's store floor, AVM common areas, or both */
export type Zone = 'store' | 'mall' | 'any';

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
  category: 'Teşhir' | 'Kasa & Depo' | 'Ortam' | 'Güvenlik & Personel' | 'AVM';
  zone?: Zone; // default 'store'
  noBlock?: boolean; // hung from the ceiling / wall: does not occupy walkable tiles
  /** register variants */
  serviceMul?: number; // <1 faster
  selfService?: boolean; // no cashier needed
  /** coverage radius for cameras / signs, seats for tables */
  radius?: number;
  seats?: number;
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
    w: 2, d: 1, cost: 1500, stage: 0, maxCount: [1, 3, 4, 4],
  },
  {
    id: 'depo', name: 'Depo Rafı', desc: 'Yedek stok burada tutulur. +240 birim depo kapasitesi.', kind: 'depot', category: 'Kasa & Depo',
    w: 2, d: 1, cost: 800, stage: 0, depotCapacity: 240,
  },
  {
    id: 'saksi', name: 'Saksı Bitki', desc: 'Çevresindeki alışverişi daha keyifli yapar.', kind: 'plant', category: 'Ortam',
    w: 1, d: 1, cost: 150, stage: 0, ambiance: 3, zone: 'any',
  },
  {
    id: 'cop', name: 'Çöp Kovası', desc: 'Yakınında yere çöp atılmaz (3 m).', kind: 'bin', category: 'Ortam',
    w: 1, d: 1, cost: 120, stage: 0, binRadius: 3, zone: 'any',
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
  // Güvenlik & personel (Market+)
  {
    id: 'kamera', name: 'Güvenlik Kamerası', desc: 'Tavana asılı dönen kamera. Görüş konisindeki hırsızlar fark edilir (6 m).', kind: 'camera', category: 'Güvenlik & Personel',
    w: 1, d: 1, cost: 900, stage: 1, zone: 'any', noBlock: true, radius: 6,
  },
  {
    id: 'alarm', name: 'Alarm Kapısı', desc: 'Kapının yanına kurulur. Ödenmemiş ürünle geçenlerde öter (%85).', kind: 'gate', category: 'Güvenlik & Personel',
    w: 1, d: 1, cost: 1600, stage: 1,
  },
  {
    id: 'cay', name: 'Çay Ocağı (Mola)', desc: 'Yorulan personel burada çay içip dinlenir. Molasız personel yavaşlar.', kind: 'break', category: 'Güvenlik & Personel',
    w: 2, d: 1, cost: 700, stage: 0,
  },
  // Süpermarket
  {
    id: 'bantkasa', name: 'Bantlı Kasa', desc: 'Yürüyen bantlı kasa. Ödeme %35 daha hızlı, uzun kuyruk için ideal.', kind: 'register', category: 'Kasa & Depo',
    w: 3, d: 1, cost: 4200, stage: 2, serviceMul: 0.65, maxCount: [0, 0, 5, 6],
  },
  {
    id: 'selfkasa', name: 'Self-Servis Kasa', desc: 'Kasiyer gerektirmez ama yavaştır ve hırsızlık riskini artırır.', kind: 'register', category: 'Kasa & Depo',
    w: 1, d: 1, cost: 3000, stage: 2, serviceMul: 1.35, selfService: true, maxCount: [0, 0, 6, 8],
  },
  {
    id: 'levha', name: 'Reyon Levhası', desc: 'Tavandan asılı kategori levhası. Yakınındaki (5 m) rafları bulmak kolaylaşır.', kind: 'sign', category: 'Ortam',
    w: 1, d: 1, cost: 250, stage: 2, noBlock: true, radius: 5,
  },
  {
    id: 'firin', name: 'Fırın Tezgâhı', desc: 'Fırıncı burada sıcak simit ve ekmek pişirir: ucuz maliyet, mutlu müşteri.', kind: 'oven', category: 'Teşhir',
    w: 2, d: 1, cost: 5200, stage: 2,
  },
  {
    id: 'araba', name: 'Alışveriş Arabası Parkı', desc: 'Haftalık alışverişçiler araba alır; yoksa sepetleri taşmaz, listeleri kısalır.', kind: 'carts', category: 'Kasa & Depo',
    w: 2, d: 1, cost: 1100, stage: 2,
  },
  // AVM ortak alan
  {
    id: 'masa', name: 'Yemek Masası', desc: 'Yemek katı için 4 kişilik masa. Kirlenince temizlik görevlisi toplar.', kind: 'table', category: 'AVM',
    w: 2, d: 2, cost: 700, stage: 3, zone: 'mall', seats: 4,
  },
  {
    id: 'oyunalani', name: 'Çocuk Oyun Alanı', desc: 'Kaydırak ve top havuzu. Aileler uzun kalır, oyuncakçı mutlu olur.', kind: 'play', category: 'AVM',
    w: 3, d: 3, cost: 6000, stage: 3, zone: 'mall',
  },
  {
    id: 'bank', name: 'Dinlenme Bankı', desc: 'Yorulan ziyaretçiler oturur, AVM keyfi artar.', kind: 'bench', category: 'AVM',
    w: 2, d: 1, cost: 400, stage: 3, zone: 'mall',
  },
];

export function fixtureZone(d: FixtureDef): Zone { return d.zone ?? 'store'; }

export const FIXTURE_MAP: Record<string, FixtureDef> = Object.fromEntries(FIXTURES.map((f) => [f.id, f]));
