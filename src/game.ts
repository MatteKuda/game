import * as THREE from 'three';
import { MAP_W, DAY_OPEN, DAY_CLOSE, MIN_PER_SEC, STAGE_LAYOUTS, ROAD_Z0, SIDEWALK_Z0, FAR_WALK_Z0, FLOOR_H } from './config';
import { Grid, R_IN, R_MALL, type Tile } from './sim/grid';
import { Fixture, footprint } from './sim/fixture';
import { buildFixtureModel } from './world/props';
import { Customer, tileCenter, floorPos, type Agent, type RideConn } from './sim/agents';
import { Staff, ROLE_LABEL, ROLE_STAGE, type Role, type Shift, type Task } from './sim/staff';
import { Visitor } from './sim/visitor';
import { Mall, type UnitState, type ConnectorState } from './sim/mall';
import { FIXTURE_MAP, fixtureZone, type FixtureDef } from './data/fixtures';
import { PRODUCTS, PRODUCT_MAP } from './data/products';
import { ARCHETYPES } from './data/customers';
import { STAGES, UPGRADES, EXPANSIONS, CAMPAIGNS } from './data/stages';
import { MALL_FOOTPRINT, TENANT_MAP } from './data/mall';
import { Renderer } from './world/renderer';
import { CameraRig } from './world/cameraRig';
import { Environment } from './world/environment';
import { ShopShell } from './world/building';
import { MallShell } from './world/mallShell';
import { Overlays, litterMesh, puddleMesh, wetSignMesh } from './world/overlays';
import { ProductInstancer, initProductVisuals } from './world/products3d';
import { CharacterView } from './world/characters';
import { initMaterials, mat, rbox } from './world/materials';
import { addMesh } from './world/props';
import { blobTexture } from './world/textures';
import { sfx } from './ui/sfx';
import type { IconKind } from './world/icons';
import { TURKISH_NAMES } from './config';
import { randomLook } from './sim/agents';
import type { SaveData } from './sim/save';

export interface Litter { tile: Tile; floor: number; obj: THREE.Object3D; claimed: number }
export interface Puddle { id: number; tile: Tile; floor: number; obj: THREE.Object3D; sign: THREE.Object3D | null; claimed: number; dry: number; age: number }
export interface Order { pid: string; qty: number; eta: number }
export interface AlertMsg { id: number; key: string; icon: IconKind; text: string; severity: 'info' | 'warn' | 'bad' | 'good'; focus?: THREE.Vector3; t: number }
export interface DayStats {
  revenue: number; purchases: number; wages: number; rent: number; other: number; utilities: number;
  visitors: number; served: number; happyServed: number; lost: number; abandoned: number; impulse: number;
  moodSum: number; moodN: number;
  soldBy: Record<string, number>; missed: Record<string, number>; tooExpensive: Record<string, number>; lostReasons: Record<string, number>;
  theft: number; theftCount: number; theftSeen: number; caught: number; caughtByGuard: number; alarms: number; slips: number; spills: number; shrink: number;
  mallIncome: number; mallVisitors: number;
}
export interface Candidate { role: Role; name: string; wage: number; skill: number }

export type Selection =
  | { kind: 'fixture'; f: Fixture } | { kind: 'customer'; c: Customer } | { kind: 'staff'; s: Staff }
  | { kind: 'visitor'; v: Visitor } | { kind: 'unit'; u: UnitState } | { kind: 'connector'; c: ConnectorState } | null;

export const newStats = (): DayStats => ({
  revenue: 0, purchases: 0, wages: 0, rent: 0, other: 0, utilities: 0, visitors: 0, served: 0, happyServed: 0, lost: 0, abandoned: 0, impulse: 0,
  moodSum: 0, moodN: 0, soldBy: {}, missed: {}, tooExpensive: {}, lostReasons: {},
  theft: 0, theftCount: 0, theftSeen: 0, caught: 0, caughtByGuard: 0, alarms: 0, slips: 0, spills: 0, shrink: 0, mallIncome: 0, mallVisitors: 0,
});

type Listener = (...a: any[]) => void;

export class Game {
  r: Renderer;
  cam: CameraRig;
  env!: Environment;
  shell!: ShopShell;
  overlays!: Overlays;
  instancer!: ProductInstancer;
  grid = new Grid(0);
  floors: Grid[] = [this.grid];
  upper = new THREE.Group(); // floor-1 fixtures, litter, puddles
  viewFloor = 0;
  mall: Mall | null = null;
  mallShell: MallShell | null = null;

  stage = 0;
  money = 6500;
  day = 1;
  clock = DAY_OPEN;
  speed = 1;
  paused = false;
  dayEnded = false;
  rating = 3.0;
  prices: Record<string, number> = {};
  auto: Record<string, boolean> = {};
  backstock: Record<string, number> = {};
  orders: Order[] = [];
  fixtures: Fixture[] = [];
  customers: Customer[] = [];
  staff: Staff[] = [];
  litter: Litter[] = [];
  puddles: Puddle[] = [];
  upgrades = new Set<string>();
  campaigns = new Set<string>();
  discounts: string[] = [];
  stats = newStats();
  totals = { served: 0, happyServed: 0, revenue: 0, visitors: 0, theft: 0 };
  history: { day: number; revenue: number; costs: number; profit: number; rating: number }[] = [];
  candidates: Candidate[] = [];
  alerts: AlertMsg[] = [];
  selection: Selection = null;
  overlayMode: 'none' | 'heat' | 'security' = 'none';
  get heatVisible() { return this.overlayMode === 'heat'; }
  private alertCooldown = new Map<string, number>();
  private alertId = 1;
  private spawnAcc = 0;
  private walkAcc = 0;
  private farAcc = 0;
  private autoAcc = 0;
  private statusAcc = 0;
  private heatAcc = 0;
  private listeners = new Map<string, Listener[]>();
  private raycaster = new THREE.Raycaster();
  private blobGeo = new THREE.PlaneGeometry(0.9, 0.9).rotateX(-Math.PI / 2);
  private blobMat: THREE.MeshBasicMaterial;
  private blobs = new Map<number, THREE.Mesh>();
  private puddleId = 1;
  private promoter: CharacterView | null = null;
  private campaignProps = new THREE.Group();
  van = { state: 'idle' as 'idle' | 'arriving' | 'unloading' | 'leaving', x: -30, t: 0, cargo: [] as Order[] };
  realTime = 0;

  placing: { def: FixtureDef; rot: number; ghost: THREE.Group; moving: Fixture | null; x: number; z: number; valid: boolean; reason: string; marks: THREE.Group } | null = null;

  constructor(canvas: HTMLCanvasElement) {
    this.r = new Renderer(canvas);
    initMaterials();
    initProductVisuals();
    this.cam = new CameraRig(this.r.camera, canvas);
    this.blobMat = new THREE.MeshBasicMaterial({ map: blobTexture(), transparent: true, depthWrite: false, opacity: 0.55 });
    const params = new URLSearchParams(location.search);
    if (params.has('para')) this.money = Number(params.get('para')) || this.money;
  }

  init(save?: SaveData | null) {
    const scene = this.r.scene;
    scene.add(this.upper, this.campaignProps);
    this.env = new Environment(scene);
    this.grid.applyLayout(STAGE_LAYOUTS[0]);
    this.applyEnvBlocks();
    this.shell = new ShopShell(scene, STAGE_LAYOUTS[0], 0, this.upgrades);
    this.setFocusPoints();
    this.overlays = new Overlays(scene);
    this.instancer = new ProductInstancer(scene, (pid, out) => { for (const f of this.fixtures) f.collectUnits(pid, out); });
    for (const p of PRODUCTS) { this.prices[p.id] = p.basePrice; this.auto[p.id] = true; this.backstock[p.id] = 0; }
    if (save) { this.loadFrom(save); return; }
    const add = (id: string, x: number, z: number, rot: number, prods: (string | null)[] = []) => {
      const f = this.addFixture(FIXTURE_MAP[id], x, z, rot);
      prods.forEach((p, i) => { if (f.slots[i]) { f.slots[i].productId = p; f.slots[i].stock = p ? f.cap() : 0; } });
      return f;
    };
    add('raf', 20, 10, 0, ['cips', 'biskuvi']);
    add('raf', 18, 10, 1, ['cikolata', null]);
    add('dolap', 25, 13, 3, ['kola', 'ayran']);
    add('sepet', 25, 12, 3, ['simit', 'ekmek']);
    add('depo', 24, 10, 0);
    add('kasa', 19, 12, 1);
    add('saksi', 18, 15, 0);
    add('cop', 25, 15, 0);
    for (const pid of ['cips', 'biskuvi', 'cikolata', 'kola', 'ayran', 'simit', 'ekmek']) this.backstock[pid] = 8;
    this.hire({ role: 'owner', name: 'Kemal Usta', wage: 0, skill: 1.1 }, true);
    this.rollCandidates();
    this.refreshAll();
    this.cam.focus(21.5, 13, 24);
    this.cam.set({ yaw: -0.3, pitch: 0.9 });
    this.cam.snap();
    for (let i = 0; i < 6; i++) this.spawnWalker(true);
  }

  // ---------------------------------------------------------------- events
  on(evt: string, fn: Listener) { (this.listeners.get(evt) ?? this.listeners.set(evt, []).get(evt)!).push(fn); }
  emit(evt: string, ...a: any[]) { for (const fn of this.listeners.get(evt) ?? []) fn(...a); }

  alert(key: string, icon: IconKind, text: string, severity: AlertMsg['severity'] = 'warn', focus?: THREE.Vector3, cooldown = 45) {
    const now = this.realTime;
    const last = this.alertCooldown.get(key) ?? -1e9;
    if (now - last < cooldown) return;
    this.alertCooldown.set(key, now);
    const a: AlertMsg = { id: this.alertId++, key, icon, text, severity, focus, t: now };
    this.alerts.unshift(a);
    if (this.alerts.length > 5) this.alerts.pop();
    this.emit('alert', a);
    if (severity === 'bad') sfx.play('alert');
  }

