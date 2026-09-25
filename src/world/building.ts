import * as THREE from 'three';
import { WALL_H, PAL, type StageLayout } from '../config';
import { M, rbox, cyl, mat, glow } from './materials';
import { addMesh } from './props';
import { mergeByMaterial } from './merge';
import { awningTexture, signTexture, posterTexture, canvasTexture, roundRect } from './textures';

interface WallSide {
  group: THREE.Group;
  normal: THREE.Vector3; // outward
  sink: number;
  /** walls with door openings shrink in height instead of sliding down, so doorways stay open */
  scaleSink?: boolean;
  extras: THREE.Object3D[]; // hidden when cut away (awning, sign)
}

export interface DoorAnim { x: number; z: number; left: THREE.Object3D; right: THREE.Object3D; open: number; baseL: number; baseR: number }

/** The shop shell: floor, walls with camera-aware cutaway, storefront, sign, lights. */
export class ShopShell {
  group = new THREE.Group();
  sides: WallSide[] = [];
  doors: DoorAnim[] = [];
  interiorLights: THREE.PointLight[] = [];
  sconces: THREE.MeshStandardMaterial[] = [];
  signMat!: THREE.MeshStandardMaterial;
  neonTube: THREE.Mesh | null = null;
  private awnings: THREE.Mesh[] = [];
  banner: THREE.Mesh | null = null;
  setCampaign(on: boolean) { if (this.banner) this.banner.visible = on; }
  cutaway = true;

  constructor(private scene: THREE.Scene, public layout: StageLayout, public stage: number, public upgrades: Set<string>) {
    scene.add(this.group);
    this.build();
  }

  rebuild(layout: StageLayout, stage: number) {
    this.layout = layout; this.stage = stage;
    this.group.clear();
    this.sides = []; this.doors = []; this.interiorLights = []; this.sconces = []; this.awnings = [];
    this.neonTube = null;
    this.build();
  }

