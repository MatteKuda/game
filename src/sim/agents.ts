import * as THREE from 'three';
import type { Tile } from './grid';
import type { Game } from '../game';
import type { Fixture } from './fixture';
import { CharacterView, type Look, type HairStyle } from '../world/characters';
import { iconMaterial, type IconKind, ICON_LABEL } from '../world/icons';
import { type Archetype, SKIN_TONES, HAIR_COLORS, GREY_HAIR } from '../data/customers';
import { PRODUCT_MAP } from '../data/products';
import { TURKISH_NAMES, MAP_W } from '../config';

const tmpV = new THREE.Vector3();
let nextId = 1;

export const tileCenter = (t: Tile, out = new THREE.Vector3()) => out.set(t.x + 0.5, 0.08, t.z + 0.5);

export abstract class Agent {
  id = nextId++;
  view: CharacterView;
  pos = new THREE.Vector3();
  path: Tile[] = [];
  pathIdx = 0;
  goal: Tile | null = null;
  gridVersion = -1;
  speed = 1.4;
  facing = 0;
  moving = 0;
  jitter = new THREE.Vector2((Math.random() - 0.5) * 0.3, (Math.random() - 0.5) * 0.3);
  bubble: THREE.Sprite;
  bubbleT = 0;
  bubbleKind: IconKind | null = null;
  lookAt: THREE.Vector3 | null = null;
  removed = false;
  crowdT = 0;

  constructor(look: Look, public name: string, withBasket = false) {
    this.view = new CharacterView(look, withBasket);
    this.bubble = new THREE.Sprite(iconMaterial('happy'));
    this.bubble.scale.set(0.6, 0.6, 1);
    this.bubble.position.y = this.view.headY + 0.22;
    this.bubble.visible = false; this.bubble.renderOrder = 16;
    this.view.root.add(this.bubble);
    this.view.root.traverse((o) => { o.userData.agent = this; });
  }

  get tile(): Tile { return { x: Math.floor(this.pos.x), z: Math.floor(this.pos.z) }; }

  think(kind: IconKind, dur = 2.2) {
    this.bubbleKind = kind; this.bubbleT = dur;
    this.bubble.material = iconMaterial(kind);
    this.bubble.visible = true;
  }

  goTo(game: Game, t: Tile): boolean {
    const from = this.tile;
    if (!game.grid.walkable(from.x, from.z)) this.unstick(game);
    const p = game.grid.findPath(this.tile, t, { avoidCrowd: true });
    this.goal = { ...t };
    this.gridVersion = game.grid.version;
    if (!p) { this.path = []; this.pathIdx = 0; return false; }
    this.path = p; this.pathIdx = p.length > 1 ? 1 : 0;
    return true;
  }

  unstick(game: Game) {
    const t = this.tile;
    for (let r = 1; r < 6; r++) for (let dz = -r; dz <= r; dz++) for (let dx = -r; dx <= r; dx++) {
      if (game.grid.walkable(t.x + dx, t.z + dz) && game.grid.region[game.grid.idx(t.x + dx, t.z + dz)] === game.grid.region[game.grid.idx(t.x, t.z)]) {
        this.pos.set(t.x + dx + 0.5, 0.08, t.z + dz + 0.5); return;
      }
    }
  }

  /** returns true when arrived at goal */
  move(dt: number, game: Game): boolean {
    if (!this.goal) return true;
    if (this.gridVersion !== game.grid.version) {
      const g = this.goal; this.goTo(game, g);
    }
    if (!this.path.length) { this.moving = 0; return false; }
    if (this.pathIdx >= this.path.length) { this.moving = 0; return true; }
    const wp = this.path[this.pathIdx];
    const last = this.pathIdx === this.path.length - 1;
    const tx = wp.x + 0.5 + (last ? this.jitter.x * 0.5 : this.jitter.x), tz = wp.z + 0.5 + (last ? this.jitter.y * 0.5 : this.jitter.y);
    const dx = tx - this.pos.x, dz = tz - this.pos.z;
    const d = Math.hypot(dx, dz);
    let sp = this.speed;
    const occ = game.grid.occupancy[game.grid.idx(wp.x, wp.z)];
    if (occ >= 2 && game.grid.isInterior(wp.x, wp.z)) { sp *= 0.5; this.crowdT += dt; }
    const step = sp * dt;
    if (d <= step || d < 0.02) {
      this.pos.x = tx; this.pos.z = tz;
      this.pathIdx++;
      if (this.pathIdx >= this.path.length) { this.moving = 0; return true; }
    } else {
      this.pos.x += (dx / d) * step; this.pos.z += (dz / d) * step;
      const want = Math.atan2(dx, dz);
      this.facing = lerpAngle(this.facing, want, Math.min(1, dt * 12));
    }
    this.moving = sp / 1.4;
    return false;
  }

