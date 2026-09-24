import * as THREE from 'three';
import type { Game } from '../game';
import type { Tile } from './grid';
import { Grid, R_MALL, R_UNIT0, R_IN, R_OUT } from './grid';
import { Visitor } from './visitor';
import { pick, rand } from './agents';
import { FLOOR_H, MAP_W, SIDEWALK_Z0 } from '../config';
import {
  UNITS, CONNECTORS, TENANTS, VISITORS, MALL_EVENTS, MALL_ENTRANCES, MALL_F0_CORRIDORS, MALL_FOOTPRINT, ESCALATOR_WELL,
  type UnitDef, type TenantDef, type ConnectorDef, type MallEventDef, type TenantCategory,
} from '../data/mall';

export interface TenantState {
  def: TenantDef;
  rent: number;
  sat: number;
  reasons: { text: string; v: number }[];
  salesToday: number;
  visitorsToday: number;
  lowDays: number;
  since: number;
}
export interface UnitState { idx: number; def: UnitDef; tenant: TenantState | null; offers: { def: TenantDef; rent: number }[] }
export interface ConnectorState { def: ConnectorDef; broken: boolean; repairT: number; liftY: number; liftTarget: number }

const newMallStats = () => ({ visitors: 0, tenantSales: 0, rentIncome: 0, shareIncome: 0, incidents: 0, noSeat: 0, moodSum: 0, moodN: 0 });

export class Mall {
  units: UnitState[];
  connectors: ConnectorState[];
  visitors: Visitor[] = [];
  event: { def: MallEventDef; day: number } | null = null;
  scheduled: { day: number; id: string }[] = [];
  mood = 3.5;
  stats = newMallStats();
  history: { day: number; income: number; visitors: number }[] = [];
  private spawnAcc = 0;
  private hourAcc = 0;
  private satAcc = 0;

  constructor(private game: Game) {
    this.units = UNITS.map((def, idx) => ({ idx, def, tenant: null, offers: [] }));
    this.connectors = CONNECTORS.map((def) => ({ def, broken: false, repairT: 0, liftY: 0, liftTarget: 0 }));
    this.rollOffers();
  }

  // ------------------------------------------------------------ layout
  /** carve mall regions, unit rooms and doors into both floor grids */
  applyGrids(g0: Grid, g1: Grid) {
    for (const r of MALL_F0_CORRIDORS) for (let z = r.z0; z < r.z1; z++) for (let x = r.x0; x < r.x1; x++) g0.region[g0.idx(x, z)] = R_MALL;
    const F = MALL_FOOTPRINT;
    g1.region.fill(0);
    for (let z = F.z0; z < F.z1; z++) for (let x = F.x0; x < F.x1; x++) g1.region[g1.idx(x, z)] = R_MALL;
    for (const u of this.units) {
      const g = u.def.floor ? g1 : g0;
      const r = u.def.rect;
      for (let z = r.z0; z < r.z1; z++) for (let x = r.x0; x < r.x1; x++) g.region[g.idx(x, z)] = R_UNIT0 + u.idx;
      for (const t of u.def.door.tiles) {
        g.addDoor(t.x, t.z, t.x + u.def.door.dir[0], t.z + u.def.door.dir[1]);
        g.reserved[g.idx(t.x + u.def.door.dir[0], t.z + u.def.door.dir[1])] = 1;
      }
    }
    // escalator well + connector footprints
    for (let z = ESCALATOR_WELL.z0; z < ESCALATOR_WELL.z1; z++) for (let x = ESCALATOR_WELL.x0; x < ESCALATOR_WELL.x1; x++) g1.region[g1.idx(x, z)] = 0;
    for (const c of CONNECTORS) for (const g of [g0, g1]) for (let z = c.blocked.z0; z < c.blocked.z1; z++) for (let x = c.blocked.x0; x < c.blocked.x1; x++) g.region[g.idx(x, z)] = 0;
    for (const c of CONNECTORS) for (const e of [c.from, c.to]) { const g = e.floor ? g1 : g0; g.reserved[g.idx(e.x, e.z)] = 1; }
    for (const x of MALL_ENTRANCES) { g0.addDoor(x, 15, x, 16); g0.reserved[g0.idx(x, 15)] = 1; }
    // supermarket back door opens to the corridor (added by the stage layout too)
    g0.version++; g1.version++;
    void R_IN; void R_OUT;
  }

