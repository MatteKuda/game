import * as THREE from 'three';
import { FLOOR_H, PAL } from '../config';
import { M, rbox, cyl, sphere, mat, glow } from './materials';
import { addMesh } from './props';
import { canvasTexture, roundRect, mulberry } from './textures';
import { mergeByMaterial } from './merge';
import { CharacterView } from './characters';
import { randomLook } from '../sim/agents';
import type { Mall, UnitState, ConnectorState } from '../sim/mall';
import { MALL_FOOTPRINT, MALL_ENTRANCES, ESCALATOR_WELL, type TenantDef } from '../data/mall';
import type { Rect } from '../config';

interface Side { group: THREE.Group; normal: THREE.Vector3; floor: number; sink: number; extras: THREE.Object3D[] }

function marbleTexture(tint = '#f1ece4') {
  return canvasTexture(512, 512, (ctx, w, h) => {
    ctx.fillStyle = tint; ctx.fillRect(0, 0, w, h);
    const rnd = mulberry(99);
    for (let i = 0; i < 26; i++) {
      ctx.strokeStyle = `rgba(150,140,130,${0.08 + rnd() * 0.12})`; ctx.lineWidth = 0.8 + rnd() * 2;
      let x = rnd() * w, y = rnd() * h; ctx.beginPath(); ctx.moveTo(x, y);
      for (let k = 0; k < 8; k++) { x += (rnd() - 0.3) * 70; y += (rnd() - 0.5) * 50; ctx.lineTo(x, y); }
      ctx.stroke();
    }
    ctx.strokeStyle = 'rgba(90,80,70,0.18)'; ctx.lineWidth = 2;
    for (let i = 0; i <= 2; i++) { ctx.beginPath(); ctx.moveTo(i * w / 2, 0); ctx.lineTo(i * w / 2, h); ctx.stroke(); ctx.beginPath(); ctx.moveTo(0, i * h / 2); ctx.lineTo(w, i * h / 2); ctx.stroke(); }
  });
}

function textPanel(text: string, sub: string, bg: string, fg: string, accent: string, w = 1024, h = 256) {
  const t = canvasTexture(w, h, (ctx) => {
    ctx.fillStyle = bg; roundRect(ctx, 0, 0, w, h, h * 0.12); ctx.fill();
    ctx.strokeStyle = accent; ctx.lineWidth = h * 0.04; roundRect(ctx, h * 0.06, h * 0.08, w - h * 0.12, h - h * 0.16, h * 0.1); ctx.stroke();
    ctx.fillStyle = fg; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.font = `800 ${h * (sub ? 0.42 : 0.5)}px "Baloo 2", system-ui`;
    ctx.fillText(text, w / 2, h * (sub ? 0.42 : 0.54));
    if (sub) { ctx.font = `700 ${h * 0.16}px "Baloo 2", system-ui`; ctx.fillStyle = accent; ctx.fillText(sub, w / 2, h * 0.76); }
  });
  return new THREE.MeshStandardMaterial({ map: t, emissive: 0xffffff, emissiveMap: t, emissiveIntensity: 0.25, roughness: 0.5 });
}

export class MallShell {
  root = new THREE.Group();
  f0 = new THREE.Group();
  f1 = new THREE.Group();
  exterior = new THREE.Group();
  sides: Side[] = [];
  unitGroups = new Map<number, THREE.Group>();
  clerks: CharacterView[] = [];
  escalatorTex: THREE.Texture[] = [];
  liftCab!: THREE.Group;
  barriers = new Map<string, THREE.Group>();
  decorations = new THREE.Group();
  stage = new THREE.Group();
  performer: CharacterView | null = null;
  signMats: THREE.MeshStandardMaterial[] = [];
  arcadeMats: THREE.MeshStandardMaterial[] = [];
  entranceDoors: { x: number; left: THREE.Object3D; right: THREE.Object3D; open: number }[] = [];
  lights: THREE.PointLight[] = [];
  private marble0 = new THREE.MeshStandardMaterial({ map: marbleTexture(), roughness: 0.25 });
  private marble1 = new THREE.MeshStandardMaterial({ map: marbleTexture('#eee6da'), roughness: 0.25 });
  private wallMat = new THREE.MeshStandardMaterial({ color: 0xf4ede2, roughness: 0.85 });
  private cladMat = new THREE.MeshStandardMaterial({ color: 0x2f3a4a, roughness: 0.5, metalness: 0.3 });

  constructor(scene: THREE.Scene, private mall: Mall) {
    scene.add(this.root);
    this.root.add(this.f0, this.f1, this.exterior);
    this.f1.position.y = 0;
    this.buildFloors();
    this.buildWalls();
    this.buildExterior();
    this.buildConnectors();
    this.f1.add(this.decorations);
    this.buildStage();
    for (const u of mall.units) this.rebuildUnit(u);
  }

  // ---------------------------------------------------------------- floors
  private floorPlane(r: Rect, y: number, m: THREE.Material, parent: THREE.Object3D) {
    const w = r.x1 - r.x0, d = r.z1 - r.z0;
    const mm = (m as THREE.MeshStandardMaterial).clone();
    if (mm.map) { mm.map = mm.map.clone(); mm.map.wrapS = mm.map.wrapT = THREE.RepeatWrapping; mm.map.repeat.set(w / 2, d / 2); mm.map.needsUpdate = true; }
    const p = new THREE.Mesh(new THREE.BoxGeometry(w, 0.1, d), mm);
    p.position.set(r.x0 + w / 2, y, r.z0 + d / 2); p.receiveShadow = true;
    parent.add(p);
    return p;
  }