  syncView(dt: number) {
    this.view.root.position.copy(this.pos);
    if (this.lookAt && !this.moving) {
      const want = Math.atan2(this.lookAt.x - this.pos.x, this.lookAt.z - this.pos.z);
      this.facing = lerpAngle(this.facing, want, Math.min(1, dt * 8));
    }
    this.view.root.rotation.y = this.facing;
    this.view.walkSpeed = this.speed;
    this.view.update(dt, this.moving);
    if (this.bubbleT > 0) {
      this.bubbleT -= dt;
      const k = Math.min(1, (2.2 - Math.max(0, this.bubbleT)) * 6);
      const s = 0.6 * (0.6 + 0.4 * k) * (this.bubbleT < 0.25 ? this.bubbleT / 0.25 : 1);
      this.bubble.scale.set(s, s, 1);
      this.bubble.position.y = this.view.headY + 0.22 + Math.sin(performance.now() * 0.004 + this.id) * 0.03;
      if (this.bubbleT <= 0) { this.bubble.visible = false; this.bubbleKind = null; }
    }
  }
}

export function lerpAngle(a: number, b: number, t: number) {
  let d = b - a;
  while (d > Math.PI) d -= Math.PI * 2;
  while (d < -Math.PI) d += Math.PI * 2;
  return a + d * t;
}

// ---------------------------------------------------------------------------

export type WantStatus = 'pending' | 'got' | 'oos' | 'notfound' | 'expensive' | 'budget';
export interface Want { pid: string; qty: number; status: WantStatus; tried: Set<number> }

export type CState = 'walkby' | 'toDoor' | 'decide' | 'toShelf' | 'browse' | 'toQueue' | 'queue' | 'paying' | 'leaving' | 'exit';

export interface Thought { icon: IconKind; text: string; t: number }

function pick<T>(arr: T[]) { return arr[(Math.random() * arr.length) | 0]; }
function rand(a: number, b: number) { return a + Math.random() * (b - a); }

export function randomLook(arch: Archetype | null): Look {
  const styles: HairStyle[] = ['short', 'long', 'bun', 'curly', 'spiky'];
  const isOld = arch?.id === 'emekli';
  const skin = pick(SKIN_TONES);
  return {
    skin,
    hair: isOld ? pick(GREY_HAIR) : pick(HAIR_COLORS),
    hairStyle: isOld ? pick<HairStyle>(['bald', 'short', 'bun']) : pick(styles),
    top: arch ? pick(arch.palette.tops) : pick([0x9aa5b1, 0x6d7b8a, 0xc9b79c, 0x8c6f5a, 0x5f7f99, 0xb27a6e]),
    bottom: arch ? pick(arch.palette.bottoms) : pick([0x2b3a55, 0x3d3d45, 0x5b4a3a]),
    shoes: pick([0x2a2a2e, 0x6b4a33, 0xf2f0ea, 0x3a4a6a]),
    height: arch?.id === 'ogrenci' ? rand(0.86, 0.95) : rand(0.95, 1.06),
    girth: arch?.id === 'emekli' ? rand(1.0, 1.18) : rand(0.9, 1.08),
    accessory: arch?.accessory,
    accent: pick([0xe0663c, 0x1f8a86, 0xf2b33d, 0x6c4ab6, 0xd6333a, 0x2f6fb5]),
    glasses: isOld ? Math.random() < 0.6 : Math.random() < 0.15,
    beard: !isOld && Math.random() < 0.15 || (isOld && Math.random() < 0.3),
  };
}

