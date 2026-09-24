import * as THREE from 'three';
import type { Tile } from './grid';
import type { Game, Litter, Puddle } from '../game';
import type { Fixture } from './fixture';
import type { Customer } from './agents';
import { Agent, nearestAccess, nearestWalkable, pick } from './agents';
import type { Look, HairStyle } from '../world/characters';
import { SKIN_TONES, HAIR_COLORS } from '../data/customers';
import { PRODUCT_MAP, BAKED } from '../data/products';
import { DAY_OPEN, DAY_CLOSE, FLOOR_H } from '../config';

export type Role = 'owner' | 'cashier' | 'stocker' | 'cleaner' | 'security' | 'baker';
export const ROLE_LABEL: Record<Role, string> = {
  owner: 'Dükkân Sahibi', cashier: 'Kasiyer', stocker: 'Reyon Görevlisi', cleaner: 'Temizlik Görevlisi', security: 'Güvenlik Görevlisi', baker: 'Fırıncı',
};
export const ROLE_DESC: Record<Role, string> = {
  owner: 'Kasaya bakar. Kuyruk yokken ve yardımcı yoksa rafları kendisi doldurur; o sırada kasa boş kalır.',
  cashier: 'Boştaki kasaya geçer ve ödemeleri alır.',
  stocker: 'Depodan koli taşıyıp azalan rafları doldurur, boşta kalınca çöp toplar.',
  cleaner: 'Islak zemini paspaslayıp uyarı levhası koyar, çöpleri ve AVM\'de kirli masaları toplar.',
  security: 'Devriye gezer. Şüpheliyi gördüğünde peşine düşer, alarm çalınca kapıda yakalar.',
  baker: 'Fırın tezgâhında sıcak simit ve ekmek pişirir; toptancıdan almaktan ucuzdur.',
};
export const ROLE_STAGE: Record<Role, number> = { owner: 0, cashier: 0, stocker: 0, cleaner: 1, security: 1, baker: 2 };

export type Shift = 'full' | 'morning' | 'evening';
export const SHIFT_LABEL: Record<Shift, string> = { full: 'Tam gün 07–22', morning: 'Sabah 07–15', evening: 'Akşam 14–22' };
export const SHIFT_HOURS: Record<Shift, [number, number]> = { full: [DAY_OPEN, DAY_CLOSE], morning: [DAY_OPEN, 15 * 60], evening: [14 * 60, DAY_CLOSE] };
export const SHIFT_WAGE: Record<Shift, number> = { full: 1, morning: 0.6, evening: 0.6 };

type RestockTask = { kind: 'restock'; fixture: Fixture; slot: number; pid: string; qty: number; depot: Fixture; phase: 'toDepot' | 'pickup' | 'toShelf' | 'stock' };
type CleanTask = { kind: 'clean'; litter: Litter; phase: 'go' | 'sweep' };
type MopTask = { kind: 'mop'; puddle: Puddle; phase: 'go' | 'mop' };
type TableTask = { kind: 'table'; table: Fixture; phase: 'go' | 'wipe' };
type RestTask = { kind: 'rest'; spot: Fixture; phase: 'go' | 'rest' };
type BakeTask = { kind: 'bake'; oven: Fixture; phase: 'go' | 'bake' };
type ChaseTask = { kind: 'chase'; target: Customer; t: number };
export type Task = RestockTask | CleanTask | MopTask | TableTask | RestTask | BakeTask | ChaseTask;

const tmpV = new THREE.Vector3();

export class Staff extends Agent {
  task: Task | null = null;
  timer = 0;
  idleT = 0;
  register: Fixture | null = null;
  skill = 1;
  activity = 'Hazır';
  shift: Shift = 'full';
  energy = 100;
  present = true;
  tiredShown = 0;

  constructor(public role: Role, name: string, public baseWage: number) {
    super(staffLook(role), name);
    this.speed = 1.6;
    this.skill = role === 'owner' ? 1.1 : 0.9 + Math.random() * 0.25;
  }

  get wage() { return Math.round(this.baseWage * SHIFT_WAGE[this.shift]); }
  get tired() { return this.energy < 30; }
  get effSkill() { return this.skill * (this.tired ? 0.7 : 1); }
  onDuty(clock: number) {
    const [a, b] = SHIFT_HOURS[this.shift];
    return clock >= a && clock < b;
  }

