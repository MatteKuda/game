import type { Game } from '../game';
import { PRODUCT_MAP } from '../data/products';

/**
 * Mahalle olayları: small decisions that pop up 2–3 times a day so there is always
 * something to react to — a wholesaler bargain, a bulk order, match night, an inspection.
 */
export type NeighborKind = 'deal' | 'bulk' | 'match' | 'inspect' | 'praise';

export interface NeighborChoice { label: string; hint?: string; primary?: boolean; disabled?: boolean }
export interface NeighborEvent {
  id: number;
  kind: NeighborKind;
  title: string;
  text: string;
  icon: string; // svg icon name
  expires: number; // absolute game minute
  choices: NeighborChoice[];
  data: Record<string, number | string | Record<string, number>>;
}

let nextId = 1;
const pick = <T,>(a: T[]) => a[(Math.random() * a.length) | 0];
const NAMES = ['Selim Bey', 'Nuriye Hanım', 'Muhtar Ahmet', 'Kerime Teyze', 'Hakan Abi', 'Sevgi Hanım'];

/** absolute minute of the evening window used by match night */
export const MATCH_FROM = 19 * 60;

export function rollEvent(g: Game): NeighborEvent | null {
  const stocked = g.unlockedProducts().filter((p) => g.isStocked(p.id));
  if (!stocked.length) return null;
  const kinds: NeighborKind[] = ['deal', 'deal', 'bulk', 'bulk', 'praise'];
  if (g.clock < 16 * 60 && !g.matchNight) kinds.push('match');
  if (g.clock < 18 * 60) kinds.push('inspect');
  const kind = pick(kinds);
  const scale = [1, 1.8, 3, 4][g.stage];
  const now = g.absMinutes;
  const base = { id: nextId++, kind, expires: now + 45 };
  switch (kind) {
    case 'deal': {
      const p = pick(stocked.filter((x) => x.id !== 'simit' && x.id !== 'ekmek')) ?? pick(stocked);
      const qty = Math.round((24 + Math.random() * 24) * scale / 6) * 6;
      const off = pick([0.3, 0.35, 0.4]);
      const cost = Math.round(qty * p.cost * (1 - off));
      const room = g.depotCapacity() - g.backstockTotal() - g.incomingTotal();
      return { ...base, title: 'Toptancıdan fırsat', icon: 'truck',
        text: `Toptancının elinde fazla ${p.name} kaldı: ${qty} adet %${Math.round(off * 100)} indirimle, 1 saat içinde getirir.`,
        choices: [{ label: `Al · ₺${cost}`, primary: true, disabled: room < qty || g.money < cost, hint: room < qty ? 'Depoda yer yok' : undefined }, { label: 'Geç' }],
        data: { pid: p.id, qty, cost } };
    }
    case 'bulk': {
      const n = Math.min(2, stocked.length);
      const items: Record<string, number> = {};
      const pool = [...stocked];
      for (let i = 0; i < n; i++) {
        const k = (Math.random() * pool.length) | 0;
        const p = pool.splice(k, 1)[0];
        items[p.id] = Math.max(4, Math.round((6 + Math.random() * 10) * scale / 2) * 2);
      }
      let pay = 0;
      for (const pid in items) pay += items[pid] * g.prices[pid];
      pay = Math.round(pay * 1.2);
      const who = pick(NAMES);
      const list = Object.entries(items).map(([pid, q]) => `${q} ${PRODUCT_MAP[pid].name.toLowerCase()}`).join(' + ');
      const enough = Object.entries(items).every(([pid, q]) => g.backstock[pid] + g.shelfStock(pid) >= q);
      return { ...base, expires: now + 60, title: 'Toplu sipariş', icon: 'people',
        text: `${who} apartmana ${list} istiyor, %20 fazlasını öder. Depodan ve raftan düşülür.`,
        choices: [{ label: `Hazırla · +₺${pay}`, primary: true, disabled: !enough, hint: enough ? undefined : 'Stok yetmiyor' }, { label: 'Reddet' }],
        data: { pay, items } };
    }
    case 'match':
      return { ...base, expires: now + 90, title: 'Bu akşam derbi var!', icon: 'star',
        text: 'Mahalle maç için toplanacak: 19:00–22:00 arası kola ve cips talebi 2,5 katı. Stok yap, istersen vitrine afiş as.',
        choices: [{ label: 'Afiş as · ₺150 (akşam +%30 müşteri)', primary: true, disabled: g.money < 150 }, { label: 'Tamam, stok yaparım' }],
        data: {} };
    case 'inspect':
      return { ...base, expires: now + 60, title: 'Zabıta denetimi geliyor', icon: 'alert',
        text: 'Belediye 1 saat içinde denetime gelecek. Yerde çöp ya da boş raf varsa ceza keser; temiz dükkâna puan artar.',
        choices: [{ label: 'Hazırız' }, { label: 'Temizlikçi çağır · ₺120', primary: true, disabled: g.money < 120 }],
        data: {} };
    case 'praise':
      return { ...base, expires: now + 30, title: 'Muhtar dükkânı övdü', icon: 'heart',
        text: 'Muhtar kahvede dükkânından bahsetmiş. Bugün mahalleden biraz daha fazla müşteri gelecek.',
        choices: [{ label: 'Harika!', primary: true }], data: {} };
  }
}

/** apply the player's choice; returns a short result line for the alert log */
export function resolveEvent(g: Game, ev: NeighborEvent, choice: number): string {
  const d = ev.data;
  switch (ev.kind) {
    case 'deal':
      if (choice !== 0) return '';
      if (g.money < (d.cost as number)) return 'Para yetmedi.';
      g.money -= d.cost as number; g.stats.purchases += d.cost as number;
      g.orders.push({ pid: d.pid as string, qty: d.qty as number, eta: g.absMinutes + 60, urgent: true });
      return `${PRODUCT_MAP[d.pid as string].name} fırsatı alındı, 1 saat içinde geliyor.`;
    case 'bulk': {
      if (choice !== 0) return '';
      const items = d.items as Record<string, number>;
      for (const [pid, q] of Object.entries(items)) {
        let need = q;
        const fromBack = Math.min(need, g.backstock[pid]); g.backstock[pid] -= fromBack; need -= fromBack;
        for (const f of g.fixtures) for (const s of f.slots) if (need > 0 && s.productId === pid) { const t = Math.min(need, s.stock); s.stock -= t; need -= t; }
        g.stats.soldBy[pid] = (g.stats.soldBy[pid] ?? 0) + q;
      }
      g.money += d.pay as number; g.stats.revenue += d.pay as number;
      g.refreshAll();
      return `Toplu sipariş teslim edildi: +₺${d.pay}.`;
    }
    case 'match':
      g.matchNight = { day: g.day, poster: choice === 0 };
      if (choice === 0) { g.money -= 150; g.stats.other += 150; }
      return choice === 0 ? 'Maç afişi asıldı: akşam kalabalık olacak.' : 'Maç akşamı: kola ve cipsi doldurmayı unutma.';
    case 'inspect':
      if (choice === 1) { g.money -= 120; g.stats.other += 120; for (const L of [...g.litter]) g.removeLitter(L); }
      g.inspectionAt = g.absMinutes + 60;
      return choice === 1 ? 'Temizlikçi yerleri pırıl pırıl yaptı.' : 'Denetim 1 saat içinde.';
    case 'praise':
      g.praiseUntil = g.absMinutes + 6 * 60;
      return '';
  }
}