export class Customer extends Agent {
  state: CState = 'toDoor';
  wants: Want[] = [];
  basket: { pid: string; price: number }[] = [];
  budget: number;
  mood = 70;
  wait = 0;
  timer = 0;
  shelf: Fixture | null = null;
  register: Fixture | null = null;
  queueIdx = -1;
  exitX = 0;
  thoughts: Thought[] = [];
  flags = new Set<string>();
  shopper: boolean;
  enteredAt = 0;
  impulseChecked = new Set<number>();
  doorX = 22;

  constructor(public arch: Archetype | null, shopper: boolean, game: Game) {
    super(randomLook(arch), pick(TURKISH_NAMES), false);
    this.shopper = shopper;
    this.budget = arch ? Math.round(rand(arch.budget[0], arch.budget[1])) : 0;
    this.speed = arch ? arch.speed * rand(0.92, 1.08) : rand(1.1, 1.5);
    if (arch && shopper) {
      const n = Math.round(rand(arch.listSize[0], arch.listSize[1]));
      const pool = Object.entries(arch.wants).filter(([pid]) => PRODUCT_MAP[pid] && PRODUCT_MAP[pid].stage <= game.stage);
      for (let i = 0; i < n && pool.length; i++) {
        const tot = pool.reduce((s, [, w]) => s + w, 0);
        let r = Math.random() * tot;
        let idx = 0;
        for (; idx < pool.length; idx++) { r -= pool[idx][1]; if (r <= 0) break; }
        idx = Math.min(idx, pool.length - 1);
        const [pid] = pool.splice(idx, 1)[0];
        this.wants.push({ pid, qty: arch.id === 'aile' && Math.random() < 0.4 ? 2 : 1, status: 'pending', tried: new Set() });
      }
    }
  }

  get spent() { return this.basket.reduce((s, b) => s + b.price, 0); }
  get inside() { return ['decide', 'toShelf', 'browse', 'toQueue', 'queue', 'paying'].includes(this.state); }

  log(icon: IconKind, text: string, game: Game, bubble = true) {
    this.thoughts.unshift({ icon, text, t: game.clock });
    if (this.thoughts.length > 6) this.thoughts.pop();
    if (bubble) this.think(icon);
  }