  private buildFloors() {
    // ground floor corridors & unit floors
    for (const r of [{ x0: 2, z0: 0, x1: 10, z1: 16 }, { x0: 34, z0: 0, x1: 42, z1: 16 }, { x0: 10, z0: 0, x1: 34, z1: 4 }]) this.floorPlane(r, 0.03, this.marble0, this.f0);
    // floor-1 slab with the escalator well cut out
    const F = MALL_FOOTPRINT, W = ESCALATOR_WELL;
    const slabs: Rect[] = [
      { x0: F.x0, z0: F.z0, x1: F.x1, z1: W.z0 },
      { x0: F.x0, z0: W.z1, x1: F.x1, z1: F.z1 },
      { x0: F.x0, z0: W.z0, x1: W.x0, z1: W.z1 },
      { x0: W.x1, z0: W.z0, x1: F.x1, z1: W.z1 },
    ];
    for (const r of slabs) {
      const w = r.x1 - r.x0, d = r.z1 - r.z0;
      const under = new THREE.Mesh(new THREE.BoxGeometry(w, 0.3, d), mat(0xe8e2d8, 0.9));
      under.position.set(r.x0 + w / 2, FLOOR_H - 0.17, r.z0 + d / 2); under.receiveShadow = true; under.castShadow = true;
      this.f1.add(under);
      this.floorPlane(r, FLOOR_H - 0.02, this.marble1, this.f1);
    }
    // food court carpet accent
    const fc = new THREE.Mesh(new THREE.PlaneGeometry(16, 6), new THREE.MeshStandardMaterial({ color: 0xe9d5b7, roughness: 0.9 }));
    fc.rotation.x = -Math.PI / 2; fc.position.set(22, FLOOR_H + 0.035, 9.5); fc.receiveShadow = true; this.f1.add(fc);
    // glass railing around the escalator well
    const rail = new THREE.Group();
    const glassM = M.glass;
    const segs: [number, number, number, number][] = [[W.x0, W.z0, W.x1, W.z0], [W.x0, W.z1, W.x1, W.z1], [W.x0, W.z0, W.x0, W.z1]];
    for (const [x0, z0, x1, z1] of segs) {
      const len = Math.hypot(x1 - x0, z1 - z0);
      const g = new THREE.Mesh(new THREE.BoxGeometry(len, 1.0, 0.04), glassM);
      g.position.set((x0 + x1) / 2, FLOOR_H + 0.5, (z0 + z1) / 2); g.rotation.y = x0 === x1 ? Math.PI / 2 : 0; g.renderOrder = 3; rail.add(g);
      const top = addMesh(rail, rbox(len, 0.05, 0.08, 0.02), M.steel, (x0 + x1) / 2, FLOOR_H + 1.02, (z0 + z1) / 2, 0, x0 === x1 ? Math.PI / 2 : 0, 0);
      void top;
    }
    this.f1.add(rail);
  }

  // ---------------------------------------------------------------- walls
  private side(normal: THREE.Vector3, floor: number) {
    const s: Side = { group: new THREE.Group(), normal, floor, sink: 0, extras: [] };
    (floor ? this.f1 : this.f0).add(s.group);
    this.sides.push(s);
    return s;
  }

  private wallSeg(parent: THREE.Object3D, x0: number, z0: number, x1: number, z1: number, y0: number, h: number, material: THREE.Material = this.wallMat, th = 0.22) {
    const len = Math.hypot(x1 - x0, z1 - z0);
    const m = new THREE.Mesh(new THREE.BoxGeometry(x0 === x1 ? th : len + th, h, x0 === x1 ? len + th : th), material);
    m.position.set((x0 + x1) / 2, y0 + h / 2, (z0 + z1) / 2); m.castShadow = true; m.receiveShadow = true;
    parent.add(m);
    return m;
  }

  private buildWalls() {
    const F = MALL_FOOTPRINT;
    const H = FLOOR_H - 0.05;
    for (const fl of [0, 1]) {
      const y0 = fl * FLOOR_H;
      const back = this.side(new THREE.Vector3(0, 0, -1), fl);
      this.wallSeg(back.group, F.x0, F.z0, F.x1, F.z0, y0, H);
      addMesh(back.group, rbox(F.x1 - F.x0, 1.1, 0.03, 0.01), mat(0xd9cfc0, 0.5), (F.x0 + F.x1) / 2, y0 + 0.6, F.z0 + 0.13, 0, 0, 0, false);
      const left = this.side(new THREE.Vector3(-1, 0, 0), fl);
      this.wallSeg(left.group, F.x0, F.z0, F.x0, F.z1, y0, H);
      const right = this.side(new THREE.Vector3(1, 0, 0), fl);
      this.wallSeg(right.group, F.x1, F.z0, F.x1, F.z1, y0, H);
      const front = this.side(new THREE.Vector3(0, 0, 1), fl);
      if (fl === 0) {
        // wing fronts: solid cladding with glass entrances (the supermarket storefront fills x10..34)
        for (const [a, b] of [[F.x0, 10], [34, F.x1]]) {
          for (let x = a; x < b; x++) {
            if (MALL_ENTRANCES.includes(x)) continue;
            this.wallSeg(front.group, x, F.z1, x + 1, F.z1, 0, 0.5, this.cladMat, 0.24);
            const g = new THREE.Mesh(new THREE.PlaneGeometry(0.96, 2.4), M.glass); g.position.set(x + 0.5, 1.7, F.z1); g.renderOrder = 3; front.group.add(g);
            addMesh(front.group, rbox(0.06, 2.4, 0.1, 0.01), mat(PAL.ink, 0.4, 0.3), x + 1, 1.7, F.z1, 0, 0, 0, false);
          }
          this.wallSeg(front.group, a, F.z1, b, F.z1, 2.9, H - 2.9, this.cladMat, 0.26);
        }
        // automatic entrance doors
        for (const x0 of [MALL_ENTRANCES[0], MALL_ENTRANCES[2]]) {
          const mk = (px: number) => {
            const p = new THREE.Group(); p.position.set(px, 0, F.z1 + 0.05);
            const gl = new THREE.Mesh(new THREE.PlaneGeometry(0.95, 2.5), M.glass); gl.position.y = 1.3; gl.renderOrder = 3; p.add(gl);
            addMesh(p, rbox(0.95, 0.06, 0.05, 0.01), mat(PAL.ink, 0.4), 0, 2.55, 0, 0, 0, 0, false);
            p.userData.dynamic = true; front.group.add(p); return p;
          };
          this.entranceDoors.push({ x: x0 + 1, left: mk(x0 + 0.5), right: mk(x0 + 1.5), open: 0 });
          // canopy
          const can = addMesh(front.group, rbox(3, 0.12, 1.6, 0.04), mat(PAL.teal, 0.5), x0 + 1, 3.0, F.z1 + 0.8);
          front.extras.push(can); can.userData.dynamic = true;
          const sign = new THREE.Mesh(new THREE.PlaneGeometry(2.6, 0.5), textPanel('AVM GİRİŞİ', '', '#1f2a44', '#fff1dc', '#f2b33d', 1024, 200));
          sign.position.set(x0 + 1, 3.35, F.z1 + 0.14); sign.userData.dynamic = true; front.group.add(sign); front.extras.push(sign);
          this.signMats.push(sign.material as THREE.MeshStandardMaterial);
        }
      } else {
        // floor-1 glass curtain wall
        for (let x = F.x0; x < F.x1; x++) {
          this.wallSeg(front.group, x, F.z1, x + 1, F.z1, FLOOR_H, 0.9, this.cladMat, 0.24);
          const g = new THREE.Mesh(new THREE.PlaneGeometry(0.97, H - 1.4), M.glass); g.position.set(x + 0.5, FLOOR_H + 0.9 + (H - 1.4) / 2, F.z1); g.renderOrder = 3; front.group.add(g);
          addMesh(front.group, rbox(0.05, H - 1.4, 0.1, 0.01), mat(PAL.ink, 0.4, 0.3), x + 1, FLOOR_H + 0.9 + (H - 1.4) / 2, F.z1, 0, 0, 0, false);
        }
        this.wallSeg(front.group, F.x0, F.z1, F.x1, F.z1, FLOOR_H + H - 0.5, 0.5, this.cladMat, 0.26);
      }
    }
    for (const s of this.sides) { for (const e of s.extras) e.userData.dynamic = true; mergeByMaterial(s.group); }
  }

