import * as THREE from 'three';
import type { Tile } from './grid';
import type { Game } from '../game';
import type { Fixture } from './fixture';
import { CharacterView, type Look, type HairStyle } from '../world/characters';
import { iconMaterial, type IconKind, ICON_LABEL } from '../world/icons';
import { type Archetype, type Accessory, SKIN_TONES, HAIR_COLORS, GREY_HAIR } from '../data/customers';
import { PRODUCT_MAP } from '../data/products';
import { TURKISH_NAMES, MAP_W, FLOOR_H } from '../config';

const tmpV = new THREE.Vector3();
let nextId = 1;

export const tileCenter = (t: Tile, out = new THREE.Vector3()) => out.set(t.x + 0.5, 0.08, t.z + 0.5);

export type Leg = { kind: 'walk'; floor: number; goal: Tile } | { kind: 'ride'; conn: RideConn };
export interface RideConn { id: string; kind: 'escalator' | 'elevator'; board: Tile; boardFloor: number; land: Tile; landFloor: number; time: number }

export abstract class Agent {
  id = nextId++;
  view: CharacterView;
  pos = new THREE.Vector3();
  floor = 0;
  path: Tile[] = [];
  pathIdx = 0;
  goal: Tile | null = null;
  /** final destination of a (possibly multi-floor) trip */
  dest: { tile: Tile; floor: number } | null = null;
  legs: Leg[] = [];
  ride: { conn: RideConn; t: number; from: THREE.Vector3; to: THREE.Vector3 } | null = null;
  gridVersion = -1;
  speed = 1.4;
  speedMul = 1;
  facing = 0;
  moving = 0;
  jitter = new THREE.Vector2((Math.random() - 0.5) * 0.3, (Math.random() - 0.5) * 0.3);
  bubble: THREE.Sprite;
  bubbleT = 0;
  bubbleKind: IconKind | null = null;
  lookAt: THREE.Vector3 | null = null;
  removed = false;
  hidden = false;
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
  gridOf(game: Game) { return game.floors[this.floor] ?? game.grid; }
  get riding() { return !!this.ride; }

  think(kind: IconKind, dur = 2.2) {
    this.bubbleKind = kind; this.bubbleT = dur;
    this.bubble.material = iconMaterial(kind);
    this.bubble.visible = true;
  }

  /** walk on the current floor */
  goTo(game: Game, t: Tile): boolean {
    const g = this.gridOf(game);
    const from = this.tile;
    if (!g.walkable(from.x, from.z)) this.unstick(game);
    const p = g.findPath(this.tile, t, { avoidCrowd: true });
    this.goal = { ...t };
    if (!this.legs.length) this.dest = { tile: { ...t }, floor: this.floor };
    this.gridVersion = g.version;
    if (!p) { this.path = []; this.pathIdx = 0; return false; }
    this.path = p; this.pathIdx = p.length > 1 ? 1 : 0;
    return true;
  }

  /** go anywhere, switching floors via escalator / elevator when needed */
  goToAny(game: Game, t: Tile, floor = 0, preferLift = false): boolean {
    this.legs = [];
    if (floor === this.floor || this.ride) { this.dest = { tile: { ...t }, floor }; if (this.ride) { this.legs = [{ kind: 'walk', floor, goal: t }]; return true; } return this.goTo(game, t); }
    const conn = game.pickConnector(this.floor, floor, this.pos, preferLift);
    if (!conn) { this.path = []; this.goal = { ...t }; return false; }
    this.legs = [{ kind: 'ride', conn }, { kind: 'walk', floor, goal: t }];
    this.dest = { tile: { ...t }, floor };
    return this.goTo(game, conn.board);
  }

  sameDest(t: Tile, floor = 0) { return !!this.dest && this.dest.tile.x === t.x && this.dest.tile.z === t.z && this.dest.floor === floor; }

  unstick(game: Game) {
    const g = this.gridOf(game);
    const t = this.tile;
    if (!g.inBounds(t.x, t.z)) return;
    for (let r = 1; r < 6; r++) for (let dz = -r; dz <= r; dz++) for (let dx = -r; dx <= r; dx++) {
      if (g.walkable(t.x + dx, t.z + dz) && g.region[g.idx(t.x + dx, t.z + dz)] === g.region[g.idx(t.x, t.z)]) {
        this.pos.set(t.x + dx + 0.5, this.pos.y, t.z + dz + 0.5); return;
      }
    }
  }