  update(dt: number, game: Game) {
    const a = this.view;
    switch (this.state) {
      case 'walkby':
      case 'exit': {
        a.play('walk');
        if (this.move(dt, game)) this.removed = true;
        break;
      }
      case 'toDoor': {
        a.play('walk');
        if (this.move(dt, game)) {
          // at the door (outside): decide whether to go in
          const crowd = game.customersInside() >= game.maxInside();
          if (crowd || !game.isOpen()) {
            this.log('crowd', crowd ? 'İçerisi çok kalabalık, vazgeçtim.' : 'Dükkân kapalı.', game);
            game.stats.lost++; game.stats.lostReasons.crowd = (game.stats.lostReasons.crowd ?? 0) + (crowd ? 1 : 0);
            this.leaveStreet(game);
          } else {
            this.state = 'decide';
            this.enteredAt = game.clock;
            game.stats.visitors++;
            this.view.ensureBasket();
            this.goTo(game, { x: this.doorX, z: game.grid.layout.interior.z1 - 1 });
          }
        }
        break;
      }
      case 'decide': {
        a.play('walk');
        if (!this.move(dt, game)) break;
        this.nextWant(game);
        break;
      }
      case 'toShelf': {
        a.play('walk');
        this.insideTick(dt, game);
        if (this.move(dt, game)) {
          this.state = 'browse'; this.timer = rand(0.8, 1.5);
          this.lookAt = this.shelf ? this.shelf.center : null;
        }
        break;
      }
      case 'browse': {
        a.play('reach');
        this.insideTick(dt, game);
        this.timer -= dt;
        if (this.timer <= 0) { this.evaluateShelf(game); }
        break;
      }
      case 'toQueue':
      case 'queue': {
        this.insideTick(dt, game);
        const reg = this.register;
        if (!reg || !game.fixtures.includes(reg)) { this.pickRegister(game); break; }
        const idx = reg.queue.indexOf(this);
        if (idx !== this.queueIdx) {
          this.queueIdx = idx;
          const slot = reg.queueSlots[Math.min(idx, reg.queueSlots.length - 1)] ?? reg.fp.access[0];
          this.goTo(game, slot);
        }
        const arrived = this.move(dt, game);
        if (arrived) {
          this.state = 'queue';
          a.play('idle');
          this.lookAt = reg.center;
          this.wait += dt;
          this.checkImpulse(game);
          const pat = this.arch!.patience * game.patienceMul();
          if (this.wait > pat * 0.55 && !this.flags.has('waitWarn')) { this.flags.add('waitWarn'); this.log('wait', 'Bu kuyruk hiç ilerlemiyor…', game); this.mood -= 8; }
          if (this.wait > pat) { this.abandon(game); break; }
          if (idx === 0 && reg.cashier && reg.cashier.atRegister(reg)) {
            this.state = 'paying';
            const items = this.basket.length;
            this.timer = (2.0 + 0.55 * items) * (game.upgrades.has('pos') ? 0.65 : 1) / reg.cashier.skill;
          } else if (idx === 0 && !(reg.cashier && reg.cashier.atRegister(reg)) && !this.flags.has('nocashier')) {
            this.flags.add('nocashier'); this.log('nocashier', 'Kasada kimse yok!', game);
          }
        } else {
          a.play('walk');
          if (this.state === 'queue') this.wait += dt; // shuffling forward still counts
        }
        break;
      }
      case 'paying': {
        a.play('pay');
        this.timer -= dt;
        if (this.timer <= 0) {
          const total = this.spent;
          game.sale(this, total);
          if (this.register) { this.register.queue.splice(this.register.queue.indexOf(this), 1); }
          if (this.wait < this.arch!.patience * 0.3) this.mood += 6;
          this.finishVisit(game, true);
        }
        break;
      }
      case 'leaving': {
        a.play(this.mood < 35 ? 'walk' : 'walk');
        if (this.move(dt, game)) this.leaveStreet(game);
        break;
      }
    }
    this.view.setFace(this.mood >= 70 ? 'happy' : this.mood >= 45 ? 'neutral' : this.mood >= 25 ? 'sad' : 'angry');
  }

  private insideTick(dt: number, game: Game) {
    // litter, ambiance, dirt & crowd perception
    const t = this.tile;
    if (this.arch && Math.random() < this.arch.litter * dt && !game.binNear(t)) game.dropLitter(t);
    if (!this.flags.has('dirty') && game.litterNear(t, 1.6)) { this.flags.add('dirty'); this.mood -= 7; this.log('dirty', 'Yerler çok kirli…', game); }
    if (!this.flags.has('ambiance') && game.plantNear(t)) { this.flags.add('ambiance'); this.mood += 4; }
    if (this.crowdT > 2.5 && !this.flags.has('crowd')) { this.flags.add('crowd'); this.mood -= 6; this.log('crowd', 'Koridorlar çok dar, sıkıştım.', game); }
  }