  // ---------------------------------------------------------------- exterior
  private buildExterior() {
    const F = MALL_FOOTPRINT;
    const top = 2 * FLOOR_H;
    // roof parapet + big sign
    const par = addMesh(this.exterior, rbox(F.x1 - F.x0 + 0.4, 0.5, 0.4, 0.05), this.cladMat, (F.x0 + F.x1) / 2, top + 0.25, F.z1);
    void par;
    for (const x of [F.x0, F.x1]) addMesh(this.exterior, rbox(0.4, 0.5, F.z1 - F.z0, 0.05), this.cladMat, x, top + 0.25, (F.z0 + F.z1) / 2);
    addMesh(this.exterior, rbox(F.x1 - F.x0, 0.5, 0.4, 0.05), this.cladMat, (F.x0 + F.x1) / 2, top + 0.25, F.z0);
    const signM = textPanel('KÖŞEBAŞI AVM', 'ALIŞVERİŞ · YEMEK · EĞLENCE', '#fff1dc', '#e0663c', '#1f8a86', 1024, 256);
    const sign = new THREE.Mesh(new THREE.BoxGeometry(12, 3, 0.3), [this.cladMat, this.cladMat, this.cladMat, this.cladMat, signM, this.cladMat]);
    sign.position.set((F.x0 + F.x1) / 2, top + 1.9, F.z1 - 0.1); sign.castShadow = true;
    this.exterior.add(sign); this.signMats.push(signM);
    for (const x of [-5, 5]) addMesh(this.exterior, rbox(0.15, 1.2, 0.15, 0.02), M.steelDark, (F.x0 + F.x1) / 2 + x, top + 0.3, F.z1 - 0.1);
    // rooftop AC units
    for (let i = 0; i < 5; i++) addMesh(this.exterior, rbox(1.4, 0.8, 1.0, 0.06), mat(0xe8e8e4, 0.5), 6 + i * 7.5, top + 0.4, 5 + (i % 2) * 4);
  }

  // ---------------------------------------------------------------- escalators & lift
  private buildConnectors() {
    const dark = mat(0x3a3f48, 0.5, 0.4), steel = M.steel;
    for (const [z, up] of [[1, true], [2, false]] as [number, boolean][]) {
      const g = new THREE.Group();
      const x0 = 12.6, x1 = 18.2, run = x1 - x0, rise = FLOOR_H;
      const len = Math.hypot(run, rise);
      const ang = Math.atan2(rise, run);
      const t = canvasTexture(64, 64, (ctx, w, h) => {
        ctx.fillStyle = '#6b7079'; ctx.fillRect(0, 0, w, h);
        ctx.fillStyle = '#4a4f58'; for (let i = 0; i < w; i += 6) ctx.fillRect(i, 0, 3, h);
        ctx.fillStyle = '#f2b33d'; ctx.fillRect(0, 0, 4, h); ctx.fillRect(w - 4, 0, 4, h);
        ctx.fillStyle = '#2a2d33'; ctx.fillRect(0, h - 8, w, 8);
      }, { repeat: [1, 14] });
      this.escalatorTex.push(t);
      (t as THREE.Texture & { dir?: number }).dir = up ? 1 : -1;
      const body = new THREE.Group(); body.position.set((x0 + x1) / 2, rise / 2 + 0.05, z + 0.5); body.rotation.z = ang;
      const st = new THREE.Mesh(new THREE.PlaneGeometry(len, 0.9), new THREE.MeshStandardMaterial({ map: t, roughness: 0.6, metalness: 0.3 }));
      (st.material as THREE.MeshStandardMaterial).map!.rotation = Math.PI / 2; (st.material as THREE.MeshStandardMaterial).map!.center.set(0.5, 0.5);
      st.rotation.x = -Math.PI / 2; st.position.y = 0.1; body.add(st);
      addMesh(body, rbox(len + 0.4, 0.45, 1.05, 0.05), dark, 0, -0.18, 0);
      for (const s of [-1, 1]) {
        const glass = new THREE.Mesh(new THREE.BoxGeometry(len, 0.9, 0.03), M.glass); glass.position.set(0, 0.6, s * 0.5); glass.renderOrder = 3; body.add(glass);
        addMesh(body, rbox(len + 0.3, 0.07, 0.1, 0.03), mat(0x1b1d22, 0.6), 0, 1.06, s * 0.5, 0, 0, 0, false);
        addMesh(body, rbox(len, 0.12, 0.1, 0.02), steel, 0, 0.12, s * 0.5, 0, 0, 0, false);
      }
      g.add(body);
      // landing plates
      addMesh(g, rbox(0.9, 0.06, 1.0, 0.02), steel, x0 - 0.35, 0.06, z + 0.5);
      addMesh(g, rbox(0.9, 0.06, 1.0, 0.02), steel, x1 + 0.1, FLOOR_H + 0.03, z + 0.5);
      const arrow = new THREE.Mesh(new THREE.PlaneGeometry(0.5, 0.5), glow(up ? 0x2fae7a : 0xf2b33d, 1.2));
      arrow.rotation.x = -Math.PI / 2; arrow.position.set(up ? x0 - 0.35 : x1 + 0.1, up ? 0.1 : FLOOR_H + 0.07, z + 0.5); g.add(arrow);
      g.userData.connector = up ? 'escUp' : 'escDown';
      g.traverse((o) => { o.userData.connector = g.userData.connector; });
      this.f0.add(g);
      const bar = this.barrier(up ? x0 - 0.4 : x1 + 0.2, up ? 0 : FLOOR_H, z + 0.5);
      this.barriers.set(g.userData.connector, bar);
      (up ? this.f0 : this.f1).add(bar);
    }
    // glass lift
    const lg = new THREE.Group();
    const shaft = new THREE.Mesh(new THREE.BoxGeometry(1.9, 2 * FLOOR_H, 1.9), new THREE.MeshPhysicalMaterial({ color: 0xcfeef0, roughness: 0.05, transparent: true, opacity: 0.18, depthWrite: false }));
    shaft.position.set(29, FLOOR_H, 1); shaft.renderOrder = 3; lg.add(shaft);
    for (const [x, z] of [[28.05, 0.05], [29.95, 0.05], [28.05, 1.95], [29.95, 1.95]]) addMesh(lg, rbox(0.1, 2 * FLOOR_H, 0.1, 0.02), M.steel, x, FLOOR_H, z);
    this.liftCab = new THREE.Group();
    addMesh(this.liftCab, rbox(1.7, 0.1, 1.7, 0.03), M.steelDark, 0, 0.05, 0);
    addMesh(this.liftCab, rbox(1.7, 0.08, 1.7, 0.03), M.steelDark, 0, 2.4, 0);
    addMesh(this.liftCab, rbox(1.6, 2.3, 0.05, 0.02), mat(0xf6efe3, 0.5), 0, 1.2, -0.8);
    const lamp = new THREE.Mesh(new THREE.PlaneGeometry(1.2, 1.2), glow(0xfff1d0, 1.2)); lamp.rotation.x = Math.PI / 2; lamp.position.y = 2.35; this.liftCab.add(lamp);
    this.liftCab.position.set(29, 0, 1);
    lg.add(this.liftCab);
    lg.traverse((o) => { o.userData.connector = 'lift'; });
    this.f0.add(lg);
    const lb = this.barrier(28.5, 0, 2.6); this.barriers.set('lift', lb); this.f0.add(lb);
    for (const s of this.barriers.values()) s.visible = false;
  }

