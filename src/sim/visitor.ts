import * as THREE from 'three';
import type { Game } from '../game';
import type { Tile } from './grid';
import type { Fixture } from './fixture';
import type { Mall, UnitState } from './mall';
import { Agent, randomLook, pick, rand, nearestAccess, type Thought } from './agents';
import { CharacterView } from '../world/characters';
import type { IconKind } from '../world/icons';
import { TURKISH_NAMES, FLOOR_H } from '../config';
import { MALL_ENTRANCES, TENANT_MAP, type VisitorArch } from '../data/mall';

type Stop = { kind: 'unit'; unit: UnitState } | { kind: 'food' } | { kind: 'play' } | { kind: 'bench' };
type VState = 'toMall' | 'enter' | 'toStop' | 'inUnit' | 'browse' | 'toCounter' | 'order' | 'toSeat' | 'eat' | 'play' | 'bench' | 'leaving' | 'exit';

/** little one trailing a parent (purely visual) */
class Child {
  view: CharacterView;
  pos = new THREE.Vector3();
  facing = 0;
  constructor(parent: Visitor) {
    const look = randomLook(null);
    look.height = 0.62; look.girth = 0.95; look.accessory = undefined; look.beard = false; look.glasses = false;
    look.top = pick([0xf2b33d, 0x61b3ff, 0xe0663c, 0x86d6b4, 0xf08f86]);
    this.view = new CharacterView(look);
    this.pos.copy(parent.pos).add(new THREE.Vector3(0.5, 0, 0.3));
    this.view.root.traverse((o) => { o.userData.agent = parent; });
  }
}

export class Visitor extends Agent {
  state: VState = 'toMall';
  stops: Stop[] = [];
  stop: Stop | null = null;
  mood = 70;
  spent = 0;
  timer = 0;
  exitX = 0;
  entranceX = 7;
  thoughts: Thought[] = [];
  flags = new Set<string>();
  seat: { table: Fixture; i: number } | null = null;
  child: Child | null = null;
  trail: THREE.Vector3[] = [];
  visited: string[] = [];

  constructor(public arch: VisitorArch, private mall: Mall, game: Game) {
    super(randomLook({ id: arch.id, accessory: arch.id === 'aile' ? 'totebag' : arch.id === 'profesyonel' ? 'briefcase' : arch.id === 'genc' ? 'backpack' : 'flatcap', palette: arch.palette }), pick(TURKISH_NAMES));
    this.speed = arch.speed * rand(0.92, 1.08);
    if (arch.child) { this.child = new Child(this); game.r.scene.add(this.child.view.root); }
    this.planStops(game);
  }

  get label() { return this.arch.name; }

  log(icon: IconKind, text: string, game: Game, bubble = true) {
    this.thoughts.unshift({ icon, text, t: game.clock });
    if (this.thoughts.length > 6) this.thoughts.pop();
    if (bubble) this.think(icon);
  }

  private planStops(game: Game) {
    const m = this.mall;
    const n = Math.round(rand(this.arch.stops[0], this.arch.stops[1]));
    const open = m.units.filter((u) => u.tenant && !u.tenant.def.food);
    const cands: { stop: Stop; w: number }[] = [];
    for (const u of open) {
      const w = (this.arch.interests[u.tenant!.def.id] ?? 0.3) * (m.eventBoost(u.tenant!.def.id));
      cands.push({ stop: { kind: 'unit', unit: u }, w });
    }
    if (game.fixtures.some((f) => f.def.kind === 'play') && this.arch.interests.play) cands.push({ stop: { kind: 'play' }, w: this.arch.interests.play * (m.event?.def.familyMul ?? 1) });
    if (game.fixtures.some((f) => f.def.kind === 'bench') && this.arch.interests.bench) cands.push({ stop: { kind: 'bench' }, w: this.arch.interests.bench });
    for (let i = 0; i < n && cands.length; i++) {
      const tot = cands.reduce((s, c) => s + c.w, 0);
      let r = Math.random() * tot, k = 0;
      for (; k < cands.length; k++) { r -= cands[k].w; if (r <= 0) break; }
      this.stops.push(cands.splice(Math.min(k, cands.length - 1), 1)[0].stop);
    }
    const hour = game.hour();
    const mealTime = Math.exp(-((hour - 12.8) ** 2) / 2) + Math.exp(-((hour - 19) ** 2) / 2.5);
    if (Math.random() < this.arch.hunger * (0.35 + mealTime)) this.stops.splice(Math.floor(Math.random() * (this.stops.length + 1)), 0, { kind: 'food' });
    if (!this.stops.length) this.stops.push({ kind: 'bench' });
  }