  private nextWant(game: Game) {
    // choose the nearest pending want that has a shelf
    let best: { w: Want; f: Fixture; d: number } | null = null;
    for (const w of this.wants) {
      if (w.status !== 'pending') continue;
      const cands = game.fixtures.filter((f) => f.isDisplay && f.slots.some((s) => s.productId === w.pid) && !w.tried.has(f.uid));
      if (!cands.length) {
        w.status = w.tried.size ? 'oos' : 'notfound';
        if (w.status === 'notfound') {
          this.mood -= 13;
          this.log('notfound', `${PRODUCT_MAP[w.pid].name} arıyordum, satılmıyor mu?`, game);
          game.stats.missed[w.pid] = (game.stats.missed[w.pid] ?? 0) + 1;
        }
        continue;
      }
      // prefer stocked shelves
      for (const f of cands) {
        const stocked = f.slots.some((s) => s.productId === w.pid && s.stock > 0);
        const d = this.pos.distanceTo(f.center) + (stocked ? 0 : 8);
        if (!best || d < best.d) best = { w, f, d };
      }
    }
    if (!best) {
      if (this.basket.length) this.pickRegister(game);
      else {
        this.log(this.mood < 40 ? 'angry' : 'wallet', 'Eli boş çıkıyorum.', game);
        this.finishVisit(game, false);
      }
      return;
    }
    this.shelf = best.f;
    best.w.tried.add(best.f.uid);
    const access = best.f.fp.access.filter((t) => game.grid.walkable(t.x, t.z));
    access.sort((a, b) => tmpV.set(a.x + 0.5, 0, a.z + 0.5).distanceTo(this.pos) - tmpV.set(b.x + 0.5, 0, b.z + 0.5).distanceTo(this.pos));
    const target = access[Math.floor(Math.random() * Math.min(2, access.length))] ?? access[0];
    if (!target || !this.goTo(game, target)) {
      // unreachable shelf
      best.w.status = 'notfound';
      this.mood -= 10;
      this.log('notfound', 'Rafa ulaşamıyorum, yol kapalı!', game);
      this.nextWant(game);
      return;
    }
    this.state = 'toShelf';
  }

  private evaluateShelf(game: Game) {
    const f = this.shelf!;
    this.lookAt = null;
    for (const w of this.wants) {
      if (w.status !== 'pending') continue;
      const slot = f.slots.find((s) => s.productId === w.pid && s.stock > 0) ?? null;
      const any = f.slots.some((s) => s.productId === w.pid);
      if (!any) continue;
      if (!slot) {
        // out of stock here — maybe another shelf has it
        const other = game.fixtures.some((o) => o !== f && o.isDisplay && !w.tried.has(o.uid) && o.slots.some((s) => s.productId === w.pid && s.stock > 0));
        if (!other) {
          w.status = 'oos'; this.mood -= 16;
          this.log('empty', `${PRODUCT_MAP[w.pid].name} bitmiş!`, game);
          game.stats.missed[w.pid] = (game.stats.missed[w.pid] ?? 0) + 1;
        }
        continue;
      }
      const p = PRODUCT_MAP[w.pid];
      const price = game.prices[w.pid];
      const tol = this.arch!.priceTolerance;
      if (price > p.basePrice * (1 + tol)) {
        w.status = 'expensive'; this.mood -= 12;
        this.log('price', `${p.name} ₺${price}? Çok pahalı!`, game);
        game.stats.tooExpensive[w.pid] = (game.stats.tooExpensive[w.pid] ?? 0) + 1;
        continue;
      }
      let took = 0;
      for (let q = 0; q < w.qty; q++) {
        if (this.spent + price > this.budget) break;
        if (slot.stock <= 0) break;
        slot.stock--; this.basket.push({ pid: w.pid, price }); took++;
      }
      if (!took) { w.status = 'budget'; this.mood -= 6; this.log('wallet', 'Param yetmiyor.', game); continue; }
      w.status = 'got'; this.mood += 6;
      if (price <= p.basePrice * 0.9 && Math.random() < 0.5) { this.mood += 4; this.log('cheap', `${p.name} ucuzmuş!`, game); }
      game.stockChanged(f);
    }
    this.view.setBasketItems(this.basket.map((b) => b.pid));
    this.nextWant(game);
  }

  private checkImpulse(game: Game) {
    const t = this.tile;
    const key = t.x * 1000 + t.z;
    if (this.impulseChecked.has(key)) return;
    this.impulseChecked.add(key);
    for (const f of game.fixtures) {
      if (!f.isDisplay) continue;
      const near = f.fp.access.some((a) => Math.max(Math.abs(a.x - t.x), Math.abs(a.z - t.z)) <= 1);
      if (!near) continue;
      for (const s of f.slots) {
        if (!s.productId || s.stock <= 0) continue;
        const p = PRODUCT_MAP[s.productId];
        if (!p.impulse) continue;
        if (this.basket.some((b) => b.pid === p.id)) continue;
        const price = game.prices[p.id];
        if (price > p.basePrice * (1 + this.arch!.priceTolerance)) continue;
        if (this.spent + price > this.budget) continue;
        if (Math.random() < this.arch!.impulse) {
          s.stock--; this.basket.push({ pid: p.id, price });
          this.view.play('reach');
          this.view.setBasketItems(this.basket.map((b) => b.pid));
          game.stockChanged(f);
          game.stats.impulse++;
          game.overlays.floatText(tmpV.copy(this.pos).setY(this.view.headY + 0.4), `+${p.name}`, '#6c4ab6', null, 1.4);
          this.log('happy', `Kasanın yanında ${p.name.toLowerCase()} gördüm, aldım.`, game, false);
          return;
        }
      }
    }
  }