  // ---------------------------------------------------------------- queries
  minPerSec() { return MIN_PER_SEC; }
  isOpen() { return this.clock >= DAY_OPEN && this.clock < DAY_CLOSE; }
  customersInside() { return this.customers.filter((c) => c.inside).length; }
  maxInside() { return STAGES[this.stage].maxInside; }
  hasRole(r: Role) { return this.staff.some((s) => s.role === r && s.present); }
  depotCapacity() { return this.fixtures.reduce((s, f) => s + (f.def.depotCapacity ?? 0), 0); }
  backstockTotal() { return Object.values(this.backstock).reduce((a, b) => a + b, 0); }
  incoming(pid: string) { return this.orders.filter((o) => o.pid === pid).reduce((s, o) => s + o.qty, 0) + this.van.cargo.filter((o) => o.pid === pid).reduce((s, o) => s + o.qty, 0); }
  incomingTotal() { return this.orders.reduce((s, o) => s + o.qty, 0) + this.van.cargo.reduce((s, o) => s + o.qty, 0); }
  shelfStock(pid: string) { let n = 0; for (const f of this.fixtures) for (const s of f.slots) if (s.productId === pid) n += s.stock; return n; }
  shelfCap(pid: string) { let n = 0; for (const f of this.fixtures) for (const s of f.slots) if (s.productId === pid) n += f.cap(); return n; }
  isStocked(pid: string) { return this.fixtures.some((f) => f.slots.some((s) => s.productId === pid)); }
  unlockedProducts() { return PRODUCTS.filter((p) => p.stage <= this.stage); }
  wagesPerDay() { return this.staff.reduce((s, x) => s + x.wage, 0); }
  rent() { return STAGES[this.stage].rent; }
  utilities() { return STAGES[this.stage].utilities; }
  hour() { return this.clock / 60; }
  get absMinutes() { return this.day * 1440 + this.clock; }

  patienceMul() {
    const plants = this.fixtures.filter((f) => f.def.kind === 'plant' && f.floor === 0).length;
    return (1 + Math.min(0.25, plants * 0.06)) * (this.upgrades.has('sadakat') ? 1.2 : 1);
  }
  toleranceBonus() { return this.upgrades.has('etiket') ? 0.05 : 0; }
  impulseMul() { return (this.campaigns.has('kasaonu') ? 2 : 1) * (this.upgrades.has('isik') ? 1.2 : 1); }
  isDiscounted(pid: string) { return this.campaigns.has('indirim') && this.discounts.includes(pid); }
  effectivePrice(pid: string) { const p = this.prices[pid]; return this.isDiscounted(pid) ? Math.round(p * 0.85) : p; }
  demandMul(pid: string) { return (this.isDiscounted(pid) ? 1.8 : 1) * (this.campaigns.has('tadim') && (pid === 'simit' || pid === 'ekmek' || pid === 'peynir') ? 1.5 : 1); }
  hasOven() { return this.fixtures.some((f) => f.def.kind === 'oven') && this.hasRole('baker'); }
  signNear(f: Fixture) { return this.fixtures.some((s) => s.def.kind === 'sign' && s.center.distanceTo(f.center) <= (s.def.radius ?? 5)); }

  private near(kind: string, t: Tile, r: number, floor = 0) {
    const p = new THREE.Vector3(t.x + 0.5, floor * FLOOR_H, t.z + 0.5);
    return this.fixtures.some((f) => f.def.kind === kind && f.floor === floor && f.center.distanceTo(p) <= r);
  }
  binNear(t: Tile, floor = 0) { return this.fixtures.some((f) => f.def.kind === 'bin' && f.floor === floor && Math.hypot(f.center.x - t.x - 0.5, f.center.z - t.z - 0.5) <= (f.def.binRadius ?? 0)); }
  plantNear(t: Tile) { return this.near('plant', t, 2.6); }
  litterNear(t: Tile, r: number, floor = 0) { return this.litter.some((l) => l.floor === floor && Math.hypot(l.tile.x - t.x, l.tile.z - t.z) <= r); }

  expansion() { return EXPANSIONS.find((e) => e.toStage === this.stage + 1) ?? null; }
  goals() {
    const e = this.expansion(); if (!e) return [];
    return e.goals.map((g) => {
      const v = g.id === 'rating' ? this.rating : g.id === 'served' ? this.totals.happyServed : this.money;
      return { ...g, value: v, done: v >= g.target };
    });
  }
  canExpand() { const e = this.expansion(); return !!e && this.goals().every((g) => g.done); }

  // ---------------------------------------------------------------- floors
  floorGrid(f: number) { return this.floors[f] ?? this.grid; }
  inFootprint(p: THREE.Vector3) { const F = MALL_FOOTPRINT; return this.stage >= 3 && p.x > F.x0 && p.x < F.x1 && p.z > F.z0 && p.z < F.z1; }
  setViewFloor(f: number) {
    if (this.stage < 3) f = 0;
    f = Math.max(0, Math.min(this.floors.length - 1, f));
    if (f === this.viewFloor) return;
    this.viewFloor = f;
    this.cam.setFloorY(f * FLOOR_H);
    this.cancelPlacement();
    this.emit('floor', f);
  }

  pickConnector(fromFloor: number, toFloor: number, pos: THREE.Vector3, preferLift = false): RideConn | null {
    if (!this.mall) return null;
    let best: { c: RideConn; d: number } | null = null;
    for (const cs of this.mall.connectors) {
      if (cs.broken) continue;
      const d = cs.def;
      let conn: RideConn | null = null;
      if (d.from.floor === fromFloor && d.to.floor === toFloor) conn = { id: d.id, kind: d.kind, board: { x: d.from.x, z: d.from.z }, boardFloor: fromFloor, land: { x: d.to.x, z: d.to.z }, landFloor: toFloor, time: d.rideTime };
      else if (d.bidirectional && d.to.floor === fromFloor && d.from.floor === toFloor) conn = { id: d.id, kind: d.kind, board: { x: d.to.x, z: d.to.z }, boardFloor: fromFloor, land: { x: d.from.x, z: d.from.z }, landFloor: toFloor, time: d.rideTime };
      if (!conn) continue;
      const dist = Math.hypot(conn.board.x + 0.5 - pos.x, conn.board.z + 0.5 - pos.z) + (d.kind === 'elevator' ? (preferLift ? -8 : 4) : 0);
      if (!best || dist < best.d) best = { c: conn, d: dist };
    }
    return best?.c ?? null;
  }
  connectorWorking(id: string) { return !this.mall || this.mall.connectorWorking(id); }
  onRide(a: Agent, c: RideConn) {
    if (c.kind === 'elevator' && this.mall && this.mallShell) {
      const cs = this.mall.connectors.find((x) => x.def.id === c.id)!;
      cs.liftY = c.boardFloor * FLOOR_H; this.mallShell.liftTo(cs, c.landFloor);
    }
    void a;
  }

  // ---------------------------------------------------------------- fixtures
  addFixture(def: FixtureDef, x: number, z: number, rot: number, floor = 0) {
    const f = new Fixture(def, x, z, rot, floor);
    this.fixtures.push(f);
    (floor ? this.upper : this.r.scene).add(f.obj);
    const g = this.floorGrid(floor);
    if (!def.noBlock) for (const t of f.fp.tiles) g.fixture[g.idx(t.x, t.z)] = f.uid;
    g.version++;
    if (this.upgrades.has('pos') && f.model.posDevice) f.model.posDevice.visible = true;
    this.layoutChanged();
    return f;
  }

  removeFixture(f: Fixture) {
    const g = this.floorGrid(f.floor);
    if (!f.def.noBlock) for (const t of f.fp.tiles) g.fixture[g.idx(t.x, t.z)] = 0;
    f.obj.removeFromParent();
    this.fixtures.splice(this.fixtures.indexOf(f), 1);
    for (const s of f.slots) if (s.productId && s.stock) this.backstock[s.productId] += s.stock;
    for (const c of [...f.queue]) c.pickRegister(this);
    if (f.cashier) { f.cashier.register = null; f.cashier.dest = null; }
    for (const s of this.staff) {
      const t = s.task as Task | null;
      if (!t) continue;
      if ((t.kind === 'restock' && (t.fixture === f || t.depot === f)) || (t.kind === 'table' && t.table === f) || (t.kind === 'rest' && t.spot === f) || (t.kind === 'bake' && t.oven === f)) s.cancelTask(this);
    }
    for (const v of this.mall?.visitors ?? []) if (v.seat?.table === f) v.seat = null;
    g.version++;
    this.layoutChanged();
  }

  layoutChanged() {
    const L = this.grid.layout;
    for (const f of this.fixtures) {
      if (f.def.kind !== 'register') continue;
      const svc = f.fp.access[0];
      let best: Tile[] | null = null;
      for (const dx of L.doors) {
        const p = this.grid.findPath(svc, { x: dx, z: L.interior.z1 - 1 });
        if (p && (!best || p.length < best.length)) best = p;
      }
      const slots = best ? [...best] : [svc];
      const last = slots[slots.length - 1];
      if (best) for (let i = 0; i < 4; i++) slots.push({ x: last.x + i, z: L.interior.z1 });
      f.queueSlots = slots.filter((t, i, arr) => arr.findIndex((o) => o.x === t.x && o.z === t.z) === i && this.grid.walkable(t.x, t.z));
    }
    // camera coverage cones
    for (const f of this.fixtures) if (f.def.kind === 'camera') this.computeCameraCover(f);
    this.instancer?.markDirty();
    this.refreshAll();
    this.emit('layout');
  }

  private computeCameraCover(f: Fixture) {
    f.covers.clear();
    const g = this.floorGrid(f.floor);
    const c = f.center;
    const dir = new THREE.Vector2(Math.sin(f.rot * Math.PI / 2), Math.cos(f.rot * Math.PI / 2));
    const R = f.def.radius ?? 6;
    const tall = new Set(this.fixtures.filter((o) => o.floor === f.floor && (o.def.kind === 'depot' || (o.def.kind === 'display' && o.def.display !== 'produce' && o.def.display !== 'basket'))).map((o) => o.uid));
    for (let z = Math.floor(c.z - R); z <= c.z + R; z++) for (let x = Math.floor(c.x - R); x <= c.x + R; x++) {
      if (!g.inBounds(x, z)) continue;
      const v = new THREE.Vector2(x + 0.5 - c.x, z + 0.5 - c.z);
      const d = v.length();
      if (d > R) continue;
      if (d > 0.8 && v.normalize().dot(dir) < Math.cos(Math.PI * 0.42)) continue;
      const r = g.region[g.idx(x, z)];
      if ((r === R_IN || r === R_MALL) && this.lineOfSight(g, c.x, c.z, x + 0.5, z + 0.5, tall)) f.covers.add(g.idx(x, z));
    }
  }

  /** tall shelving (shelves, gondolas, fridges, depot racks) blocks a ceiling camera's view of the aisle behind it */
  private lineOfSight(g: Grid, ax: number, az: number, bx: number, bz: number, tall: Set<number>) {
    const d = Math.hypot(bx - ax, bz - az);
    const n = Math.ceil(d / 0.25);
    const target = g.idx(Math.floor(bx), Math.floor(bz));
    for (let i = 1; i < n; i++) {
      const k = i / n;
      const t = g.idx(Math.floor(ax + (bx - ax) * k), Math.floor(az + (bz - az) * k));
      if (t !== target && tall.has(g.fixture[t])) return false;
    }
    return true;
  }

