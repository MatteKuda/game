import type { Game } from '../game';
import { STAGES } from '../data/stages';

export interface SaveData {
  v: 1;
  savedAt: number;
  label: string;
  day: number;
  stage: number;
  money: number;
  rating: number;
  prices: Record<string, number>;
  auto: Record<string, boolean>;
  backstock: Record<string, number>;
  orders: { pid: string; qty: number; eta: number }[];
  upgrades: string[];
  totals: Game['totals'];
  history: Game['history'];
  fixtures: { id: string; x: number; z: number; rot: number; floor: number; slots: [string | null, number][] }[];
  staff: { role: string; name: string; wage: number; skill: number; shift: string }[];
  mall?: { tenants: { unit: number; id: string; rent: number; sat: number }[]; scheduled: { day: number; id: string }[]; mood: number; history: { day: number; income: number; visitors: number }[] };
}

const KEY = 'tezgah.save.';
export const SLOTS = ['oto', '1', '2', '3'] as const;
export type Slot = typeof SLOTS[number];

export function serialize(g: Game): SaveData {
  const day = g.dayEnded ? g.day + 1 : g.day; // an end-of-day save resumes on the next morning
  return {
    v: 1,
    savedAt: Date.now(),
    label: `Gün ${day} · ${STAGES[g.stage].name}`,
    day,
    stage: g.stage,
    money: Math.round(g.money),
    rating: g.rating,
    prices: { ...g.prices },
    auto: { ...g.auto },
    backstock: { ...g.backstock },
    orders: g.orders.map((o) => ({ ...o })),
    upgrades: [...g.upgrades],
    totals: { ...g.totals },
    history: g.history.map((h) => ({ ...h })),
    fixtures: g.fixtures.map((f) => ({ id: f.def.id, x: f.x, z: f.z, rot: f.rot, floor: f.floor, slots: f.slots.map((s) => [s.productId, s.stock] as [string | null, number]) })),
    staff: g.staff.map((s) => ({ role: s.role, name: s.name, wage: s.baseWage, skill: s.skill, shift: s.shift })),
    mall: g.mall ? {
      tenants: g.mall.units.filter((u) => u.tenant).map((u) => ({ unit: u.idx, id: u.tenant!.def.id, rent: u.tenant!.rent, sat: u.tenant!.sat })),
      scheduled: g.mall.scheduled.map((s) => ({ ...s })),
      mood: g.mall.mood,
      history: g.mall.history,
    } : undefined,
  };
}

export function writeSave(slot: Slot, data: SaveData): boolean {
  try { localStorage.setItem(KEY + slot, JSON.stringify(data)); return true; } catch { return false; }
}

export function readSave(slot: string): SaveData | null {
  try {
    const raw = localStorage.getItem(KEY + slot);
    if (!raw) return null;
    const d = JSON.parse(raw) as SaveData;
    return d && d.v === 1 ? d : null;
  } catch { return null; }
}

export function listSaves(): { slot: Slot; data: SaveData | null }[] {
  return SLOTS.map((slot) => ({ slot, data: readSave(slot) }));
}

export function deleteSave(slot: Slot) { try { localStorage.removeItem(KEY + slot); } catch { /* ignore */ } }

/** loading restarts the page with ?load=slot so the world is rebuilt cleanly */
export function loadAndRestart(slot: Slot) {
  const u = new URL(location.href);
  u.searchParams.set('load', slot);
  location.href = u.toString();
}

export function newGame() {
  const u = new URL(location.href);
  u.searchParams.delete('load');
  u.searchParams.set('yeni', '1');
  location.href = u.toString();
}