  pickRegister(game: Game) {
    const regs = game.fixtures.filter((f) => f.def.kind === 'register');
    if (!regs.length) {
      this.log('nocashier', 'Kasa yok! Nasıl ödeyeceğim?', game);
      this.returnItems(game);
      this.finishVisit(game, false);
      return;
    }
    // staffed registers first, then shortest queue
    regs.sort((a, b) => (a.cashier ? 0 : 50) + a.queue.length - ((b.cashier ? 0 : 50) + b.queue.length));
    const reg = regs[0];
    if (this.register && this.register !== reg) { const i = this.register.queue.indexOf(this); if (i >= 0) this.register.queue.splice(i, 1); }
    this.register = reg;
    if (!reg.queue.includes(this)) reg.queue.push(this);
    this.queueIdx = -1;
    this.state = 'toQueue';
  }

  private returnItems(game: Game) {
    for (const b of this.basket) game.backstock[b.pid] = (game.backstock[b.pid] ?? 0) + 1;
    this.basket = [];
    this.view.setBasketItems([]);
  }

  private abandon(game: Game) {
    if (this.register) { const i = this.register.queue.indexOf(this); if (i >= 0) this.register.queue.splice(i, 1); }
    this.mood = Math.min(this.mood, 15) - 10;
    this.log('angry', 'Yeter! Sepeti bırakıp gidiyorum.', game);
    this.view.play('angry');
    game.stats.abandoned++;
    game.stats.lostReasons.queue = (game.stats.lostReasons.queue ?? 0) + 1;
    this.returnItems(game);
    this.finishVisit(game, false);
  }

  finishVisit(game: Game, paid: boolean) {
    this.mood = Math.max(0, Math.min(100, this.mood));
    game.recordVisit(this, paid);
    if (paid && this.mood >= 60) this.log('happy', 'Güzel dükkân, yine gelirim!', game);
    else if (paid && this.mood < 40) this.log('angry', 'Aldım ama memnun kalmadım.', game);
    this.state = 'leaving';
    this.register = null;
    this.goTo(game, { x: this.doorX, z: game.grid.layout.interior.z1 });
  }

  leaveStreet(game: Game) {
    this.state = 'exit';
    this.goTo(game, { x: this.exitX, z: this.tile.z >= 16 && this.tile.z <= 18 ? this.tile.z : 17 });
  }

  statusLabel(): string {
    switch (this.state) {
      case 'walkby': return 'Geçip gidiyor';
      case 'toDoor': return 'Dükkâna yöneliyor';
      case 'decide': return 'İçeri giriyor';
      case 'toShelf': return this.shelf ? `${this.shelf.def.name} rafına gidiyor` : 'Raf arıyor';
      case 'browse': return 'Ürünlere bakıyor';
      case 'toQueue': return 'Kasaya gidiyor';
      case 'queue': return `Kuyrukta (${this.queueIdx + 1}. sırada)`;
      case 'paying': return 'Ödeme yapıyor';
      case 'leaving': case 'exit': return 'Ayrılıyor';
    }
  }
}

// ---------------------------------------------------------------------------

export type Role = 'owner' | 'cashier' | 'stocker' | 'cleaner';
export const ROLE_LABEL: Record<Role, string> = { owner: 'Dükkân Sahibi', cashier: 'Kasiyer', stocker: 'Reyon Görevlisi', cleaner: 'Temizlik Görevlisi' };