  refreshAll() {
    const sale = new Set(this.campaigns.has('indirim') ? this.discounts : []);
    for (const f of this.fixtures) f.refreshTags(this.prices, sale);
    this.depotChanged();
    this.instancer?.markDirty();
  }

  stockChanged(f: Fixture) { f.refreshTags(this.prices, new Set(this.campaigns.has('indirim') ? this.discounts : [])); this.instancer.markDirty(); }
  depotChanged() {
    const cap = this.depotCapacity();
    const fill = cap ? Math.min(1, this.backstockTotal() / cap) : 0;
    for (const f of this.fixtures) if (f.def.kind === 'depot') f.setDepotFill(fill);
  }

  validate(def: FixtureDef, x: number, z: number, rot: number, ignore: Fixture | null, floor = this.viewFloor): { ok: boolean; reason: string } {
    const fp = footprint(def, x, z, rot);
    const g = this.floorGrid(floor);
    const zone = fixtureZone(def);
    const inZone = (t: Tile) => {
      if (!g.inBounds(t.x, t.z)) return false;
      const r = g.region[g.idx(t.x, t.z)];
      return (zone !== 'mall' && r === R_IN && floor === 0) || (zone !== 'store' && r === R_MALL);
    };
    for (const t of fp.tiles) {
      if (!inZone(t)) return { ok: false, reason: zone === 'mall' ? 'AVM ortak alanına (koridor / yemek katı) yerleştirilmeli' : 'Dükkânın içine yerleştirilmeli' };
      if (def.noBlock) {
        if (this.fixtures.some((f) => f !== ignore && f.def.id === def.id && f.floor === floor && f.x === t.x && f.z === t.z)) return { ok: false, reason: 'Burada zaten bir tane var' };
        continue;
      }
      const occ = g.fixture[g.idx(t.x, t.z)];
      if (occ && occ !== ignore?.uid) return { ok: false, reason: 'Başka bir eşyanın üstüne gelemez' };
      if (g.reserved[g.idx(t.x, t.z)]) return { ok: false, reason: 'Kapı / geçiş önü boş kalmalı' };
    }
    if (def.noBlock) return { ok: true, reason: '' };
    if (def.kind === 'gate') {
      const L = this.grid.layout;
      const near = L.doors.some((dx) => Math.abs(dx - x) <= 2 && Math.abs(L.interior.z1 - 1 - z) <= 1);
      if (!near) return { ok: false, reason: 'Alarm kapısı bir giriş kapısının hemen yanına kurulmalı' };
    }
    const needsAccess = ['display', 'register', 'depot', 'break', 'oven', 'carts', 'table', 'play', 'bench'].includes(def.kind);
    const tileSet = new Set(fp.tiles.map((t) => g.idx(t.x, t.z)));
    const accFree = (t: Tile) => inZone(t) && !tileSet.has(g.idx(t.x, t.z)) && (!g.fixture[g.idx(t.x, t.z)] || g.fixture[g.idx(t.x, t.z)] === ignore?.uid);
    if (needsAccess && !fp.access.some(accFree)) return { ok: false, reason: 'Önü açık olmalı (erişim alanı)' };
    if (def.kind === 'register') {
      if (!accFree(fp.access[0])) return { ok: false, reason: 'Kasanın müşteri tarafı boş olmalı' };
      if (!def.selfService && !accFree(fp.back[0])) return { ok: false, reason: 'Kasiyerin arkada duracağı yer yok' };
    }
    const maxc = def.maxCount?.[this.stage];
    if (maxc !== undefined && !ignore && this.fixtures.filter((f) => f.def.id === def.id).length >= maxc) return { ok: false, reason: `Bu aşamada en fazla ${maxc} adet` };
    // reachability with tentative placement
    const saved: [number, number][] = [];
    if (ignore && ignore.floor === floor) for (const t of ignore.fp.tiles) { saved.push([g.idx(t.x, t.z), g.fixture[g.idx(t.x, t.z)]]); g.fixture[g.idx(t.x, t.z)] = 0; }
    for (const t of fp.tiles) { saved.push([g.idx(t.x, t.z), g.fixture[g.idx(t.x, t.z)]]); g.fixture[g.idx(t.x, t.z)] = -1; }
    let start: Tile;
    if (floor === 0) { const L = g.layout; start = { x: L.doors[0], z: L.interior.z1 - 1 }; }
    else start = this.mall ? { x: this.mall.connectors[0].def.to.x, z: this.mall.connectors[0].def.to.z } : { x: 20, z: 6 };
    const reach = g.reachableFrom(start);
    let ok = true, reason = '';
    const check = (t: Tile, what: string) => { if (ok && !reach[g.idx(t.x, t.z)]) { ok = false; reason = `${what} ulaşılamaz hâle gelir`; } };
    for (const f of this.fixtures) {
      if (f === ignore || f.floor !== floor || f.def.noBlock || f.def.kind === 'gate') continue;
      if (['display', 'depot', 'register', 'break', 'oven', 'carts', 'table', 'play', 'bench'].includes(f.def.kind)) {
        if (!f.fp.access.some((t) => g.walkable(t.x, t.z) && reach[g.idx(t.x, t.z)])) check(f.fp.access[0], f.def.name);
        if (f.def.kind === 'register' && !f.def.selfService) check(f.fp.back[0], 'Kasiyer yeri');
      }
    }
    if (needsAccess && ok && !fp.access.some((t) => g.walkable(t.x, t.z) && reach[g.idx(t.x, t.z)])) { ok = false; reason = 'Bu konuma yol yok'; }
    if (floor === 0) for (const dx of g.layout.doors) if (ok && !reach[g.idx(dx, g.layout.interior.z1 - 1)]) { ok = false; reason = 'Kapılardan biri kapanıyor'; }
    if (this.mall && ok) {
      for (const u of this.mall.units) if (u.def.floor === floor) { const o = this.mall.doorOutside(u); if (!reach[g.idx(o.x, o.z)]) { ok = false; reason = 'Bir mağaza girişini kapatıyor'; break; } }
      for (const c of this.mall.connectors) for (const e of [c.def.from, c.def.to]) if (ok && e.floor === floor && !reach[g.idx(e.x, e.z)]) { ok = false; reason = 'Merdiven / asansör yolunu kapatıyor'; }
    }
    for (let i = saved.length - 1; i >= 0; i--) g.fixture[saved[i][0]] = saved[i][1];
    return { ok, reason };
  }

  // placement flow ----------------------------------------------------------
  startPlacement(defId: string, moving: Fixture | null = null) {
    this.cancelPlacement();
    const def = FIXTURE_MAP[defId];
    if (moving && moving.floor !== this.viewFloor) this.setViewFloor(moving.floor);
    const ghost = new THREE.Group();
    const clone = buildFixtureModel(def).root;
    const gm = new THREE.MeshStandardMaterial({ color: 0x5ad19a, transparent: true, opacity: 0.55, emissive: 0x2f9a6a, emissiveIntensity: 0.5, depthWrite: false });
    clone.traverse((o) => { const m = o as THREE.Mesh; if (m.isMesh) { m.material = gm; m.castShadow = false; } if ((o as THREE.Sprite).isSprite) o.visible = false; });
    ghost.add(clone);
    const marks = new THREE.Group();
    this.r.scene.add(ghost, marks);
    this.placing = { def, rot: moving ? moving.rot : 0, ghost, moving, x: 0, z: 0, valid: false, reason: '', marks };
    if (moving) { moving.obj.visible = false; this.placing.x = moving.x; this.placing.z = moving.z; }
    this.overlays.buildGrid.visible = true;
    this.overlays.buildGrid.position.y = this.viewFloor * FLOOR_H + 0.095;
    this.select(null);
    this.emit('placing', this.placing);
  }

  cancelPlacement() {
    if (!this.placing) return;
    this.placing.ghost.removeFromParent(); this.placing.marks.removeFromParent();
    if (this.placing.moving) this.placing.moving.obj.visible = true;
    this.placing = null;
    this.overlays.buildGrid.visible = false;
    this.emit('placing', null);
  }

  rotatePlacement() { if (this.placing) { this.placing.rot = (this.placing.rot + 1) % 4; this.updatePlacement(this.placing.x, this.placing.z, true); sfx.play('click'); } }

  updatePlacement(cx: number, cz: number, anchored = false) {
    const p = this.placing; if (!p) return;
    const fl = this.viewFloor;
    const fp0 = footprint(p.def, 0, 0, p.rot);
    const x = anchored ? cx : cx - Math.floor((fp0.fw - 1) / 2), z = anchored ? cz : cz - Math.floor((fp0.fd - 1) / 2);
    p.x = x; p.z = z;
    const fp = footprint(p.def, x, z, p.rot);
    const v = this.validate(p.def, x, z, p.rot, p.moving, fl);
    const afford = p.moving ? true : this.money >= p.def.cost;
    p.valid = v.ok && afford;
    p.reason = !v.ok ? v.reason : !afford ? 'Yeterli para yok' : '';
    const y = fl * FLOOR_H;
    p.ghost.position.set(x + fp.fw / 2, y + 0.08, z + fp.fd / 2);
    p.ghost.rotation.y = p.rot * Math.PI / 2;
    const col = p.valid ? 0x5ad19a : 0xe5484d;
    p.ghost.traverse((o) => { const m = o as THREE.Mesh; if (m.isMesh) { (m.material as THREE.MeshStandardMaterial).color.setHex(col); (m.material as THREE.MeshStandardMaterial).emissive.setHex(col); } });
    p.marks.clear();
    const tileGeo = new THREE.PlaneGeometry(0.92, 0.92).rotateX(-Math.PI / 2);
    const mark = (t: Tile, c: number, o: number) => { const m = new THREE.Mesh(tileGeo, new THREE.MeshBasicMaterial({ color: c, transparent: true, opacity: o, depthWrite: false })); m.position.set(t.x + 0.5, y + 0.11, t.z + 0.5); p.marks.add(m); };
    for (const t of fp.tiles) mark(t, col, 0.35);
    if (!['plant', 'bin', 'camera', 'sign', 'gate'].includes(p.def.kind)) for (const t of fp.access) mark(t, 0x61b3ff, 0.3);
    if (p.def.kind === 'register' && !p.def.selfService) mark(fp.back[0], 0xf2b33d, 0.35);
    if (p.def.kind === 'camera') {
      // preview the view cone
      const tmp = new Fixture(p.def, x, z, p.rot, fl);
      this.computeCameraCover(tmp);
      const g = this.floorGrid(fl);
      for (const i of tmp.covers) mark({ x: i % g.w, z: Math.floor(i / g.w) }, 0xff4a5a, 0.16);
    }
    if (p.def.kind === 'sign') {
      const c = new THREE.Vector3(x + 0.5, 0, z + 0.5);
      const g = this.floorGrid(fl);
      for (let zz = z - 5; zz <= z + 5; zz++) for (let xx = x - 5; xx <= x + 5; xx++) if (g.isInterior(xx, zz) && c.distanceTo(new THREE.Vector3(xx + 0.5, 0, zz + 0.5)) <= 5) mark({ x: xx, z: zz }, 0x7a5ae0, 0.12);
    }
    this.emit('placingUpdate', p);
  }