  update(dt: number, game: Game) {
    const v = this.view;
    this.trackChild(dt);
    // closing time: wrap up whatever they are doing and head out
    if (!game.isOpen() && (this.state === 'browse' || this.state === 'bench' || this.state === 'play' || this.state === 'eat' || this.state === 'order')) this.timer = Math.min(this.timer, 1.2);
    switch (this.state) {
      case 'toMall':
        v.play('walk');
        if (this.move(dt, game)) {
          if (!game.isOpen()) { this.leaveStreet(game); break; }
          this.state = 'enter'; this.goTo(game, { x: this.entranceX, z: 15 });
        }
        break;
      case 'enter':
        v.play('walk');
        if (this.move(dt, game)) { this.mall.stats.visitors++; this.next(game); }
        break;
      case 'toStop':
        v.play('walk');
        this.ambient(dt, game);
        if (this.move(dt, game)) this.arrive(game);
        break;
      case 'inUnit':
        v.play('walk');
        if (this.move(dt, game)) { this.state = 'browse'; this.timer = rand(3.5, 7); }
        break;
      case 'browse': {
        v.play(Math.sin(this.timer * 2) > 0 ? 'reach' : 'idle');
        this.timer -= dt;
        if (this.timer <= 0) {
          const u = (this.stop as { unit: UnitState }).unit;
          if (u.tenant) this.mall.shopAt(this, u, game);
          const out = this.mall.doorOutside(u);
          this.state = 'toStop'; this.stop = null;
          this.goToAny(game, out, u.def.floor);
          this.state = 'leaving';
          this.flags.add('fromUnit');
        }
        break;
      }
      case 'toCounter':
        v.play('walk');
        if (this.move(dt, game)) { this.state = 'order'; this.timer = rand(2.5, 4); }
        break;
      case 'order':
        v.play('pay');
        this.timer -= dt;
        if (this.timer <= 0) {
          const u = this.foodUnit;
          if (u?.tenant) this.mall.shopAt(this, u, game, true);
          this.findSeat(game);
        }
        break;
      case 'toSeat':
        v.play('walk');
        if (this.move(dt, game)) {
          if (this.seat) {
            const p = this.seat.table.seatWorld(this.seat.i);
            this.pos.set(p.x, this.pos.y, p.z);
            this.lookAt = this.seat.table.center;
            this.facing = Math.atan2(this.seat.table.center.x - p.x, this.seat.table.center.z - p.z);
          }
          this.state = 'eat'; this.timer = rand(7, 11);
        }
        break;
      case 'eat':
        v.play(this.seat ? 'sit' : 'rest');
        this.timer -= dt;
        if (this.timer <= 0) {
          if (this.seat) {
            this.seat.table.seatsUsed[this.seat.i] = null;
            if (Math.random() < 0.6) game.dirtyTable(this.seat.table);
            this.seat = null;
          } else if (Math.random() < 0.5) game.dropLitter(this.tile, this.floor);
          this.mood += 6;
          this.log('happy', 'Karnım doydu.', game, false);
          this.lookAt = null;
          this.next(game);
        }
        break;
      case 'play':
        v.play('idle');
        this.timer -= dt;
        if (this.timer <= 0) { this.mood += 10; this.log('fun', 'Çocuk bayıldı, çıkarmak zor oldu!', game); this.next(game); }
        break;
      case 'bench':
        v.play('sit');
        this.timer -= dt;
        if (this.timer <= 0) { this.mood += 5; this.lookAt = null; this.next(game); }
        break;
      case 'leaving':
        v.play('walk');
        this.ambient(dt, game);
        if (this.move(dt, game)) {
          if (this.flags.has('fromUnit')) { this.flags.delete('fromUnit'); this.next(game); break; }
          this.state = 'exit';
          this.goTo(game, { x: this.exitX, z: 17 });
        }
        break;
      case 'exit':
        v.play('walk');
        if (this.move(dt, game)) this.removed = true;
        break;
    }
    this.view.setFace(this.mood >= 70 ? 'happy' : this.mood >= 45 ? 'neutral' : this.mood >= 25 ? 'sad' : 'angry');
  }