  atRegister(reg: Fixture) {
    if (this.register !== reg || this.task || !this.present) return false;
    const b = reg.fp.back[0];
    return this.floor === 0 && Math.abs(this.pos.x - (b.x + 0.5)) < 0.35 && Math.abs(this.pos.z - (b.z + 0.5)) < 0.35;
  }

  update(dt: number, game: Game) {
    const v = this.view;
    // --- shift handling --------------------------------------------------
    const duty = this.onDuty(game.clock) || this.role === 'owner';
    if (!duty && game.clock >= DAY_OPEN) {
      if (this.present) this.goHome(dt, game);
      return;
    }
    if (duty && !this.present) this.arrive(game);
    if (this.hidden) return;
    // --- fatigue ---------------------------------------------------------
    const working = !!this.task && this.task.kind !== 'rest';
    const drain = (this.shift === 'full' ? 1 : 0.55) * (this.role === 'owner' ? 0.6 : 1) * (working ? 1 : 0.5);
    if (!this.task || this.task.kind !== 'rest') this.energy = Math.max(0, this.energy - dt * 0.11 * drain * game.minPerSec());
    this.speedMul = this.tired ? 0.72 : 1;
    if (this.tired) {
      this.tiredShown -= dt;
      if (this.tiredShown <= 0) { this.think('tired', 2); this.tiredShown = 14; }
      if (!this.task || this.task.kind === 'clean') {
        const spot = game.fixtures.find((f) => f.def.kind === 'break');
        const canLeave = !(this.role === 'owner' || this.role === 'cashier') || !this.register || this.register.queue.length === 0;
        if (spot && canLeave) {
          if (this.task) this.cancelTask(game);
          this.task = { kind: 'rest', spot, phase: 'go' }; this.dest = null;
        }
      }
    }

    if (this.role === 'owner' || this.role === 'cashier') { this.cashierLogic(dt, game); return; }

    if (!this.task) this.task = this.findWork(game);
    if (this.task) { this.doTask(dt, game); return; }
    this.activity = this.role === 'security' ? 'Devriye geziyor' : 'Boşta, iş bekliyor';
    if (this.goal && !this.move(dt, game)) { v.play('walk'); return; }
    v.play('idle');
    this.idleT += dt;
    if (this.idleT > (this.role === 'security' ? 2.5 : 6)) {
      this.idleT = 0;
      this.wander(game);
    }
  }

  private findWork(game: Game): Task | null {
    switch (this.role) {
      case 'stocker': return game.findRestockTask(this, 0.55) || game.findMopTask(this) || game.findCleanTask(this);
      case 'cleaner': return game.findMopTask(this) || game.findTableTask(this) || game.findCleanTask(this);
      case 'baker': return game.findBakeTask(this);
      case 'security': return game.findChaseTask(this);
      default: return null;
    }
  }

  private wander(game: Game) {
    // security patrols store + (in the AVM) the ground floor corridors; others drift around
    const g = game.grid;
    for (let tries = 0; tries < 12; tries++) {
      const r = g.layout.interior;
      const mall = this.role === 'security' && game.stage >= 3 && Math.random() < 0.4;
      const tx = mall ? 6 + Math.floor(Math.random() * 32) : r.x0 + Math.floor(Math.random() * (r.x1 - r.x0));
      const tz = mall ? Math.floor(Math.random() * 16) : r.z0 + Math.floor(Math.random() * (r.z1 - r.z0 - 1));
      if (g.walkable(tx, tz) && (g.isInterior(tx, tz) || (mall && g.region[g.idx(tx, tz)] === 4))) { this.goToAny(game, { x: tx, z: tz }, 0); return; }
    }
  }