  confirmPlacement(keep = false) {
    const p = this.placing; if (!p || !p.valid) { sfx.play('error'); return; }
    const fl = this.viewFloor;
    if (p.moving) {
      const f = p.moving;
      const g = this.floorGrid(f.floor);
      if (!f.def.noBlock) for (const t of f.fp.tiles) g.fixture[g.idx(t.x, t.z)] = 0;
      f.place(p.x, p.z, p.rot);
      if (!f.def.noBlock) for (const t of f.fp.tiles) g.fixture[g.idx(t.x, t.z)] = f.uid;
      f.obj.visible = true;
      g.version++;
      this.layoutChanged();
      p.moving = null;
      this.cancelPlacement();
      this.select({ kind: 'fixture', f });
    } else {
      this.money -= p.def.cost;
      this.stats.other += p.def.cost;
      const f = this.addFixture(p.def, p.x, p.z, p.rot, fl);
      this.overlays.floatText(f.center.setY(f.center.y + 2), `−₺${p.def.cost}`, '#e0663c');
      if (!keep) { this.cancelPlacement(); this.select({ kind: 'fixture', f }); }
      else this.updatePlacement(p.x, p.z, true);
    }
    sfx.play('place');
  }

  sellFixture(f: Fixture) {
    const refund = Math.round(f.def.cost * 0.5);
    this.money += refund;
    this.removeFixture(f);
    this.overlays.floatText(f.center.setY(f.center.y + 1.5), `+₺${refund}`, '#1f8a86');
    if (this.selection?.kind === 'fixture' && this.selection.f === f) this.select(null);
    sfx.play('coin');
  }

  assignSlot(f: Fixture, i: number, pid: string | null) {
    const s = f.slots[i];
    if (s.productId && s.stock) this.backstock[s.productId] += s.stock;
    s.productId = pid; s.stock = 0; s.claimed = 0;
    for (const st of this.staff) if (st.task && st.task.kind === 'restock' && st.task.fixture === f && st.task.slot === i) st.cancelTask(this);
    this.stockChanged(f);
    this.emit('changed');
  }

  setPrice(pid: string, price: number) {
    this.prices[pid] = Math.max(1, Math.round(price));
    this.refreshAll();
    this.emit('changed');
  }

  order(pid: string, qty: number, auto = false): boolean {
    const p = PRODUCT_MAP[pid];
    const room = this.depotCapacity() - this.backstockTotal() - this.incomingTotal();
    if (room <= 0) { this.alert('depofull', 'box', auto ? `Depo dolu: otomatik sipariş (${p.name}) verilemedi. Depo rafı ekle ya da yavaş satan ürünü azalt.` : 'Depo dolu — sipariş verilemedi. Depo rafı ekleyin.', 'warn', undefined, auto ? 120 : 45); return false; }
    qty = Math.min(qty, room);
    const cost = qty * p.cost;
    if (this.money < cost) { this.alert('nomoney', 'wallet', 'Sipariş için yeterli nakit yok.', 'bad'); return false; }
    this.money -= cost;
    this.stats.purchases += cost;
    let eta = this.absMinutes + 50;
    if (this.clock + 50 >= DAY_CLOSE) eta = (this.day + 1) * 1440 + DAY_OPEN + 20;
    this.orders.push({ pid, qty, eta });
    if (!auto) sfx.play('click');
    this.emit('changed');
    return true;
  }

  // staff -------------------------------------------------------------------
  rollCandidates() {
    const roles: Role[] = ['stocker', 'cashier', 'stocker', 'cleaner', 'security', 'baker'].filter((r) => ROLE_STAGE[r as Role] <= this.stage) as Role[];
    const pool = this.stage === 0 ? ['stocker', 'stocker', 'cashier'] as Role[] : roles;
    this.candidates = pool.slice(0, 5).map((role) => {
      const skill = 0.85 + Math.random() * 0.35;
      const base = { stocker: 260, cashier: 300, cleaner: 230, security: 340, baker: 380, owner: 0 }[role];
      return { role, name: TURKISH_NAMES[(Math.random() * TURKISH_NAMES.length) | 0], wage: Math.round(base * (0.8 + skill * 0.3) / 10) * 10, skill };
    });
  }

  hire(c: Candidate, free = false, shift: Shift = 'full') {
    const s = new Staff(c.role, c.name, c.wage);
    s.skill = c.skill;
    s.shift = shift;
    const L = this.grid.layout;
    s.pos.set(L.doors[0] + 0.5, 0.08, L.interior.z1 - 0.5);
    this.staff.push(s);
    this.r.scene.add(s.view.root);
    if (!free) {
      const i = this.candidates.indexOf(c); if (i >= 0) this.candidates.splice(i, 1);
      this.overlays.floatText(s.pos.clone().setY(2.2), `${ROLE_LABEL[c.role]} işe başladı`, '#1f8a86', '#ffffff', 2.2);
      sfx.play('place');
    }
    this.emit('changed');
    return s;
  }

  setShift(s: Staff, shift: Shift) { s.shift = shift; this.emit('changed'); }

  fire(s: Staff) {
    if (s.role === 'owner') return;
    s.cancelTask(this);
    for (const f of this.fixtures) if (f.cashier === s) f.cashier = null;
    this.staff.splice(this.staff.indexOf(s), 1);
    s.view.dispose();
    if (this.selection?.kind === 'staff' && this.selection.s === s) this.select(null);
    this.emit('changed');
  }

  findRestockTask(st: Staff, threshold: number): Task | null {
    const depots = this.fixtures.filter((f) => f.def.kind === 'depot');
    if (!depots.length) return null;
    let best: { f: Fixture; i: number; ratio: number; d: number } | null = null;
    for (const f of this.fixtures) {
      if (!f.isDisplay) continue;
      f.slots.forEach((s, i) => {
        if (!s.productId || s.claimed) return;
        const ratio = s.stock / f.cap();
        if (ratio >= threshold) return;
        if ((this.backstock[s.productId] ?? 0) <= 0) return;
        const d = st.pos.distanceTo(f.center);
        if (!best || ratio < best.ratio - 0.1 || (Math.abs(ratio - best.ratio) <= 0.1 && d < best.d)) best = { f, i, ratio, d };
      });
    }
    if (!best) return null;
    const b = best as { f: Fixture; i: number };
    const s = b.f.slots[b.i];
    s.claimed = st.id;
    const depot = depots.sort((a, c) => a.center.distanceTo(st.pos) - c.center.distanceTo(st.pos))[0];
    st.dest = null;
    return { kind: 'restock', fixture: b.f, slot: b.i, pid: s.productId!, qty: Math.min(b.f.cap() - s.stock, 16), depot, phase: 'toDepot' };
  }

  findCleanTask(st: Staff): Task | null {
    const free = this.litter.filter((l) => !l.claimed && (l.floor === 0 || st.role === 'cleaner'));
    if (!free.length) return null;
    free.sort((a, b) => (a.floor !== st.floor ? 20 : 0) + Math.hypot(a.tile.x - st.pos.x, a.tile.z - st.pos.z) - ((b.floor !== st.floor ? 20 : 0) + Math.hypot(b.tile.x - st.pos.x, b.tile.z - st.pos.z)));
    free[0].claimed = st.id;
    st.dest = null;
    return { kind: 'clean', litter: free[0], phase: 'go' };
  }

  findMopTask(st: Staff): Task | null {
    const free = this.puddles.filter((p) => !p.claimed && p.dry <= 0 && (p.floor === 0 || st.role === 'cleaner'));
    if (!free.length) return null;
    free.sort((a, b) => Math.hypot(a.tile.x - st.pos.x, a.tile.z - st.pos.z) - Math.hypot(b.tile.x - st.pos.x, b.tile.z - st.pos.z));
    free[0].claimed = st.id;
    st.dest = null;
    return { kind: 'mop', puddle: free[0], phase: 'go' };
  }

  findTableTask(st: Staff): Task | null {
    const t = this.fixtures.find((f) => f.def.kind === 'table' && f.dirty && !f.claimed);
    if (!t) return null;
    t.claimed = st.id; st.dest = null;
    return { kind: 'table', table: t, phase: 'go' };
  }

  findBakeTask(st: Staff): Task | null {
    const o = this.fixtures.find((f) => f.def.kind === 'oven' && !f.claimed);
    if (!o) return null;
    const want = (pid: string) => this.isStocked(pid) && (this.backstock[pid] ?? 0) < Math.max(8, Math.round(this.shelfCap(pid) * 0.8));
    const need = want('simit') || want('ekmek');
    if (!need || this.depotCapacity() - this.backstockTotal() < 4) return null;
    o.claimed = st.id; st.dest = null;
    return { kind: 'bake', oven: o, phase: 'go' };
  }

  findChaseTask(st: Staff): Task | null {
    const s = this.customers.find((c) => c.suspect && (c.state === 'toExit' || c.state === 'toShelf' || c.state === 'browse') && !this.staff.some((o) => o.task?.kind === 'chase' && o.task.target === c));
    if (!s) return null;
    st.dest = null;
    return { kind: 'chase', target: s, t: 0 };
  }

  // security ------------------------------------------------------------------
  watchInfo(t: Tile, floor = 0): { staff: Staff | null; camera: boolean } {
    const p = new THREE.Vector3(t.x + 0.5, floor * FLOOR_H + 0.08, t.z + 0.5);
    const staff = this.staff.find((s) => s.present && !s.hidden && s.floor === floor && s.pos.distanceTo(p) < (s.role === 'security' ? 5.5 : 3.2)) ?? null;
    const g = this.floorGrid(floor);
    const camera = this.fixtures.some((f) => f.def.kind === 'camera' && f.floor === floor && f.covers.has(g.idx(t.x, t.z)));
    return { staff, camera };
  }

  suspectSeen(c: Customer, text: string) {
    this.stats.theftSeen++;
    this.alert('suspect', 'sneak', text + (this.hasRole('security') ? ' Güvenlik peşine düştü.' : ' Güvenlik görevlisi olsaydı yakalanabilirdi.'), 'bad', c.pos.clone(), 20);
    const guard = this.staff.filter((s) => s.role === 'security' && s.present && s.task?.kind !== 'chase').sort((a, b) => a.pos.distanceTo(c.pos) - b.pos.distanceTo(c.pos))[0];
    if (guard) { if (guard.task) guard.cancelTask(this); guard.task = { kind: 'chase', target: c, t: 0 }; guard.dest = null; }
  }