  private foodUnit: UnitState | null = null;

  private next(game: Game) {
    this.stop = this.stops.shift() ?? null;
    if (!this.stop || !game.isOpen()) {
      // done: head back out through the nearest entrance
      this.mall.recordVisit(this, game);
      this.state = 'leaving';
      const ex = MALL_ENTRANCES.reduce((b, x) => (Math.abs(x - this.pos.x) < Math.abs(b - this.pos.x) ? x : b), MALL_ENTRANCES[0]);
      this.goToAny(game, { x: ex, z: 15 }, 0, this.arch.prefersLift);
      this.stop = null;
      return;
    }
    const s = this.stop;
    let target: Tile | null = null; let floor = 0;
    if (s.kind === 'unit') {
      if (!s.unit.tenant) { this.next(game); return; }
      target = this.mall.doorOutside(s.unit); floor = s.unit.def.floor;
    } else if (s.kind === 'food') {
      const foods = this.mall.units.filter((u) => u.tenant?.def.food);
      if (!foods.length) { this.log('food', 'Acıktım ama yemek yeri yok!', game); this.mood -= 8; this.next(game); return; }
      this.foodUnit = pick(foods);
      target = this.mall.doorOutside(this.foodUnit); floor = this.foodUnit.def.floor;
    } else {
      const kind = s.kind === 'play' ? 'play' : 'bench';
      const fx = game.fixtures.filter((f) => f.def.kind === kind);
      if (!fx.length) { this.next(game); return; }
      const f = pick(fx);
      target = nearestAccess(game, f, this.pos); floor = f.floor;
      this.lookAt = f.center;
      (this as unknown as { target: Fixture }).target = f;
    }
    this.state = 'toStop';
    if (!this.goToAny(game, target, floor, this.arch.prefersLift || this.flags.has('lift')) && !this.riding) {
      this.log('wrench', 'Oraya nasıl gidilir ki?', game); this.mood -= 5; this.next(game);
    }
  }

  private arrive(game: Game) {
    const s = this.stop;
    if (!s) { this.next(game); return; }
    if (s.kind === 'unit') {
      const u = s.unit;
      if (!u.tenant) { this.next(game); return; }
      this.state = 'inUnit';
      this.goTo(game, this.mall.randomInside(u));
      this.visited.push(u.tenant.def.id);
      u.tenant.visitorsToday++;
    } else if (s.kind === 'food') {
      const u = this.foodUnit!;
      this.state = 'toCounter';
      this.goTo(game, u.def.door.tiles[0]);
    } else if (s.kind === 'play') {
      const f = (this as unknown as { target: Fixture }).target;
      this.state = 'play'; this.timer = rand(8, 13);
      this.lookAt = f.center;
      if (this.child) this.childPlay = f.center.clone().add(new THREE.Vector3(rand(-0.8, 0.8), 0.12, rand(-0.8, 0.8)));
    } else {
      const f = (this as unknown as { target: Fixture }).target;
      const c = f.center;
      this.pos.set(c.x - 0.2, this.pos.y, c.z - 0.1);
      this.facing = f.rot * Math.PI / 2;
      this.state = 'bench'; this.timer = rand(5, 9);
    }
  }