  /** returns true when arrived at the final goal */
  move(dt: number, game: Game): boolean {
    if (this.ride) return this.stepRide(dt, game);
    if (!this.goal) return true;
    const g = this.gridOf(game);
    if (this.gridVersion !== g.version) {
      const gl = this.goal; const legs = this.legs; this.goTo(game, gl); this.legs = legs;
    }
    if (!this.path.length) { this.moving = 0; return false; }
    if (this.pathIdx >= this.path.length) return this.nextLeg(game);
    const wp = this.path[this.pathIdx];
    const last = this.pathIdx === this.path.length - 1;
    const tx = wp.x + 0.5 + (last ? this.jitter.x * 0.5 : this.jitter.x), tz = wp.z + 0.5 + (last ? this.jitter.y * 0.5 : this.jitter.y);
    const dx = tx - this.pos.x, dz = tz - this.pos.z;
    const d = Math.hypot(dx, dz);
    let sp = this.speed * this.speedMul;
    const occ = g.occupancy[g.idx(wp.x, wp.z)];
    if (occ >= 2 && (g.isInterior(wp.x, wp.z) || g.region[g.idx(wp.x, wp.z)] >= 4)) { sp *= 0.5; this.crowdT += dt; }
    const step = sp * dt;
    if (d <= step || d < 0.02) {
      this.pos.x = tx; this.pos.z = tz;
      this.pathIdx++;
      if (this.pathIdx >= this.path.length) return this.nextLeg(game);
    } else {
      this.pos.x += (dx / d) * step; this.pos.z += (dz / d) * step;
      const want = Math.atan2(dx, dz);
      this.facing = lerpAngle(this.facing, want, Math.min(1, dt * 12));
    }
    this.moving = sp / 1.4;
    return false;
  }

  private nextLeg(game: Game): boolean {
    this.moving = 0;
    const leg = this.legs.shift();
    if (!leg) return true;
    if (leg.kind === 'ride') {
      const c = leg.conn;
      if (!game.connectorWorking(c.id)) {
        // broken while we were walking: re-plan
        const d = this.dest; this.legs = [];
        if (d) this.goToAny(game, d.tile, d.floor, true);
        return false;
      }
      const from = floorPos(c.board, c.boardFloor), to = floorPos(c.land, c.landFloor);
      this.ride = { conn: c, t: 0, from, to };
      game.onRide(this, c);
      return false;
    }
    this.floor = leg.floor;
    this.pos.y = leg.floor * FLOOR_H + 0.08;
    this.goTo(game, leg.goal);
    return false;
  }

  private stepRide(dt: number, game: Game): boolean {
    const r = this.ride!;
    r.t += dt / r.conn.time;
    const k = Math.min(1, r.t);
    if (r.conn.kind === 'escalator') {
      // step on, glide, step off
      const e = k < 0.1 ? k / 0.1 * 0.1 : k > 0.9 ? 0.9 + (k - 0.9) : k;
      this.pos.lerpVectors(r.from, r.to, e);
      const ramp = THREE.MathUtils.smoothstep(k, 0.12, 0.88);
      this.pos.y = r.from.y + (r.to.y - r.from.y) * ramp;
      this.facing = lerpAngle(this.facing, Math.atan2(r.to.x - r.from.x, r.to.z - r.from.z), Math.min(1, dt * 10));
    } else {
      // glass lift: step in, rise, step out
      const cx = r.from.x + 0.5, cz = r.from.z - 1.0;
      if (k < 0.15) { const q = k / 0.15; this.pos.set(r.from.x + (cx - r.from.x) * q, r.from.y, r.from.z + (cz - r.from.z) * q); }
      else if (k < 0.85) { const q = THREE.MathUtils.smoothstep((k - 0.15) / 0.7, 0, 1); this.pos.set(cx, r.from.y + (r.to.y - r.from.y) * q, cz); }
      else { const q = (k - 0.85) / 0.15; this.pos.set(cx + (r.to.x - cx) * q, r.to.y, cz + (r.to.z - cz) * q); }
    }
    this.moving = 0;
    if (k >= 1) {
      this.ride = null;
      this.floor = r.conn.landFloor;
      this.pos.copy(r.to);
      return this.nextLeg(game);
    }
    return false;
  }