  thiefAtDoor(c: Customer): 'caught' | 'alarm' | 'escaped' {
    const L = this.grid.layout;
    const doorTile = { x: c.doorX, z: L.interior.z1 - 1 };
    const gate = this.fixtures.find((f) => f.def.kind === 'gate' && Math.abs(f.x - doorTile.x) <= 2.5 && Math.abs(f.z - doorTile.z) <= 1.5);
    if (gate && Math.random() < 0.85) {
      gate.alarmT = 3.5;
      this.stats.alarms++;
      sfx.play('alarm');
      c.think('alarm', 3);
      const guard = this.staff.find((s) => s.role === 'security' && s.present && s.pos.distanceTo(c.pos) < 9);
      if (guard) { this.stats.caughtByGuard++; return 'caught'; }
      // goods are dropped at the gate, the thief runs
      for (const pid of c.stolen) this.backstock[pid] = (this.backstock[pid] ?? 0) + 1;
      c.stolen = []; c.view.setBasketItems([]);
      this.alert('alarm', 'alarm', 'Alarm kapısı öttü! Hırsız ürünleri bırakıp kaçtı.', 'warn', c.pos.clone(), 10);
      return 'alarm';
    }
    return 'escaped';
  }

  recordTheft(c: Customer) {
    if (!c.stolen.length) return;
    const value = c.stolen.reduce((s, pid) => s + this.prices[pid], 0);
    this.stats.theft += value; this.stats.theftCount += c.stolen.length; this.totals.theft += value;
    if (c.suspect) this.alert('theft', 'sneak', `Şüpheli ₺${value} değerinde ürünle kaçtı! Alarm kapısı ve güvenlik görevlisi caydırır.`, 'bad', c.pos.clone(), 10);
    c.stolen = [];
  }

  recordShrink(pid: string, reason: string, at: THREE.Vector3) {
    this.stats.shrink += this.prices[pid];
    this.stats.theftCount++;
    void reason; void at;
  }

  // litter, spills, tables ----------------------------------------------------
  dropLitter(t: Tile, floor = 0) {
    const g = this.floorGrid(floor);
    if (!g.inBounds(t.x, t.z)) return;
    const r = g.region[g.idx(t.x, t.z)];
    if (!(r === R_IN || r === R_MALL) || this.litter.length > 30) return;
    if (this.litter.some((l) => l.floor === floor && l.tile.x === t.x && l.tile.z === t.z)) return;
    const obj = litterMesh();
    obj.position.set(t.x + 0.3 + Math.random() * 0.4, floor * FLOOR_H, t.z + 0.3 + Math.random() * 0.4);
    const L: Litter = { tile: { ...t }, floor, obj, claimed: 0 };
    obj.traverse((o) => { o.userData.litter = L; });
    (floor ? this.upper : this.r.scene).add(obj);
    this.litter.push(L);
    if (this.litter.length >= 4) this.alert('litter', 'dirty', `Yerde ${this.litter.length} çöp var — müşteriler rahatsız. Çöpe tıklayarak temizleyebilirsin.`, 'warn', obj.position.clone(), 60);
  }

  removeLitter(L: Litter) {
    L.obj.removeFromParent();
    const i = this.litter.indexOf(L); if (i >= 0) this.litter.splice(i, 1);
  }

  puddleAt(t: Tile, floor = 0) { return this.puddles.find((p) => p.floor === floor && p.tile.x === t.x && p.tile.z === t.z) ?? null; }

  spillAt(t: Tile, floor = 0, reason = 'Yere bir şey döküldü') {
    const g = this.floorGrid(floor);
    if (!g.inBounds(t.x, t.z) || !(g.region[g.idx(t.x, t.z)] === R_IN || g.region[g.idx(t.x, t.z)] === R_MALL)) return;
    if (this.puddles.length >= 8 || this.puddleAt(t, floor)) return;
    const obj = puddleMesh();
    obj.position.set(t.x + 0.5, floor * FLOOR_H, t.z + 0.5);
    const P: Puddle = { id: this.puddleId++, tile: { ...t }, floor, obj, sign: null, claimed: 0, dry: 0, age: 0 };
    obj.traverse((o) => { o.userData.puddle = P; });
    (floor ? this.upper : this.r.scene).add(obj);
    this.puddles.push(P);
    g.extraCost[g.idx(t.x, t.z)] += 3;
    g.version++;
    this.stats.spills++;
    const canMop = this.hasRole('cleaner') || this.hasRole('stocker') || (!this.hasRole('stocker') && floor === 0);
    this.alert('spill', 'slip', `${reason}: zemin ıslak!${this.hasRole('cleaner') ? ' Temizlik görevlisi yolda.' : canMop ? ' Boştaki personel paspas yapacak.' : ''}`, 'warn', obj.position.clone(), 25);
  }

  placeWetSign(P: Puddle) {
    if (P.sign) return;
    const s = wetSignMesh();
    s.position.set(P.tile.x + 0.85, P.floor * FLOOR_H + 0.08, P.tile.z + 0.2);
    s.rotation.y = Math.random() * 3;
    (P.floor ? this.upper : this.r.scene).add(s);
    P.sign = s;
  }

  mopped(P: Puddle) {
    P.obj.removeFromParent();
    P.dry = 25; // sign stays while drying
    const g = this.floorGrid(P.floor);
    g.extraCost[g.idx(P.tile.x, P.tile.z)] = Math.max(0, g.extraCost[g.idx(P.tile.x, P.tile.z)] - 1.5);
    g.version++;
  }

  dirtyTable(f: Fixture) {
    f.dirty = true; if (f.model.trays) f.model.trays.visible = true;
    const n = this.fixtures.filter((x) => x.def.kind === 'table' && x.dirty).length;
    if (n >= 3) this.alert('tables', 'dirty', `${n} masa kirli. Temizlik görevlisi olmadan yemek katı dağılır.`, 'warn', f.center, 60);
  }
  cleanTable(f: Fixture) { f.dirty = false; f.claimed = 0; if (f.model.trays) f.model.trays.visible = false; }

  // campaigns -------------------------------------------------------------------
  startCampaign(id: string, products: string[] = []) {
    const c = CAMPAIGNS.find((x) => x.id === id)!;
    if (this.campaigns.has(id)) return false;
    if (this.money < c.cost) { this.alert('nomoney', 'wallet', 'Kampanya için yeterli nakit yok.', 'bad'); return false; }
    if (id === 'indirim' && !products.length) return false;
    this.money -= c.cost; this.stats.other += c.cost;
    this.campaigns.add(id);
    if (id === 'indirim') this.discounts = products.slice(0, 3);
    this.refreshAll();
    this.updateCampaignVisuals();
    this.overlays.floatText(this.cam.target.clone().setY(this.cam.target.y + 3), c.name + '!', '#d6333a', '#ffffff', 2.4);
    sfx.play('fanfare');
    this.emit('changed');
    return true;
  }

  private updateCampaignVisuals() {
    this.shell.setCampaign(this.campaigns.size > 0);
    this.campaignProps.clear();
    const L = this.grid.layout;
    if (this.campaigns.has('brosur')) {
      if (!this.promoter) {
        const look = randomLook(null); look.top = 0xd6333a; look.accessory = 'apron'; look.accent = 0xf2b33d;
        this.promoter = new CharacterView(look);
        addMesh(this.promoter.root, rbox(0.2, 0.26, 0.04, 0.01), mat(0xfff1dc, 0.9), 0.24, 0.9, 0.2);
      }
      this.promoter.root.position.set(L.doors[0] - 1.2, 0.08, L.interior.z1 + 1.1);
      this.promoter.root.rotation.y = 0.4;
      this.campaignProps.add(this.promoter.root);
    }
    if (this.campaigns.has('kasaonu')) {
      for (const f of this.fixtures) if (f.def.kind === 'register') {
        const st = new THREE.Group();
        const cols = [0xe5484d, 0xf2b33d, 0x2fae7a, 0x61b3ff];
        addMesh(st, rbox(0.5, 1.1, 0.35, 0.03), mat(0x6c4ab6, 0.5), 0, 0.55, 0);
        for (let i = 0; i < 12; i++) addMesh(st, rbox(0.1, 0.05, 0.08, 0.01), mat(cols[i % 4], 0.4), -0.16 + (i % 4) * 0.1, 0.5 + Math.floor(i / 4) * 0.22, 0.2, 0, 0, 0, false);
        const a = f.fp.access[f.fp.access.length - 1];
        st.position.set(a.x + 0.5 + (f.rot % 2 ? 0 : 0.6), 0.08, a.z + 0.5 + (f.rot % 2 ? 0.6 : 0));
        this.campaignProps.add(st);
      }
    }
    if (this.campaigns.has('tadim')) {
      const oven = this.fixtures.find((f) => f.def.kind === 'oven');
      if (oven) {
        const t = new THREE.Group();
        addMesh(t, rbox(1.0, 0.8, 0.5, 0.03), mat(0xfaf6ea, 0.6), 0, 0.4, 0);
        for (let i = 0; i < 6; i++) addMesh(t, rbox(0.08, 0.04, 0.08, 0.01), mat(0xf2d9a0, 0.8), -0.3 + i * 0.12, 0.83, 0);
        const a = oven.fp.access[0];
        t.position.set(a.x + 0.5, 0.08, a.z + 1.3);
        this.campaignProps.add(t);
      }
    }
  }

  // sales & visits ------------------------------------------------------------
  sale(c: Customer, total: number) {
    this.money += total;
    this.stats.revenue += total;
    this.totals.revenue += total;
    for (const b of c.basket) this.stats.soldBy[b.pid] = (this.stats.soldBy[b.pid] ?? 0) + 1;
    const reg = c.register;
    const at = reg ? reg.center.setY(1.9) : c.pos.clone().setY(2);
    this.overlays.floatText(at, `+₺${total}`, '#1a7f5a', null, 1.5);
    sfx.play('coin');
  }

  recordVisit(c: Customer, paid: boolean) {
    this.stats.moodN++; this.stats.moodSum += c.mood;
    const stars = c.mood / 20;
    this.rating += (stars - this.rating) * (this.upgrades.has('sadakat') ? 0.03 : 0.045);
    if (paid) {
      this.stats.served++; this.totals.served++;
      if (c.mood >= 60) { this.stats.happyServed++; this.totals.happyServed++; }
    } else this.stats.lost++;
    this.emit('visit', c);
  }