  private build() {
    const r = this.layout.interior;
    const W = r.x1 - r.x0, D = r.z1 - r.z0;
    const cx = r.x0 + W / 2, cz = r.z0 + D / 2;
    // floor slab
    const ft = (M.floor.map as THREE.Texture);
    ft.repeat.set(W / 2, D / 2);
    const floor = new THREE.Mesh(new THREE.BoxGeometry(W + 0.2, 0.1, D + 0.2), M.floor);
    floor.position.set(cx, 0.03, cz); floor.receiveShadow = true;
    this.group.add(floor);
    // entrance mat(s)
    for (const dx of this.layout.doors) {
      if (!this.layout.doors.includes(dx - 1)) {
        const mm = addMesh(this.group, rbox(1.8, 0.02, 0.9, 0.01), mat(0x8a3a24, 0.95), dx + 1, 0.085, r.z1 - 0.55, 0, 0, 0, false);
        mm.receiveShadow = true;
      }
    }

    const th = 0.22;
    const mkSide = (normal: THREE.Vector3) => {
      const s: WallSide = { group: new THREE.Group(), normal, sink: 0, extras: [] };
      this.group.add(s.group); this.sides.push(s); return s;
    };
    // BACK wall (z0), normal -z
    const back = mkSide(new THREE.Vector3(0, 0, -1));
    const bd = this.layout.backDoors ?? [];
    if (!bd.length) this.solidWall(back.group, r.x0 - th / 2, r.z0 - th / 2, r.x1 + th / 2, r.z0 - th / 2, th, 'x', 1);
    else {
      const a = Math.min(...bd), b = Math.max(...bd) + 1;
      this.solidWall(back.group, r.x0 - th / 2, r.z0 - th / 2, a, r.z0 - th / 2, th, 'x', 1);
      this.solidWall(back.group, b, r.z0 - th / 2, r.x1 + th / 2, r.z0 - th / 2, th, 'x', 1);
      const z = r.z0 - th / 2;
      const frame = mat(PAL.ink, 0.45, 0.3);
      addMesh(back.group, rbox(b - a + 0.2, WALL_H - 2.35, th, 0.02), M.wall, (a + b) / 2, 2.35 + (WALL_H - 2.35) / 2, z);
      for (const x of [a, b]) addMesh(back.group, rbox(0.1, 2.35, 0.24, 0.02), frame, x, 1.175, z, 0, 0, 0, false);
      const w = b - a;
      const mk = (px: number) => {
        const p = new THREE.Group(); p.position.set(px, 0, z);
        const gl = new THREE.Mesh(new THREE.PlaneGeometry(w / 2 - 0.06, 2.2), M.glass); gl.position.y = 1.15; gl.renderOrder = 3; p.add(gl);
        addMesh(p, rbox(w / 2, 0.06, 0.05, 0.01), frame, 0, 2.25, 0, 0, 0, 0, false);
        back.group.add(p); return p;
      };
      const L = mk(a + w / 4), R2 = mk(b - w / 4);
      this.doors.push({ x: (a + b) / 2, z, left: L, right: R2, open: 0, baseL: a + w / 4, baseR: b - w / 4 });
      const sgn = new THREE.Mesh(new THREE.PlaneGeometry(1.8, 0.3), backDoorSign());
      sgn.position.set((a + b) / 2, 2.6, z + 0.12); back.group.add(sgn);
      back.scaleSink = true; back.extras.push(sgn);
      const lintel = back.group.children.find((c) => (c as THREE.Mesh).isMesh && Math.abs(c.position.y - (2.35 + (WALL_H - 2.35) / 2)) < 0.01 && Math.abs(c.position.x - (a + b) / 2) < 0.01);
      if (lintel) back.extras.push(lintel);
    }
    // LEFT wall (x0), normal -x
    const left = mkSide(new THREE.Vector3(-1, 0, 0));
    this.solidWall(left.group, r.x0 - th / 2, r.z0, r.x0 - th / 2, r.z1, th, 'z', 1);
    // RIGHT wall (x1), normal +x
    const right = mkSide(new THREE.Vector3(1, 0, 0));
    this.solidWall(right.group, r.x1 + th / 2, r.z0, r.x1 + th / 2, r.z1, th, 'z', -1);
    // FRONT storefront (z1), normal +z
    const front = mkSide(new THREE.Vector3(0, 0, 1));
    front.scaleSink = true;
    this.storefront(front, r.x0, r.x1, r.z1 + th / 2 - 0.05);

    this.decorateBackWall(r.x0, r.x1, r.z0 + 0.01);
    for (const sd of this.sides) {
      for (const e of sd.extras) e.userData.dynamic = true;
      for (const d of this.doors) { d.left.userData.dynamic = true; d.right.userData.dynamic = true; }
      mergeByMaterial(sd.group);
    }
    // interior lights (warm)
    const nL = this.stage === 0 ? 2 : 4;
    for (let i = 0; i < nL; i++) {
      const pl = new THREE.PointLight(0xffd9a8, 0, Math.max(W, D) * 0.9, 1.4);
      pl.position.set(r.x0 + W * ((i % 2) + 0.5) / 2, 2.7, r.z0 + (this.stage === 0 ? D / 2 : D * (Math.floor(i / 2) + 0.5) / 2));
      this.group.add(pl); this.interiorLights.push(pl);
    }
  }

