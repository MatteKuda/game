import * as THREE from 'three';
import { MAP_W, DAY_OPEN, DAY_CLOSE, MIN_PER_SEC, STAGE_LAYOUTS, ROAD_Z0, SIDEWALK_Z0, FAR_WALK_Z0 } from './config';
import { Grid, R_IN, type Tile } from './sim/grid';
import { Fixture, footprint } from './sim/fixture';
import { buildFixtureModel } from './world/props';
import { Customer, Staff, type Role, ROLE_LABEL, tileCenter } from './sim/agents';
import { FIXTURE_MAP, type FixtureDef } from './data/fixtures';
import { PRODUCTS, PRODUCT_MAP } from './data/products';
import { ARCHETYPES } from './data/customers';
import { STAGES, UPGRADES, EXPANSION } from './data/stages';
import { Renderer } from './world/renderer';
import { CameraRig } from './world/cameraRig';
import { Environment } from './world/environment';
import { ShopShell } from './world/building';
import { Overlays, litterMesh } from './world/overlays';
import { ProductInstancer, initProductVisuals } from './world/products3d';
import { initMaterials, mat } from './world/materials';
import { blobTexture } from './world/textures';
import { sfx } from './ui/sfx';
import type { IconKind } from './world/icons';
import { TURKISH_NAMES } from './config';

export interface Litter { tile: Tile; obj: THREE.Object3D; claimed: number }
export interface Order { pid: string; qty: number; eta: number }
export interface AlertMsg { id: number; key: string; icon: IconKind; text: string; severity: 'info' | 'warn' | 'bad' | 'good'; focus?: THREE.Vector3; t: number }
export interface DayStats {
  revenue: number; purchases: number; wages: number; rent: number; other: number;
  visitors: number; served: number; happyServed: number; lost: number; abandoned: number; impulse: number;
  moodSum: number; moodN: number;
  soldBy: Record<string, number>; missed: Record<string, number>; tooExpensive: Record<string, number>; lostReasons: Record<string, number>;
}
export interface Candidate { role: Role; name: string; wage: number; skill: number }

export type Selection = { kind: 'fixture'; f: Fixture } | { kind: 'customer'; c: Customer } | { kind: 'staff'; s: Staff } | null;

const newStats = (): DayStats => ({
  revenue: 0, purchases: 0, wages: 0, rent: 0, other: 0, visitors: 0, served: 0, happyServed: 0, lost: 0, abandoned: 0, impulse: 0,
  moodSum: 0, moodN: 0, soldBy: {}, missed: {}, tooExpensive: {}, lostReasons: {},
});

type Listener = (...a: any[]) => void;

export class Game {
  r: Renderer;
  cam: CameraRig;
  env!: Environment;
  shell!: ShopShell;
  overlays!: Overlays;
  instancer!: ProductInstancer;
  grid = new Grid();

  stage = 0;
  money = 6500;
  day = 1;
  clock = DAY_OPEN; // minutes of day
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
  upgrades = new Set<string>();
  stats = newStats();
  totals = { served: 0, happyServed: 0, revenue: 0, visitors: 0 };
  history: { day: number; revenue: number; costs: number; profit: number; rating: number }[] = [];
  candidates: Candidate[] = [];
  alerts: AlertMsg[] = [];
  selection: Selection = null;
  heatVisible = false;
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
  van = { state: 'idle' as 'idle' | 'arriving' | 'unloading' | 'leaving', x: -30, t: 0, cargo: [] as Order[] };
  realTime = 0;

  // placement
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