  // spawning ------------------------------------------------------------------
  private attract() {
    let a = 0.55 + (this.rating / 5) * 0.75;
    if (this.upgrades.has('neon')) a *= this.hour() > 18 ? 1.45 : 1.15;
    if (this.upgrades.has('tente')) a *= 1.1;
    if (this.stage >= 1) a *= 1.3;
    if (this.stage >= 2) a *= 1.45;
    if (this.campaigns.has('brosur')) a *= 1.35;
    if (this.mall) a *= (1 + Math.min(0.45, this.mall.visitors.length * 0.012)) * (this.mall.event?.def.storeMul ?? 1);
    return a;
  }

  private spawnWalker(anywhere = false, far = false) {
    const c = new Customer(null, false, this);
    const fromLeft = Math.random() < 0.5;
    const z = far ? FAR_WALK_Z0 + (Math.random() < 0.5 ? 0 : 1) : SIDEWALK_Z0 + ((Math.random() * 3) | 0);
    let x = fromLeft ? 0 : MAP_W - 1;
    if (anywhere) x = 1 + Math.floor(Math.random() * (MAP_W - 2));
    if (!this.grid.walkable(x, z)) { c.view.dispose(); return; }
    c.pos.set(x + 0.5, 0.08, z + 0.5);
    c.exitX = fromLeft ? MAP_W - 1 : 0;
    c.state = 'walkby';
    let ez = z;
    if (!this.grid.walkable(c.exitX, ez)) ez = far ? FAR_WALK_Z0 : SIDEWALK_Z0;
    c.goTo(this, { x: c.exitX, z: ez });
    this.customers.push(c);
    this.r.scene.add(c.view.root);
  }

  private spawnShopper() {
    const h = this.hour();
    const pool = ARCHETYPES.filter((a) => a.stage <= this.stage);
    const weights = pool.map((a) => a.hourCurve(h) * (a.id === 'haftalik' && this.upgrades.has('otopark') ? 1.6 : 1) * (a.thief && this.stage >= 2 ? 1.5 : 1));
    const tot = weights.reduce((a, b) => a + b, 0);
    let r = Math.random() * tot, i = 0;
    for (; i < pool.length; i++) { r -= weights[i]; if (r <= 0) break; }
    const arch = pool[Math.min(i, pool.length - 1)];
    const c = new Customer(arch, true, this);
    const fromLeft = Math.random() < 0.5;
    const z = SIDEWALK_Z0 + ((Math.random() * 3) | 0);
    const x = fromLeft ? 0 : MAP_W - 1;
    if (!this.grid.walkable(x, z)) { c.view.dispose(); return; }
    c.pos.set(x + 0.5, 0.08, z + 0.5);
    c.exitX = Math.random() < 0.5 ? 0 : MAP_W - 1;
    const doors = this.grid.layout.doors;
    c.doorX = doors.reduce((b, d) => (Math.abs(d - x) < Math.abs(b - x) ? d : b), doors[0]);
    c.state = 'toDoor';
    c.goTo(this, { x: c.doorX, z: this.grid.layout.interior.z1 });
    this.customers.push(c);
    this.r.scene.add(c.view.root);
  }

  private demand(h: number) {
    const pool = ARCHETYPES.filter((a) => a.stage <= this.stage && !a.thief);
    return pool.reduce((s, a) => s + a.hourCurve(h), 0) / pool.length;
  }

  // ---------------------------------------------------------------- main tick
  frame(realDt: number) {
    realDt = Math.max(0, Math.min(realDt, 0.1));
    this.realTime += realDt;
    this.cam.update(realDt);
    const running = !this.paused && !this.dayEnded;
    if (running) {
      const total = realDt * this.speed;
      const steps = Math.ceil(total / (1 / 30));
      for (let i = 0; i < steps; i++) this.tick(total / steps);
    }
    const viewDt = running ? realDt * this.speed : 0;
    const far = this.cam.farFactor;
    const agents: Agent[] = [...this.customers, ...this.staff, ...(this.mall?.visitors ?? [])];
    for (const a of agents) {
      a.syncView(viewDt);
      if (!a.hidden) a.view.root.visible = this.agentVisible(a, far);
    }
    this.updateBlobs(agents);
    this.overlays.viewFloor = !this.mall || far > 0.5 ? -1 : this.viewFloor;
    this.overlays.update(realDt);
    this.instancer.update();
    // floor visibility
    const lowerHidden = this.stage >= 3 && this.viewFloor >= 1 && far < 0.5;
    this.shell.group.visible = !lowerHidden;
    for (const im of this.instancer.meshes.values()) im.visible = !lowerHidden;
    for (const f of this.fixtures) if (f.floor === 0 && this.stage >= 3) f.obj.visible = !lowerHidden && !(this.placing?.moving === f);
    this.upper.visible = this.stage >= 3 && (this.viewFloor >= 1 || far > 0.5);
    // world
    const camDir = new THREE.Vector3(); this.r.camera.getWorldDirection(camDir);
    const agentPos = agents.map((a) => a.pos);
    this.shell.update(realDt, camDir, agentPos, far);
    this.mallShell?.update(realDt, viewDt, camDir, this.viewFloor, far, this.shell.cutaway, this.r.night, agentPos);
    this.r.setTimeOfDay(this.hour(), this.cam.target);
    const night = this.r.night;
    this.shell.setSignLit(night, this.upgrades.has('neon'));
    this.env.update(running ? realDt * Math.min(this.speed, 2) : 0, realDt, night, this.r.camera.position, this.cam.target, far);
    this.env.van.position.set(this.van.x, 0, ROAD_Z0 + 1.1);
    this.animateFixtures(realDt, viewDt);
    if (this.promoter && this.campaigns.has('brosur')) { this.promoter.play(Math.sin(this.realTime * 0.7) > 0 ? 'pay' : 'idle'); this.promoter.update(viewDt || realDt * 0.3, 0); }
    this.updateSelectionVisual();
    this.heatAcc += realDt;
    if (this.heatAcc > 0.4) {
      this.heatAcc = 0;
      if (this.overlayMode === 'heat') this.overlays.updateHeat(this.floorGrid(this.viewFloor).traffic, (i) => { const r = this.floorGrid(this.viewFloor).region[i]; return r === R_IN || r === R_MALL; });
      if (this.overlayMode === 'security') this.overlays.updateSecurity(this.securityMask());
      this.overlays.heat.position.y = this.viewFloor * FLOOR_H + 0.1;
      const sel = this.selection;
      this.overlays.setQueueLine(sel?.kind === 'fixture' && sel.f.def.kind === 'register' ? sel.f.queueSlots.map((t) => tileCenter(t).setY(0.16)) : null);
    }
    this.r.render();
  }

  private agentVisible(a: Agent, far: number) {
    if (far > 0.5 || this.stage < 3) return true;
    const r = a.ride;
    if (r) return this.viewFloor === r.conn.boardFloor || this.viewFloor === r.conn.landFloor;
    if (a.floor === this.viewFloor) return true;
    if (a.floor === 0 && !this.inFootprint(a.pos)) return true;
    return false;
  }

  private animateFixtures(realDt: number, simDt: number) {
    const t = this.realTime;
    for (const f of this.fixtures) {
      const m = f.model;
      if (m.led) m.led.emissiveIntensity = Math.sin(t * 4) > 0 ? 3 : 0.4;
      if (m.alarmLight) {
        f.alarmT = Math.max(0, f.alarmT - realDt);
        m.alarmLight.emissiveIntensity = f.alarmT > 0 ? (Math.sin(t * 22) > 0 ? 4 : 0.2) : 0.05;
      }
      if (m.belt) m.belt.offset.y -= simDt * (f.queue[0]?.state === 'paying' ? 0.6 : 0.05);
      if (m.ovenGlow) m.ovenGlow.emissiveIntensity = f.baking ? 1.6 + Math.sin(t * 9) * 0.4 : 0.4;
    }
    for (const p of this.puddles) if (p.sign) p.sign.visible = true;
  }

  private tick(dt: number) {
    const prevClock = this.clock;
    this.clock += dt * MIN_PER_SEC;
    for (const g of this.floors) g.occupancy.fill(0);
    const all: Agent[] = [...this.customers, ...this.staff, ...(this.mall?.visitors ?? [])];
    for (const a of all) {
      if (a.hidden || a.ride) continue;
      const g = this.floorGrid(a.floor); const t = a.tile;
      if (g.inBounds(t.x, t.z)) g.occupancy[g.idx(t.x, t.z)]++;
    }
    for (const a of all) {
      if (a.hidden || a.ride) continue;
      const g = this.floorGrid(a.floor); const t = a.tile;
      if (!g.inBounds(t.x, t.z)) continue;
      const r = g.region[g.idx(t.x, t.z)];
      if ((r === R_IN && (a as Customer).shopper) || r === R_MALL) g.traffic[g.idx(t.x, t.z)] += dt;
    }
    for (const g of this.floors) for (let i = 0; i < g.traffic.length; i++) g.traffic[i] *= 1 - 0.004 * dt;

    // spawns
    const h = this.hour();
    this.walkAcc += dt * 0.35;
    while (this.walkAcc > 1) { this.walkAcc -= Math.random() * 2; if (this.customers.length < 60) this.spawnWalker(); }
    this.farAcc += dt * 0.18;
    while (this.farAcc > 1) { this.farAcc -= Math.random() * 2; if (this.customers.length < 60) this.spawnWalker(false, true); }
    if (this.isOpen()) {
      const rate = 0.34 * this.demand(h) * this.attract();
      this.spawnAcc += dt * rate;
      const cap = 70 + this.stage * 20;
      while (this.spawnAcc > 1) { this.spawnAcc -= 1; if (this.customers.length < cap) this.spawnShopper(); }
    }

    for (const c of this.customers) c.update(dt, this);
    for (const s of this.staff) s.update(dt, this);
    this.mall?.update(dt);
    for (let i = this.customers.length - 1; i >= 0; i--) {
      const c = this.customers[i];
      if (c.removed) {
        if (c.state === 'flee' || (c.thief && c.stolen.length)) this.recordTheft(c);
        c.view.dispose(); this.customers.splice(i, 1);
        if (this.selection?.kind === 'customer' && this.selection.c === c) this.select(null);
      }
    }

    // wet floor drying
    for (let i = this.puddles.length - 1; i >= 0; i--) {
      const p = this.puddles[i];
      p.age += dt;
      if (p.dry > 0) {
        p.dry -= dt;
        if (p.dry <= 0) {
          p.sign?.removeFromParent();
          const g = this.floorGrid(p.floor);
          g.extraCost[g.idx(p.tile.x, p.tile.z)] = 0; g.version++;
          this.puddles.splice(i, 1);
        }
      }
    }
    // fridges occasionally leak in bigger stores
    if (this.stage >= 1 && Math.random() < dt * 0.0006) {
      const fr = this.fixtures.filter((f) => f.def.display === 'fridge');
      if (fr.length) { const f = fr[(Math.random() * fr.length) | 0]; const a = f.fp.access[0]; this.spillAt(a, f.floor, `${f.def.name} su sızdırıyor`); }
    }

    this.updateVan(dt);
    const due = this.orders.filter((o) => o.eta <= this.absMinutes);
    if (due.length && this.van.state === 'idle') {
      this.van.cargo = due; this.orders = this.orders.filter((o) => !due.includes(o));
      this.van.state = 'arriving'; this.van.x = -32; this.env.van.visible = true;
    }
    this.autoAcc += dt * MIN_PER_SEC;
    if (this.autoAcc > 30) {
      this.autoAcc = 0;
      const stockedN = this.unlockedProducts().filter((p) => this.isStocked(p.id)).length || 1;
      const fair = Math.max(8, Math.floor(this.depotCapacity() / stockedN * 1.4)); // no single product may hog the depot
      if (this.clock < DAY_CLOSE - 60) for (const p of this.unlockedProducts()) {
        if (!this.auto[p.id] || !this.isStocked(p.id)) continue;
        if ((p.id === 'simit' || p.id === 'ekmek') && this.hasOven()) continue;
        const cap = this.shelfCap(p.id);
        const have = this.backstock[p.id] + this.incoming(p.id);
        const target = Math.min(fair, Math.max(12, Math.round(cap * 1.2)));
        if (have < target * 0.5) this.order(p.id, Math.ceil((target - have) / 6) * 6, true);
      }
    }
    this.statusAcc += dt;
    if (this.statusAcc > 0.25) { this.statusAcc = 0; this.updateStatuses(); }

    if (prevClock < DAY_CLOSE && this.clock >= DAY_CLOSE) this.alert('closing', 'wait', 'Saat 22:00 — dükkân kapanıyor. Son müşteriler çıkınca gün sonu raporu gelecek.', 'info');
    const mallBusy = this.mall ? this.mall.visitors.some((v) => v.state !== 'exit') : false;
    if (this.clock >= DAY_CLOSE && ((this.customersInside() === 0 && !mallBusy) || this.clock > DAY_CLOSE + 50)) this.endDay();
  }