  private cashierLogic(dt: number, game: Game) {
    const v = this.view;
    if (!this.register || !game.fixtures.includes(this.register) || this.register.cashier !== this) {
      this.register = game.fixtures.find((f) => f.def.kind === 'register' && !f.def.selfService && (!f.cashier || f.cashier === this || !game.staff.includes(f.cashier) || !f.cashier.present)) ?? null;
      if (this.register) this.register.cashier = this;
      this.goal = null; this.dest = null;
    }
    const reg = this.register;
    const busy = reg && reg.queue.length > 0;
    if (this.task && busy && !(this.task.kind === 'restock' && (this.task.phase === 'toShelf' || this.task.phase === 'stock')) && this.task.kind !== 'mop') this.cancelTask(game);
    if (this.task) { this.doTask(dt, game); return; }
    if (reg) {
      const b = reg.fp.back[0];
      if (!this.sameDest(b, 0)) this.goToAny(game, b, 0);
      const arrived = this.move(dt, game);
      if (arrived) {
        this.lookAt = tmpV.set(reg.fp.access[0].x + 0.5, 0, reg.fp.access[0].z + 0.5).clone();
        const serving = reg.queue[0]?.state === 'paying';
        v.play(serving ? 'work' : 'idle');
        this.activity = serving ? 'Müşteriye hizmet veriyor' : 'Kasada bekliyor';
        if (!busy) {
          this.idleT += dt;
          if (this.idleT > 0.8) {
            const t = (!game.hasRole('stocker') && game.findRestockTask(this, 0.4))
              || (!game.hasRole('stocker') && !game.hasRole('cleaner') && (game.findMopTask(this) || game.findCleanTask(this)));
            if (t) { this.task = t; this.idleT = 0; }
          }
        } else this.idleT = 0;
      } else { v.play('walk'); this.activity = 'Kasaya dönüyor'; }
    } else {
      this.activity = 'Kasa yok — boşta';
      const t = game.findRestockTask(this, 0.5) || game.findMopTask(this) || game.findCleanTask(this);
      if (t) this.task = t; else v.play('idle');
    }
  }

  private goHome(dt: number, game: Game) {
    if (this.task && this.task.kind !== 'chase') this.cancelTask(game);
    this.task = null;
    if (this.register?.cashier === this) this.register.cashier = null;
    this.register = null;
    this.activity = 'Vardiyası bitti, çıkıyor';
    const L = game.grid.layout;
    const door = { x: L.doors[0], z: L.interior.z1 };
    if (!this.sameDest(door, 0)) this.goToAny(game, door, 0);
    this.view.play('walk');
    if (this.move(dt, game)) { this.present = false; this.hidden = true; this.view.root.visible = false; }
  }

  private arrive(game: Game) {
    const L = game.grid.layout;
    this.present = true; this.hidden = false; this.view.root.visible = true;
    this.floor = 0;
    this.pos.set(L.doors[0] + 0.5, 0.08, L.interior.z1 + 0.5);
    this.energy = Math.max(this.energy, 100);
    this.goal = null; this.dest = null; this.legs = []; this.ride = null;
    this.activity = 'Vardiyaya geldi';
  }

  cancelTask(game: Game) {
    const t = this.task; if (!t) return;
    if (t.kind === 'restock') {
      t.fixture.slots[t.slot].claimed = 0;
      if (t.phase === 'toShelf' || t.phase === 'stock') game.backstock[t.pid] = (game.backstock[t.pid] ?? 0) + t.qty;
    } else if (t.kind === 'clean') t.litter.claimed = 0;
    else if (t.kind === 'mop') t.puddle.claimed = 0;
    else if (t.kind === 'table') t.table.claimed = 0;
    else if (t.kind === 'bake') t.oven.claimed = 0;
    this.task = null; this.view.setCarry(false); this.view.setBroom(false); this.goal = null; this.dest = null; this.legs = [];
  }