  private barrier(x: number, y: number, z: number) {
    const b = new THREE.Group(); b.position.set(x, y, z);
    const stripe = canvasTexture(128, 32, (ctx, w, h) => { for (let i = 0; i < 8; i++) { ctx.fillStyle = i % 2 ? '#1f2a44' : '#f2b33d'; ctx.beginPath(); ctx.moveTo(i * 16, 0); ctx.lineTo(i * 16 + 16, 0); ctx.lineTo(i * 16 + 8, h); ctx.lineTo(i * 16 - 8, h); ctx.fill(); } });
    addMesh(b, rbox(0.08, 1.0, 0.08, 0.02), M.steelDark, 0, 0.5, -0.6);
    addMesh(b, rbox(0.08, 1.0, 0.08, 0.02), M.steelDark, 0, 0.5, 0.6);
    const tape = new THREE.Mesh(new THREE.BoxGeometry(0.04, 0.16, 1.2), new THREE.MeshStandardMaterial({ map: stripe })); tape.position.y = 0.85; b.add(tape);
    const sign = new THREE.Mesh(new THREE.PlaneGeometry(0.8, 0.35), textPanel('ARIZALI', '', '#e5484d', '#ffffff', '#ffffff', 512, 200));
    sign.position.set(0.05, 1.25, 0); sign.rotation.y = Math.PI / 2; b.add(sign);
    return b;
  }

  // ---------------------------------------------------------------- units
  rebuildUnit(u: UnitState) {
    const old = this.unitGroups.get(u.idx);
    if (old) { old.removeFromParent(); old.traverse((o) => { const c = o.userData.clerk as CharacterView | undefined; if (c) this.clerks.splice(this.clerks.indexOf(c), 1); }); }
    const g = new THREE.Group();
    const r = u.def.rect; const y0 = u.def.floor * FLOOR_H; const H = FLOOR_H - 0.6;
    const t = u.tenant?.def;
    // floor
    const fl = new THREE.Mesh(new THREE.BoxGeometry(r.x1 - r.x0, 0.1, r.z1 - r.z0), mat(t ? shade(t.color, 0.25) : 0xd8d2c8, 0.6));
    fl.position.set((r.x0 + r.x1) / 2, y0 + 0.04, (r.z0 + r.z1) / 2); fl.receiveShadow = true; g.add(fl);
    // partition walls on sides that are not the mall perimeter, storefront on the door side
    const F = MALL_FOOTPRINT;
    const [dx, dz] = u.def.door.dir;
    const edges: { x0: number; z0: number; x1: number; z1: number; dirX: number; dirZ: number }[] = [
      { x0: r.x0, z0: r.z0, x1: r.x1, z1: r.z0, dirX: 0, dirZ: -1 },
      { x0: r.x0, z0: r.z1, x1: r.x1, z1: r.z1, dirX: 0, dirZ: 1 },
      { x0: r.x0, z0: r.z0, x1: r.x0, z1: r.z1, dirX: -1, dirZ: 0 },
      { x0: r.x1, z0: r.z0, x1: r.x1, z1: r.z1, dirX: 1, dirZ: 0 },
    ];
    const wallM = new THREE.MeshStandardMaterial({ color: t ? shade(t.color, 0.12) : 0xf0e9dd, roughness: 0.85 });
    for (const e of edges) {
      const perimeter = (e.x0 === e.x1 && (e.x0 === F.x0 || e.x0 === F.x1)) || (e.z0 === e.z1 && (e.z0 === F.z0 || (e.z0 === F.z1)));
      if (perimeter) continue;
      if (e.dirX === dx && e.dirZ === dz) this.storefront(g, e, u, y0, H);
      else this.wallSeg(g, e.x0, e.z0, e.x1, e.z1, y0, H, wallM, 0.14);
    }
    if (t) this.furnish(g, u, t, y0);
    for (const c of g.children) if (c.userData.clerk) c.userData.dynamic = true;
    mergeByMaterial(g);
    g.userData.unit = u.idx;
    g.traverse((o) => { if (!o.userData.clerk) o.userData.unit = u.idx; });
    (u.def.floor ? this.f1 : this.f0).add(g);
    this.unitGroups.set(u.idx, g);
  }