  private updateStatuses() {
    for (const f of this.fixtures) {
      let k: IconKind | null = null;
      if (f.isDisplay) {
        const assigned = f.slots.filter((s) => s.productId);
        if (assigned.some((s) => s.stock === 0)) k = 'empty';
        else if (assigned.some((s) => s.stock / f.cap() < 0.34 && (this.backstock[s.productId!] ?? 0) === 0)) k = 'low';
        else if (assigned.length < f.slots.length) k = 'noproduct';
        if (k === 'empty') {
          const s = assigned.find((x) => x.stock === 0)!;
          const noBack = (this.backstock[s.productId!] ?? 0) === 0;
          if (!noBack && !this.staff.some((x) => x.role === 'stocker')) this.alert('needstocker', 'nocashier', 'Kemal Usta kasadan ayrılamıyor, raflar boş kalıyor. Personel panelinden (H) reyon görevlisi al.', 'bad', f.center, 70);
          this.alert('empty:' + s.productId, 'empty', `${PRODUCT_MAP[s.productId!].name} rafta bitti${noBack ? ' ve depoda da yok — sipariş ver!' : '.'}`, noBack ? 'bad' : 'warn', f.center, 50);
        }
      } else if (f.def.kind === 'register') {
        if (!f.def.selfService && (!f.cashier || !this.staff.includes(f.cashier) || !f.cashier.present)) k = 'nocashier';
        else if (f.queue.length >= 4) k = 'queue';
        if (f.queue.length >= 5) this.alert('queue', 'queue', `Kasada ${f.queue.length} kişilik kuyruk! Kasaya yakın düzen ve hızlı ödeme bekleme süresini düşürür.`, 'warn', f.center, 60);
        if (k === 'nocashier' && f.queue.length) this.alert('nocashier', 'nocashier', 'Bir kasada kasiyer yok. Personel panelinden kasiyer işe al ya da vardiyaları kontrol et.', 'bad', f.center, 60);
      } else if (f.def.kind === 'depot') {
        const cap = this.depotCapacity();
        if (cap && this.backstockTotal() + this.incomingTotal() < cap * 0.08) k = 'box';
      } else if (f.def.kind === 'table') {
        k = f.dirty ? 'dirty' : null;
      } else if (f.def.kind === 'oven') {
        k = this.hasRole('baker') ? null : 'nocashier';
      }
      f.setStatus(k);
    }
    const tired = this.staff.find((s) => s.tired && s.present && !this.fixtures.some((f) => f.def.kind === 'break'));
    if (tired) this.alert('tired', 'tired', `${tired.name} çok yorgun, yavaşladı. Bir Çay Ocağı (Mola) kur ya da vardiyaları böl.`, 'warn', tired.pos.clone(), 90);
  }

  private updateVan(dt: number) {
    const v = this.van;
    const park = this.grid.layout.doors[0] - 0.5;
    const vz = ROAD_Z0 + 1.1;
    if (v.state === 'arriving') {
      v.x += Math.max(1.2, (park - v.x) * 1.4) * dt;
      if (v.x >= park) { v.x = park; v.state = 'unloading'; v.t = 2.5; }
    } else if (v.state === 'unloading') {
      v.t -= dt;
      if (v.t <= 0) {
        let n = 0; let overflow = 0;
        const cap = this.depotCapacity();
        for (const o of v.cargo) {
          const room = Math.max(0, cap - this.backstockTotal());
          const put = Math.min(room, o.qty);
          this.backstock[o.pid] += put; n += put;
          if (o.qty - put > 0) overflow += (o.qty - put) * PRODUCT_MAP[o.pid].cost;
        }
        if (overflow) { this.money += overflow; this.stats.purchases -= overflow; this.alert('overflow', 'box', `Depo doldu, ₺${overflow} tutarında mal iade edildi.`, 'warn'); }
        v.cargo = [];
        this.depotChanged();
        this.overlays.floatText(new THREE.Vector3(park, 3.2, vz - 1), `Teslimat +${n} birim`, '#2f5d8a', '#ffffff', 2.2);
        sfx.play('delivery');
        v.state = 'leaving';
        this.emit('changed');
      }
    } else if (v.state === 'leaving') {
      v.x += Math.min(9, 1.5 + (v.x - park) * 1.2) * dt;
      if (v.x > MAP_W + 32) { v.state = 'idle'; this.env.van.visible = false; }
    }
  }

  endDay() {
    if (this.dayEnded) return;
    for (const c of this.customers) if (c.inside) { if (c.register) { const i = c.register.queue.indexOf(c); if (i >= 0) c.register.queue.splice(i, 1); } c.finishVisit(this, false); }
    const wages = this.wagesPerDay();
    const rent = this.rent();
    const utilities = this.utilities();
    let mallSummary = null;
    if (this.mall) {
      mallSummary = this.mall.endDay();
      const inc = mallSummary.rent + mallSummary.share;
      this.money += inc;
      this.stats.mallIncome = inc; this.stats.mallVisitors = mallSummary.visitors;
    }
    this.money -= wages + rent + utilities;
    this.stats.wages = wages; this.stats.rent = rent; this.stats.utilities = utilities;
    const income = this.stats.revenue + this.stats.mallIncome;
    const costs = this.stats.purchases + wages + rent + utilities + this.stats.other;
    this.history.push({ day: this.day, revenue: income, costs, profit: income - costs, rating: this.rating });
    this.dayEnded = true;
    sfx.play('dayend');
    this.emit('dayEnd', { day: this.day, stats: this.stats, costs, rating: this.rating, money: this.money, mall: mallSummary });
  }

  startNextDay() {
    this.day++;
    this.clock = DAY_OPEN;
    this.stats = newStats();
    this.dayEnded = false;
    this.campaigns.clear(); this.discounts = [];
    this.refreshAll();
    this.updateCampaignVisuals();
    this.rollCandidates();
    for (const s of this.staff) s.energy = 100;
    for (const g of this.floors) for (let i = 0; i < g.traffic.length; i++) g.traffic[i] *= 0.5;
    this.mall?.startDay();
    this.mallShell?.setEvent(this.mall?.event?.def.id ?? null);
    this.emit('changed');
    this.emit('newDay', this.day);
  }

  buyUpgrade(id: string) {
    const u = UPGRADES.find((x) => x.id === id)!;
    if (this.upgrades.has(id) || this.money < u.cost) { sfx.play('error'); return; }
    this.money -= u.cost; this.stats.other += u.cost;
    this.upgrades.add(id);
    this.applyUpgradeVisual(id);
    this.overlays.floatText(this.cam.target.clone().setY(this.cam.target.y + 3), u.name + '!', '#6c4ab6', '#ffffff', 2.4);
    sfx.play('fanfare');
    this.emit('changed');
  }

  private applyUpgradeVisual(id: string) {
    if (id === 'pos') for (const f of this.fixtures) if (f.model.posDevice) f.model.posDevice.visible = true;
    if (id === 'neon' || id === 'tente') { this.shell.rebuild(this.grid.layout, this.stage); this.updateCampaignVisuals(); }
  }

  expand() {
    const e = this.expansion();
    if (!e || !this.canExpand()) { sfx.play('error'); return; }
    this.money -= e.cost; this.stats.other += e.cost;
    this.applyStage(e.toStage);
    const msg = ['', 'Mahalle Marketi açıldı! Yeni reyonlar, manav ve aile alışverişçileri seni bekliyor.', 'Süpermarket açıldı! Bantlı kasalar, fırın ve reyon levhaları kilidi açıldı.', 'Köşebaşı AVM açıldı! Kiracı birimlerini Kiracılar panelinden (V) doldur, yürüyen merdivenlerle üst kata çık (PageUp).'][e.toStage];
    this.alert('expanded', 'star', msg, 'good', undefined, 0);
    this.overlays.floatText(new THREE.Vector3(20, 5, 12), STAGES[e.toStage].name.toUpperCase() + '!', '#e0663c', '#fff1dc', 3.5);
    sfx.play('fanfare');
    this.emit('stage', e.toStage);
    this.emit('changed');
  }