  doorOutside(u: UnitState): Tile {
    const t = u.def.door.tiles[0];
    return { x: t.x + u.def.door.dir[0], z: t.z + u.def.door.dir[1] };
  }

  randomInside(u: UnitState): Tile {
    const r = u.def.rect;
    const x = r.x0 + 1 + Math.floor(Math.random() * Math.max(1, r.x1 - r.x0 - 2));
    const z = r.z0 + 1 + Math.floor(Math.random() * Math.max(1, r.z1 - r.z0 - 2));
    const g = this.game.floors[u.def.floor];
    return g.walkable(x, z) ? { x, z } : u.def.door.tiles[0];
  }

  // ------------------------------------------------------------ tenants
  rollOffers() {
    const present = new Set(this.units.filter((u) => u.tenant).map((u) => u.tenant!.def.id));
    for (const u of this.units) {
      if (u.tenant) { u.offers = []; continue; }
      const pool = TENANTS.filter((t) => !!t.food === !!u.def.food && !present.has(t.id));
      const offers: { def: TenantDef; rent: number }[] = [];
      while (offers.length < 3 && pool.length) {
        const d = pool.splice(Math.floor(Math.random() * pool.length), 1)[0];
        offers.push({ def: d, rent: Math.round(d.rent * rand(0.85, 1.15) / 10) * 10 });
      }
      u.offers = offers;
    }
  }

  lease(u: UnitState, offerIdx: number) {
    const o = u.offers[offerIdx]; if (!o || u.tenant) return;
    u.tenant = { def: o.def, rent: o.rent, sat: 65, reasons: [], salesToday: 0, visitorsToday: 0, lowDays: 0, since: this.game.day };
    for (const other of this.units) other.offers = other.offers.filter((x) => x.def.id !== o.def.id);
    u.offers = [];
    this.recalcSat();
    this.game.emit('mallChanged');
  }

  evict(u: UnitState, reason = 'Sözleşme feshedildi') {
    if (!u.tenant) return;
    this.game.alert('tenantLeft' + u.idx, 'shop', `${u.tenant.def.brand} (${u.tenant.def.name}) çıktı: ${reason}. Birim yeniden kiralık.`, 'bad');
    u.tenant = null;
    this.rollOffers();
    this.game.emit('mallChanged');
  }

  eventBoost(cat: TenantCategory) {
    const e = this.event?.def; if (!e) return 1;
    return (e.boost === cat ? 2.6 : 1) * (e.tenantMul > 1 ? 1.15 : 1);
  }

  shopAt(v: Visitor, u: UnitState, game: Game, food = false) {
    const t = u.tenant!; const d = t.def;
    const mood = THREE.MathUtils.clamp(0.6 + (this.mood - 3) * 0.2 + (t.sat - 50) / 200, 0.3, 1.4);
    const chance = d.buyChance * mood * (this.event?.def.tenantMul ?? 1) * (this.event?.def.boost === d.id ? 1.6 : 1);
    if (food || Math.random() < chance) {
      let amt = Math.round(rand(d.spend[0], d.spend[1]));
      if (game.upgrades.has('dijital')) amt = Math.round(amt * 1.15);
      if (this.event?.def.boost === d.id) amt = Math.round(amt * 1.5);
      t.salesToday += amt; this.stats.tenantSales += amt;
      v.spent += amt;
      if (!food) { v.view.addBag(parseInt(d.color.slice(1), 16)); v.log('shop', `${d.brand}'dan alışveriş yaptım.`, game); }
      v.mood += 5;
    } else {
      v.log('wallet', `${d.brand}'da beğendiğim bir şey yoktu.`, game, false);
    }
  }