  init() {
    const scene = this.r.scene;
    this.env = new Environment(scene);
    this.grid.applyLayout(STAGE_LAYOUTS[0]);
    this.applyEnvBlocks();
    this.shell = new ShopShell(scene, STAGE_LAYOUTS[0], 0, this.upgrades);
    this.setFocusPoints();
    this.overlays = new Overlays(scene);
    this.instancer = new ProductInstancer(scene, (pid, out) => { for (const f of this.fixtures) f.collectUnits(pid, out); });
    for (const p of PRODUCTS) { this.prices[p.id] = p.basePrice; this.auto[p.id] = true; this.backstock[p.id] = 0; }
    // starter layout
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
    // a few pedestrians so the street is alive from frame one
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
  isOpen() { return this.clock >= DAY_OPEN && this.clock < DAY_CLOSE; }
  customersInside() { return this.customers.filter((c) => c.inside).length; }
  maxInside() { return this.stage === 0 ? 11 : 28; }
  hasRole(r: Role) { return this.staff.some((s) => s.role === r); }
  patienceMul() { const plants = this.fixtures.filter((f) => f.def.kind === 'plant').length; return 1 + Math.min(0.25, plants * 0.06); }
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
  hour() { return this.clock / 60; }
  get absMinutes() { return this.day * 1440 + this.clock; }

  binNear(t: Tile) { return this.fixtures.some((f) => f.def.kind === 'bin' && f.center.distanceTo(new THREE.Vector3(t.x + 0.5, 0, t.z + 0.5)) <= (f.def.binRadius ?? 0)); }
  plantNear(t: Tile) { return this.fixtures.some((f) => f.def.kind === 'plant' && f.center.distanceTo(new THREE.Vector3(t.x + 0.5, 0, t.z + 0.5)) <= 2.6); }
  litterNear(t: Tile, r: number) { return this.litter.some((l) => Math.hypot(l.tile.x - t.x, l.tile.z - t.z) <= r); }

  goals() {
    return EXPANSION.goals.map((g) => {
      const v = g.id === 'rating' ? this.rating : g.id === 'served' ? this.totals.happyServed : this.money;
      return { ...g, value: v, done: v >= g.target };
    });
  }
  canExpand() { return this.stage === 0 && this.goals().every((g) => g.done); }

  // ---------------------------------------------------------------- fixtures
  addFixture(def: FixtureDef, x: number, z: number, rot: number) {
    const f = new Fixture(def, x, z, rot);
    this.fixtures.push(f);
    this.r.scene.add(f.obj);
    for (const t of f.fp.tiles) this.grid.fixture[this.grid.idx(t.x, t.z)] = f.uid;
    this.grid.version++;
    this.layoutChanged();
    return f;
  }

  removeFixture(f: Fixture) {
    for (const t of f.fp.tiles) this.grid.fixture[this.grid.idx(t.x, t.z)] = 0;
    f.obj.removeFromParent();
    this.fixtures.splice(this.fixtures.indexOf(f), 1);
    for (const s of f.slots) if (s.productId && s.stock) this.backstock[s.productId] += s.stock;
    for (const c of [...f.queue]) c.pickRegister(this);
    if (f.cashier) { f.cashier.register = null; f.cashier.goal = null; }
    for (const s of this.staff) if (s.task && s.task.kind === 'restock' && (s.task.fixture === f || s.task.depot === f)) s.cancelTask(this);
    this.grid.version++;
    this.layoutChanged();
  }

  layoutChanged() {
    // recompute register queue lanes: from service tile towards nearest door, then out onto the sidewalk
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
      if (best) for (let i = 0; i < 4; i++) slots.push({ x: last.x + (i === 0 ? 0 : i), z: L.interior.z1 + (i === 0 ? 0 : 0) });
      f.queueSlots = slots.filter((t, i, arr) => arr.findIndex((o) => o.x === t.x && o.z === t.z) === i && this.grid.walkable(t.x, t.z));
    }
    this.instancer?.markDirty();
    this.refreshAll();
    this.emit('layout');
  }

  refreshAll() {
    for (const f of this.fixtures) f.refreshTags(this.prices);
    this.depotChanged();
    this.instancer?.markDirty();
  }

  stockChanged(f: Fixture) { f.refreshTags(this.prices); this.instancer.markDirty(); }
  depotChanged() {
    const cap = this.depotCapacity();
    const fill = cap ? Math.min(1, this.backstockTotal() / cap) : 0;
    for (const f of this.fixtures) if (f.def.kind === 'depot') f.setDepotFill(fill);
  }