  /** transform the world to a stage (used by expansions and by loading a save) */
  applyStage(n: number) {
    for (let s = this.stage + 1; s <= n; s++) {
      if (s === 1) this.env.removeNeighbor();
      if (s === 2) this.env.removeBakery();
      if (s === 3) this.env.removeForMall();
    }
    this.stage = n;
    this.grid.applyLayout(STAGE_LAYOUTS[n]);
    if (n >= 3 && !this.mall) {
      const g1 = new Grid(1); g1.applyLayout(STAGE_LAYOUTS[n]); g1.region.fill(0); g1.doorEdges.clear(); g1.reserved.fill(0);
      this.floors = [this.grid, g1];
      this.mall = new Mall(this);
      this.mall.applyGrids(this.grid, g1);
      this.mallShell = new MallShell(this.r.scene, this.mall);
      this.cam.bounds = { x0: 2, x1: 42, z0: -2, z1: 30 };
      this.on('mallChanged', () => { for (const u of this.mall!.units) if (this.mallShell!.unitGroups.get(u.idx)?.userData.tenant !== (u.tenant?.def.id ?? null)) { this.mallShell!.rebuildUnit(u); this.mallShell!.unitGroups.get(u.idx)!.userData.tenant = u.tenant?.def.id ?? null; } });
    } else if (n >= 3 && this.mall) this.mall.applyGrids(this.grid, this.floors[1]);
    this.applyEnvBlocks();
    for (const f of this.fixtures) if (!f.def.noBlock) { const g = this.floorGrid(f.floor); for (const t of f.fp.tiles) g.fixture[g.idx(t.x, t.z)] = f.uid; }
    this.shell.rebuild(STAGE_LAYOUTS[n], n);
    this.updateCampaignVisuals();
    this.setFocusPoints();
    for (const g of this.floors) g.version++;
    this.layoutChanged();
    for (const p of PRODUCTS) if (this.backstock[p.id] === undefined) this.backstock[p.id] = 0;
    this.rollCandidates();
    const L = STAGE_LAYOUTS[n].interior;
    this.cam.focus((L.x0 + L.x1) / 2, (L.z0 + L.z1) / 2, n >= 3 ? 36 : n === 2 ? 36 : 32);
  }

  private setFocusPoints() {
    const r = this.grid.layout.interior;
    this.env.focusPoints = [
      new THREE.Vector3(r.x0 + 0.5, 0.5, r.z0 + 0.5), new THREE.Vector3(r.x1 - 0.5, 0.5, r.z0 + 0.5),
      new THREE.Vector3(r.x0 + 0.5, 0.5, r.z1 - 0.5), new THREE.Vector3(r.x1 - 0.5, 0.5, r.z1 - 0.5),
      new THREE.Vector3((r.x0 + r.x1) / 2, 0.5, (r.z0 + r.z1) / 2),
    ];
  }

  private applyEnvBlocks() {
    for (const [x, z] of this.env.blockedTiles) if (this.grid.inBounds(x, z) && this.grid.region[this.grid.idx(x, z)] === 1) this.grid.region[this.grid.idx(x, z)] = 0;
    this.grid.version++;
  }

  // ---------------------------------------------------------------- save / load
  loadFrom(d: SaveData) {
    this.money = d.money; this.day = d.day; this.clock = DAY_OPEN; this.rating = d.rating;
    Object.assign(this.prices, d.prices); Object.assign(this.auto, d.auto); Object.assign(this.backstock, d.backstock);
    this.orders = d.orders; this.totals = { ...this.totals, ...d.totals }; this.history = d.history;
    for (const u of d.upgrades) this.upgrades.add(u);
    if (d.stage > 0) this.applyStage(d.stage);
    for (const u of d.upgrades) this.applyUpgradeVisual(u);
    for (const fd of d.fixtures) {
      const def = FIXTURE_MAP[fd.id]; if (!def) continue;
      const f = this.addFixture(def, fd.x, fd.z, fd.rot, fd.floor ?? 0);
      fd.slots.forEach(([pid, stock], i) => { if (f.slots[i]) { f.slots[i].productId = pid; f.slots[i].stock = stock; } });
    }
    for (const s of d.staff) this.hire({ role: s.role as Role, name: s.name, wage: s.wage, skill: s.skill }, true, s.shift as Shift);
    if (this.mall && d.mall) {
      for (const t of d.mall.tenants) { const u = this.mall.units[t.unit]; u.offers = [{ def: TENANT_MAP[t.id], rent: t.rent }]; this.mall.lease(u, 0); if (u.tenant) u.tenant.sat = t.sat; }
      this.mall.scheduled = d.mall.scheduled; this.mall.mood = d.mall.mood;
      this.mall.history = d.mall.history ?? [];
      this.mall.rollOffers();
      this.mall.startDay();
      this.mallShell?.setEvent(this.mall.event?.def.id ?? null);
    }
    this.rollCandidates();
    this.refreshAll();
    this.cam.snap();
    for (let i = 0; i < 6; i++) this.spawnWalker(true);
  }

  // ---------------------------------------------------------------- picking & selection
  pick(ndc: THREE.Vector2): { fixture?: Fixture; agent?: Customer | Staff | Visitor; litter?: Litter; puddle?: Puddle; unit?: UnitState; connector?: ConnectorState; ground?: THREE.Vector3 } {
    this.raycaster.setFromCamera(ndc, this.r.camera);
    const objs: THREE.Object3D[] = [];
    for (const f of this.fixtures) if (f.obj.visible && (f.floor === 0 ? this.r.scene : this.upper).visible !== false && (f.floor === this.viewFloor || this.stage < 3)) objs.push(f.obj);
    for (const a of [...this.customers, ...this.staff, ...(this.mall?.visitors ?? [])]) if (a.view.root.visible) objs.push(a.view.root);
    for (const l of this.litter) if (l.floor === this.viewFloor) objs.push(l.obj);
    for (const p of this.puddles) if (p.floor === this.viewFloor && p.obj.parent) objs.push(p.obj);
    if (this.mallShell) {
      for (const [, g] of this.mallShell.unitGroups) if (g.parent?.visible !== false) objs.push(g);
      objs.push(this.mallShell.f0);
    }
    const hits = this.raycaster.intersectObjects(objs, true);
    const res: ReturnType<Game['pick']> = {};
    for (const h of hits) {
      let o: THREE.Object3D | null = h.object;
      let visible = true;
      for (let p: THREE.Object3D | null = o; p; p = p.parent) if (!p.visible) { visible = false; break; }
      if (!visible) continue;
      const ud = o.userData;
      if ((o as THREE.Sprite).isSprite && !ud.fixture) continue;
      if (ud.agent) { res.agent = ud.agent; break; }
      if (ud.litter) { res.litter = ud.litter; break; }
      if (ud.puddle) { res.puddle = ud.puddle; break; }
      if (ud.fixture) { res.fixture = ud.fixture; break; }
      if (ud.connector && this.mall) { res.connector = this.mall.connectors.find((c) => c.def.id === ud.connector); break; }
      if (ud.unit !== undefined && this.mall) { res.unit = this.mall.units[ud.unit]; break; }
      o = null;
    }
    const plane = new THREE.Plane(new THREE.Vector3(0, 1, 0), -(this.viewFloor * FLOOR_H + 0.08));
    const gp = new THREE.Vector3();
    if (this.raycaster.ray.intersectPlane(plane, gp)) res.ground = gp;
    return res;
  }

  select(sel: Selection) {
    this.selection = sel;
    this.emit('select', sel);
  }

  private updateSelectionVisual() {
    const ring = this.overlays.selectRing;
    const s = this.selection;
    if (!s) { ring.visible = false; return; }
    ring.visible = true;
    if (s.kind === 'fixture') {
      const c = s.f.center; ring.position.set(c.x, c.y + 0.12, c.z);
      const sz = Math.max(s.f.fp.fw, s.f.fp.fd) + 0.6; ring.scale.set(sz, 1, sz);
    } else if (s.kind === 'unit') {
      const r = s.u.def.rect; ring.position.set((r.x0 + r.x1) / 2, s.u.def.floor * FLOOR_H + 0.14, (r.z0 + r.z1) / 2);
      const sz = Math.max(r.x1 - r.x0, r.z1 - r.z0); ring.scale.set(sz, 1, sz);
    } else if (s.kind === 'connector') {
      const b = s.c.def.blocked; ring.position.set((b.x0 + b.x1) / 2, s.c.def.from.floor * FLOOR_H + 0.14, (b.z0 + b.z1) / 2); ring.scale.set(4, 1, 4);
    } else {
      const a = s.kind === 'customer' ? s.c : s.kind === 'staff' ? s.s : s.v;
      ring.position.set(a.pos.x, a.pos.y + 0.04, a.pos.z); ring.scale.set(1.1, 1, 1.1);
    }
  }

  private updateBlobs(agents: Agent[]) {
    const seen = new Set<number>();
    for (const a of agents) {
      seen.add(a.id);
      let b = this.blobs.get(a.id);
      if (!b) { b = new THREE.Mesh(this.blobGeo, this.blobMat); b.renderOrder = 1; this.r.scene.add(b); this.blobs.set(a.id, b); }
      b.position.set(a.pos.x, a.pos.y + 0.02, a.pos.z);
      b.visible = a.view.root.visible && !a.hidden;
    }
    for (const [id, b] of this.blobs) if (!seen.has(id)) { b.removeFromParent(); this.blobs.delete(id); }
  }

  setOverlay(mode: 'none' | 'heat' | 'security') {
    this.overlayMode = this.overlayMode === mode ? 'none' : mode;
    this.overlays.heat.visible = this.overlayMode !== 'none';
    if (this.overlayMode === 'heat') this.overlays.updateHeat(this.floorGrid(this.viewFloor).traffic, (i) => { const r = this.floorGrid(this.viewFloor).region[i]; return r === R_IN || r === R_MALL; });
    if (this.overlayMode === 'security') this.overlays.updateSecurity(this.securityMask());
  }
  setHeat(on: boolean) { if (on !== this.heatVisible) this.setOverlay('heat'); }

  private securityMask() {
    const g = this.floorGrid(this.viewFloor);
    const out = new Uint8Array(g.w * g.h);
    for (let i = 0; i < out.length; i++) { const r = g.region[i]; if (r === R_IN || r === R_MALL) out[i] = 1; }
    for (const f of this.fixtures) if (f.def.kind === 'camera' && f.floor === this.viewFloor) for (const i of f.covers) out[i] = 2;
    for (const s of this.staff) if (s.present && !s.hidden && s.floor === this.viewFloor) {
      const R = s.role === 'security' ? 5 : 3;
      for (let dz = -R; dz <= R; dz++) for (let dx = -R; dx <= R; dx++) {
        const x = Math.floor(s.pos.x) + dx, z = Math.floor(s.pos.z) + dz;
        if (!g.inBounds(x, z) || Math.hypot(dx, dz) > R) continue;
        const i = g.idx(x, z); if (out[i]) out[i] = Math.max(out[i], 3);
      }
    }
    return out;
  }
}


export { mat, ROLE_LABEL, floorPos };