  private storefront(g: THREE.Group, e: { x0: number; z0: number; x1: number; z1: number }, u: UnitState, y0: number, H: number) {
    const t = u.tenant?.def;
    const horiz = e.z0 === e.z1;
    const len = horiz ? e.x1 - e.x0 : e.z1 - e.z0;
    const doorSet = new Set(u.def.door.tiles.map((d) => (horiz ? d.x : d.z)));
    const frame = mat(PAL.ink, 0.4, 0.3);
    for (let i = 0; i < len; i++) {
      const a = (horiz ? e.x0 : e.z0) + i;
      const cx = horiz ? a + 0.5 : e.x0, cz = horiz ? e.z0 : a + 0.5;
      if (doorSet.has(a)) continue;
      if (t) {
        const gl = new THREE.Mesh(new THREE.PlaneGeometry(0.96, 2.5), M.glass); gl.position.set(cx, y0 + 1.35, cz); if (!horiz) gl.rotation.y = Math.PI / 2; gl.renderOrder = 3; g.add(gl);
        addMesh(g, rbox(horiz ? 0.96 : 0.14, 0.3, horiz ? 0.14 : 0.96, 0.02), mat(parseInt(t.color.slice(1), 16), 0.5), cx, y0 + 0.15, cz, 0, 0, 0, false);
      } else {
        const sh = new THREE.Mesh(new THREE.BoxGeometry(horiz ? 0.98 : 0.06, 2.6, horiz ? 0.06 : 0.98), shutterMat());
        sh.position.set(cx, y0 + 1.3, cz); g.add(sh);
      }
      addMesh(g, rbox(horiz ? 0.05 : 0.1, 2.6, horiz ? 0.1 : 0.05, 0.01), frame, horiz ? a + 1 : cx, y0 + 1.3, horiz ? cz : a + 1, 0, 0, 0, false);
    }
    // fascia band + sign
    const bandLen = len;
    const bx = horiz ? (e.x0 + e.x1) / 2 : e.x0, bz = horiz ? e.z0 : (e.z0 + e.z1) / 2;
    addMesh(g, rbox(horiz ? bandLen : 0.2, H - 2.6, horiz ? 0.2 : bandLen, 0.02), mat(t ? parseInt(t.color.slice(1), 16) : 0xcfc6b8, 0.6), bx, y0 + 2.6 + (H - 2.6) / 2, bz, 0, 0, 0, true);
    const signM = t ? textPanel(t.brand, t.name.toUpperCase(), t.color, '#ffffff', t.accent, 1024, 256) : textPanel('KİRALIK', 'KİRACI PANELİNDEN SEÇ', '#fff1dc', '#e0663c', '#1f8a86', 1024, 256);
    this.signMats.push(signM);
    const sign = new THREE.Mesh(new THREE.PlaneGeometry(Math.min(3.6, bandLen * 0.8), 0.9), signM);
    const [dx, dz] = u.def.door.dir;
    sign.position.set(bx + dx * 0.12, y0 + 2.6 + (H - 2.6) / 2, bz + dz * 0.12);
    sign.rotation.y = Math.atan2(dx, dz);
    g.add(sign);
  }

  private clerk(g: THREE.Group, x: number, y: number, z: number, face: number, top: number) {
    const look = randomLook(null);
    look.top = top; look.accessory = 'apron'; look.accent = top;
    const c = new CharacterView(look);
    c.root.position.set(x, y, z); c.root.rotation.y = face;
    c.root.userData.clerk = c;
    g.add(c.root); this.clerks.push(c);
    return c;
  }