  validate(def: FixtureDef, x: number, z: number, rot: number, ignore: Fixture | null): { ok: boolean; reason: string } {
    const fp = footprint(def, x, z, rot);
    const g = this.grid;
    for (const t of fp.tiles) {
      if (!g.isInterior(t.x, t.z)) return { ok: false, reason: 'Dükkânın içine yerleştirilmeli' };
      const occ = g.fixture[g.idx(t.x, t.z)];
      if (occ && occ !== ignore?.uid) return { ok: false, reason: 'Başka bir eşyanın üstüne gelemez' };
      if (g.reserved[g.idx(t.x, t.z)]) return { ok: false, reason: 'Kapı girişi boş kalmalı' };
    }
    const needsAccess = def.kind === 'display' || def.kind === 'register' || def.kind === 'depot';
    const tileSet = new Set(fp.tiles.map((t) => g.idx(t.x, t.z)));
    const accFree = (t: Tile) => g.isInterior(t.x, t.z) && !tileSet.has(g.idx(t.x, t.z)) && (!g.fixture[g.idx(t.x, t.z)] || g.fixture[g.idx(t.x, t.z)] === ignore?.uid);
    if (needsAccess && !fp.access.some(accFree)) return { ok: false, reason: 'Önü açık olmalı (erişim alanı)' };
    if (def.kind === 'register') {
      if (!accFree(fp.access[0])) return { ok: false, reason: 'Kasanın müşteri tarafı boş olmalı' };
      if (!accFree(fp.back[0])) return { ok: false, reason: 'Kasiyerin arkada duracağı yer yok' };
    }
    const maxc = def.maxCount?.[this.stage];
    if (maxc !== undefined && !ignore && this.fixtures.filter((f) => f.def.id === def.id).length >= maxc) return { ok: false, reason: `Bu aşamada en fazla ${maxc} adet` };
    // reachability check with tentative placement
    const saved: [number, number][] = [];
    if (ignore) for (const t of ignore.fp.tiles) { saved.push([g.idx(t.x, t.z), g.fixture[g.idx(t.x, t.z)]]); g.fixture[g.idx(t.x, t.z)] = 0; }
    for (const t of fp.tiles) { saved.push([g.idx(t.x, t.z), g.fixture[g.idx(t.x, t.z)]]); g.fixture[g.idx(t.x, t.z)] = -1; }
    const L = g.layout;
    const reach = g.reachableFrom({ x: L.doors[0], z: L.interior.z1 - 1 });
    let ok = true, reason = '';
    const check = (t: Tile, what: string) => { if (ok && !reach[g.idx(t.x, t.z)]) { ok = false; reason = `${what} ulaşılamaz hâle gelir`; } };
    const others = this.fixtures.filter((f) => f !== ignore);
    for (const f of others) {
      if (f.def.kind === 'display' || f.def.kind === 'depot' || f.def.kind === 'register') {
        if (!f.fp.access.some((t) => g.walkable(t.x, t.z) && reach[g.idx(t.x, t.z)])) check(f.fp.access[0], f.def.name);
        if (f.def.kind === 'register') check(f.fp.back[0], 'Kasiyer yeri');
      }
    }
    if (needsAccess && ok && !fp.access.some((t) => g.walkable(t.x, t.z) && reach[g.idx(t.x, t.z)])) { ok = false; reason = 'Bu konuma yol yok'; }
    for (const dx of L.doors) if (ok && !reach[g.idx(dx, L.interior.z1 - 1)]) { ok = false; reason = 'Kapılardan biri kapanıyor'; }
    for (let i = saved.length - 1; i >= 0; i--) g.fixture[saved[i][0]] = saved[i][1];
    return { ok, reason };
  }

  // placement flow ----------------------------------------------------------
  startPlacement(defId: string, moving: Fixture | null = null) {
    this.cancelPlacement();
    const def = FIXTURE_MAP[defId];
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
    const fp0 = footprint(p.def, 0, 0, p.rot);
    const x = anchored ? cx : cx - Math.floor((fp0.fw - 1) / 2), z = anchored ? cz : cz - Math.floor((fp0.fd - 1) / 2);
    p.x = x; p.z = z;
    const fp = footprint(p.def, x, z, p.rot);
    const v = this.validate(p.def, x, z, p.rot, p.moving);
    const afford = p.moving ? true : this.money >= p.def.cost;
    p.valid = v.ok && afford;
    p.reason = !v.ok ? v.reason : !afford ? 'Yeterli para yok' : '';
    p.ghost.position.set(x + fp.fw / 2, 0.08, z + fp.fd / 2);
    p.ghost.rotation.y = p.rot * Math.PI / 2;
    const col = p.valid ? 0x5ad19a : 0xe5484d;
    p.ghost.traverse((o) => { const m = o as THREE.Mesh; if (m.isMesh) { (m.material as THREE.MeshStandardMaterial).color.setHex(col); (m.material as THREE.MeshStandardMaterial).emissive.setHex(col); } });
    // tile marks: footprint + access tiles
    p.marks.clear();
    const tileGeo = new THREE.PlaneGeometry(0.92, 0.92).rotateX(-Math.PI / 2);
    for (const t of fp.tiles) { const m = new THREE.Mesh(tileGeo, new THREE.MeshBasicMaterial({ color: col, transparent: true, opacity: 0.35, depthWrite: false })); m.position.set(t.x + 0.5, 0.11, t.z + 0.5); p.marks.add(m); }
    if (p.def.kind !== 'plant' && p.def.kind !== 'bin') for (const t of fp.access) { const m = new THREE.Mesh(tileGeo, new THREE.MeshBasicMaterial({ color: 0x61b3ff, transparent: true, opacity: 0.3, depthWrite: false })); m.position.set(t.x + 0.5, 0.11, t.z + 0.5); p.marks.add(m); }
    if (p.def.kind === 'register') { const t = fp.back[0]; const m = new THREE.Mesh(tileGeo, new THREE.MeshBasicMaterial({ color: 0xf2b33d, transparent: true, opacity: 0.35, depthWrite: false })); m.position.set(t.x + 0.5, 0.11, t.z + 0.5); p.marks.add(m); }
    this.emit('placingUpdate', p);
  }