interface Task { kind: 'restock'; fixture: Fixture; slot: number; pid: string; qty: number; depot: Fixture; phase: 'toDepot' | 'pickup' | 'toShelf' | 'stock' }
interface CleanTask { kind: 'clean'; litter: import('../game').Litter; phase: 'go' | 'sweep' }

export class Staff extends Agent {
  task: Task | CleanTask | null = null;
  timer = 0;
  idleT = 0;
  register: Fixture | null = null;
  skill = 1;
  activity = 'Hazır';

  constructor(public role: Role, name: string, public wage: number) {
    super(staffLook(role), name);
    this.speed = 1.6;
    this.skill = role === 'owner' ? 1.1 : 0.9 + Math.random() * 0.25;
  }

  atRegister(reg: Fixture) {
    if (this.register !== reg || this.task) return false;
    const b = reg.fp.back[0];
    return Math.abs(this.pos.x - (b.x + 0.5)) < 0.35 && Math.abs(this.pos.z - (b.z + 0.5)) < 0.35;
  }

  update(dt: number, game: Game) {
    const v = this.view;
    if (this.role === 'owner' || this.role === 'cashier') {
      if (!this.register || !game.fixtures.includes(this.register) || this.register.cashier !== this) {
        this.register = game.fixtures.find((f) => f.def.kind === 'register' && (!f.cashier || f.cashier === this || !game.staff.includes(f.cashier))) ?? null;
        if (this.register) this.register.cashier = this;
        this.goal = null;
      }
      const reg = this.register;
      const busy = reg && (reg.queue.length > 0);
      // If customers are waiting, drop non-carrying tasks and return to the till
      if (this.task && busy && !(this.task.kind === 'restock' && (this.task.phase === 'toShelf' || this.task.phase === 'stock'))) this.cancelTask(game);
      if (this.task) { this.doTask(dt, game); return; }
      if (reg) {
        const b = reg.fp.back[0];
        if (!this.goal || this.goal.x !== b.x || this.goal.z !== b.z) this.goTo(game, b);
        const arrived = this.move(dt, game);
        if (arrived) {
          this.lookAt = tmpV.set(reg.fp.access[0].x + 0.5, 0, reg.fp.access[0].z + 0.5).clone();
          const serving = reg.queue[0]?.state === 'paying';
          v.play(serving ? 'work' : 'idle');
          this.activity = serving ? 'Müşteriye hizmet veriyor' : 'Kasada bekliyor';
          if (!busy) {
            this.idleT += dt;
            // help out when idle and nobody else can
            if (this.idleT > 0.8) {
              const t = (!game.hasRole('stocker') && game.findRestockTask(this, 0.4)) || (!game.hasRole('stocker') && !game.hasRole('cleaner') && game.findCleanTask(this));
              if (t) { this.task = t; this.idleT = 0; }
            }
          } else this.idleT = 0;
        } else { v.play('walk'); this.activity = 'Kasaya dönüyor'; }
      } else {
        this.activity = 'Kasa yok — boşta';
        const t = game.findRestockTask(this, 0.5) || game.findCleanTask(this);
        if (t) this.task = t; else v.play('idle');
      }
      if (this.task) this.doTask(0, game);
      return;
    }
    if (!this.task) {
      const t = this.role === 'stocker' ? (game.findRestockTask(this, 0.55) || game.findCleanTask(this)) : game.findCleanTask(this);
      if (t) this.task = t;
    }
    if (this.task) this.doTask(dt, game);
    else {
      this.activity = 'Boşta, iş bekliyor';
      if (this.goal && !this.move(dt, game)) v.play('walk');
      else {
        v.play('idle');
        this.idleT += dt;
        if (this.idleT > 6) {
          this.idleT = 0;
          const r = game.grid.layout.interior;
          const tx = r.x0 + Math.floor(Math.random() * (r.x1 - r.x0)), tz = r.z0 + Math.floor(Math.random() * (r.z1 - r.z0 - 1));
          if (game.grid.walkable(tx, tz)) this.goTo(game, { x: tx, z: tz });
        }
      }
    }
  }