  recordVisit(v: Visitor, game: Game) {
    this.stats.moodSum += v.mood; this.stats.moodN++;
    const stars = THREE.MathUtils.clamp(v.mood / 20, 0, 5);
    this.mood += (stars - this.mood) * 0.03;
    void game;
  }

  /** tenant satisfaction with explainable reasons */
  recalcSat() {
    const game = this.game;
    const fx = game.fixtures;
    const litter = game.litter.filter((l) => l.floor === 1 || game.grid.region[game.grid.idx(l.tile.x, l.tile.z)] === R_MALL).length;
    const seats = fx.filter((f) => f.def.kind === 'table').reduce((s, f) => s + (f.def.seats ?? 0), 0);
    const dirty = fx.filter((f) => f.def.kind === 'table' && f.dirty).length;
    const noisy = this.units.filter((u) => u.tenant?.def.noisy);
    const dist = (a: UnitState, b: { x: number; z: number; floor: number }) => {
      if (a.def.floor !== b.floor) return 99;
      const d = this.doorOutside(a);
      return Math.hypot(d.x - b.x, d.z - b.z);
    };
    const brokenAny = this.connectors.some((c) => c.broken);
    for (const u of this.units) {
      const t = u.tenant; if (!t) continue;
      const R: { text: string; v: number }[] = [];
      const add = (text: string, v: number) => { if (v) R.push({ text, v }); };
      add('Temel memnuniyet', 55);
      add(`Bugünkü ziyaretçi (${t.visitorsToday})`, Math.min(22, Math.round(t.visitorsToday * 1.5)) - (game.clock > 13 * 60 && t.visitorsToday < 5 ? 10 : 0));
      add('AVM keyfi', Math.round((this.mood - 3.2) * 10));
      switch (t.def.id) {
        case 'giyim':
          add(u.def.floor === 0 ? 'Zemin katta, girişe yakın' : 'Üst katta, girişten uzak', u.def.floor === 0 ? 10 : -6); break;
        case 'elektronik': {
          const near = CONNECTORS.some((c) => [c.from, c.to].some((e) => dist(u, e) < 10));
          add(near ? 'Yürüyen merdiven / asansöre yakın' : 'Merdiven ve asansörden uzak', near ? 12 : -14); break;
        }
        case 'oyuncak': {
          const play = fx.some((f) => f.def.kind === 'play' && dist(u, { x: f.center.x, z: f.center.z, floor: f.floor }) < 12);
          add(play ? 'Çocuk oyun alanı yakında' : 'Yakında oyun alanı yok', play ? 18 : -6); break;
        }
        case 'spor': add(u.def.floor === 1 ? 'Üst kat vitrini' : 'Zemin kat', u.def.floor === 1 ? 6 : 0); break;
        case 'kuafor': add(litter >= 3 ? 'Koridorlar kirli' : 'Koridorlar temiz', litter >= 3 ? -12 : 5); break;
        case 'kitap': if (this.event?.def.noisy) add('Konser gürültüsü', -15); break;
      }
      if (t.def.food) {
        add(seats >= 8 ? `Yemek katında ${seats} koltuk` : `Sadece ${seats} koltuk var`, seats >= 12 ? 16 : seats >= 8 ? 10 : seats >= 4 ? -10 : -26);
        if (dirty >= 2) add(`${dirty} kirli masa`, -14);
      }
      if (!t.def.noisy && t.def.id !== 'oyuncak') {
        const n = noisy.filter((o) => o !== u && o.def.floor === u.def.floor && dist(u, { ...this.doorOutside(o), floor: o.def.floor }) < 11).length;
        if (n) add('Yanında gürültülü oyun salonu', -12 * n);
      }
      if (brokenAny && u.def.floor === 1) add('Yürüyen merdiven arızalı', -8);
      if (this.event && this.event.def.boost === t.def.id) add(`${this.event.def.name} etkinliği`, 15);
      t.reasons = R;
      const target = THREE.MathUtils.clamp(R.reduce((s, r) => s + r.v, 0), 0, 100);
      t.sat = target;
    }
  }