  private doTask(dt: number, game: Game) {
    const t = this.task!;
    const v = this.view;
    switch (t.kind) {
      case 'restock': {
        if (!game.fixtures.includes(t.fixture) || !game.fixtures.includes(t.depot)) { this.cancelTask(game); return; }
        switch (t.phase) {
          case 'toDepot': {
            this.activity = 'Depoya gidiyor';
            v.play('walk');
            const acc = nearestAccess(game, t.depot, this.pos);
            if (!this.sameDest(acc, 0)) this.goToAny(game, acc, 0);
            if (this.move(dt, game)) { t.phase = 'pickup'; this.timer = 0.9; this.lookAt = t.depot.center; }
            break;
          }
          case 'pickup': {
            this.activity = 'Koli alıyor';
            v.play('reach');
            this.timer -= dt;
            if (this.timer <= 0) {
              const have = game.backstock[t.pid] ?? 0;
              const qty = Math.min(t.qty, have);
              if (qty <= 0) { this.cancelTask(game); return; }
              game.backstock[t.pid] = have - qty; t.qty = qty;
              game.depotChanged();
              v.setCarry(true); this.lookAt = null;
              t.phase = 'toShelf'; this.dest = null;
            }
            break;
          }
          case 'toShelf': {
            this.activity = `${PRODUCT_MAP[t.pid].name} rafa taşıyor`;
            v.play('carry');
            const acc = nearestAccess(game, t.fixture, this.pos);
            if (!this.dest) this.goToAny(game, acc, 0);
            if (this.move(dt, game)) { t.phase = 'stock'; this.timer = 1.4 / this.effSkill; this.lookAt = t.fixture.center; v.setCarry(false); }
            break;
          }
          case 'stock': {
            this.activity = 'Rafı dolduruyor';
            v.play('work');
            this.timer -= dt;
            if (this.timer <= 0) {
              const s = t.fixture.slots[t.slot];
              if (s.productId === t.pid) {
                const room = t.fixture.cap() - s.stock;
                const put = Math.min(room, t.qty);
                s.stock += put;
                if (t.qty - put > 0) game.backstock[t.pid] += t.qty - put;
              } else game.backstock[t.pid] += t.qty;
              s.claimed = 0;
              game.stockChanged(t.fixture);
              game.overlays.floatText(t.fixture.center.setY(t.fixture.model.height + 0.2), `+${t.qty} ${PRODUCT_MAP[t.pid].name}`, '#2f5d8a', null, 1.2);
              this.task = null; this.goal = null; this.dest = null; this.lookAt = null;
            }
            break;
          }
        }
        break;
      }
      case 'clean': {
        const L = t.litter;
        if (!game.litter.includes(L)) { this.task = null; v.setBroom(false); this.dest = null; return; }
        if (t.phase === 'go') {
          this.activity = 'Çöpü temizlemeye gidiyor';
          v.play('walk');
          const tgt = nearestWalkable(game, L.tile, L.floor);
          if (!this.sameDest(tgt, L.floor)) { if (!this.goToAny(game, tgt, L.floor) && !this.riding) { this.cancelTask(game); return; } }
          if (this.move(dt, game)) { t.phase = 'sweep'; this.timer = 1.8 / this.effSkill; v.setBroom(true); this.lookAt = new THREE.Vector3(L.tile.x + 0.5, 0, L.tile.z + 0.5); }
        } else {
          this.activity = 'Süpürüyor';
          v.play('sweep');
          this.timer -= dt;
          if (this.timer <= 0) { game.removeLitter(L); v.setBroom(false); this.task = null; this.dest = null; this.lookAt = null; }
        }
        break;
      }
      case 'mop': {
        const P = t.puddle;
        if (!game.puddles.includes(P)) { this.task = null; v.setBroom(false); this.dest = null; return; }
        if (t.phase === 'go') {
          this.activity = 'Islak zemine koşuyor';
          v.play('walk');
          const tgt = nearestWalkable(game, P.tile, P.floor);
          if (!this.sameDest(tgt, P.floor)) { if (!this.goToAny(game, tgt, P.floor) && !this.riding) { this.cancelTask(game); return; } }
          if (this.move(dt, game)) {
            t.phase = 'mop';
            this.timer = (this.role === 'cleaner' ? 2.2 : 4.5) / this.effSkill;
            v.setBroom(true); this.lookAt = P.obj.position.clone();
            game.placeWetSign(P);
          }
        } else {
          this.activity = 'Paspas yapıyor';
          v.play('sweep');
          this.timer -= dt;
          if (this.timer <= 0) { game.mopped(P); v.setBroom(false); this.task = null; this.dest = null; this.lookAt = null; }
        }
        break;
      }
      case 'table': {
        const T = t.table;
        if (!game.fixtures.includes(T) || !T.dirty) { T.claimed = 0; this.task = null; this.dest = null; return; }
        if (t.phase === 'go') {
          this.activity = 'Kirli masaya gidiyor';
          v.play('walk');
          const acc = nearestAccess(game, T, this.pos);
          if (!this.sameDest(acc, T.floor)) this.goToAny(game, acc, T.floor);
          if (this.move(dt, game)) { t.phase = 'wipe'; this.timer = 2 / this.effSkill; this.lookAt = T.center; }
        } else {
          this.activity = 'Masayı siliyor';
          v.play('work');
          this.timer -= dt;
          if (this.timer <= 0) { game.cleanTable(T); this.task = null; this.dest = null; this.lookAt = null; }
        }
        break;
      }
      case 'rest': {
        const S = t.spot;
        if (!game.fixtures.includes(S)) { this.task = null; this.dest = null; return; }
        if (t.phase === 'go') {
          this.activity = 'Molaya gidiyor';
          v.play('walk');
          const acc = nearestAccess(game, S, this.pos);
          if (!this.sameDest(acc, S.floor)) this.goToAny(game, acc, S.floor);
          if (this.move(dt, game)) { t.phase = 'rest'; this.timer = 11; this.lookAt = S.center; }
        } else {
          this.activity = 'Çay molasında';
          v.play('rest');
          this.timer -= dt;
          this.energy = Math.min(100, this.energy + dt * 5.5);
          if (this.timer <= 0 || this.energy >= 98) { this.task = null; this.dest = null; this.lookAt = null; }
        }
        break;
      }
      case 'bake': {
        const O = t.oven;
        if (!game.fixtures.includes(O)) { this.task = null; this.dest = null; return; }
        if (t.phase === 'go') {
          this.activity = 'Fırına geçiyor';
          v.play('walk');
          const acc = nearestAccess(game, O, this.pos);
          if (!this.sameDest(acc, 0)) this.goToAny(game, acc, 0);
          if (this.move(dt, game)) { t.phase = 'bake'; this.timer = 9 / this.effSkill; this.lookAt = O.center; O.baking = 1; }
        } else {
          this.activity = 'Hamur yoğuruyor, fırın yanıyor';
          v.play('work');
          this.timer -= dt;
          if (this.timer <= 0) {
            O.baking = 0; O.claimed = 0;
            const pid = !game.isStocked('ekmek') ? 'simit' : !game.isStocked('simit') ? 'ekmek' : (game.backstock.simit ?? 0) <= (game.backstock.ekmek ?? 0) ? 'simit' : 'ekmek';
            const room = game.depotCapacity() - game.backstockTotal();
            const n = Math.min(8, room);
            if (n > 0) {
              game.backstock[pid] = (game.backstock[pid] ?? 0) + n;
              const cost = Math.round(n * BAKED[pid]);
              game.money -= cost; game.stats.purchases += cost;
              game.depotChanged();
              game.overlays.floatText(O.center.setY(1.9), `+${n} sıcak ${PRODUCT_MAP[pid].name.toLowerCase()}`, '#b44a28', null, 1.6);
            }
            this.task = null; this.dest = null; this.lookAt = null;
          }
        }
        break;
      }
      case 'chase': {
        const c = t.target;
        t.t += dt;
        if (c.removed || c.state === 'caught' || c.state === 'exit' || c.state === 'flee' || t.t > 25) { this.task = null; this.dest = null; this.speedMul = 1; return; }
        this.activity = 'Şüphelinin peşinde!';
        this.speedMul = 1.35;
        v.play('walk');
        const ct = c.tile;
        if (!this.dest || Math.abs(this.dest.tile.x - ct.x) + Math.abs(this.dest.tile.z - ct.z) > 1) this.goToAny(game, ct, 0);
        this.move(dt, game);
        if (this.pos.distanceTo(c.pos) < 1.3) {
          c.beCaught(game);
          game.stats.caughtByGuard = (game.stats.caughtByGuard ?? 0) + 1;
          this.think('happy', 2);
          this.task = null; this.dest = null; this.speedMul = 1;
        }
        break;
      }
    }
  }
}

function staffLook(role: Role): Look {
  const accent = { owner: 0xe0663c, cashier: 0x1f8a86, stocker: 0x2f5d8a, cleaner: 0x6c4ab6, security: 0x1f2a44, baker: 0xf6efe3 }[role];
  return {
    skin: pick(SKIN_TONES), hair: pick(HAIR_COLORS), hairStyle: role === 'owner' ? 'short' : pick<HairStyle>(['short', 'bun', 'curly', 'spiky']),
    top: role === 'security' ? 0x2b3448 : 0xfaf3e6, bottom: role === 'security' ? 0x1b2130 : 0x2b3a55, shoes: 0x2a2a2e,
    height: role === 'owner' ? 1.04 : role === 'security' ? 1.06 : 1, girth: role === 'owner' ? 1.12 : role === 'security' ? 1.1 : 1,
    accessory: role === 'security' ? 'cap' : role === 'baker' ? 'chef' : 'apron', accent, glasses: false, beard: role === 'owner',
  };
}

export { FLOOR_H };