  syncView(dt: number) {
    this.view.root.position.copy(this.pos);
    if (this.lookAt && !this.moving) {
      const want = Math.atan2(this.lookAt.x - this.pos.x, this.lookAt.z - this.pos.z);
      this.facing = lerpAngle(this.facing, want, Math.min(1, dt * 8));
    }
    this.view.root.rotation.y = this.facing;
    this.view.walkSpeed = this.speed * this.speedMul;
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

export const floorPos = (t: Tile, floor: number) => new THREE.Vector3(t.x + 0.5, floor * FLOOR_H + 0.08, t.z + 0.5);

export function lerpAngle(a: number, b: number, t: number) {
  let d = b - a;
  while (d > Math.PI) d -= Math.PI * 2;
  while (d < -Math.PI) d += Math.PI * 2;
  return a + d * t;
}

// ---------------------------------------------------------------------------

export type WantStatus = 'pending' | 'got' | 'oos' | 'notfound' | 'expensive' | 'budget' | 'stolen' | 'skipped';
export interface Want { pid: string; qty: number; status: WantStatus; tried: Set<number> }

export type CState = 'walkby' | 'toDoor' | 'decide' | 'toCart' | 'toShelf' | 'browse' | 'toQueue' | 'queue' | 'paying' | 'leaving' | 'exit' | 'toExit' | 'caught' | 'flee';

export interface Thought { icon: IconKind; text: string; t: number }

export function pick<T>(arr: T[]) { return arr[(Math.random() * arr.length) | 0]; }
export function rand(a: number, b: number) { return a + Math.random() * (b - a); }

export function randomLook(arch: { id: string; accessory?: Accessory; palette: { tops: number[]; bottoms: number[] } } | null): Look {
  const styles: HairStyle[] = ['short', 'long', 'bun', 'curly', 'spiky'];
  const isOld = arch?.id === 'emekli' || arch?.id === 'emekliz';
  const skin = pick(SKIN_TONES);
  return {
    skin,
    hair: isOld ? pick(GREY_HAIR) : pick(HAIR_COLORS),
    hairStyle: isOld ? pick<HairStyle>(['bald', 'short', 'bun']) : pick(styles),
    top: arch ? pick(arch.palette.tops) : pick([0x9aa5b1, 0x6d7b8a, 0xc9b79c, 0x8c6f5a, 0x5f7f99, 0xb27a6e]),
    bottom: arch ? pick(arch.palette.bottoms) : pick([0x2b3a55, 0x3d3d45, 0x5b4a3a]),
    shoes: pick([0x2a2a2e, 0x6b4a33, 0xf2f0ea, 0x3a4a6a]),
    height: arch?.id === 'ogrenci' || arch?.id === 'genc' ? rand(0.86, 0.95) : rand(0.95, 1.06),
    girth: isOld ? rand(1.0, 1.18) : rand(0.9, 1.08),
    accessory: arch?.accessory,
    accent: arch?.id === 'firsatci' ? pick([0x2f3440, 0x3a3a3a]) : pick([0xe0663c, 0x1f8a86, 0xf2b33d, 0x6c4ab6, 0xd6333a, 0x2f6fb5]),
    glasses: isOld ? Math.random() < 0.6 : Math.random() < 0.15,
    beard: !isOld && Math.random() < 0.15 || (isOld && Math.random() < 0.3),
  };
}

export class Customer extends Agent {
  state: CState = 'toDoor';
  wants: Want[] = [];
  basket: { pid: string; price: number }[] = [];
  stolen: string[] = [];
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
  slipT = 0;
  suspect = false; // seen stealing (camera / staff)
  hasCart = false;
  searchT = 0;

  constructor(public arch: Archetype | null, shopper: boolean, game: Game) {
    super(randomLook(arch), pick(TURKISH_NAMES), false);
    this.shopper = shopper;
    this.budget = arch ? Math.round(rand(arch.budget[0], arch.budget[1])) : 0;
    this.speed = arch ? arch.speed * rand(0.92, 1.08) : rand(1.1, 1.5);
    if (arch && shopper) {
      const n = Math.round(rand(arch.listSize[0], arch.listSize[1]));
      const pool = Object.entries(arch.wants)
        .filter(([pid]) => PRODUCT_MAP[pid] && PRODUCT_MAP[pid].stage <= game.stage)
        .map(([pid, w]) => [pid, w * game.demandMul(pid)] as [string, number]);
      for (let i = 0; i < n && pool.length; i++) {
        const tot = pool.reduce((s, [, w]) => s + w, 0);
        let r = Math.random() * tot;
        let idx = 0;
        for (; idx < pool.length; idx++) { r -= pool[idx][1]; if (r <= 0) break; }
        idx = Math.min(idx, pool.length - 1);
        const [pid] = pool.splice(idx, 1)[0];
        this.wants.push({ pid, qty: (arch.id === 'aile' || arch.id === 'haftalik') && Math.random() < 0.4 ? 2 : 1, status: 'pending', tried: new Set() });
      }
    }
  }

  get thief() { return !!this.arch?.thief; }
  get spent() { return this.basket.reduce((s, b) => s + b.price, 0); }
  get inside() { return ['decide', 'toCart', 'toShelf', 'browse', 'toQueue', 'queue', 'paying', 'toExit', 'caught'].includes(this.state); }

  log(icon: IconKind, text: string, game: Game, bubble = true) {
    this.thoughts.unshift({ icon, text, t: game.clock });
    if (this.thoughts.length > 6) this.thoughts.pop();
    if (bubble) this.think(icon);
  }

  update(dt: number, game: Game) {
    const a = this.view;
    // slipping on a wet floor interrupts everything
    if (this.slipT > 0) {
      this.slipT -= dt; a.play('fall'); this.moving = 0;
      if (this.slipT <= 0) a.play('idle');
      return;
    }
    if (this.inside && this.state !== 'caught') this.checkPuddle(game);
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
          const crowd = game.customersInside() >= game.maxInside();
          if (crowd || !game.isOpen()) {
            if (!this.thief) {
              this.log('crowd', crowd ? 'İçerisi çok kalabalık, vazgeçtim.' : 'Dükkân kapalı.', game);
              game.stats.lost++; game.stats.lostReasons.crowd = (game.stats.lostReasons.crowd ?? 0) + (crowd ? 1 : 0);
            }
            this.leaveStreet(game);
          } else {
            this.enteredAt = game.clock;
            if (!this.thief) game.stats.visitors++;
            this.view.ensureBasket();
            const station = this.arch?.cart ? game.fixtures.find((f) => f.def.kind === 'carts') : undefined;
            if (this.arch?.cart && station) {
              this.state = 'toCart';
              this.goTo(game, nearestAccess(game, station, this.pos));
            } else {
              if (this.arch?.cart) {
                // no cart: the list gets trimmed
                this.wants = this.wants.slice(0, 3);
                this.mood -= 6;
                this.flags.add('nocart');
              }
              this.state = 'decide';
              this.goTo(game, { x: this.doorX, z: game.grid.layout.interior.z1 - 1 });
            }
          }
        }
        break;
      }
      case 'toCart': {
        a.play('walk');
        if (this.move(dt, game)) {
          this.hasCart = true; this.view.setCart(true);
          this.nextWant(game);
        }
        break;
      }
      case 'decide': {
        a.play('walk');
        if (!this.move(dt, game)) break;
        if (this.flags.has('nocart')) this.log('box', 'Araba yok, bu sepete her şey sığmaz. Listemi kısalttım.', game);
        this.nextWant(game);
        break;
      }
      case 'toShelf': {
        a.play(this.hasCart ? 'push' : 'walk');
        this.insideTick(dt, game);
        if (this.move(dt, game)) {
          this.state = 'browse'; this.timer = rand(0.8, 1.5) + this.searchT; this.searchT = 0;
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
          a.play(this.hasCart ? 'push' : 'idle');
          if (this.hasCart) this.moving = 0;
          this.lookAt = reg.center;
          this.wait += dt;
          this.checkImpulse(game);
          const pat = (this.arch!.patience) * game.patienceMul();
          if (this.wait > pat * 0.55 && !this.flags.has('waitWarn')) { this.flags.add('waitWarn'); this.log('wait', 'Bu kuyruk hiç ilerlemiyor…', game); this.mood -= 8; }
          if (this.wait > pat) { this.abandon(game); break; }
          const staffed = reg.def.selfService || (reg.cashier && reg.cashier.atRegister(reg));
          if (idx === 0 && staffed) {
            this.state = 'paying';
            const items = this.basket.length;
            const skill = reg.def.selfService ? 1 : reg.cashier!.effSkill;
            this.timer = (2.0 + 0.55 * items) * (game.upgrades.has('pos') ? 0.65 : 1) * (reg.def.serviceMul ?? 1) / skill;
          } else if (idx === 0 && !staffed && !this.flags.has('nocashier')) {
            this.flags.add('nocashier'); this.log('nocashier', 'Kasada kimse yok!', game);
          }
        } else {
          a.play(this.hasCart ? 'push' : 'walk');
          if (this.state === 'queue') this.wait += dt;
        }
        break;
      }
      case 'paying': {
        a.play('pay');
        this.timer -= dt;
        if (this.timer <= 0) {
          const reg = this.register;
          // self-checkout invites the odd "forgotten" item
          if (reg?.def.selfService && this.basket.length > 2 && Math.random() < 0.08) {
            const b = this.basket.pop()!;
            game.recordShrink(b.pid, 'Self-servis kasada okutulmadı', reg.center);
          }
          const total = this.spent;
          game.sale(this, total);
          if (reg) { const i = reg.queue.indexOf(this); if (i >= 0) reg.queue.splice(i, 1); }
          if (this.wait < this.arch!.patience * 0.3) this.mood += 6;
          this.finishVisit(game, true);
        }
        break;
      }
      case 'leaving': {
        a.play('walk');
        if (this.move(dt, game)) this.leaveStreet(game);
        break;
      }
      case 'toExit': {
        // shoplifter heading out with unpaid goods
        a.play('walk');
        this.insideTick(dt, game);
        if (this.move(dt, game)) {
          const res = game.thiefAtDoor(this);
          if (res === 'caught') this.beCaught(game);
          else if (res === 'alarm') { this.state = 'flee'; this.speedMul = 1.7; this.goTo(game, { x: this.exitX, z: 17 }); }
          else { game.recordTheft(this); this.leaveStreet(game); }
        }
        break;
      }
      case 'flee': {
        a.play('walk');
        if (this.move(dt, game)) this.removed = true;
        break;
      }
      case 'caught': {
        a.play('angry'); this.moving = 0;
        this.timer -= dt;
        if (this.timer <= 0) { this.speedMul = 0.8; this.state = 'leaving'; this.goTo(game, { x: this.doorX, z: game.grid.layout.interior.z1 }); }
        break;
      }
    }
    this.view.setFace(this.state === 'caught' ? 'surprised' : this.mood >= 70 ? 'happy' : this.mood >= 45 ? 'neutral' : this.mood >= 25 ? 'sad' : 'angry');
  }

  beCaught(game: Game) {
    this.state = 'caught'; this.timer = 2.2; this.path = []; this.goal = null;
    for (const pid of this.stolen) game.backstock[pid] = (game.backstock[pid] ?? 0) + 1;
    game.stats.caught = (game.stats.caught ?? 0) + 1;
    this.stolen = [];
    this.view.setBasketItems([]);
    this.log('angry', 'Yakalandım…', game);
    game.overlays.floatText(this.pos.clone().setY(this.view.headY + 0.6), 'Yakalandı!', '#1f8a86', '#ffffff', 2);
  }

  private checkPuddle(game: Game) {
    const p = game.puddleAt(this.tile, this.floor);
    if (!p || p.dry > 0) return;
    const key = 'slip' + p.id;
    if (this.flags.has(key)) return;
    this.flags.add(key);
    if (Math.random() < 0.4) {
      this.slipT = 1.7;
      this.mood -= 16;
      game.stats.slips = (game.stats.slips ?? 0) + 1;
      this.log('slip', 'Kaydım! Kimse paspas yapmıyor mu?', game);
      game.alert('slip', 'slip', 'Bir müşteri ıslak zeminde kaydı! Temizlik görevlisi paspas yapıp uyarı levhası koyar.', 'bad', p.obj.position.clone(), 40);
    }
  }

  private insideTick(dt: number, game: Game) {
    const t = this.tile;
    if (this.arch && Math.random() < this.arch.litter * dt && !game.binNear(t)) game.dropLitter(t, this.floor);
    // drinks in the basket sometimes spill
    if (this.basket.some((b) => ['kola', 'ayran', 'sut', 'su'].includes(b.pid)) && Math.random() < 0.0008 * dt) game.spillAt(t, this.floor, 'Bir müşteri içeceğini döktü');
    if (!this.flags.has('dirty') && game.litterNear(t, 1.6, this.floor)) { this.flags.add('dirty'); this.mood -= 7; this.log('dirty', 'Yerler çok kirli…', game); }
    if (!this.flags.has('ambiance') && game.plantNear(t)) { this.flags.add('ambiance'); this.mood += 4 + (game.upgrades.has('isik') ? 2 : 0); }
    if (this.crowdT > 2.5 && !this.flags.has('crowd')) { this.flags.add('crowd'); this.mood -= 6; this.log('crowd', 'Koridorlar çok dar, sıkıştım.', game); }
  }

  private nextWant(game: Game) {
    let best: { w: Want; f: Fixture; d: number } | null = null;
    for (const w of this.wants) {
      if (w.status !== 'pending') continue;
      const cands = game.fixtures.filter((f) => f.isDisplay && f.slots.some((s) => s.productId === w.pid) && !w.tried.has(f.uid));
      if (!cands.length) {
        w.status = w.tried.size ? 'oos' : 'notfound';
        if (w.status === 'notfound' && !this.thief) {
          this.mood -= 13;
          this.log('notfound', `${PRODUCT_MAP[w.pid].name} arıyordum, satılmıyor mu?`, game);
          game.stats.missed[w.pid] = (game.stats.missed[w.pid] ?? 0) + 1;
        }
        continue;
      }
      for (const f of cands) {
        const stocked = f.slots.some((s) => s.productId === w.pid && s.stock > 0);
        const d = this.pos.distanceTo(f.center) + (stocked ? 0 : 8);
        if (!best || d < best.d) best = { w, f, d };
      }
    }
    if (!best) {
      if (this.thief) {
        if (this.stolen.length) { this.state = 'toExit'; this.goTo(game, { x: this.doorX, z: game.grid.layout.interior.z1 - 1 }); }
        else { this.state = 'leaving'; this.goTo(game, { x: this.doorX, z: game.grid.layout.interior.z1 }); }
        return;
      }
      if (this.basket.length) this.pickRegister(game);
      else {
        this.log(this.mood < 40 ? 'angry' : 'wallet', 'Eli boş çıkıyorum.', game);
        this.finishVisit(game, false);
      }
      return;
    }
    this.shelf = best.f;
    best.w.tried.add(best.f.uid);
    // supermarket: without a category sign nearby, finding the aisle takes a while
    if (game.stage >= 2 && !this.thief && !game.signNear(best.f)) {
      this.searchT = 2.4;
      this.mood -= 3;
      if (!this.flags.has('lost')) { this.flags.add('lost'); this.log('notfound', 'Reyonu bulmak zor, levha yok mu?', game); }
    }
    const access = best.f.fp.access.filter((t) => game.grid.walkable(t.x, t.z));
    access.sort((a, b) => tmpV.set(a.x + 0.5, 0, a.z + 0.5).distanceTo(this.pos) - tmpV.set(b.x + 0.5, 0, b.z + 0.5).distanceTo(this.pos));
    const target = access[Math.floor(Math.random() * Math.min(2, access.length))] ?? access[0];
    if (!target || !this.goTo(game, target)) {
      best.w.status = 'notfound';
      if (!this.thief) { this.mood -= 10; this.log('notfound', 'Rafa ulaşamıyorum, yol kapalı!', game); }
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
        const other = game.fixtures.some((o) => o !== f && o.isDisplay && !w.tried.has(o.uid) && o.slots.some((s) => s.productId === w.pid && s.stock > 0));
        if (!other) {
          w.status = 'oos';
          if (!this.thief) {
            this.mood -= 16;
            this.log('empty', `${PRODUCT_MAP[w.pid].name} bitmiş!`, game);
            game.stats.missed[w.pid] = (game.stats.missed[w.pid] ?? 0) + 1;
          }
        }
        continue;
      }
      const p = PRODUCT_MAP[w.pid];
      if (this.thief) { this.trySteal(game, w, slot, f); continue; }
      const price = game.effectivePrice(w.pid);
      const tol = this.arch!.priceTolerance + game.toleranceBonus();
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
      if (game.isDiscounted(w.pid)) { this.mood += 4; if (Math.random() < 0.6) this.log('cheap', `${p.name} indirimde, iyi denk geldi!`, game); }
      else if (price <= p.basePrice * 0.9 && Math.random() < 0.5) { this.mood += 4; this.log('cheap', `${p.name} ucuzmuş!`, game); }
      if ((w.pid === 'simit' || w.pid === 'ekmek') && game.hasOven() && !this.flags.has('fresh')) { this.flags.add('fresh'); this.mood += 5; this.log('happy', 'Ekmek sıcacık, fırından yeni çıkmış!', game); }
      game.stockChanged(f);
    }
    this.view.setBasketItems(this.basket.map((b) => b.pid).concat(this.stolen));
    this.nextWant(game);
  }

  private trySteal(game: Game, w: Want, slot: { stock: number; productId: string | null }, f: Fixture) {
    const watch = game.watchInfo(this.tile, this.floor);
    if (watch.staff) {
      // someone is looking: act casual and move on
      w.status = 'skipped';
      if (!this.flags.has('nervous')) { this.flags.add('nervous'); this.log('sneak', 'Burada göz var… başka rafa bakayım.', game, false); }
      return;
    }
    if (watch.camera && Math.random() < 0.5) { w.status = 'skipped'; this.log('sneak', 'Kamera var, riskli.', game, false); return; }
    slot.stock--; this.stolen.push(w.pid); w.status = 'stolen';
    game.stockChanged(f);
    if (watch.camera) {
      this.suspect = true;
      this.think('sneak', 6);
      game.suspectSeen(this, 'Kamera bir müşterinin ürünü cebine attığını kaydetti!');
    }
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
        const price = game.effectivePrice(p.id);
        if (price > p.basePrice * (1 + this.arch!.priceTolerance)) continue;
        if (this.spent + price > this.budget) continue;
        if (Math.random() < this.arch!.impulse * game.impulseMul()) {
          s.stock--; this.basket.push({ pid: p.id, price });
          this.view.play('reach');
          this.view.setBasketItems(this.basket.map((b) => b.pid));
          game.stockChanged(f);
          game.stats.impulse++;
          game.overlays.floatText(tmpV.copy(this.pos).setY(this.pos.y + this.view.headY + 0.4), `+${p.name}`, '#6c4ab6', null, 1.4);
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
    const score = (f: Fixture) => (f.def.selfService || f.cashier ? 0 : 50) + f.queue.length * (f.def.serviceMul ?? 1) + (f.def.selfService && this.basket.length > 5 ? 4 : 0);
    regs.sort((a, b) => score(a) - score(b));
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
    if (!this.thief) game.recordVisit(this, paid);
    if (paid && this.mood >= 60) this.log('happy', 'Güzel dükkân, yine gelirim!', game);
    else if (paid && this.mood < 40) this.log('angry', 'Aldım ama memnun kalmadım.', game);
    this.state = 'leaving';
    this.register = null;
    if (this.hasCart) { this.hasCart = false; this.view.setCart(false); }
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
      case 'toCart': return 'Araba alıyor';
      case 'toShelf': return this.shelf ? `${this.shelf.def.name} rafına gidiyor` : 'Raf arıyor';
      case 'browse': return 'Ürünlere bakıyor';
      case 'toQueue': return 'Kasaya gidiyor';
      case 'queue': return `Kuyrukta (${this.queueIdx + 1}. sırada)`;
      case 'paying': return 'Ödeme yapıyor';
      case 'leaving': case 'exit': return 'Ayrılıyor';
      case 'toExit': return this.suspect ? 'Ödemeden kapıya gidiyor!' : 'Kapıya yöneliyor';
      case 'flee': return 'Kaçıyor!';
      case 'caught': return 'Güvenliğe yakalandı';
    }
  }
}

export function nearestAccess(game: Game, f: Fixture, from: THREE.Vector3): Tile {
  const g = game.floors[f.floor] ?? game.grid;
  const acc = f.fp.access.filter((t) => g.walkable(t.x, t.z));
  acc.sort((a, b) => Math.hypot(a.x + 0.5 - from.x, a.z + 0.5 - from.z) - Math.hypot(b.x + 0.5 - from.x, b.z + 0.5 - from.z));
  return acc[0] ?? f.fp.access[0];
}

export function nearestWalkable(game: Game, t: Tile, floor = 0): Tile {
  const g = game.floors[floor] ?? game.grid;
  if (g.walkable(t.x, t.z)) return t;
  for (let r = 1; r < 4; r++) for (let dz = -r; dz <= r; dz++) for (let dx = -r; dx <= r; dx++) if (g.walkable(t.x + dx, t.z + dz) && g.region[g.idx(t.x + dx, t.z + dz)] !== 1) return { x: t.x + dx, z: t.z + dz };
  return t;
}

export { ICON_LABEL, MAP_W };