  private findSeat(game: Game) {
    const tables = game.fixtures.filter((f) => f.def.kind === 'table' && f.floor === this.floor);
    let best: { t: Fixture; i: number; d: number } | null = null;
    for (const t of tables) t.seatsUsed.forEach((u, i) => {
      if (u) return;
      const d = t.center.distanceTo(this.pos) + (t.dirty ? 6 : 0);
      if (!best || d < best.d) best = { t, i, d };
    });
    if (!best) {
      this.log('food', 'Oturacak masa yok, ayakta yiyorum…', game); this.mood -= 10;
      this.mall.stats.noSeat++;
      this.state = 'eat'; this.timer = rand(5, 7); this.seat = null;
      return;
    }
    const b = best as { t: Fixture; i: number };
    if (b.t.dirty) { this.log('dirty', 'Masalar kirli, kimse toplamıyor mu?', game); this.mood -= 8; }
    b.t.seatsUsed[b.i] = this;
    this.seat = { table: b.t, i: b.i };
    this.state = 'toSeat';
    this.goTo(game, nearestAccess(game, b.t, b.t.seatWorld(b.i)));
  }

  private ambient(dt: number, game: Game) {
    const t = this.tile;
    if (!this.flags.has('dirty') && game.litterNear(t, 1.6, this.floor)) { this.flags.add('dirty'); this.mood -= 6; this.log('dirty', 'AVM pek temiz değil.', game); }
    if (this.crowdT > 3 && !this.flags.has('crowd')) { this.flags.add('crowd'); this.mood -= 5; this.log('crowd', 'Çok kalabalık!', game); }
    if (this.mall.event && !this.flags.has('event')) { this.flags.add('event'); this.mood += 6; this.log('fun', `${this.mall.event.def.name}! Tam zamanında geldik.`, game); }
    if (Math.random() < 0.0015 * dt * 30 && !game.binNear(t)) game.dropLitter(t, this.floor);
  }

  leaveStreet(game: Game) { this.state = 'exit'; this.goTo(game, { x: this.exitX, z: 17 }); }

  childPlay: THREE.Vector3 | null = null;
  private trackChild(dt: number) {
    const c = this.child; if (!c) return;
    this.trail.push(this.pos.clone());
    if (this.trail.length > 24) this.trail.shift();
    let target = this.trail[0];
    if (this.state === 'play' && this.childPlay) target = this.childPlay;
    else if (this.state === 'eat' && this.seat) target = this.seat.table.center.clone().add(new THREE.Vector3(0.55, 0, 0.55));
    const d = c.pos.distanceTo(target);
    const moving = d > 0.05;
    if (moving) {
      const step = Math.min(d, (this.speed * 1.2 + d) * dt);
      const dir = target.clone().sub(c.pos).normalize();
      c.pos.addScaledVector(dir, step);
      c.facing = Math.atan2(dir.x, dir.z);
    }
    c.pos.y = target.y;
    c.view.root.position.copy(c.pos);
    c.view.root.rotation.y = c.facing;
    c.view.play(this.state === 'play' ? 'play' : moving ? 'walk' : 'idle');
    c.view.update(dt, moving ? 1 : 0);
    c.view.root.visible = this.view.root.visible;
  }

  statusLabel() {
    switch (this.state) {
      case 'toMall': case 'enter': return 'AVM\'ye giriyor';
      case 'toStop': return this.stop?.kind === 'unit' ? `${this.stop.unit.tenant?.def.brand ?? 'Mağaza'} mağazasına gidiyor` : this.stop?.kind === 'food' ? 'Yemek katına gidiyor' : 'Geziniyor';
      case 'inUnit': case 'browse': return 'Mağazada bakınıyor';
      case 'toCounter': case 'order': return 'Yemek sipariş ediyor';
      case 'toSeat': return 'Masaya geçiyor';
      case 'eat': return this.seat ? 'Yemek yiyor' : 'Ayakta yemek yiyor';
      case 'play': return 'Çocuk oyun alanında';
      case 'bench': return 'Bankta dinleniyor';
      case 'leaving': return 'Ayrılıyor';
      case 'exit': return 'Gitti';
    }
  }

  dispose() {
    this.view.dispose();
    this.child?.view.dispose();
    if (this.seat) this.seat.table.seatsUsed[this.seat.i] = null;
  }
}

export { FLOOR_H, TENANT_MAP };