  private solidWall(parent: THREE.Group, x0: number, z0: number, x1: number, z1: number, th: number, axis: 'x' | 'z', innerSign: number) {
    const len = axis === 'x' ? Math.abs(x1 - x0) : Math.abs(z1 - z0);
    const cx = (x0 + x1) / 2, cz = (z0 + z1) / 2;
    const geo = axis === 'x' ? new THREE.BoxGeometry(len, WALL_H, th) : new THREE.BoxGeometry(th, WALL_H, len);
    const wallTex = (M.wall.map as THREE.Texture);
    wallTex.repeat.set(2, 1);
    const w = addMesh(parent, geo, M.wall, cx, WALL_H / 2, cz);
    // inner wainscot panel
    const ws = (M.wainscot.map as THREE.Texture).clone();
    ws.wrapS = ws.wrapT = THREE.RepeatWrapping; ws.repeat.set(len / 1.2, 1); ws.needsUpdate = true;
    const wsM = new THREE.MeshStandardMaterial({ map: ws, roughness: 0.25 });
    const panelH = 1.15;
    const off = th / 2 + 0.01;
    if (axis === 'x') {
      const inner = (z0 > 0 ? 1 : 1) * innerSign;
      const p = new THREE.Mesh(new THREE.BoxGeometry(len, panelH, 0.02), wsM); p.position.set(cx, panelH / 2 + 0.08, cz + inner * off); p.receiveShadow = true; parent.add(p);
      addMesh(parent, rbox(len, 0.06, 0.05, 0.015), M.teal, cx, panelH + 0.1, cz + inner * (off + 0.02), 0, 0, 0, false);
      addMesh(parent, rbox(len, 0.1, 0.04, 0.01), M.woodDark, cx, 0.1, cz + inner * (off + 0.02), 0, 0, 0, false);
      addMesh(parent, rbox(len + th, 0.08, th + 0.06, 0.02), M.cream, cx, WALL_H + 0.04, cz, 0, 0, 0, false);
    } else {
      const inner = innerSign;
      const p = new THREE.Mesh(new THREE.BoxGeometry(0.02, panelH, len), wsM); p.position.set(cx + inner * off, panelH / 2 + 0.08, cz); p.receiveShadow = true; parent.add(p);
      addMesh(parent, rbox(0.05, 0.06, len, 0.015), M.teal, cx + inner * (off + 0.02), panelH + 0.1, cz, 0, 0, 0, false);
      addMesh(parent, rbox(0.04, 0.1, len, 0.01), M.woodDark, cx + inner * (off + 0.02), 0.1, cz, 0, 0, 0, false);
      addMesh(parent, rbox(th + 0.06, 0.08, len + th, 0.02), M.cream, cx, WALL_H + 0.04, cz, 0, 0, 0, false);
    }
    void w;
  }

