// AVM (stage 3) layout, tenants, visitor archetypes and events. Everything is fictional/original.
import type { Rect } from '../config';

export interface UnitDef {
  id: string;
  floor: number;
  rect: Rect;
  door: { tiles: { x: number; z: number }[]; dir: [number, number] }; // door tiles inside the unit, dir points to the corridor
  food?: boolean; // food-court stall
}

export const MALL_FOOTPRINT: Rect = { x0: 2, z0: 0, x1: 42, z1: 16 };

// Floor 0 common areas (the supermarket sits in the middle: x10..34, z4..16)
export const MALL_F0_CORRIDORS: Rect[] = [
  { x0: 6, z0: 0, x1: 10, z1: 16 },
  { x0: 34, z0: 0, x1: 38, z1: 16 },
  { x0: 10, z0: 0, x1: 34, z1: 4 },
];
export const MALL_ENTRANCES: number[] = [7, 8, 35, 36]; // x of doors on the front edge (z15<->z16)

export const UNITS: UnitDef[] = [
  { id: 'L1', floor: 0, rect: { x0: 2, z0: 0, x1: 6, z1: 8 }, door: { tiles: [{ x: 5, z: 3 }, { x: 5, z: 4 }], dir: [1, 0] } },
  { id: 'L2', floor: 0, rect: { x0: 2, z0: 8, x1: 6, z1: 16 }, door: { tiles: [{ x: 5, z: 11 }, { x: 5, z: 12 }], dir: [1, 0] } },
  { id: 'R1', floor: 0, rect: { x0: 38, z0: 0, x1: 42, z1: 8 }, door: { tiles: [{ x: 38, z: 3 }, { x: 38, z: 4 }], dir: [-1, 0] } },
  { id: 'R2', floor: 0, rect: { x0: 38, z0: 8, x1: 42, z1: 16 }, door: { tiles: [{ x: 38, z: 11 }, { x: 38, z: 12 }], dir: [-1, 0] } },
  { id: 'U1', floor: 1, rect: { x0: 2, z0: 0, x1: 10, z1: 5 }, door: { tiles: [{ x: 5, z: 4 }, { x: 6, z: 4 }], dir: [0, 1] } },
  { id: 'U2', floor: 1, rect: { x0: 19, z0: 0, x1: 27, z1: 5 }, door: { tiles: [{ x: 22, z: 4 }, { x: 23, z: 4 }], dir: [0, 1] } },
  { id: 'U3', floor: 1, rect: { x0: 31, z0: 0, x1: 42, z1: 5 }, door: { tiles: [{ x: 35, z: 4 }, { x: 36, z: 4 }], dir: [0, 1] } },
  { id: 'U4', floor: 1, rect: { x0: 2, z0: 7, x1: 8, z1: 16 }, door: { tiles: [{ x: 7, z: 10 }, { x: 7, z: 11 }], dir: [1, 0] } },
  { id: 'U5', floor: 1, rect: { x0: 36, z0: 7, x1: 42, z1: 16 }, door: { tiles: [{ x: 36, z: 10 }, { x: 36, z: 11 }], dir: [-1, 0] } },
  { id: 'U6', floor: 1, rect: { x0: 12, z0: 13, x1: 20, z1: 16 }, door: { tiles: [{ x: 15, z: 13 }, { x: 16, z: 13 }], dir: [0, -1] }, food: true },
  { id: 'U7', floor: 1, rect: { x0: 24, z0: 13, x1: 32, z1: 16 }, door: { tiles: [{ x: 27, z: 13 }, { x: 28, z: 13 }], dir: [0, -1] }, food: true },
];

export interface ConnectorDef {
  id: string;
  kind: 'escalator' | 'elevator';
  name: string;
  blocked: Rect; // tiles blocked on both floors
  from: { floor: number; x: number; z: number }; // boarding tile
  to: { floor: number; x: number; z: number }; // landing tile
  bidirectional?: boolean; // elevators work both ways
  rideTime: number; // seconds
}