  cancelTask(game: Game) {
    const t = this.task; if (!t) return;
    if (t.kind === 'restock') {
      t.fixture.slots[t.slot].claimed = 0;
      if (t.phase === 'toShelf' || t.phase === 'stock') game.backstock[t.pid] = (game.backstock[t.pid] ?? 0) + t.qty;
    } else t.litter.claimed = 0;
    this.task = null; this.view.setCarry(false); this.view.setBroom(false); this.goal = null;
  }

  private doTask(dt: number, game: Game) {
    const t = this.task!;
    const v = this.view;
    if (t.kind === 'restock') {
      if (!game.fixtures.includes(t.fixture) || !game.fixtures.includes(t.depot)) { this.cancelTask(game); return; }
      switch (t.phase) {
        case 'toDepot': {
          this.activity = 'Depoya gidiyor';
          v.play('walk');
          if (!this.goal) this.goTo(game, nearestAccess(game, t.depot, this.pos));
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
            t.phase = 'toShelf'; this.goal = null;
          }
          break;
        }
        case 'toShelf': {
          this.activity = `${PRODUCT_MAP[t.pid].name} rafa taşıyor`;
          v.play('carry');
          if (!this.goal) this.goTo(game, nearestAccess(game, t.fixture, this.pos));
          if (this.move(dt, game)) { t.phase = 'stock'; this.timer = 1.4; this.lookAt = t.fixture.center; v.setCarry(false); }
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
            this.task = null; this.goal = null; this.lookAt = null;
          }
          break;
        }
      }
    } else {
      const L = t.litter;
      if (!game.litter.includes(L)) { this.task = null; this.view.setBroom(false); this.goal = null; return; }
      if (t.phase === 'go') {
        this.activity = 'Çöpü temizlemeye gidiyor';
        v.play('walk');
        if (!this.goal) { if (!this.goTo(game, nearestWalkable(game, L.tile))) { this.cancelTask(game); return; } }
        if (this.move(dt, game)) { t.phase = 'sweep'; this.timer = 1.8; v.setBroom(true); this.lookAt = new THREE.Vector3(L.tile.x + 0.5, 0, L.tile.z + 0.5); }
      } else {
        this.activity = 'Temizlik yapıyor';
        v.play('sweep');
        this.timer -= dt;
        if (this.timer <= 0) { game.removeLitter(L); v.setBroom(false); this.task = null; this.goal = null; this.lookAt = null; }
      }
    }
  }
}

export function nearestAccess(game: Game, f: Fixture, from: THREE.Vector3): Tile {
  const acc = f.fp.access.filter((t) => game.grid.walkable(t.x, t.z));
  acc.sort((a, b) => Math.hypot(a.x + 0.5 - from.x, a.z + 0.5 - from.z) - Math.hypot(b.x + 0.5 - from.x, b.z + 0.5 - from.z));
  return acc[0] ?? f.fp.access[0];
}

function nearestWalkable(game: Game, t: Tile): Tile {
  if (game.grid.walkable(t.x, t.z)) return t;
  for (let r = 1; r < 4; r++) for (let dz = -r; dz <= r; dz++) for (let dx = -r; dx <= r; dx++) if (game.grid.isInterior(t.x + dx, t.z + dz) && game.grid.walkable(t.x + dx, t.z + dz)) return { x: t.x + dx, z: t.z + dz };
  return t;
}

function staffLook(role: Role): Look {
  const accent = role === 'owner' ? 0xe0663c : role === 'cashier' ? 0x1f8a86 : role === 'stocker' ? 0x2f5d8a : 0x6c4ab6;
  return {
    skin: pick(SKIN_TONES), hair: pick(HAIR_COLORS), hairStyle: role === 'owner' ? 'short' : pick<HairStyle>(['short', 'bun', 'curly', 'spiky']),
    top: 0xfaf3e6, bottom: 0x2b3a55, shoes: 0x2a2a2e, height: role === 'owner' ? 1.04 : 1, girth: role === 'owner' ? 1.12 : 1,
    accessory: 'apron', accent, glasses: false, beard: role === 'owner',
  };
}

export { ICON_LABEL, MAP_W };