  private storefront(side: WallSide, x0: number, x1: number, z: number) {
    const g = side.group;
    const doors = new Set(this.layout.doors);
    const frame = mat(PAL.ink, 0.45, 0.3);
    const sillH = 0.55, topH = 2.35;
    // corner pillars
    for (const x of [x0 - 0.11, x1 + 0.11]) addMesh(g, rbox(0.34, WALL_H, 0.34, 0.03), M.terracotta, x, WALL_H / 2, z);
    for (let x = x0; x < x1; x++) {
      if (doors.has(x)) continue;
      addMesh(g, rbox(1.0, sillH, 0.26, 0.02), M.terracotta, x + 0.5, sillH / 2, z);
      addMesh(g, rbox(1.02, 0.06, 0.34, 0.02), M.cream, x + 0.5, sillH + 0.03, z, 0, 0, 0, false);
      const glass = new THREE.Mesh(new THREE.PlaneGeometry(0.96, topH - sillH - 0.06), M.glass);
      glass.position.set(x + 0.5, (sillH + topH) / 2, z); glass.renderOrder = 3; g.add(glass);
      addMesh(g, rbox(0.06, topH - sillH, 0.08, 0.01), frame, x + 1, (sillH + topH) / 2, z, 0, 0, 0, false);
      // window decals: every other bay gets a friendly vinyl
      if ((x - x0) % 3 === 1) {
        const d = new THREE.Mesh(new THREE.PlaneGeometry(0.7, 0.36), windowDecal((x - x0) % 2 ? 'SOĞUK İÇECEK' : 'TAZE SİMİT'));
        d.position.set(x + 0.5, 1.45, z + 0.012); g.add(d);
      }
    }
    // door frames + sliding panels
    const runs: [number, number][] = [];
    for (const dx of this.layout.doors) {
      const last = runs[runs.length - 1];
      if (last && last[1] === dx) last[1] = dx + 1; else runs.push([dx, dx + 1]);
    }
    for (const [a, b] of runs) {
      const w = b - a;
      addMesh(g, rbox(0.1, topH, 0.2, 0.02), frame, a + 0.03, topH / 2, z, 0, 0, 0, false);
      addMesh(g, rbox(0.1, topH, 0.2, 0.02), frame, b - 0.03, topH / 2, z, 0, 0, 0, false);
      const mkPanel = (px: number) => {
        const p = new THREE.Group(); p.position.set(px, 0, z + 0.06);
        addMesh(p, rbox(w / 2, 0.06, 0.05, 0.01), frame, 0, 0.1, 0, 0, 0, 0, false);
        addMesh(p, rbox(w / 2, 0.06, 0.05, 0.01), frame, 0, topH - 0.05, 0, 0, 0, 0, false);
        addMesh(p, rbox(0.05, topH, 0.05, 0.01), frame, -w / 4 + 0.02, topH / 2, 0, 0, 0, 0, false);
        addMesh(p, rbox(0.05, topH, 0.05, 0.01), frame, w / 4 - 0.02, topH / 2, 0, 0, 0, 0, false);
        const gl = new THREE.Mesh(new THREE.PlaneGeometry(w / 2 - 0.06, topH - 0.14), M.glass); gl.position.y = topH / 2; gl.renderOrder = 3; p.add(gl);
        g.add(p); return p;
      };
      const L = mkPanel(a + w / 4), R = mkPanel(b - w / 4);
      this.doors.push({ x: (a + b) / 2, z, left: L, right: R, open: 0, baseL: a + w / 4, baseR: b - w / 4 });
      // "AÇIK" sign on door
      const open = new THREE.Mesh(new THREE.PlaneGeometry(0.42, 0.16), openSignMat());
      open.position.set(0, 1.45, 0.03); L.add(open);
    }
    // top band
    const bandH = WALL_H - topH;
    // the band over the doors is hidden while the storefront is lowered (it would block the doorways)
    side.extras.push(addMesh(g, rbox(x1 - x0 + 0.1, bandH, 0.3, 0.02), M.teal, (x0 + x1) / 2, topH + bandH / 2, z));
    side.extras.push(addMesh(g, rbox(x1 - x0 + 0.1, 0.08, 0.4, 0.02), M.cream, (x0 + x1) / 2, WALL_H + 0.04, z, 0, 0, 0, false));
    // SIGN
    const sub = this.stage === 0 ? 'BÜFE · SİMİT · SOĞUK İÇECEK' : 'MAHALLE MARKETİ';
    const tex = signTexture('KÖŞEBAŞI', sub, { bg: '#fff1dc', fg: '#e0663c', accent: '#1f8a86', w: 1024, h: 256, neon: false });
    this.signMat = new THREE.MeshStandardMaterial({ map: tex, emissive: 0xffffff, emissiveMap: tex, emissiveIntensity: 0.05, roughness: 0.5 });
    const signW = Math.min(6.4, (x1 - x0) * 0.62);
    const signX = this.stage === 0 ? (x0 + x1) / 2 : (x0 + x1) / 2 + 3.5;
    const sign = new THREE.Mesh(new THREE.BoxGeometry(signW, signW / 4, 0.12), [M.cream, M.cream, M.cream, M.cream, this.signMat, M.cream]);
    // sits on top of the band, clear of the awnings in front
    sign.position.set(signX, topH + signW / 8 + 0.04, z + 0.22); sign.castShadow = true;
    g.add(sign); side.extras.push(sign);
    // campaign banner (toggled by setCampaign)
    this.banner = new THREE.Mesh(new THREE.PlaneGeometry(Math.min(4.2, (x1 - x0) * 0.5), 0.55), campaignMat());
    this.banner.position.set(this.stage === 0 ? (x0 + x1) / 2 : x0 + 4, 1.95, z + 0.16);
    this.banner.visible = false; this.banner.userData.dynamic = true; g.add(this.banner);
    // neon outline (upgrade)
    if (this.upgrades.has('neon')) {
      const shape = new THREE.Shape();
      const hw = signW / 2 + 0.08, hh = signW / 8 + 0.08;
      shape.moveTo(-hw, -hh); shape.lineTo(hw, -hh); shape.lineTo(hw, hh); shape.lineTo(-hw, hh); shape.lineTo(-hw, -hh);
      const path = new THREE.CurvePath<THREE.Vector3>();
      const pts = [[-hw, -hh], [hw, -hh], [hw, hh], [-hw, hh], [-hw, -hh]];
      for (let i = 0; i < 4; i++) path.add(new THREE.LineCurve3(new THREE.Vector3(pts[i][0], pts[i][1], 0), new THREE.Vector3(pts[i + 1][0], pts[i + 1][1], 0)));
      const tube = new THREE.Mesh(new THREE.TubeGeometry(path as unknown as THREE.Curve<THREE.Vector3>, 64, 0.03, 6, false), glow(0xff5fa2, 3));
      tube.position.copy(sign.position); tube.position.z += 0.1;
      g.add(tube); side.extras.push(tube); this.neonTube = tube;
    }
    // awning(s) over window runs
    const striped = this.upgrades.has('tente');
    const awTex = striped ? awningTexture('#e0663c', '#fff1dc') : awningTexture('#1f8a86', '#e8f3ef');
    awTex.wrapS = THREE.RepeatWrapping;
    let runStart = x0;
    const flush = (endX: number) => {
      const w = endX - runStart; if (w < 1) return;
      const t = awTex.clone(); t.repeat.set(w / 2, 1); t.needsUpdate = true;
      const aw = new THREE.Mesh(new THREE.BoxGeometry(w - 0.1, 0.06, 1.2), [M.cream, M.cream, new THREE.MeshStandardMaterial({ map: t, roughness: 0.85 }), M.cream, new THREE.MeshStandardMaterial({ map: t, roughness: 0.85 }), M.cream]);
      aw.position.set(runStart + w / 2, topH - 0.3, z + 0.62); aw.rotation.x = 0.32; aw.castShadow = true;
      g.add(aw); side.extras.push(aw); this.awnings.push(aw);
      // scalloped valance
      const val = new THREE.Mesh(new THREE.BoxGeometry(w - 0.1, 0.22, 0.03), new THREE.MeshStandardMaterial({ map: t, roughness: 0.85 }));
      val.position.set(runStart + w / 2, topH - 0.58, z + 1.2); g.add(val); side.extras.push(val);
    };
    for (let x = x0; x <= x1; x++) {
      if (x === x1 || doors.has(x)) { flush(x); runStart = x + 1; }
    }
    // sidewalk A-frame chalk board next to the door
    const firstDoor = this.layout.doors[this.layout.doors.length - 2] ?? this.layout.doors[0];
    const board = new THREE.Group(); board.position.set(firstDoor + 2.6, 0.06, z + 1.1); board.rotation.y = -0.4;
    const chalk = new THREE.MeshStandardMaterial({ map: chalkBoard(), roughness: 0.9 });
    for (const s of [-1, 1]) {
      const p = new THREE.Group(); p.rotation.x = s * 0.2; p.position.z = s * 0.14;
      addMesh(p, rbox(0.62, 0.95, 0.04, 0.02), M.wood, 0, 0.47, 0);
      const face = new THREE.Mesh(new THREE.PlaneGeometry(0.52, 0.8), chalk);
      face.position.set(0, 0.5, s * 0.025); if (s < 0) face.rotation.y = Math.PI; p.add(face);
      board.add(p);
    }
    g.add(board);
  }