  confirmPlacement(keep = false) {
    const p = this.placing; if (!p || !p.valid) { sfx.play('error'); return; }
    if (p.moving) {
      const f = p.moving;
      for (const t of f.fp.tiles) this.grid.fixture[this.grid.idx(t.x, t.z)] = 0;
      f.place(p.x, p.z, p.rot);
      for (const t of f.fp.tiles) this.grid.fixture[this.grid.idx(t.x, t.z)] = f.uid;
      f.obj.visible = true;
      this.grid.version++;
      this.layoutChanged();
      p.moving = null;
      this.cancelPlacement();
      this.select({ kind: 'fixture', f });
    } else {
      this.money -= p.def.cost;
      this.stats.other += p.def.cost;
      const f = this.addFixture(p.def, p.x, p.z, p.rot);
      this.overlays.floatText(f.center.setY(2), `−₺${p.def.cost}`, '#e0663c');
      if (!keep) { this.cancelPlacement(); this.select({ kind: 'fixture', f }); }
      else this.updatePlacement(p.x, p.z, true);
    }
    sfx.play('place');
  }

  sellFixture(f: Fixture) {
    const refund = Math.round(f.def.cost * 0.5);
    this.money += refund;
    this.removeFixture(f);
    this.overlays.floatText(f.center.setY(1.5), `+₺${refund}`, '#1f8a86');
    if (this.selection?.kind === 'fixture' && this.selection.f === f) this.select(null);
    sfx.play('coin');
  }

  assignSlot(f: Fixture, i: number, pid: string | null) {
    const s = f.slots[i];
    if (s.productId && s.stock) this.backstock[s.productId] += s.stock;
    s.productId = pid; s.stock = 0; s.claimed = 0;
    for (const st of this.staff) if (st.task && st.task.kind === 'restock' && st.task.fixture === f && st.task.slot === i) st.cancelTask(this);
    // instant top-up from backroom if the owner is right there feels good; keep realistic: staff will restock
    this.stockChanged(f);
    this.emit('changed');
  }

  setPrice(pid: string, price: number) {
    this.prices[pid] = Math.max(1, Math.round(price));
    for (const f of this.fixtures) if (f.slots.some((s) => s.productId === pid)) f.refreshTags(this.prices);
    this.emit('changed');
  }

  order(pid: string, qty: number, auto = false): boolean {
    const p = PRODUCT_MAP[pid];
    const room = this.depotCapacity() - this.backstockTotal() - this.incomingTotal();
    if (room <= 0) { if (!auto) this.alert('depofull', 'box', 'Depo dolu — sipariş verilemedi. Depo rafı ekleyin.', 'warn'); return false; }
    qty = Math.min(qty, room);
    const cost = qty * p.cost;
    if (this.money < cost) { this.alert('nomoney', 'wallet', 'Sipariş için yeterli nakit yok.', 'bad'); return false; }
    this.money -= cost;
    this.stats.purchases += cost;
    // arrives ~50 game-minutes later (next morning if the shop is closed)
    let eta = this.absMinutes + 50;
    if (this.clock + 50 >= DAY_CLOSE) eta = (this.day + 1) * 1440 + DAY_OPEN + 20;
    this.orders.push({ pid, qty, eta });
    if (!auto) sfx.play('click');
    this.emit('changed');
    return true;
  }

  // staff -------------------------------------------------------------------
  rollCandidates() {
    const roles: Role[] = this.stage >= 1 ? ['stocker', 'cashier', 'cleaner'] : ['stocker', 'stocker', 'cashier'];
    this.candidates = roles.map((role) => {
      const skill = 0.85 + Math.random() * 0.35;
      const base = role === 'stocker' ? 260 : role === 'cashier' ? 300 : 230;
      return { role, name: TURKISH_NAMES[(Math.random() * TURKISH_NAMES.length) | 0], wage: Math.round(base * (0.8 + skill * 0.3) / 10) * 10, skill };
    });
  }