  private furnish(g: THREE.Group, u: UnitState, t: TenantDef, y0: number) {
    const r = u.def.rect;
    const col = parseInt(t.color.slice(1), 16), acc = parseInt(t.accent.slice(1), 16);
    const cx = (r.x0 + r.x1) / 2, cz = (r.z0 + r.z1) / 2;
    const [dx, dz] = u.def.door.dir;
    const back = { x: cx - dx * ((r.x1 - r.x0) / 2 - 0.6), z: cz - dz * ((r.z1 - r.z0) / 2 - 0.6) };
    const faceDoor = Math.atan2(dx, dz);
    const along = dx !== 0 ? 'z' : 'x';
    const span = along === 'x' ? r.x1 - r.x0 : r.z1 - r.z0;
    const rnd = mulberry(u.idx * 31 + 7);
    const P = (a: number, depth: number) => ({ x: along === 'x' ? r.x0 + a : back.x + dx * depth, z: along === 'z' ? r.z0 + a : back.z + dz * depth });
    const place = (o: THREE.Object3D, a: number, depth: number, rot = faceDoor) => { const p = P(a, depth); o.position.set(p.x, y0 + 0.08, p.z); o.rotation.y = rot; g.add(o); return o; };
    const props = new THREE.Group();
    switch (t.id) {
      case 'giyim': case 'spor': {
        const shirtCols = t.id === 'giyim' ? [0xe0663c, 0xf2b33d, 0x1f8a86, 0xf6efe3, 0x6c4ab6, 0x2f6fb5] : [0xd6333a, 0x1f2a44, 0xffffff, 0x2fae7a];
        for (let i = 0; i < Math.max(1, Math.floor(span / 2.2)); i++) {
          const rack = new THREE.Group();
          addMesh(rack, cyl(0.02, 0.02, 1.5, 6), M.steel, -0.7, 0.75, 0); addMesh(rack, cyl(0.02, 0.02, 1.5, 6), M.steel, 0.7, 0.75, 0);
          addMesh(rack, cyl(0.015, 0.015, 1.5, 6), M.steel, 0, 1.45, 0, 0, 0, Math.PI / 2);
          for (let k = 0; k < 7; k++) addMesh(rack, rbox(0.06, 0.62, 0.42, 0.02), mat(shirtCols[(k + i) % shirtCols.length], 0.9), -0.6 + k * 0.2, 1.1, 0, 0, 0, (rnd() - 0.5) * 0.1);
          place(rack, 1.2 + i * 2.2, 1.6 + (i % 2) * 0.5, faceDoor + Math.PI / 2);
        }
        const table = new THREE.Group();
        addMesh(table, rbox(1.2, 0.75, 0.7, 0.03), M.wood, 0, 0.375, 0);
        for (let k = 0; k < 6; k++) addMesh(table, rbox(0.3, 0.06, 0.26, 0.02), mat(shirtCols[k % shirtCols.length], 0.9), -0.4 + (k % 3) * 0.4, 0.78 + Math.floor(k / 3) * 0.06, -0.15 + Math.floor(k / 3) * 0.3);
        place(table, span / 2, 3.2);
        const man = new THREE.Group();
        addMesh(man, capsule2(), mat(0xf6efe3, 0.4), 0, 1.1, 0);
        addMesh(man, sphere(0.14, 12, 10), mat(0xf6efe3, 0.4), 0, 1.65, 0);
        addMesh(man, rbox(0.42, 0.5, 0.26, 0.08), mat(col, 0.8), 0, 1.15, 0);
        addMesh(man, cyl(0.02, 0.02, 0.8, 6), M.steel, 0, 0.4, 0);
        place(man, span - 1, 3.4);
        this.clerk(g, P(0.9, 0.3).x, y0 + 0.08, P(0.9, 0.3).z, faceDoor, col);
        break;
      }
      case 'elektronik': {
        for (let i = 0; i < Math.max(1, Math.floor(span / 2.4)); i++) {
          const tb = new THREE.Group();
          addMesh(tb, rbox(1.6, 0.9, 0.8, 0.04), mat(0xf4f4f2, 0.3), 0, 0.45, 0);
          for (let k = 0; k < 3; k++) {
            const lap = addMesh(tb, rbox(0.34, 0.02, 0.24, 0.01), M.steel, -0.5 + k * 0.5, 0.92, 0.05);
            void lap;
            const scr = addMesh(tb, rbox(0.34, 0.22, 0.015, 0.005), mat(0x1b1f2a, 0.2), -0.5 + k * 0.5, 1.03, -0.08, -0.25);
            const d = new THREE.Mesh(new THREE.PlaneGeometry(0.3, 0.18), glow([0x61d4ff, 0x7fe3c8, 0xf2b33d][k], 0.9)); d.position.z = 0.009; scr.add(d); d.userData.dynamic = true;
          }
          place(tb, 1.3 + i * 2.4, 2.2);
        }
        const wall = new THREE.Group();
        for (let k = 0; k < 3; k++) { const tv = new THREE.Mesh(new THREE.PlaneGeometry(1.1, 0.65), glow([0x2f6fb5, 0x6c4ab6, 0x1f8a86][k], 1.1)); tv.position.set(-1.2 + k * 1.2, 2.0, 0); wall.add(tv); this.arcadeMats.push(tv.material as THREE.MeshStandardMaterial); }
        place(wall, span / 2, 0.05);
        this.clerk(g, P(span - 1, 1.2).x, y0 + 0.08, P(span - 1, 1.2).z, faceDoor, col);
        break;
      }
      case 'kitap': {
        const spines = canvasTexture(256, 256, (ctx, w, h) => {
          ctx.fillStyle = '#5b3a24'; ctx.fillRect(0, 0, w, h);
          const cs = ['#e0663c', '#1f8a86', '#f2b33d', '#6c4ab6', '#2f6fb5', '#d6333a', '#f6efe3', '#3f8f3a'];
          const R = mulberry(5);
          for (let row = 0; row < 4; row++) { let x = 4; while (x < w - 6) { const bw = 6 + R() * 10; ctx.fillStyle = cs[(R() * cs.length) | 0]; ctx.fillRect(x, row * 64 + 8 + R() * 8, bw - 1, 50 - R() * 8); x += bw; } ctx.fillStyle = '#8a5a35'; ctx.fillRect(0, row * 64 + 58, w, 6); }
        });
        const shelfM = new THREE.MeshStandardMaterial({ map: spines, roughness: 0.8 });
        const shelf = new THREE.Mesh(new THREE.BoxGeometry(span - 0.6, 2.4, 0.4), [M.woodDark, M.woodDark, M.woodDark, M.woodDark, shelfM, M.woodDark]);
        shelf.castShadow = true; place(shelf, span / 2, 0.2);
        const tb = new THREE.Group(); addMesh(tb, rbox(1.4, 0.8, 0.8, 0.03), M.wood, 0, 0.4, 0);
        for (let k = 0; k < 5; k++) addMesh(tb, rbox(0.22, 0.05, 0.3, 0.01), mat([0xe0663c, 0x1f8a86, 0xf2b33d, 0x6c4ab6, 0x2f6fb5][k], 0.7), -0.5 + k * 0.25, 0.83 + (k % 2) * 0.05, 0, 0, rnd(), 0);
        place(tb, span / 2, 2.4);
        addMesh(g, cyl(0.25, 0.25, 0.5, 14), M.terracotta, P(0.7, 3).x, y0 + 0.3, P(0.7, 3).z);
        this.clerk(g, P(span - 0.9, 2.5).x, y0 + 0.08, P(span - 0.9, 2.5).z, faceDoor, col);
        break;
      }
      case 'oyuncak': {
        const blocks = [0xe5484d, 0xf2b33d, 0x2fae7a, 0x61b3ff, 0x6c4ab6];
        for (let k = 0; k < 18; k++) addMesh(props, rbox(0.3, 0.3, 0.3, 0.05), mat(blocks[k % 5], 0.5), (k % 6) * 0.34 - 0.85, 0.15 + Math.floor(k / 6) * 0.31, 0, 0, rnd() * 0.3, 0);
        place(props, span / 2, 0.4);
        const bear = new THREE.Group();
        const fur = mat(0xb07a4a, 0.95);
        addMesh(bear, sphere(0.45, 16, 12), fur, 0, 0.5, 0); addMesh(bear, sphere(0.3, 16, 12), fur, 0, 1.1, 0);
        for (const s of [-1, 1]) { addMesh(bear, sphere(0.1, 10, 8), fur, s * 0.2, 1.35, 0); addMesh(bear, sphere(0.14, 10, 8), fur, s * 0.42, 0.55, 0.15); }
        addMesh(bear, sphere(0.1, 10, 8), mat(0xe9cfa8, 0.9), 0, 1.05, 0.25);
        addMesh(bear, rbox(0.3, 0.1, 0.06, 0.03), mat(0xd6333a, 0.6), 0, 0.85, 0.22);
        place(bear, span - 1.2, 2.2);
        for (let k = 0; k < 3; k++) { const b = addMesh(g, sphere(0.2, 12, 10), mat(blocks[k], 0.3), P(1 + k * 0.4, 2.6).x, y0 + 2.2 + k * 0.2, P(1 + k * 0.4, 2.6).z); void b; }
        this.clerk(g, P(1.2, 1.5).x, y0 + 0.08, P(1.2, 1.5).z, faceDoor, col);
        break;
      }
      case 'kuafor': {
        for (let i = 0; i < Math.max(1, Math.floor(span / 2)); i++) {
          const ch = new THREE.Group();
          addMesh(ch, cyl(0.2, 0.25, 0.1, 14), M.steel, 0, 0.05, 0);
          addMesh(ch, cyl(0.05, 0.05, 0.45, 8), M.steel, 0, 0.3, 0);
          addMesh(ch, rbox(0.55, 0.14, 0.5, 0.06), mat(0x1b1d22, 0.4), 0, 0.55, 0);
          addMesh(ch, rbox(0.55, 0.6, 0.12, 0.06), mat(0x1b1d22, 0.4), 0, 0.9, -0.22);
          place(ch, 1 + i * 2, 1.2);
          const mirror = new THREE.Mesh(new THREE.PlaneGeometry(0.8, 1.1), new THREE.MeshStandardMaterial({ color: 0xcfe2ea, metalness: 0.9, roughness: 0.05 }));
          place(mirror, 1 + i * 2, 0.08).position.y += 1.5;
          addMesh(g, rbox(0.95, 1.25, 0.04, 0.02), mat(acc, 0.5), mirror.position.x, y0 + 1.58, mirror.position.z).rotation.y = faceDoor;
        }
        this.clerk(g, P(1.4, 1.8).x, y0 + 0.08, P(1.4, 1.8).z, faceDoor, col);
        break;
      }
      case 'oyun': {
        for (let i = 0; i < Math.max(2, Math.floor(span / 1.3)); i++) {
          const cab = new THREE.Group();
          addMesh(cab, rbox(0.8, 1.8, 0.7, 0.05), mat([0x6c4ab6, 0xe0663c, 0x1f8a86][i % 3], 0.4), 0, 0.9, 0);
          const scrM = glow([0x7fe3c8, 0xff5fa2, 0xf2b33d][i % 3], 1.4).clone();
          const scr = new THREE.Mesh(new THREE.PlaneGeometry(0.6, 0.45), scrM); scr.position.set(0, 1.35, 0.36); scr.rotation.x = -0.2; cab.add(scr);
          this.arcadeMats.push(scrM);
          addMesh(cab, rbox(0.7, 0.08, 0.3, 0.03), mat(0x1b1d22, 0.5), 0, 0.95, 0.4, 0.3, 0, 0);
          const mq = new THREE.Mesh(new THREE.PlaneGeometry(0.7, 0.2), glow(0xffffff, 0.9)); mq.position.set(0, 1.72, 0.36); cab.add(mq);
          place(cab, 0.8 + i * 1.3, 0.4);
        }
        const claw = new THREE.Group();
        addMesh(claw, rbox(0.9, 0.8, 0.9, 0.04), mat(0xe5484d, 0.4), 0, 0.4, 0);
        const box = new THREE.Mesh(new THREE.BoxGeometry(0.86, 0.9, 0.86), M.glass); box.position.y = 1.25; box.renderOrder = 3; claw.add(box);
        for (let k = 0; k < 8; k++) addMesh(claw, sphere(0.1, 8, 6), mat([0xf2b33d, 0x61b3ff, 0x2fae7a, 0xf08f86][k % 4], 0.6), (k % 3 - 1) * 0.22, 0.9, (Math.floor(k / 3) - 1) * 0.22, 0, 0, 0, false);
        place(claw, span - 0.8, 2.6);
        break;
      }
      case 'kafe': case 'burger': case 'pide': {
        const ct = new THREE.Group();
        addMesh(ct, rbox(span - 1.2, 1.0, 0.7, 0.04), mat(t.id === 'kafe' ? 0x5b3a24 : 0xf6efe3, 0.5), 0, 0.5, 0);
        addMesh(ct, rbox(span - 1.1, 0.06, 0.8, 0.02), mat(col, 0.4), 0, 1.03, 0);
        if (t.id === 'kafe') {
          addMesh(ct, rbox(0.6, 0.45, 0.45, 0.04), M.steel, -0.8, 1.28, -0.05);
          for (let k = 0; k < 4; k++) addMesh(ct, cyl(0.045, 0.035, 0.1, 10), mat(0xffffff, 0.4), 0.2 + k * 0.2, 1.11, 0.15);
        } else if (t.id === 'burger') {
          addMesh(ct, rbox(0.7, 0.35, 0.5, 0.03), M.steel, -0.9, 1.2, -0.05);
          for (let k = 0; k < 3; k++) { const b = new THREE.Group(); b.position.set(0.1 + k * 0.35, 1.1, 0.15); addMesh(b, cyl(0.1, 0.1, 0.05, 12), mat(0xd99a55, 0.8), 0, 0, 0); addMesh(b, cyl(0.105, 0.105, 0.03, 12), mat(0x6b3b2a, 0.8), 0, 0.04, 0); addMesh(b, sphere(0.1, 12, 6), mat(0xd99a55, 0.8), 0, 0.07, 0).scale.set(1, 0.5, 1); ct.add(b); }
        } else {
          const oven = addMesh(ct, new THREE.SphereGeometry(0.6, 16, 10, 0, Math.PI * 2, 0, Math.PI / 2), mat(0xb44a28, 0.8), -span / 2 + 1.5, 1.06, -0.3);
          void oven;
          const m2 = new THREE.Mesh(new THREE.CircleGeometry(0.2, 12, 0, Math.PI), glow(0xff7a2a, 1.2)); m2.position.set(-span / 2 + 1.5, 1.1, 0.29); ct.add(m2);
          for (let k = 0; k < 3; k++) addMesh(ct, rbox(0.45, 0.05, 0.14, 0.03), mat(0xe0a860, 0.8), 0.2 + k * 0.5, 1.1, 0.12, 0, 0.2, 0);
        }
        place(ct, span / 2, 1.1);
        const menuT = canvasTexture(512, 192, (ctx, w, h) => {
          ctx.fillStyle = '#1f2a44'; roundRect(ctx, 0, 0, w, h, 20); ctx.fill();
          ctx.fillStyle = t.accent; ctx.font = '800 48px "Baloo 2", system-ui'; ctx.textAlign = 'center'; ctx.fillText(t.brand, w / 2, 62);
          ctx.fillStyle = '#fff'; ctx.font = '600 28px "Baloo 2", system-ui';
          const items = t.id === 'kafe' ? ['Türk Kahvesi  ₺45', 'Latte  ₺70', 'Cheesecake  ₺90'] : t.id === 'burger' ? ['Klasik  ₺140', 'Tombul Menü  ₺195', 'Patates  ₺60'] : ['Kıymalı  ₺120', 'Kaşarlı  ₺110', 'Ayran  ₺25'];
          items.forEach((s, i) => ctx.fillText(s, w / 2, 104 + i * 32));
        });
        const menu = new THREE.Mesh(new THREE.PlaneGeometry(2.2, 0.82), new THREE.MeshStandardMaterial({ map: menuT, emissive: 0xffffff, emissiveMap: menuT, emissiveIntensity: 0.5 }));
        place(menu, span / 2, 0.1).position.y += 2.35;
        this.clerk(g, P(span / 2 - 0.8, 0.55).x, y0 + 0.08, P(span / 2 - 0.8, 0.55).z, faceDoor, col);
        if (span > 6) this.clerk(g, P(span / 2 + 1, 0.55).x, y0 + 0.08, P(span / 2 + 1, 0.55).z, faceDoor, col);
        break;
      }
    }
  }

