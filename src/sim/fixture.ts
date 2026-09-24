import * as THREE from 'three';
import type { FixtureDef } from '../data/fixtures';
import type { Tile } from './grid';
import { buildFixtureModel, priceTagMaterial, type FixtureModel } from '../world/props';
import { iconMaterial, type IconKind } from '../world/icons';
import { FLOOR_H } from '../config';

export interface Slot { productId: string | null; stock: number; claimed: number }

export interface Footprint { fw: number; fd: number; tiles: Tile[]; access: Tile[]; back: Tile[] }

export function footprint(def: FixtureDef, x: number, z: number, rot: number): Footprint {
  const odd = rot % 2 === 1;
  const fw = odd ? def.d : def.w, fd = odd ? def.w : def.d;
  const tiles: Tile[] = [];
  for (let dz = 0; dz < fd; dz++) for (let dx = 0; dx < fw; dx++) tiles.push({ x: x + dx, z: z + dz });
  const access: Tile[] = [], back: Tile[] = [];
  switch (rot) {
    case 0: for (let i = 0; i < fw; i++) { access.push({ x: x + i, z: z + fd }); back.push({ x: x + i, z: z - 1 }); } break;
    case 1: for (let i = 0; i < fd; i++) { access.push({ x: x + fw, z: z + fd - 1 - i }); back.push({ x: x - 1, z: z + fd - 1 - i }); } break;
    case 2: for (let i = 0; i < fw; i++) { access.push({ x: x + fw - 1 - i, z: z - 1 }); back.push({ x: x + fw - 1 - i, z: z + fd }); } break;
    case 3: for (let i = 0; i < fd; i++) { access.push({ x: x - 1, z: z + i }); back.push({ x: x + fw, z: z + i }); } break;
  }
  return { fw, fd, tiles, access, back };
}

let nextUid = 1;

export class Fixture {
  uid = nextUid++;
  slots: Slot[] = [];
  model: FixtureModel;
  obj = new THREE.Group();
  tags: THREE.Mesh[] = [];
  status: THREE.Sprite;
  statusKind: IconKind | null = null;
  fp!: Footprint;
  queue: import('./agents').Customer[] = []; // registers only
  queueSlots: Tile[] = [];
  cashier: import('./staff').Staff | null = null;
  highlight = 0;
  claimed = 0; // staff id working on it (tables, ovens)
  dirty = false; // food-court table needs clearing
  baking = 0;
  seatsUsed: (object | null)[] = [];
  covers = new Set<number>(); // camera: tile indices within the view cone
  alarmT = 0;
  brokenT = 0;

  constructor(public def: FixtureDef, public x: number, public z: number, public rot: number, public floor = 0) {
    this.model = buildFixtureModel(def);
    this.obj.add(this.model.root);
    for (let i = 0; i < (def.slots ?? 0); i++) this.slots.push({ productId: null, stock: 0, claimed: 0 });
    this.model.slots.forEach((s, i) => {
      const tag = new THREE.Mesh(new THREE.PlaneGeometry(0.2, 0.1), priceTagMaterial(null, 'none'));
      tag.position.copy(s.tag).add(new THREE.Vector3(0, 0, 0.012));
      tag.userData.slot = i;
      this.model.root.add(tag); this.tags.push(tag);
    });
    this.status = new THREE.Sprite(iconMaterial('empty', 'badge'));
    this.status.scale.set(0.62, 0.62, 1);
    this.status.visible = false; this.status.renderOrder = 15;
    this.status.position.y = this.model.height + 0.55;
    this.obj.add(this.status);
    this.obj.traverse((o) => { o.userData.fixture = this; });
    if (this.model.seats) this.seatsUsed = this.model.seats.map(() => null);
    this.place(x, z, rot);
  }

  place(x: number, z: number, rot: number) {
    this.x = x; this.z = z; this.rot = rot;
    this.fp = footprint(this.def, x, z, rot);
    this.obj.position.set(x + this.fp.fw / 2, this.floor * FLOOR_H + 0.08, z + this.fp.fd / 2);
    this.obj.rotation.y = rot * Math.PI / 2;
    this.obj.updateMatrixWorld(true);
  }

  get center() { return new THREE.Vector3(this.x + this.fp.fw / 2, this.floor * FLOOR_H, this.z + this.fp.fd / 2); }
  seatWorld(i: number) {
    const s = this.model.seats?.[i]; if (!s) return this.center;
    return s.clone().applyMatrix4(this.model.root.matrixWorld);
  }
  get isDisplay() { return this.def.kind === 'display'; }

  cap() { return this.def.slotCapacity ?? 0; }

  setStatus(kind: IconKind | null) {
    if (kind === this.statusKind) return;
    this.statusKind = kind;
    this.status.visible = !!kind;
    if (kind) this.status.material = iconMaterial(kind, 'badge');
  }

  refreshTags(prices: Record<string, number>, sale: Set<string> = new Set()) {
    this.slots.forEach((s, i) => {
      const tag = this.tags[i]; if (!tag) return;
      const cap = this.cap();
      const onSale = !!s.productId && sale.has(s.productId);
      const state = !s.productId ? 'none' : s.stock === 0 ? 'empty' : onSale ? 'sale' : s.stock / cap < 0.34 ? 'low' : 'ok';
      tag.material = priceTagMaterial(s.productId ? (onSale ? Math.round(prices[s.productId] * 0.85) : prices[s.productId]) : null, state);
    });
  }

  /** world matrices of visible product units per product id */
  collectUnits(pid: string, out: THREE.Matrix4[]) {
    this.slots.forEach((s, i) => {
      if (s.productId !== pid || s.stock <= 0) return;
      const lay = this.model.slots[i]; if (!lay) return;
      const n = Math.min(s.stock, lay.units.length);
      for (let k = 0; k < n; k++) out.push(new THREE.Matrix4().multiplyMatrices(this.model.root.matrixWorld, lay.units[k]));
    });
  }

  setDepotFill(f: number) {
    const boxes = this.model.depotBoxes; if (!boxes) return;
    const n = Math.ceil(f * boxes.length);
    boxes.forEach((b, i) => { b.visible = i < n; });
  }
}