  hire(c: Candidate, free = false) {
    const s = new Staff(c.role, c.name, c.wage);
    s.skill = c.skill;
    const L = this.grid.layout;
    s.pos.set(L.doors[0] + 0.5, 0.08, L.interior.z1 - 0.5);
    this.staff.push(s);
    this.r.scene.add(s.view.root);
    if (!free) {
      this.candidates.splice(this.candidates.indexOf(c), 1);
      this.overlays.floatText(s.pos.clone().setY(2.2), `${ROLE_LABEL[c.role]} işe başladı`, '#1f8a86', '#ffffff', 2.2);
      sfx.play('place');
    }
    this.emit('changed');
    return s;
  }

  fire(s: Staff) {
    if (s.role === 'owner') return;
    s.cancelTask(this);
    for (const f of this.fixtures) if (f.cashier === s) f.cashier = null;
    this.staff.splice(this.staff.indexOf(s), 1);
    s.view.dispose();
    if (this.selection?.kind === 'staff' && this.selection.s === s) this.select(null);
    this.emit('changed');
  }

  findRestockTask(st: Staff, threshold: number) {
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
    st.goal = null;
    return { kind: 'restock' as const, fixture: b.f, slot: b.i, pid: s.productId!, qty: Math.min(b.f.cap() - s.stock, 16), depot, phase: 'toDepot' as const };
  }

  findCleanTask(st: Staff) {
    const free = this.litter.filter((l) => !l.claimed);
    if (!free.length) return null;
    free.sort((a, b) => Math.hypot(a.tile.x - st.pos.x, a.tile.z - st.pos.z) - Math.hypot(b.tile.x - st.pos.x, b.tile.z - st.pos.z));
    free[0].claimed = st.id;
    st.goal = null;
    return { kind: 'clean' as const, litter: free[0], phase: 'go' as const };
  }

  // litter --------------------------------------------------------------------
  dropLitter(t: Tile) {
    if (!this.grid.isInterior(t.x, t.z) || this.litter.length > 24) return;
    if (this.litter.some((l) => l.tile.x === t.x && l.tile.z === t.z)) return;
    const obj = litterMesh();
    obj.position.set(t.x + 0.3 + Math.random() * 0.4, 0, t.z + 0.3 + Math.random() * 0.4);
    const L: Litter = { tile: { ...t }, obj, claimed: 0 };
    obj.traverse((o) => { o.userData.litter = L; });
    this.r.scene.add(obj);
    this.litter.push(L);
    if (this.litter.length >= 4) this.alert('litter', 'dirty', `Yerde ${this.litter.length} çöp var — müşteriler rahatsız. Çöpe tıklayarak temizleyebilirsin.`, 'warn', obj.position.clone(), 60);
  }

  removeLitter(L: Litter) {
    L.obj.removeFromParent();
    this.litter.splice(this.litter.indexOf(L), 1);
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
    this.rating += (stars - this.rating) * 0.045;
    if (paid) {
      this.stats.served++; this.totals.served++;
      if (c.mood >= 60) { this.stats.happyServed++; this.totals.happyServed++; }
    } else {
      this.stats.lost++;
    }
    this.emit('visit', c);
  }

  // spawning ------------------------------------------------------------------
  private attract() {
    let a = 0.55 + (this.rating / 5) * 0.75;
    if (this.upgrades.has('neon')) a *= this.hour() > 18 ? 1.45 : 1.15;
    if (this.upgrades.has('tente')) a *= 1.1;
    if (this.stage >= 1) a *= 1.3;
    return a;
  }