  private decorateBackWall(x0: number, x1: number, z: number) {
    const g = this.sides[0].group;
    // wall clock
    const clock = new THREE.Group(); clock.position.set(x0 + 1.2, 2.35, z + 0.14);
    addMesh(clock, cyl(0.24, 0.24, 0.05, 24), M.ink, 0, 0, 0, Math.PI / 2, 0, 0, false);
    addMesh(clock, cyl(0.21, 0.21, 0.02, 24), mat(0xfffaf0, 0.6), 0, 0, 0.02, Math.PI / 2, 0, 0, false);
    addMesh(clock, rbox(0.02, 0.14, 0.01, 0.005), M.ink, 0, 0.05, 0.04, 0, 0, 0, false);
    addMesh(clock, rbox(0.02, 0.1, 0.01, 0.005), M.terracotta, 0.03, -0.02, 0.045, 0, 0, -1, false);
    g.add(clock);
    // posters
    const posters = [
      posterTexture('SİMİT', 'her sabah taze', '#f2b33d', '#1f2a44', (ctx, w) => {
        ctx.fillStyle = '#c47a37'; ctx.beginPath(); ctx.arc(w / 2, 120, 78, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = '#f2b33d'; ctx.beginPath(); ctx.arc(w / 2, 120, 38, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = '#f7e6c3'; for (let i = 0; i < 70; i++) { const a = Math.random() * 6.28, rr = 45 + Math.random() * 30; ctx.fillRect(w / 2 + Math.cos(a) * rr, 120 + Math.sin(a) * rr, 4, 2); }
      }),
      posterTexture('KÖPÜK', 'buz gibi', '#1f8a86', '#fff1dc', (ctx, w) => {
        ctx.fillStyle = '#d8352c'; roundRect(ctx, w / 2 - 34, 40, 68, 170, 26); ctx.fill();
        ctx.fillStyle = '#fff'; ctx.fillRect(w / 2 - 34, 110, 68, 36);
        ctx.fillStyle = 'rgba(255,255,255,0.4)'; for (let i = 0; i < 12; i++) { ctx.beginPath(); ctx.arc(30 + Math.random() * 190, 30 + Math.random() * 200, 4 + Math.random() * 8, 0, 6.28); ctx.fill(); }
      }),
    ];
    const W = x1 - x0;
    posters.forEach((t, i) => {
      const p = new THREE.Mesh(new THREE.PlaneGeometry(0.62, 0.88), new THREE.MeshStandardMaterial({ map: t, roughness: 0.7 }));
      p.position.set(x0 + W * (0.45 + i * 0.22), 2.2, z + 0.13); p.rotation.z = (i ? -1 : 1) * 0.02;
      g.add(p);
    });
    // sconces
    for (let i = 0; i < Math.max(2, Math.floor(W / 3)); i++) {
      const sx = x0 + (i + 0.5) * W / Math.max(2, Math.floor(W / 3));
      const s = new THREE.Group(); s.position.set(sx, 2.75, z + 0.14);
      addMesh(s, rbox(0.1, 0.1, 0.12, 0.02), M.ink, 0, 0, 0, 0, 0, 0, false);
      const shade = new THREE.MeshStandardMaterial({ color: 0xfff0d0, emissive: 0xffd08a, emissiveIntensity: 0.4 });
      addMesh(s, cyl(0.12, 0.08, 0.16, 16, ), shade, 0, -0.05, 0.12, 0, 0, 0, false);
      this.sconces.push(shade);
      g.add(s);
    }
  }

  setSignLit(night: number, neon: boolean) {
    this.signMat.emissiveIntensity = 0.06 + night * (neon ? 1.1 : 0.45);
    for (const s of this.sconces) s.emissiveIntensity = 0.5 + night * 2.5;
    for (const l of this.interiorLights) l.intensity = 2 + night * 10;
    if (this.neonTube) ((this.neonTube.material as THREE.MeshStandardMaterial).emissiveIntensity = 1 + night * 4 + Math.sin(performance.now() * 0.004) * 0.3);
  }

  /** camera-aware cut-away: walls facing the camera sink so the interior is visible */
  update(dt: number, camDir: THREE.Vector3, agentPositions: THREE.Vector3[], zoomFar: number) {
    for (const s of this.sides) {
      const facing = -camDir.dot(s.normal); // >0 when wall faces camera
      let target = this.cutaway && facing > 0.15 ? 1 : 0;
      target *= 1 - zoomFar; // walls come back up when zoomed far out
      s.sink = THREE.MathUtils.clamp(s.sink + (target - s.sink) * Math.min(1, Math.max(0, dt) * 7), 0, 1);
      if (s.scaleSink) { s.group.scale.y = THREE.MathUtils.lerp(1, 0.45 / WALL_H, s.sink); s.group.position.y = 0; }
      else s.group.position.y = -(WALL_H - 0.45) * s.sink;
      const showExtras = s.sink < 0.4;
      for (const e of s.extras) e.visible = showExtras;
    }
    // automatic sliding doors
    for (const d of this.doors) {
      let near = false;
      for (const p of agentPositions) { if (Math.abs(p.x - d.x) < 1.6 && Math.abs(p.z - d.z) < 1.6) { near = true; break; } }
      d.open = THREE.MathUtils.clamp(d.open + ((near ? 1 : 0) - d.open) * Math.min(1, Math.max(0, dt) * 6), 0, 1);
      const off = d.open * 0.48;
      d.left.position.x = d.baseL - off; d.right.position.x = d.baseR + off;
    }
  }
}

function backDoorSign() {
  const t = canvasTexture(512, 96, (ctx, w, h) => {
    ctx.fillStyle = '#1f2a44'; roundRect(ctx, 0, 0, w, h, 18); ctx.fill();
    ctx.fillStyle = '#fff1dc'; ctx.font = '800 50px "Baloo 2", system-ui'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText('AVM GİRİŞİ ↔ SÜPERMARKET', w / 2, h / 2 + 3);
  });
  return new THREE.MeshStandardMaterial({ map: t, emissive: 0xffffff, emissiveMap: t, emissiveIntensity: 0.5 });
}

let _camp: THREE.Material | null = null;
function campaignMat() {
  if (_camp) return _camp;
  const t = canvasTexture(768, 100, (ctx, w, h) => {
    ctx.fillStyle = '#d6333a'; roundRect(ctx, 0, 0, w, h, 16); ctx.fill();
    ctx.fillStyle = '#ffd84a'; ctx.font = '800 56px "Baloo 2", system-ui'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillText('KAMPANYA · FIRSATLAR İÇERİDE', w / 2, h / 2 + 4);
  });
  _camp = new THREE.MeshStandardMaterial({ map: t, emissive: 0xffffff, emissiveMap: t, emissiveIntensity: 0.35, side: THREE.DoubleSide });
  return _camp;
}

let _open: THREE.Material | null = null;
function openSignMat() {
  if (_open) return _open;
  const t = canvasTexture(256, 96, (ctx, w, h) => {
    ctx.fillStyle = '#1f2a44'; roundRect(ctx, 0, 0, w, h, 16); ctx.fill();
    ctx.fillStyle = '#7fe3c8'; ctx.font = '800 58px "Baloo 2", system-ui'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText('AÇIK', w / 2, h / 2 + 4);
  });
  _open = new THREE.MeshStandardMaterial({ map: t, emissive: 0xffffff, emissiveMap: t, emissiveIntensity: 0.8, side: THREE.DoubleSide });
  return _open;
}

function windowDecal(text: string) {
  const t = canvasTexture(256, 128, (ctx, w, h) => {
    ctx.clearRect(0, 0, w, h);
    ctx.fillStyle = 'rgba(255,241,220,0.92)';
    ctx.font = '800 38px "Baloo 2", system-ui'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillText(text, w / 2, h / 2);
    ctx.strokeStyle = 'rgba(255,241,220,0.9)'; ctx.lineWidth = 4; roundRect(ctx, 8, 14, w - 16, h - 28, 20); ctx.stroke();
  });
  return new THREE.MeshBasicMaterial({ map: t, transparent: true, depthWrite: false });
}

function chalkBoard() {
  return canvasTexture(256, 400, (ctx, w, h) => {
    ctx.fillStyle = '#2d3436'; ctx.fillRect(0, 0, w, h);
    ctx.fillStyle = '#fdf6e3'; ctx.textAlign = 'center';
    ctx.font = '800 44px "Baloo 2", system-ui'; ctx.fillText('BUGÜN', w / 2, 70);
    ctx.font = '600 32px "Baloo 2", system-ui';
    ctx.fillStyle = '#f2b33d'; ctx.fillText('Simit + Ayran', w / 2, 150);
    ctx.fillStyle = '#fdf6e3'; ctx.fillText('~ taze ~', w / 2, 200);
    ctx.fillStyle = '#86d6b4'; ctx.fillText('Soğuk kola', w / 2, 270);
    ctx.strokeStyle = '#fdf6e3'; ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(40, 320); ctx.bezierCurveTo(90, 300, 160, 340, 216, 315); ctx.stroke();
  });
}