export const CONNECTORS: ConnectorDef[] = [
  { id: 'escUp', kind: 'escalator', name: 'Yürüyen Merdiven (yukarı)', blocked: { x0: 13, z0: 1, x1: 18, z1: 2 }, from: { floor: 0, x: 12, z: 1 }, to: { floor: 1, x: 18, z: 1 }, rideTime: 5.5 },
  { id: 'escDown', kind: 'escalator', name: 'Yürüyen Merdiven (aşağı)', blocked: { x0: 13, z0: 2, x1: 18, z1: 3 }, from: { floor: 1, x: 18, z: 2 }, to: { floor: 0, x: 12, z: 2 }, rideTime: 5.5 },
  { id: 'lift', kind: 'elevator', name: 'Cam Asansör', blocked: { x0: 28, z0: 0, x1: 30, z1: 2 }, from: { floor: 0, x: 28, z: 2 }, to: { floor: 1, x: 28, z: 2 }, bidirectional: true, rideTime: 4 },
];

// The opening in the floor-1 slab above the escalators
export const ESCALATOR_WELL: Rect = { x0: 12, z0: 1, x1: 18, z1: 3 };

export type TenantCategory = 'giyim' | 'elektronik' | 'kitap' | 'oyuncak' | 'kuafor' | 'oyun' | 'spor' | 'kafe' | 'burger' | 'pide';

export interface TenantDef {
  id: TenantCategory;
  name: string; // category label
  brand: string; // fictional brand on the sign
  color: string;
  accent: string;
  rent: number; // per day
  share: number; // share of tenant sales paid to us
  spend: [number, number];
  buyChance: number;
  food?: boolean;
  noisy?: boolean;
  rule: string; // what makes them happy, shown in UI
}

export const TENANTS: TenantDef[] = [
  { id: 'giyim', name: 'Giyim', brand: 'KUMAŞ & KO', color: '#1f8a86', accent: '#f2b33d', rent: 900, share: 0.08, spend: [120, 420], buyChance: 0.45, rule: 'Zemin katı ve girişe yakınlığı sever' },
  { id: 'elektronik', name: 'Elektronik', brand: 'VOLTAJ', color: '#2f3a8a', accent: '#61d4ff', rent: 1400, share: 0.06, spend: [300, 1600], buyChance: 0.25, rule: 'Yürüyen merdiven / asansöre yakın olmak ister' },
  { id: 'kitap', name: 'Kitabevi', brand: 'SAYFA', color: '#7a4a2a', accent: '#f6e7c8', rent: 500, share: 0.1, spend: [60, 220], buyChance: 0.5, rule: 'Gürültülü komşu (oyun salonu) istemez' },
  { id: 'oyuncak', name: 'Oyuncakçı', brand: 'ZIPZIP', color: '#e0663c', accent: '#ffe066', rent: 700, share: 0.1, spend: [80, 350], buyChance: 0.5, rule: 'Çocuk oyun alanına yakın olmayı sever' },
  { id: 'kuafor', name: 'Kuaför', brand: 'MAKAS', color: '#b0546a', accent: '#ffd6e0', rent: 600, share: 0.12, spend: [150, 400], buyChance: 0.6, rule: 'Sakin köşeler ve temiz koridor ister' },
  { id: 'oyun', name: 'Oyun Salonu', brand: 'JETON', color: '#6c4ab6', accent: '#7fe3c8', rent: 1100, share: 0.1, spend: [40, 160], buyChance: 0.8, noisy: true, rule: 'Gürültülüdür: yanındaki kiracıları rahatsız eder' },
  { id: 'spor', name: 'Spor', brand: 'KOŞU', color: '#d6333a', accent: '#ffffff', rent: 1000, share: 0.07, spend: [150, 700], buyChance: 0.35, rule: 'Kalabalık koridor ve üst katta vitrin sever' },
  { id: 'kafe', name: 'Kahveci', brand: 'DEMLİK', color: '#5b3a24', accent: '#f2b33d', rent: 800, share: 0.12, spend: [45, 120], buyChance: 0.9, food: true, rule: 'Yemek katında yeterli masa (≥8 koltuk) ister' },
  { id: 'burger', name: 'Burgerci', brand: 'TOMBUL', color: '#f2b33d', accent: '#d6333a', rent: 950, share: 0.12, spend: [90, 200], buyChance: 0.9, food: true, rule: 'Yemek katında yeterli masa ve temiz masalar ister' },
  { id: 'pide', name: 'Pideci', brand: 'NAZLI PİDE', color: '#3f8f3a', accent: '#fff1dc', rent: 850, share: 0.12, spend: [80, 180], buyChance: 0.9, food: true, rule: 'Temiz masa ve aile ziyaretçileri sever' },
];