  private spawnWalker(anywhere = false, far = false) {
    const c = new Customer(null, false, this);
    const fromLeft = Math.random() < 0.5;
    const z = far ? FAR_WALK_Z0 + (Math.random() < 0.5 ? 0 : 1) : SIDEWALK_Z0 + ((Math.random() * 3) | 0);
    let x = fromLeft ? 0 : MAP_W - 1;
    if (anywhere) x = 1 + Math.floor(Math.random() * (MAP_W - 2));
    if (!this.grid.walkable(x, z)) return;
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
    const weights = pool.map((a) => a.hourCurve(h));
    const tot = weights.reduce((a, b) => a + b, 0);
    let r = Math.random() * tot, i = 0;
    for (; i < pool.length; i++) { r -= weights[i]; if (r <= 0) break; }
    const arch = pool[Math.min(i, pool.length - 1)];
    const c = new Customer(arch, true, this);
    const fromLeft = Math.random() < 0.5;
    const z = SIDEWALK_Z0 + ((Math.random() * 3) | 0);
    const x = fromLeft ? 0 : MAP_W - 1;
    if (!this.grid.walkable(x, z)) return;
    c.pos.set(x + 0.5, 0.08, z + 0.5);
    c.exitX = Math.random() < 0.5 ? 0 : MAP_W - 1;
    // nearest door
    const doors = this.grid.layout.doors;
    c.doorX = doors.reduce((b, d) => (Math.abs(d - x) < Math.abs(b - x) ? d : b), doors[0]);
    c.state = 'toDoor';
    c.goTo(this, { x: c.doorX, z: this.grid.layout.interior.z1 });
    this.customers.push(c);
    this.r.scene.add(c.view.root);
  }