  // ---------------------------------------------------------------- events
  private buildStage() {
    const s = this.stage;
    s.position.set(22, FLOOR_H, 12.2);
    addMesh(s, rbox(4, 0.4, 2.2, 0.06), mat(0x1f2a44, 0.5), 0, 0.2, 0);
    addMesh(s, rbox(4.1, 0.05, 2.3, 0.02), mat(PAL.terracotta, 0.6), 0, 0.42, 0);
    for (const x of [-2, 2]) { addMesh(s, rbox(0.1, 3.2, 0.1, 0.02), M.steelDark, x, 1.6, -1); addMesh(s, rbox(0.5, 0.9, 0.45, 0.04), mat(0x1b1d22, 0.6), x * 0.85, 0.85, 0.6); }
    addMesh(s, rbox(4.1, 0.1, 0.1, 0.02), M.steelDark, 0, 3.2, -1);
    const spots: THREE.MeshStandardMaterial[] = [];
    for (let i = 0; i < 4; i++) { const m = glow([0xff5fa2, 0x61d4ff, 0xf2b33d, 0x7fe3c8][i], 3).clone(); addMesh(s, cyl(0.1, 0.14, 0.22, 10), m, -1.5 + i, 3.05, -0.95, 0.6, 0, 0, false); spots.push(m); }
    this.arcadeMats.push(...spots);
    const look = randomLook(null); look.top = 0xd6333a; look.hairStyle = 'curly';
    this.performer = new CharacterView(look);
    this.performer.root.position.set(0, 0.45, -0.2);
    addMesh(this.performer.root, rbox(0.12, 0.34, 0.06, 0.03), mat(0x8a5a35, 0.6), 0.1, 0.95, 0.25, 0, 0, 0.9);
    s.add(this.performer.root);
    s.visible = false;
    this.f1.add(s);
  }

