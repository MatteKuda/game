import { MAP_W, MAP_H, SIDEWALK_Z0, SIDEWALK_Z1, FAR_WALK_Z0, FAR_WALK_Z1, type StageLayout } from '../config';

export const R_VOID = 0;
export const R_OUT = 1; // near sidewalk
export const R_IN = 2; // shop interior
export const R_FAR = 3; // far sidewalk (ambient walkers only)

export interface Tile { x: number; z: number }

const SQRT2 = Math.SQRT2;

class MinHeap {
  private items: number[] = [];
  private prio: number[] = [];
  get size() { return this.items.length; }
  push(v: number, p: number) {
    this.items.push(v); this.prio.push(p);
    let i = this.items.length - 1;
    while (i > 0) {
      const pa = (i - 1) >> 1;
      if (this.prio[pa] <= this.prio[i]) break;
      this.swap(i, pa); i = pa;
    }
  }
  pop(): number {
    const top = this.items[0];
    const lv = this.items.pop()!; const lp = this.prio.pop()!;
    if (this.items.length) {
      this.items[0] = lv; this.prio[0] = lp;
      let i = 0; const n = this.items.length;
      for (;;) {
        const l = i * 2 + 1, r = l + 1; let m = i;
        if (l < n && this.prio[l] < this.prio[m]) m = l;
        if (r < n && this.prio[r] < this.prio[m]) m = r;
        if (m === i) break;
        this.swap(i, m); i = m;
      }
    }
    return top;
  }
  private swap(a: number, b: number) {
    [this.items[a], this.items[b]] = [this.items[b], this.items[a]];
    [this.prio[a], this.prio[b]] = [this.prio[b], this.prio[a]];
  }
}

export class Grid {
  readonly w = MAP_W;
  readonly h = MAP_H;
  region = new Uint8Array(MAP_W * MAP_H);
  fixture = new Int32Array(MAP_W * MAP_H); // fixture uid occupying tile (0 = none)
  reserved = new Uint8Array(MAP_W * MAP_H); // tiles that must stay free (door approach)
  traffic = new Float32Array(MAP_W * MAP_H); // decaying heat for overlay
  occupancy = new Uint8Array(MAP_W * MAP_H); // agents per tile (rebuilt each tick)
  doorEdges = new Set<number>(); // index of interior tile whose +z edge is a door
  version = 0;
  layout!: StageLayout;

  idx(x: number, z: number) { return z * this.w + x; }
  inBounds(x: number, z: number) { return x >= 0 && z >= 0 && x < this.w && z < this.h; }

  applyLayout(layout: StageLayout) {
    this.layout = layout;
    this.region.fill(R_VOID);
    for (let z = SIDEWALK_Z0; z < SIDEWALK_Z1; z++) for (let x = 0; x < this.w; x++) this.region[this.idx(x, z)] = R_OUT;
    for (let z = FAR_WALK_Z0; z < FAR_WALK_Z1; z++) for (let x = 0; x < this.w; x++) this.region[this.idx(x, z)] = R_FAR;
    const r = layout.interior;
    for (let z = r.z0; z < r.z1; z++) for (let x = r.x0; x < r.x1; x++) this.region[this.idx(x, z)] = R_IN;
    this.doorEdges.clear();
    this.reserved.fill(0);
    for (const dx of layout.doors) {
      this.doorEdges.add(this.idx(dx, r.z1 - 1));
      this.reserved[this.idx(dx, r.z1 - 1)] = 1;
    }
    this.version++;
  }

  isInterior(x: number, z: number) { return this.inBounds(x, z) && this.region[this.idx(x, z)] === R_IN; }

  walkable(x: number, z: number) {
    if (!this.inBounds(x, z)) return false;
    const i = this.idx(x, z);
    return this.region[i] !== R_VOID && this.fixture[i] === 0;
  }

  /** orthogonal step legality incl. walls (region boundaries) and doors */
  private orthOk(ax: number, az: number, bx: number, bz: number) {
    if (!this.walkable(bx, bz)) return false;
    const ra = this.region[this.idx(ax, az)], rb = this.region[this.idx(bx, bz)];
    if (ra === rb) return true;
    // interior <-> near sidewalk through a door edge (vertical step only)
    if (ax === bx && ((ra === R_IN && rb === R_OUT) || (ra === R_OUT && rb === R_IN))) {
      const inZ = ra === R_IN ? az : bz;
      return bz !== az && this.doorEdges.has(this.idx(ax, inZ)) && Math.abs(az - bz) === 1;
    }
    return false;
  }