export const TENANT_MAP: Record<string, TenantDef> = Object.fromEntries(TENANTS.map((t) => [t.id, t]));

export interface VisitorArch {
  id: string;
  name: string;
  interests: Partial<Record<TenantCategory | 'play' | 'bench', number>>;
  stops: [number, number];
  speed: number;
  hunger: number; // chance to eat
  prefersLift?: boolean;
  child?: boolean;
  weight: (h: number) => number;
  palette: { tops: number[]; bottoms: number[] };
}

const bell = (h: number, c: number, w: number) => Math.exp(-((h - c) * (h - c)) / (2 * w * w));

export const VISITORS: VisitorArch[] = [
  { id: 'genc', name: 'Genç', interests: { giyim: 3, elektronik: 2, oyun: 3, burger: 2, spor: 2, kafe: 1 }, stops: [2, 4], speed: 1.45, hunger: 0.5,
    weight: (h) => 0.3 + bell(h, 16, 2) * 1.2 + bell(h, 20, 1.5) * 0.8, palette: { tops: [0x6c63ff, 0x2ec4b6, 0xff6b6b], bottoms: [0x2b3a67, 0x3d405b] } },
  { id: 'aile', name: 'Aile', interests: { oyuncak: 3, giyim: 2, play: 4, pide: 2, burger: 1, kafe: 1, bench: 1 }, stops: [2, 4], speed: 1.05, hunger: 0.7, child: true,
    weight: (h) => 0.2 + bell(h, 12, 2) * 0.8 + bell(h, 18, 2) * 1.2, palette: { tops: [0xe76f51, 0xf4a261, 0x8ecae6], bottoms: [0x3a5a40, 0x6d597a] } },
  { id: 'profesyonel', name: 'Profesyonel', interests: { elektronik: 3, kitap: 2, kafe: 3, kuafor: 1, spor: 1 }, stops: [1, 3], speed: 1.4, hunger: 0.4,
    weight: (h) => 0.2 + bell(h, 12.5, 1) * 1.0 + bell(h, 18.5, 1.2) * 1.1, palette: { tops: [0xf1faee, 0xa8dadc, 0xcdb4db], bottoms: [0x1d3557, 0x343a40] } },
  { id: 'emekliz', name: 'Emekli Çift', interests: { kitap: 2, kafe: 3, kuafor: 2, pide: 1, bench: 3 }, stops: [1, 3], speed: 0.9, hunger: 0.5, prefersLift: true,
    weight: (h) => 0.3 + bell(h, 11, 2) * 1.0, palette: { tops: [0x9c6644, 0x6b705c, 0xa5a58d], bottoms: [0x4a4e69, 0x5e503f] } },
];

export interface MallEventDef {
  id: string;
  name: string;
  desc: string;
  cost: number;
  visitorMul: number;
  tenantMul: number;
  storeMul: number;
  familyMul?: number;
  boost?: TenantCategory; // tenant whose sales triple
  needs?: TenantCategory | 'play';
  noisy?: boolean;
}

export const MALL_EVENTS: MallEventDef[] = [
  { id: 'konser', name: 'Akşam Konseri', desc: 'Yemek katında sahne kurulur, akşam kalabalık gelir. Gürültülüdür.', cost: 4000, visitorMul: 1.7, tenantMul: 1.1, storeMul: 1.1, noisy: true },
  { id: 'imza', name: 'İmza Günü', desc: 'Sevilen bir yazar kitabevinde. Kitabevi satışları üç katına çıkar.', cost: 1500, visitorMul: 1.25, tenantMul: 1.0, storeMul: 1.0, boost: 'kitap', needs: 'kitap' },
  { id: 'bayram', name: 'Bayram İndirimleri', desc: 'Her yer süslenir, herkes alışverişte. Süpermarket de kazanır.', cost: 2500, visitorMul: 1.4, tenantMul: 1.5, storeMul: 1.3 },
  { id: 'cocuk', name: 'Çocuk Şenliği', desc: 'Balonlar, palyaço, oyun alanında etkinlik. Aileler akın eder.', cost: 2000, visitorMul: 1.3, tenantMul: 1.1, storeMul: 1.05, familyMul: 2.2, boost: 'oyuncak', needs: 'play' },
];