  setEvent(id: string | null) {
    this.decorations.clear();
    this.stage.visible = id === 'konser';
    if (!id) return;
    const cols = [0xe0663c, 0xf2b33d, 0x1f8a86, 0x6c4ab6, 0xd6333a, 0x61b3ff];
    // bunting across both floors
    for (const [fl, z] of [[0, 2], [1, 6], [1, 12.5]] as [number, number][]) {
      const y = fl * FLOOR_H + 3.6;
      const x0 = fl ? 3 : 6.5, x1 = fl ? 41 : 37.5;
      const n = Math.floor((x1 - x0) / 0.5);
      for (let i = 0; i < n; i++) {
        const x = x0 + i * 0.5;
        const sag = Math.sin((i / n) * Math.PI) * 0.5;
        const f = new THREE.Mesh(new THREE.ConeGeometry(0.16, 0.34, 3), mat(cols[i % cols.length], 0.7));
        f.position.set(x, y - sag - 0.17, z); f.rotation.x = Math.PI; f.rotation.y = Math.PI / 6;
        this.decorations.add(f);
      }
    }
    if (id === 'cocuk' || id === 'bayram') {
      for (let k = 0; k < 7; k++) {
        const bx = 6 + k * 5.2, bz = 6 + (k % 3) * 3;
        const grp = new THREE.Group(); grp.position.set(bx, FLOOR_H, bz);
        for (let b = 0; b < 4; b++) {
          addMesh(grp, sphere(0.22, 12, 10), mat(cols[(k + b) % cols.length], 0.25), (b % 2) * 0.3 - 0.15, 2.3 + b * 0.18, Math.floor(b / 2) * 0.3 - 0.15);
          addMesh(grp, cyl(0.004, 0.004, 2.1, 3), mat(0xffffff, 0.5), (b % 2) * 0.3 - 0.15, 1.2 + b * 0.09, Math.floor(b / 2) * 0.3 - 0.15, 0, 0, 0, false);
        }
        addMesh(grp, rbox(0.3, 0.12, 0.3, 0.03), mat(0x2a2d33, 0.6), 0, 0.06, 0);
        this.decorations.add(grp);
      }
    }
    if (id === 'bayram' || id === 'imza') {
      const txt = id === 'bayram' ? 'BAYRAM İNDİRİMLERİ' : 'İMZA GÜNÜ · SAYFA';
      for (const [fl, x] of [[0, 8], [1, 22]] as [number, number][]) {
        const ban = new THREE.Mesh(new THREE.PlaneGeometry(4.5, 1), textPanel(txt, '', '#d6333a', '#ffffff', '#f2b33d', 1024, 228));
        ban.position.set(x, fl * FLOOR_H + 3.1, fl ? 5.2 : 0.5); this.decorations.add(ban);
      }
    }
  }

  // ---------------------------------------------------------------- per-frame
  update(dt: number, simDt: number, camDir: THREE.Vector3, viewFloor: number, far: number, cutaway: boolean, night: number, agents: THREE.Vector3[]) {
    const showAll = far > 0.5;
    this.f1.visible = showAll || viewFloor >= 1;
    this.exterior.visible = far > 0.3 || !cutaway;
    for (const s of this.sides) {
      const facing = -camDir.dot(s.normal);
      let target = cutaway && facing > 0.15 && s.floor === viewFloor ? 1 : 0;
      if (s.floor < viewFloor) target = 0; // lower floor walls stay (outer facade)
      target *= 1 - far;
      s.sink = THREE.MathUtils.clamp(s.sink + (target - s.sink) * Math.min(1, dt * 7), 0, 1);
      s.group.position.y = -(FLOOR_H - 0.6) * s.sink;
      for (const e of s.extras) e.visible = s.sink < 0.4;
    }
    for (const t of this.escalatorTex) { t.offset.y += simDt * 0.35 * ((t as THREE.Texture & { dir?: number }).dir ?? 1); }
    for (const m of this.signMats) m.emissiveIntensity = 0.25 + night * 0.9;
    const tm = performance.now() * 0.001;
    this.arcadeMats.forEach((m, i) => { m.emissiveIntensity = 1.1 + Math.sin(tm * 3 + i) * 0.5; });
    for (const c of this.clerks) c.update(dt, 0);
    if (this.performer && this.stage.visible) { this.performer.play('happy'); this.performer.update(dt, 0); if (this.performer.anim === 'happy' && Math.random() < dt * 0.3) this.performer.play('idle'); }
    // lift car follows the rider
    const lift = this.mall.connectors.find((c) => c.def.id === 'lift');
    if (lift) { lift.liftY += (lift.liftTarget - lift.liftY) * Math.min(1, simDt * 1.6); this.liftCab.position.y = lift.liftY; }
    for (const c of this.mall.connectors) { const b = this.barriers.get(c.def.id); if (b) b.visible = c.broken; }
    // entrance sliding doors
    for (const d of this.entranceDoors) {
      const near = agents.some((p) => p.y < 1 && Math.abs(p.x - d.x) < 1.8 && Math.abs(p.z - 16) < 1.6);
      d.open = THREE.MathUtils.clamp(d.open + ((near ? 1 : 0) - d.open) * Math.min(1, dt * 6), 0, 1);
      d.left.position.x = d.x - 0.5 - d.open * 0.5; d.right.position.x = d.x + 0.5 + d.open * 0.5;
    }
  }

  liftTo(c: ConnectorState, floor: number) { c.liftTarget = floor * FLOOR_H; }
}

function capsule2() { return new THREE.CapsuleGeometry(0.18, 0.5, 4, 10); }
function shade(hex: string, k: number) {
  const c = parseInt(hex.slice(1), 16);
  const base = new THREE.Color(0xf4efe6), col = new THREE.Color(c);
  return base.lerp(col, k).getHex();
}
let _shutter: THREE.Material | null = null;
function shutterMat() {
  if (_shutter) return _shutter;
  const t = canvasTexture(128, 128, (ctx, w, h) => {
    for (let y = 0; y < h; y += 8) { const g = ctx.createLinearGradient(0, y, 0, y + 8); g.addColorStop(0, '#d4d9de'); g.addColorStop(1, '#8a939b'); ctx.fillStyle = g; ctx.fillRect(0, y, w, 8); }
  });
  _shutter = new THREE.MeshStandardMaterial({ map: t, metalness: 0.5, roughness: 0.45 });
  return _shutter;
}