  canStep(ax: number, az: number, bx: number, bz: number) {
    const dx = bx - ax, dz = bz - az;
    if (dx === 0 || dz === 0) return this.orthOk(ax, az, bx, bz);
    // diagonal: both orthogonal paths must be clear and all tiles in same region
    if (!this.walkable(bx, bz)) return false;
    const r = this.region[this.idx(ax, az)];
    if (this.region[this.idx(bx, bz)] !== r) return false;
    return this.orthOk(ax, az, ax + dx, az) && this.orthOk(ax, az, ax, az + dz) &&
      this.region[this.idx(ax + dx, az)] === r && this.region[this.idx(ax, az + dz)] === r;
  }

  /** A* path from a to b. `allowEndBlocked` lets goal be a blocked tile (unused normally). */
  findPath(a: Tile, b: Tile, opts: { avoidCrowd?: boolean } = {}): Tile[] | null {
    if (!this.inBounds(a.x, a.z) || !this.inBounds(b.x, b.z)) return null;
    if (!this.walkable(b.x, b.z)) return null;
    const start = this.idx(a.x, a.z), goal = this.idx(b.x, b.z);
    if (start === goal) return [{ ...a }];
    const n = this.w * this.h;
    const g = new Float32Array(n).fill(Infinity);
    const came = new Int32Array(n).fill(-1);
    const closed = new Uint8Array(n);
    const open = new MinHeap();
    g[start] = 0;
    const hfn = (i: number) => {
      const x = i % this.w, z = (i / this.w) | 0;
      const dx = Math.abs(x - b.x), dz = Math.abs(z - b.z);
      return Math.max(dx, dz) + (SQRT2 - 1) * Math.min(dx, dz);
    };
    open.push(start, hfn(start));
    while (open.size) {
      const cur = open.pop();
      if (cur === goal) break;
      if (closed[cur]) continue;
      closed[cur] = 1;
      const cx = cur % this.w, cz = (cur / this.w) | 0;
      for (let dz = -1; dz <= 1; dz++) for (let dx = -1; dx <= 1; dx++) {
        if (!dx && !dz) continue;
        const nx = cx + dx, nz = cz + dz;
        if (!this.inBounds(nx, nz)) continue;
        const ni = this.idx(nx, nz);
        if (closed[ni]) continue;
        // start tile may be inside a fixture (e.g. worker behind counter) - allow leaving
        if (!this.canStep(cx, cz, nx, nz)) continue;
        let cost = dx && dz ? SQRT2 : 1;
        if (opts.avoidCrowd) cost += this.occupancy[ni] * 0.6;
        const ng = g[cur] + cost;
        if (ng < g[ni]) {
          g[ni] = ng; came[ni] = cur;
          open.push(ni, ng + hfn(ni));
        }
      }
    }
    if (came[goal] === -1) return null;
    const out: Tile[] = [];
    let c = goal;
    while (c !== -1) { out.push({ x: c % this.w, z: (c / this.w) | 0 }); if (c === start) break; c = came[c]; }
    out.reverse();
    return out;
  }

  /** BFS distance field from a tile (walk steps) — used for reachability validation */
  reachableFrom(a: Tile): Uint8Array {
    const seen = new Uint8Array(this.w * this.h);
    if (!this.walkable(a.x, a.z)) return seen;
    const q: number[] = [this.idx(a.x, a.z)];
    seen[q[0]] = 1;
    while (q.length) {
      const cur = q.shift()!;
      const cx = cur % this.w, cz = (cur / this.w) | 0;
      const nbs = [[1, 0], [-1, 0], [0, 1], [0, -1]];
      for (const [dx, dz] of nbs) {
        const nx = cx + dx, nz = cz + dz;
        if (!this.inBounds(nx, nz)) continue;
        const ni = this.idx(nx, nz);
        if (seen[ni]) continue;
        if (!this.canStep(cx, cz, nx, nz)) continue;
        seen[ni] = 1; q.push(ni);
      }
    }
    return seen;
  }
}