  private demand(h: number) {
    const pool = ARCHETYPES.filter((a) => a.stage <= this.stage);
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
    } else {
      // keep idle animations breathing while paused? freeze instead, but sync view
    }
    const viewDt = running ? realDt * this.speed : 0;
    for (const a of [...this.customers, ...this.staff]) a.syncView(viewDt);
    this.updateBlobs();
    this.overlays.update(realDt);
    this.instancer.update();
    // world
    const camDir = new THREE.Vector3(); this.r.camera.getWorldDirection(camDir);
    const agentPos = [...this.customers, ...this.staff].map((a) => a.pos);
    this.shell.update(realDt, camDir, agentPos, this.cam.farFactor);
    this.r.setTimeOfDay(this.hour(), this.cam.target);
    const night = this.r.night;
    this.shell.setSignLit(night, this.upgrades.has('neon'));
    this.env.update(running ? realDt * Math.min(this.speed, 2) : 0, realDt, night, this.r.camera.position, this.cam.target, this.cam.farFactor);
    this.env.van.position.set(this.van.x, 0, ROAD_Z0 + 1.1);
    // selection ring follows; queue lane + heat map refresh (also while paused)
    this.updateSelectionVisual();
    this.heatAcc += realDt;
    if (this.heatAcc > 0.4) {
      this.heatAcc = 0;
      if (this.heatVisible) this.overlays.updateHeat(this.grid.traffic, (i) => this.grid.region[i] === R_IN);
      const sel = this.selection;
      this.overlays.setQueueLine(sel?.kind === 'fixture' && sel.f.def.kind === 'register' ? sel.f.queueSlots.map((t) => tileCenter(t).setY(0.16)) : null);
    }
    this.r.render();
  }

  private tick(dt: number) {
    const prevClock = this.clock;
    this.clock += dt * MIN_PER_SEC;
    // occupancy
    this.grid.occupancy.fill(0);
    for (const a of [...this.customers, ...this.staff]) {
      const t = a.tile; if (this.grid.inBounds(t.x, t.z)) this.grid.occupancy[this.grid.idx(t.x, t.z)]++;
    }
    for (const c of this.customers) {
      const t = c.tile;
      if (c.shopper && this.grid.inBounds(t.x, t.z) && this.grid.region[this.grid.idx(t.x, t.z)] === R_IN) this.grid.traffic[this.grid.idx(t.x, t.z)] += dt;
    }
    for (let i = 0; i < this.grid.traffic.length; i++) this.grid.traffic[i] *= 1 - 0.004 * dt;

    // spawns
    const h = this.hour();
    this.walkAcc += dt * 0.35;
    while (this.walkAcc > 1) { this.walkAcc -= Math.random() * 2; if (this.customers.length < 60) this.spawnWalker(); }
    this.farAcc += dt * 0.18;
    while (this.farAcc > 1) { this.farAcc -= Math.random() * 2; if (this.customers.length < 60) this.spawnWalker(false, true); }
    if (this.isOpen()) {
      const rate = 0.34 * this.demand(h) * this.attract();
      this.spawnAcc += dt * rate;
      while (this.spawnAcc > 1) { this.spawnAcc -= 1; if (this.customers.length < 70) this.spawnShopper(); }
    }

    for (const c of this.customers) c.update(dt, this);
    for (const s of this.staff) s.update(dt, this);
    for (let i = this.customers.length - 1; i >= 0; i--) {
      const c = this.customers[i];
      if (c.removed) { c.view.dispose(); this.customers.splice(i, 1); const b = this.blobs.get(c.id); if (b) { b.removeFromParent(); this.blobs.delete(c.id); } if (this.selection?.kind === 'customer' && this.selection.c === c) this.select(null); }
    }

    this.updateVan(dt);
    // deliveries
    const due = this.orders.filter((o) => o.eta <= this.absMinutes);
    if (due.length && this.van.state === 'idle') {
      this.van.cargo = due; this.orders = this.orders.filter((o) => !due.includes(o));
      this.van.state = 'arriving'; this.van.x = -32; this.env.van.visible = true;
    }
    // auto re-order every ~30 game minutes
    this.autoAcc += dt * MIN_PER_SEC;
    if (this.autoAcc > 30) {
      this.autoAcc = 0;
      if (this.clock < DAY_CLOSE - 60) for (const p of this.unlockedProducts()) {
        if (!this.auto[p.id] || !this.isStocked(p.id)) continue;
        const cap = this.shelfCap(p.id);
        const have = this.backstock[p.id] + this.incoming(p.id);
        const target = Math.max(12, Math.round(cap * 1.2));
        if (have < target * 0.5) this.order(p.id, Math.ceil((target - have) / 6) * 6, true);
      }
    }
    // status icons & alerts (4Hz)
    this.statusAcc += dt;
    if (this.statusAcc > 0.25) { this.statusAcc = 0; this.updateStatuses(); }

    // day end
    if (prevClock < DAY_CLOSE && this.clock >= DAY_CLOSE) this.alert('closing', 'wait', 'Saat 22:00 — dükkân kapanıyor. Son müşteriler çıkınca gün sonu raporu gelecek.', 'info');
    if (this.clock >= DAY_CLOSE && (this.customersInside() === 0 || this.clock > DAY_CLOSE + 50)) this.endDay();
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
          if (!noBack && !this.hasRole('stocker')) this.alert('needstocker', 'nocashier', 'Kemal Usta kasadan ayrılamıyor, raflar boş kalıyor. Personel panelinden (H) reyon görevlisi al.', 'bad', f.center, 70);
          this.alert('empty:' + s.productId, 'empty', `${PRODUCT_MAP[s.productId!].name} rafta bitti${noBack ? ' ve depoda da yok — sipariş ver!' : '.'}`, noBack ? 'bad' : 'warn', f.center, 50);
        }
      } else if (f.def.kind === 'register') {
        if (!f.cashier || !this.staff.includes(f.cashier)) k = 'nocashier';
        else if (f.queue.length >= 4) k = 'queue';
        if (f.queue.length >= 5) this.alert('queue', 'queue', `Kasada ${f.queue.length} kişilik kuyruk! Kasaya yakın düzen ve hızlı ödeme bekleme süresini düşürür.`, 'warn', f.center, 60);
        if (k === 'nocashier') this.alert('nocashier', 'nocashier', 'Bir kasada kasiyer yok. Personel panelinden kasiyer işe al.', 'bad', f.center, 60);
      } else if (f.def.kind === 'depot') {
        const cap = this.depotCapacity();
        if (cap && this.backstockTotal() + this.incomingTotal() < cap * 0.08) k = 'box';
      }
      f.setStatus(k);
    }
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
          if (o.qty - put > 0) { overflow += (o.qty - put) * PRODUCT_MAP[o.pid].cost; }
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
    // send everyone still inside home
    for (const c of this.customers) if (c.inside) { if (c.register) { const i = c.register.queue.indexOf(c); if (i >= 0) c.register.queue.splice(i, 1); } c.finishVisit(this, false); }
    const wages = this.wagesPerDay();
    const rent = this.rent();
    this.money -= wages + rent;
    this.stats.wages = wages; this.stats.rent = rent;
    const costs = this.stats.purchases + wages + rent + this.stats.other;
    this.history.push({ day: this.day, revenue: this.stats.revenue, costs, profit: this.stats.revenue - costs, rating: this.rating });
    this.dayEnded = true;
    sfx.play('dayend');
    this.emit('dayEnd', { day: this.day, stats: this.stats, costs, rating: this.rating, money: this.money });
  }

  startNextDay() {
    this.day++;
    this.clock = DAY_OPEN;
    this.stats = newStats();
    this.dayEnded = false;
    this.rollCandidates();
    for (let i = 0; i < this.grid.traffic.length; i++) this.grid.traffic[i] *= 0.5;
    // orders scheduled for this morning keep their eta
    this.emit('changed');
  }

  buyUpgrade(id: string) {
    const u = UPGRADES.find((x) => x.id === id)!;
    if (this.upgrades.has(id) || this.money < u.cost) { sfx.play('error'); return; }
    this.money -= u.cost; this.stats.other += u.cost;
    this.upgrades.add(id);
    if (id === 'pos') for (const f of this.fixtures) if (f.model.posDevice) f.model.posDevice.visible = true;
    if (id === 'neon' || id === 'tente') { this.shell.rebuild(this.grid.layout, this.stage); }
    this.overlays.floatText(this.cam.target.clone().setY(3), u.name + '!', '#6c4ab6', '#ffffff', 2.4);
    sfx.play('fanfare');
    this.emit('changed');
  }

  expand() {
    if (!this.canExpand()) { sfx.play('error'); return; }
    this.money -= EXPANSION.cost; this.stats.other += EXPANSION.cost;
    this.stage = 1;
    this.grid.applyLayout(STAGE_LAYOUTS[1]);
    this.applyEnvBlocks();
    for (const f of this.fixtures) for (const t of f.fp.tiles) this.grid.fixture[this.grid.idx(t.x, t.z)] = f.uid;
    this.env.removeNeighbor();
    this.shell.rebuild(STAGE_LAYOUTS[1], 1);
    this.setFocusPoints();
    this.grid.version++;
    this.layoutChanged();
    for (const p of PRODUCTS) if (this.backstock[p.id] === undefined) this.backstock[p.id] = 0;
    this.rollCandidates();
    this.cam.focus(18, 11, 34);
    this.alert('expanded', 'star', 'Mahalle Marketi açıldı! Yeni reyonlar, manav ve aile alışverişçileri seni bekliyor.', 'good', undefined, 0);
    this.overlays.floatText(new THREE.Vector3(18, 4, 12), 'MAHALLE MARKETİ!', '#e0663c', '#fff1dc', 3.5);
    sfx.play('fanfare');
    this.emit('stage', 1);
    this.emit('changed');
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
    for (const [x, z] of this.env.blockedTiles) if (this.grid.inBounds(x, z)) this.grid.region[this.grid.idx(x, z)] = 0;
    this.grid.version++;
  }

  // ---------------------------------------------------------------- picking & selection
  pick(ndc: THREE.Vector2): { fixture?: Fixture; agent?: Customer | Staff; litter?: Litter; ground?: THREE.Vector3 } {
    this.raycaster.setFromCamera(ndc, this.r.camera);
    const objs: THREE.Object3D[] = [];
    for (const f of this.fixtures) objs.push(f.obj);
    for (const c of this.customers) objs.push(c.view.root);
    for (const s of this.staff) objs.push(s.view.root);
    for (const l of this.litter) objs.push(l.obj);
    const hits = this.raycaster.intersectObjects(objs, true);
    const res: ReturnType<Game['pick']> = {};
    for (const h of hits) {
      const ud = h.object.userData;
      if ((h.object as THREE.Sprite).isSprite && !ud.fixture) continue;
      if (ud.agent) { res.agent = ud.agent; break; }
      if (ud.litter) { res.litter = ud.litter; break; }
      if (ud.fixture) { res.fixture = ud.fixture; break; }
    }
    const plane = new THREE.Plane(new THREE.Vector3(0, 1, 0), -0.08);
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
      const c = s.f.center; ring.position.set(c.x, 0.12, c.z);
      const sz = Math.max(s.f.fp.fw, s.f.fp.fd) + 0.6; ring.scale.set(sz, 1, sz);
    } else {
      const a = s.kind === 'customer' ? s.c : s.s;
      ring.position.set(a.pos.x, 0.12, a.pos.z); ring.scale.set(1.1, 1, 1.1);
    }
  }

  private updateBlobs() {
    for (const a of [...this.customers, ...this.staff]) {
      let b = this.blobs.get(a.id);
      if (!b) { b = new THREE.Mesh(this.blobGeo, this.blobMat); b.renderOrder = 1; this.r.scene.add(b); this.blobs.set(a.id, b); }
      b.position.set(a.pos.x, 0.1, a.pos.z);
    }
    for (const [id, b] of this.blobs) if (!this.customers.some((c) => c.id === id) && !this.staff.some((s) => s.id === id)) { b.removeFromParent(); this.blobs.delete(id); }
  }

  setHeat(on: boolean) {
    this.heatVisible = on;
    this.overlays.heat.visible = on;
    if (on) this.overlays.updateHeat(this.grid.traffic, (i) => this.grid.region[i] === R_IN);
  }
}

export { mat, ROLE_LABEL };