  // ------------------------------------------------------------ connectors
  connectorWorking(id: string) { const c = this.connectors.find((x) => x.def.id === id); return !!c && !c.broken; }

  repair(c: ConnectorState) {
    if (!c.broken || c.repairT > 0) return;
    const cost = 600;
    if (this.game.money < cost) { this.game.alert('nomoney', 'wallet', 'Tamir için yeterli nakit yok.', 'bad'); return; }
    this.game.money -= cost; this.game.stats.other += cost;
    c.repairT = 40; // game minutes
    this.game.emit('mallChanged');
  }

  // ------------------------------------------------------------ events
  schedule(id: string, when: 'today' | 'tomorrow') {
    const def = MALL_EVENTS.find((e) => e.id === id)!;
    const day = when === 'today' ? this.game.day : this.game.day + 1;
    if (this.scheduled.some((s) => s.day === day) || (when === 'today' && this.event)) { this.game.alert('evbusy', 'crowd', 'O gün için zaten bir etkinlik var.', 'warn'); return false; }
    if (def.needs === 'play' && !this.game.fixtures.some((f) => f.def.kind === 'play')) { this.game.alert('evneeds', 'fun', 'Çocuk Şenliği için önce bir oyun alanı kur.', 'warn'); return false; }
    if (def.needs && def.needs !== 'play' && !this.units.some((u) => u.tenant?.def.id === def.needs)) { this.game.alert('evneeds', 'shop', 'Bu etkinlik için ilgili kiracı (kitabevi) gerekli.', 'warn'); return false; }
    if (this.game.money < def.cost) { this.game.alert('nomoney', 'wallet', 'Etkinlik için yeterli nakit yok.', 'bad'); return false; }
    this.game.money -= def.cost; this.game.stats.other += def.cost;
    if (when === 'today') { this.event = { def, day }; this.game.emit('event', def); }
    else this.scheduled.push({ day, id });
    this.game.emit('mallChanged');
    return true;
  }

  startDay() {
    this.stats = newMallStats();
    for (const u of this.units) if (u.tenant) { u.tenant.salesToday = 0; u.tenant.visitorsToday = 0; }
    this.event = null;
    const s = this.scheduled.find((x) => x.day === this.game.day);
    if (s) { this.event = { def: MALL_EVENTS.find((e) => e.id === s.id)!, day: s.day }; this.scheduled = this.scheduled.filter((x) => x !== s); this.game.emit('event', this.event.def); this.game.alert('eventday', 'fun', `Bugün: ${this.event.def.name}! Kalabalık bekleniyor.`, 'good', undefined, 0); }
    this.rollOffers();
  }

  /** end of day: collect rent + share, tenants may leave */
  endDay() {
    this.recalcSat();
    let rent = 0, share = 0;
    for (const u of this.units) {
      const t = u.tenant; if (!t) continue;
      rent += t.rent;
      share += Math.round(t.salesToday * t.def.share);
      if (t.sat < 25) {
        t.lowDays++;
        if (t.lowDays >= 2) this.evict(u, 'memnun kalmadı');
        else this.game.alert('tenantWarn' + u.idx, 'angry', `${t.def.brand} memnun değil (${Math.round(t.sat)}). Sebepleri kiracı kartında.`, 'warn', undefined, 0);
      } else t.lowDays = 0;
    }
    this.stats.rentIncome = rent; this.stats.shareIncome = share;
    this.history.push({ day: this.game.day, income: rent + share, visitors: this.stats.visitors });
    return { rent, share, visitors: this.stats.visitors, sales: this.stats.tenantSales, incidents: this.stats.incidents, mood: this.mood };
  }

  // ------------------------------------------------------------ tick
  update(dt: number) {
    const game = this.game;
    // spawn visitors
    const open = this.units.filter((u) => u.tenant).length;
    if (game.isOpen() && open > 0) {
      const h = game.hour();
      const w = VISITORS.reduce((s, a) => s + a.weight(h), 0) / VISITORS.length;
      const rate = 0.1 * w * (0.4 + 0.1 * open) * (0.6 + this.mood / 5 * 0.7) * (this.event?.def.visitorMul ?? 1) * (this.event?.def.id === 'konser' && h > 17 ? 1.5 : 1) * (game.upgrades.has('klima') ? 1.1 : 1);
      this.spawnAcc += dt * rate;
      const cap = this.event ? 60 : 44;
      while (this.spawnAcc > 1) { this.spawnAcc -= 1; if (this.visitors.length < cap) this.spawn(); }
    }
    for (const v of this.visitors) v.update(dt, game);
    for (let i = this.visitors.length - 1; i >= 0; i--) {
      const v = this.visitors[i];
      if (v.removed) { v.dispose(); this.visitors.splice(i, 1); if (game.selection?.kind === 'visitor' && game.selection.v === v) game.select(null); }
    }
    // connectors: repairs, breakdowns, lift car
    this.hourAcc += dt * game.minPerSec();
    for (const c of this.connectors) {
      if (c.repairT > 0) {
        c.repairT -= dt * game.minPerSec();
        if (c.repairT <= 0) { c.broken = false; c.repairT = 0; game.alert('fixed' + c.def.id, 'wrench', `${c.def.name} tamir edildi.`, 'good'); game.emit('mallChanged'); }
      }
    }
    if (this.hourAcc > 60) {
      this.hourAcc = 0;
      if (game.isOpen()) for (const c of this.connectors) {
        if (!c.broken && Math.random() < (c.def.kind === 'escalator' ? 0.02 : 0.012)) {
          c.broken = true;
          game.alert('broke' + c.def.id, 'wrench', `${c.def.name} arızalandı! Ziyaretçiler dolaşmak zorunda. Tıklayıp tamir ettir.`, 'bad', new THREE.Vector3((c.def.blocked.x0 + c.def.blocked.x1) / 2, c.def.from.floor * FLOOR_H, (c.def.blocked.z0 + c.def.blocked.z1) / 2), 0);
          game.emit('mallChanged');
        }
      }
      // crowd incidents during events without security
      if (this.event && this.visitors.length > 32 && !game.hasRole('security') && Math.random() < 0.4) {
        const v = pick(this.visitors);
        v.view.play('angry'); v.log('angry', 'Kalabalıkta itiş kakış çıktı!', game);
        this.stats.incidents++;
        this.mood = Math.max(0, this.mood - 0.25);
        game.alert('incident', 'crowd', 'Etkinlik kalabalığında arbede çıktı! Güvenlik görevlisi olmadan büyük etkinlik riskli.', 'bad', v.pos.clone(), 60);
      }
    }
    this.satAcc += dt;
    if (this.satAcc > 1.5) { this.satAcc = 0; this.recalcSat(); }
  }

  private spawn() {
    const game = this.game;
    const h = game.hour();
    const ws = VISITORS.map((a) => a.weight(h) * (a.child ? (this.event?.def.familyMul ?? 1) : 1));
    let r = Math.random() * ws.reduce((s, x) => s + x, 0), i = 0;
    for (; i < ws.length; i++) { r -= ws[i]; if (r <= 0) break; }
    const arch = VISITORS[Math.min(i, VISITORS.length - 1)];
    const v = new Visitor(arch, this, game);
    const fromLeft = Math.random() < 0.5;
    const z = SIDEWALK_Z0 + ((Math.random() * 3) | 0);
    const x = fromLeft ? 0 : MAP_W - 1;
    if (!game.grid.walkable(x, z)) { v.dispose(); return; }
    v.pos.set(x + 0.5, 0.08, z + 0.5);
    v.exitX = Math.random() < 0.5 ? 0 : MAP_W - 1;
    v.entranceX = MALL_ENTRANCES.reduce((b, e) => (Math.abs(e - x) < Math.abs(b - x) ? e : b), MALL_ENTRANCES[0]);
    v.goTo(game, { x: v.entranceX, z: 16 });
    this.visitors.push(v);
    game.r.scene.add(v.view.root);
  }
}
