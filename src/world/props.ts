import * as THREE from 'three';
import { PAL } from '../config';
import type { FixtureDef } from '../data/fixtures';
import { M, rbox, cyl, sphere, mat, glow } from './materials';
import { canvasTexture, roundRect } from './textures';
import { mergeByMaterial } from './merge';
import { buildCamera, buildGate, buildBreak, buildConveyorRegister, buildSelfCheckout, buildHangingSign, buildOven, buildCartStation, buildTable, buildPlayArea, buildBench } from './props2';

export interface SlotLayout {
  units: THREE.Matrix4[]; // local transforms, filled in order
  tag: THREE.Vector3; // price tag position (local)
  tagRotX?: number;
}

export interface FixtureModel {
  root: THREE.Group;
  slots: SlotLayout[];
  height: number;
  depotBoxes?: THREE.Object3D[];
  posDevice?: THREE.Object3D;
  led?: THREE.MeshStandardMaterial;
  alarmLight?: THREE.MeshStandardMaterial;
  belt?: THREE.Texture;
  ovenGlow?: THREE.MeshStandardMaterial;
  trays?: THREE.Object3D;
  seats?: THREE.Vector3[];
}

export function addMesh(parent: THREE.Object3D, geo: THREE.BufferGeometry, material: THREE.Material, x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = 0, shadow = true) {
  const m = new THREE.Mesh(geo, material);
  m.position.set(x, y, z); m.rotation.set(rx, ry, rz);
  m.castShadow = shadow; m.receiveShadow = true;
  parent.add(m);
  return m;
}

const U = (x: number, y: number, z: number, ry = 0, s = 1) =>
  new THREE.Matrix4().compose(new THREE.Vector3(x, y, z), new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), ry), new THREE.Vector3(s, s, s));

/** grid units: `levels` y values, columns spread over [x0,x1], filled column-by-column so shelves empty evenly */
function gridUnits(cap: number, levels: number[], x0: number, x1: number, z: number, jitter = 0.03, seed = 1) {
  const cols = Math.ceil(cap / levels.length);
  const out: THREE.Matrix4[] = [];
  let s = seed;
  const rnd = () => { s = (s * 16807) % 2147483647; return s / 2147483647; };
  for (let c = 0; c < cols; c++) for (let l = 0; l < levels.length; l++) {
    if (out.length >= cap) break;
    const t = cols === 1 ? 0.5 : c / (cols - 1);
    out.push(U(x0 + (x1 - x0) * t, levels[l], z + (rnd() - 0.5) * jitter, (rnd() - 0.5) * 0.25));
  }
  return out;
}

function pileUnits(cap: number, cx: number, cy: number, cz: number, rx: number, rz: number, layerH: number, seed = 3, tiltX = 0) {
  const out: THREE.Matrix4[] = [];
  let s = seed;
  const rnd = () => { s = (s * 16807) % 2147483647; return s / 2147483647; };
  const perLayer = Math.max(3, Math.round(cap / 2.2));
  for (let i = 0; i < cap; i++) {
    const layer = Math.floor(i / perLayer);
    const k = i % perLayer;
    const a = (k / perLayer) * Math.PI * 2 + layer * 0.7;
    const rr = (layer === 0 ? 0.75 : 0.45) * (0.6 + 0.4 * ((k % 2) ? 1 : 0.55));
    const x = cx + Math.cos(a) * rx * rr;
    const z = cz + Math.sin(a) * rz * rr;
    const y = cy + layer * layerH + (z - cz) * tiltX;
    const m = new THREE.Matrix4().compose(new THREE.Vector3(x, y, z),
      new THREE.Quaternion().setFromEuler(new THREE.Euler(tiltX * 0.8 + (rnd() - 0.5) * 0.3, rnd() * 6.28, (rnd() - 0.5) * 0.3)),
      new THREE.Vector3(1, 1, 1));
    out.push(m);
  }
  // reverse so the top of the pile disappears first when stock drops
  return out;
}

function headerTexture(text: string, bg: string, fg: string) {
  return canvasTexture(512, 96, (ctx, w, h) => {
    ctx.fillStyle = bg; roundRect(ctx, 0, 0, w, h, 18); ctx.fill();
    ctx.fillStyle = fg; ctx.font = '800 58px "Baloo 2", system-ui'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillText(text, w / 2, h * 0.56);
  });
}

const headerCache = new Map<string, THREE.Material>();
function headerMat(text: string, bg: string, fg: string, emissive = false) {
  const k = text + bg + fg + emissive;
  let m = headerCache.get(k);
  if (!m) {
    const t = headerTexture(text, bg, fg);
    m = new THREE.MeshStandardMaterial({ map: t, roughness: 0.5, emissive: emissive ? 0xffffff : 0x000000, emissiveMap: emissive ? t : null, emissiveIntensity: emissive ? 0.9 : 0 });
    headerCache.set(k, m);
  }
  return m;
}

// ---------------------------------------------------------------------------

function buildShelf(def: FixtureDef): FixtureModel {
  const g = new THREE.Group();
  const W = def.w - 0.12, D = 0.52, H = 1.9;
  const zc = -0.5 + D / 2 + 0.04; // hug the back of the tile
  addMesh(g, rbox(W, H, 0.05, 0.015), M.woodDark, 0, H / 2, zc - D / 2 + 0.025);
  addMesh(g, rbox(0.05, H, D, 0.015), M.woodDark, -W / 2 + 0.025, H / 2, zc);
  addMesh(g, rbox(0.05, H, D, 0.015), M.woodDark, W / 2 - 0.025, H / 2, zc);
  addMesh(g, rbox(W, 0.14, D, 0.02), M.teal, 0, 0.07, zc);
  const levels = [0.16, 0.66, 1.16];
  for (const y of [0.64, 1.14]) addMesh(g, rbox(W - 0.08, 0.035, D - 0.03, 0.01), M.wood, 0, y - 0.018, zc + 0.01);
  addMesh(g, rbox(W + 0.06, 0.08, D + 0.04, 0.02), M.wood, 0, H + 0.02, zc);
  // header signage
  const head = addMesh(g, rbox(W * 0.9, 0.24, 0.04, 0.02), headerMat(def.slots === 3 ? 'REYON' : 'KURU GIDA', '#1f8a86', '#fff1dc'), 0, H - 0.25, zc - D / 2 + 0.07);
  head.castShadow = false;
  // shelf edge strips
  for (const y of [0.14, 0.64, 1.14]) addMesh(g, rbox(W - 0.06, 0.05, 0.02, 0.008), M.terracotta, 0, y + 0.01, zc + D / 2 - 0.01, 0, 0, 0, false);
  const slots: SlotLayout[] = [];
  const n = def.slots!;
  const sw = (W - 0.12) / n;
  for (let s = 0; s < n; s++) {
    const x0 = -W / 2 + 0.06 + s * sw + 0.12, x1 = x0 + sw - 0.24;
    slots.push({ units: gridUnits(def.slotCapacity!, levels, x0, x1, zc + 0.04, 0.05, s + 7), tag: new THREE.Vector3((x0 + x1) / 2, 0.64 + 0.03, zc + D / 2 + 0.005) });
  }
  return { root: g, slots, height: H + 0.1 };
}

function buildGondola(def: FixtureDef): FixtureModel {
  const g = new THREE.Group();
  const W = def.w - 0.12, D = 0.7, H = 1.65;
  const zc = 0;
  const white = mat(0xf2f0ea, 0.45, 0.1);
  addMesh(g, rbox(W, 0.12, D, 0.02), mat(PAL.ink, 0.6), 0, 0.06, zc);
  addMesh(g, rbox(W, H, 0.06, 0.01), white, 0, H / 2, zc - 0.05);
  addMesh(g, rbox(0.05, H, D, 0.01), M.steelDark, -W / 2, H / 2, zc);
  addMesh(g, rbox(0.05, H, D, 0.01), M.steelDark, W / 2, H / 2, zc);
  const levels = [0.13, 0.6, 1.07];
  for (const y of [0.58, 1.05, 1.52]) {
    addMesh(g, rbox(W - 0.06, 0.03, D - 0.05, 0.008), white, 0, y, zc + 0.01);
    addMesh(g, rbox(W - 0.06, 0.05, 0.02, 0.008), M.mustard, 0, y, zc + D / 2 - 0.02, 0, 0, 0, false);
  }
  const head = addMesh(g, rbox(W * 0.95, 0.26, 0.05, 0.02), headerMat('MARKET REYONU', '#e0663c', '#fff1dc'), 0, H + 0.2, zc);
  head.castShadow = false;
  addMesh(g, cyl(0.02, 0.02, 0.2, 8), M.steelDark, -W * 0.3, H + 0.05, zc);
  addMesh(g, cyl(0.02, 0.02, 0.2, 8), M.steelDark, W * 0.3, H + 0.05, zc);
  const slots: SlotLayout[] = [];
  const n = def.slots!;
  const sw = (W - 0.1) / n;
  for (let s = 0; s < n; s++) {
    const x0 = -W / 2 + 0.05 + s * sw + 0.11, x1 = x0 + sw - 0.22;
    slots.push({ units: gridUnits(def.slotCapacity!, levels, x0, x1, zc + 0.12, 0.08, s + 3), tag: new THREE.Vector3((x0 + x1) / 2, 0.6, zc + D / 2 - 0.005) });
  }
  return { root: g, slots, height: H + 0.35 };
}

function buildFridge(def: FixtureDef): FixtureModel {
  const g = new THREE.Group();
  const W = 0.88, H = 2.05, D = 0.72;
  const zc = -0.5 + D / 2 + 0.03;
  const enamel = mat(0xf7f5f0, 0.35, 0.05);
  // shell (open box made of panels)
  addMesh(g, rbox(W, 0.2, D, 0.03), M.teal, 0, 0.1, zc);
  addMesh(g, rbox(W, 0.08, D, 0.03), enamel, 0, H - 0.04, zc);
  addMesh(g, rbox(0.05, H, D, 0.02), enamel, -W / 2 + 0.025, H / 2, zc);
  addMesh(g, rbox(0.05, H, D, 0.02), enamel, W / 2 - 0.025, H / 2, zc);
  addMesh(g, rbox(W, H, 0.04, 0.01), enamel, 0, H / 2, zc - D / 2 + 0.02);
  // inner glowing back panel
  const back = new THREE.Mesh(new THREE.PlaneGeometry(W - 0.12, H - 0.36), new THREE.MeshStandardMaterial({ color: 0xe6f6ff, emissive: 0xcdeeff, emissiveIntensity: 0.9, roughness: 0.4 }));
  back.position.set(0, H / 2 + 0.06, zc - D / 2 + 0.05); g.add(back);
  // wire shelves
  const levels = [0.22, 0.62, 1.02, 1.42];
  for (const y of levels) addMesh(g, rbox(W - 0.1, 0.02, D - 0.1, 0.005), M.steel, 0, y - 0.012, zc, 0, 0, 0, false);
  // header
  const head = addMesh(g, rbox(W, 0.26, 0.05, 0.02), headerMat('SOĞUK', '#1f8a86', '#ffffff', true), 0, H + 0.05, zc + D / 2 - 0.03);
  head.castShadow = false;
  // glass door with frame
  const door = new THREE.Group();
  door.position.set(0, 0, zc + D / 2 + 0.01);
  addMesh(door, rbox(W - 0.04, 0.05, 0.04, 0.01), M.steelDark, 0, 0.22, 0);
  addMesh(door, rbox(W - 0.04, 0.05, 0.04, 0.01), M.steelDark, 0, H - 0.1, 0);
  addMesh(door, rbox(0.05, H - 0.3, 0.04, 0.01), M.steelDark, -W / 2 + 0.04, H / 2 + 0.06, 0);
  addMesh(door, rbox(0.05, H - 0.3, 0.04, 0.01), M.steelDark, W / 2 - 0.04, H / 2 + 0.06, 0);
  addMesh(door, rbox(0.03, 0.5, 0.05, 0.012), M.steel, W / 2 - 0.1, 1.15, 0.04);
  const glassPane = new THREE.Mesh(new THREE.PlaneGeometry(W - 0.1, H - 0.34), M.glass);
  glassPane.position.set(0, H / 2 + 0.06, 0); glassPane.renderOrder = 2; door.add(glassPane);
  g.add(door);
  // subtle cold light spill
  const slots: SlotLayout[] = [];
  const upper = [levels[2], levels[3]], lower = [levels[0], levels[1]];
  slots.push({ units: gridUnits(def.slotCapacity!, upper, -0.28, 0.28, zc + 0.02, 0.06, 5), tag: new THREE.Vector3(0.2, 1.0, zc + D / 2 + 0.05) });
  slots.push({ units: gridUnits(def.slotCapacity!, lower, -0.28, 0.28, zc + 0.02, 0.06, 9), tag: new THREE.Vector3(0.2, 0.2, zc + D / 2 + 0.05) });
  return { root: g, slots, height: H + 0.2 };
}

function buildOpenChiller(def: FixtureDef): FixtureModel {
  const g = new THREE.Group();
  const W = def.w - 0.1, H = 1.95, D = 0.85;
  const zc = -0.5 + D / 2 + 0.03;
  const enamel = mat(0xf7f5f0, 0.35, 0.05);
  addMesh(g, rbox(W, 0.45, D, 0.03), M.teal, 0, 0.225, zc + 0.02);
  addMesh(g, rbox(W, 0.3, D * 0.6, 0.03), enamel, 0, H - 0.15, zc - D * 0.2);
  addMesh(g, rbox(0.06, H, D, 0.02), enamel, -W / 2, H / 2, zc);
  addMesh(g, rbox(0.06, H, D, 0.02), enamel, W / 2, H / 2, zc);
  addMesh(g, rbox(W, H, 0.05, 0.01), enamel, 0, H / 2, zc - D / 2 + 0.025);
  const back = new THREE.Mesh(new THREE.PlaneGeometry(W - 0.14, H - 0.8), new THREE.MeshStandardMaterial({ color: 0xe6f6ff, emissive: 0xcdeeff, emissiveIntensity: 0.8 }));
  back.position.set(0, 1.12, zc - D / 2 + 0.06); g.add(back);
  const levels = [0.47, 0.93, 1.35];
  for (const [i, y] of levels.entries()) {
    const depth = D - 0.18 - i * 0.12;
    addMesh(g, rbox(W - 0.14, 0.025, depth, 0.005), M.steel, 0, y - 0.015, zc - D / 2 + depth / 2 + 0.06, 0, 0, 0, false);
    addMesh(g, rbox(W - 0.14, 0.05, 0.02, 0.005), M.terracotta, 0, y, zc - D / 2 + depth + 0.06, 0, 0, 0, false);
  }
  const head = addMesh(g, rbox(W * 0.9, 0.22, 0.04, 0.02), headerMat('SÜT & SOĞUK', '#136361', '#ffffff', true), 0, H - 0.12, zc + 0.12);
  head.castShadow = false;
  const slots: SlotLayout[] = [];
  const n = def.slots!;
  const sw = (W - 0.2) / n;
  for (let s = 0; s < n; s++) {
    const x0 = -W / 2 + 0.1 + s * sw + 0.1, x1 = x0 + sw - 0.2;
    slots.push({ units: gridUnits(def.slotCapacity!, [levels[0], levels[1]], x0, x1, zc + 0.05, 0.08, s + 2).map((m, i) => i % 2 ? m : m), tag: new THREE.Vector3((x0 + x1) / 2, 0.47, zc - D / 2 + D - 0.12 + 0.06) });
  }
  return { root: g, slots, height: H };
}

function wickerMat() {
  const t = canvasTexture(128, 128, (ctx, w, h) => {
    ctx.fillStyle = '#b8864f'; ctx.fillRect(0, 0, w, h);
    for (let y = 0; y < h; y += 8) for (let x = 0; x < w; x += 16) {
      ctx.fillStyle = ((x + y) / 8) % 2 ? '#d6a567' : '#a0703e';
      ctx.fillRect(x + ((y / 8) % 2) * 8, y, 12, 6);
    }
  }, { repeat: [3, 1] });
  // open basket shells: draw both sides, otherwise the far half vanishes and the wall shows through
  return new THREE.MeshStandardMaterial({ map: t, roughness: 0.85, side: THREE.DoubleSide });
}
let _wicker: THREE.Material | null = null;

function buildBasket(def: FixtureDef): FixtureModel {
  const g = new THREE.Group();
  const wick = _wicker ??= wickerMat();
  // wooden stepped stand
  addMesh(g, rbox(0.86, 0.5, 0.36, 0.02), M.wood, 0, 0.25, 0.15);
  addMesh(g, rbox(0.86, 0.95, 0.36, 0.02), M.wood, 0, 0.475, -0.22);
  addMesh(g, rbox(0.9, 0.06, 0.8, 0.02), M.woodDark, 0, 0.03, -0.02);
  // baskets (shallow, open)
  const mkBasket = (y: number, z: number) => {
    const b = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.32, 0.14, 20, 1, true), wick);
    b.scale.set(1, 1, 0.45); b.position.set(0, y + 0.07, z); b.castShadow = true; b.receiveShadow = true;
    const base = new THREE.Mesh(new THREE.CircleGeometry(0.32, 20), wick);
    base.rotation.x = -Math.PI / 2; base.scale.set(1, 0.45, 1); base.position.set(0, y + 0.005, z);
    const cloth = new THREE.Mesh(new THREE.CircleGeometry(0.3, 20), mat(0xf0e2c8, 0.9));
    cloth.rotation.x = -Math.PI / 2; cloth.scale.set(1, 0.42, 1); cloth.position.set(0, y + 0.012, z);
    g.add(b, base, cloth);
  };
  mkBasket(0.95, -0.22);
  mkBasket(0.5, 0.15);
  // chalk sign
  const sign = new THREE.Mesh(new THREE.PlaneGeometry(0.34, 0.2), headerMat('TAZE', '#2d3436', '#fdf6e3'));
  sign.position.set(0.3, 1.25, -0.2); sign.rotation.y = -0.2; g.add(sign);
  addMesh(g, cyl(0.008, 0.008, 0.3), M.woodDark, 0.3, 1.1, -0.21);
  const slots: SlotLayout[] = [
    { units: pileUnits(def.slotCapacity!, 0, 0.97, -0.22, 0.28, 0.1, 0.05, 4), tag: new THREE.Vector3(-0.25, 0.97, -0.02) },
    { units: pileUnits(def.slotCapacity!, 0, 0.52, 0.15, 0.28, 0.1, 0.05, 8), tag: new THREE.Vector3(-0.25, 0.5, 0.34) },
  ];
  return { root: g, slots, height: 1.4 };
}

function buildProduce(def: FixtureDef): FixtureModel {
  const g = new THREE.Group();
  const W = def.w - 0.14;
  // A-frame stand
  addMesh(g, rbox(W, 0.7, 0.8, 0.03), M.woodDark, 0, 0.35, -0.05);
  const grass = mat(0x6fbf5a, 0.95);
  const slots: SlotLayout[] = [];
  const n = def.slots!;
  const sw = W / n;
  for (let s = 0; s < n; s++) {
    const cx = -W / 2 + sw * (s + 0.5);
    const crate = new THREE.Group();
    crate.position.set(cx, 0.78, 0.0); crate.rotation.x = 0.28;
    addMesh(crate, rbox(sw - 0.08, 0.04, 0.72, 0.01), M.wood, 0, 0, 0);
    for (const side of [-1, 1]) addMesh(crate, rbox(0.03, 0.16, 0.72, 0.01), M.wood, side * (sw / 2 - 0.055), 0.07, 0);
    for (const side of [-1, 1]) addMesh(crate, rbox(sw - 0.08, 0.16, 0.03, 0.01), M.wood, 0, 0.07, side * 0.35);
    addMesh(crate, rbox(sw - 0.14, 0.01, 0.66, 0.004), grass, 0, 0.025, 0, 0, 0, 0, false);
    g.add(crate);
    // units in world-ish local space (approximate the tilt)
    const units = pileUnits(def.slotCapacity!, cx, 0.82, 0.0, sw * 0.36, 0.28, 0.07, s + 11, -0.28);
    slots.push({ units, tag: new THREE.Vector3(cx, 0.72, 0.42) });
  }
  const sign = new THREE.Mesh(new THREE.PlaneGeometry(0.7, 0.2), headerMat('MANAV', '#3f8f3a', '#fff'));
  sign.position.set(0, 1.35, -0.4); g.add(sign);
  addMesh(g, cyl(0.015, 0.015, 0.7), M.woodDark, -0.3, 1.0, -0.42);
  addMesh(g, cyl(0.015, 0.015, 0.7), M.woodDark, 0.3, 1.0, -0.42);
  return { root: g, slots, height: 1.5 };
}

function buildRegister(def: FixtureDef): FixtureModel {
  const g = new THREE.Group();
  const W = def.w - 0.08, D = 0.7, H = 0.98;
  // counter body with teal front + wood side
  addMesh(g, rbox(W, H - 0.06, D, 0.03), M.cream, 0, (H - 0.06) / 2, 0);
  addMesh(g, rbox(W + 0.02, H * 0.72, 0.04, 0.02), M.teal, 0, H * 0.4, D / 2 + 0.01);
  // decorative slats on front
  for (let i = 0; i < 9; i++) addMesh(g, rbox(0.05, H * 0.62, 0.03, 0.01), M.tealDark, -W / 2 + 0.12 + i * (W - 0.24) / 8, H * 0.4, D / 2 + 0.035, 0, 0, 0, false);
  addMesh(g, rbox(W + 0.08, 0.06, D + 0.08, 0.02), M.wood, 0, H - 0.03, 0);
  addMesh(g, rbox(W, 0.08, D, 0.02), M.ink, 0, 0.04, 0);
  // cash register machine
  const reg = new THREE.Group(); reg.position.set(-0.35, H, -0.05); g.add(reg);
  addMesh(reg, rbox(0.38, 0.1, 0.34, 0.02), M.ink, 0, 0.05, 0);
  addMesh(reg, rbox(0.3, 0.05, 0.2, 0.01), mat(0x3a4560, 0.5), 0, 0.12, 0.04, -0.3);
  const screen = addMesh(reg, rbox(0.26, 0.18, 0.03, 0.01), M.ink, 0, 0.26, -0.1, -0.2);
  const disp = new THREE.Mesh(new THREE.PlaneGeometry(0.22, 0.13), glow(0x7fe3c8, 1.2));
  disp.position.set(0, 0, 0.017); screen.add(disp);
  addMesh(reg, cyl(0.02, 0.02, 0.12), M.steelDark, 0, 0.17, -0.12);
  // bag holder + receipt roll
  addMesh(g, rbox(0.3, 0.02, 0.2, 0.005), M.steelDark, 0.45, H + 0.01, 0.05);
  for (let i = 0; i < 4; i++) addMesh(g, rbox(0.26, 0.03, 0.17, 0.02), mat(0xfaf4e8, 0.9), 0.45, H + 0.035 + i * 0.03, 0.05, 0, 0.05 * i, 0, false);
  // candy dish on counter (static)
  const dish = addMesh(g, cyl(0.12, 0.08, 0.06, 16), M.glass, 0.05, H + 0.03, 0.2);
  dish.castShadow = false;
  const candyCols = [0xef476f, 0xffd166, 0x06d6a0, 0x118ab2];
  for (let i = 0; i < 8; i++) addMesh(g, sphere(0.022, 8, 6), mat(candyCols[i % 4], 0.3), 0.05 + Math.cos(i) * 0.06, H + 0.05, 0.2 + Math.sin(i) * 0.06, 0, 0, 0, false);
  // POS terminal (upgrade)
  const pos = new THREE.Group(); pos.position.set(0.15, H, 0.24); pos.visible = false;
  addMesh(pos, rbox(0.09, 0.16, 0.05, 0.015), M.ink, 0, 0.08, 0, -0.35);
  const posScreen = new THREE.Mesh(new THREE.PlaneGeometry(0.06, 0.05), glow(0x61d4ff, 1.4)); posScreen.position.set(0, 0.12, 0.03); posScreen.rotation.x = -0.35; pos.add(posScreen);
  g.add(pos);
  return { root: g, slots: [], height: 1.4, posDevice: pos };
}

function buildDepot(def: FixtureDef): FixtureModel {
  const g = new THREE.Group();
  const W = def.w - 0.1, D = 0.6, H = 2.1;
  const zc = -0.5 + D / 2 + 0.04;
  const post = mat(0x2f5d8a, 0.5, 0.4);
  for (const x of [-W / 2 + 0.03, W / 2 - 0.03]) for (const z of [zc - D / 2 + 0.03, zc + D / 2 - 0.03]) addMesh(g, rbox(0.05, H, 0.05, 0.008), post, x, H / 2, z);
  const beams = [0.1, 0.8, 1.5];
  for (const y of beams) {
    addMesh(g, rbox(W, 0.06, 0.05, 0.008), M.terracotta, 0, y, zc + D / 2 - 0.03);
    addMesh(g, rbox(W, 0.06, 0.05, 0.008), M.terracotta, 0, y, zc - D / 2 + 0.03);
    addMesh(g, rbox(W - 0.04, 0.02, D - 0.04, 0.004), M.woodDark, 0, y + 0.04, zc, 0, 0, 0, false);
  }
  const boxes: THREE.Object3D[] = [];
  const card = mat(0xc89b63, 0.85);
  const tape = mat(0xe8d6b2, 0.7);
  let k = 0;
  for (const y of beams) {
    for (let i = 0; i < 4; i++) {
      const bw = 0.36 + ((k * 37) % 7) * 0.012, bh = 0.3 + ((k * 13) % 5) * 0.04;
      const b = new THREE.Group();
      b.position.set(-W / 2 + 0.25 + i * (W - 0.5) / 3, y + 0.05 + bh / 2, zc + (((k * 7) % 3) - 1) * 0.03);
      b.rotation.y = (((k * 11) % 5) - 2) * 0.04;
      addMesh(b, rbox(bw, bh, 0.42, 0.015), card, 0, 0, 0);
      addMesh(b, rbox(0.06, 0.005, 0.43, 0.002), tape, 0, bh / 2 + 0.002, 0, 0, 0, 0, false);
      g.add(b); boxes.push(b); k++;
    }
  }
  const sign = new THREE.Mesh(new THREE.PlaneGeometry(0.8, 0.16), headerMat('DEPO', '#2f5d8a', '#fff'));
  sign.position.set(0, H + 0.1, zc + D / 2 - 0.02); g.add(sign);
  return { root: g, slots: [], height: H + 0.2, depotBoxes: boxes };
}

function buildPlant(): FixtureModel {
  const g = new THREE.Group();
  const pot = mat(PAL.terracotta, 0.8);
  addMesh(g, cyl(0.26, 0.2, 0.46, 20), pot, 0, 0.23, 0);
  addMesh(g, cyl(0.28, 0.28, 0.06, 20), mat(PAL.terracottaDark, 0.8), 0, 0.45, 0);
  addMesh(g, cyl(0.24, 0.24, 0.02, 16), mat(0x5b3a24, 1), 0, 0.47, 0, 0, 0, 0, false);
  const leafMats = [mat(0x4e9a51, 0.7), mat(0x6cbf5f, 0.7), mat(0x3f7f46, 0.7)];
  const leafGeo = new THREE.SphereGeometry(0.17, 8, 6); leafGeo.scale(1, 0.35, 0.6);
  for (let i = 0; i < 16; i++) {
    const a = i * 2.4, h = 0.55 + (i / 16) * 0.8;
    const stem = addMesh(g, cyl(0.008, 0.01, h - 0.4), mat(0x4b7a3a, 0.8), Math.cos(a) * 0.05, 0.47 + (h - 0.4) / 2, Math.sin(a) * 0.05, Math.sin(a) * 0.2, 0, Math.cos(a) * 0.2, false);
    void stem;
    const leaf = addMesh(g, leafGeo, leafMats[i % 3], Math.cos(a) * (0.12 + (i % 3) * 0.05), h + 0.1, Math.sin(a) * (0.12 + (i % 3) * 0.05), 0.2, -a, 0.35 + (i % 4) * 0.1);
    void leaf;
  }
  return { root: g, slots: [], height: 1.5 };
}

function buildBin(): FixtureModel {
  const g = new THREE.Group();
  addMesh(g, cyl(0.2, 0.17, 0.62, 20), M.steel, 0, 0.31, 0);
  addMesh(g, cyl(0.205, 0.205, 0.07, 20), M.teal, 0, 0.5, 0);
  addMesh(g, cyl(0.21, 0.21, 0.05, 20), M.steelDark, 0, 0.65, 0);
  addMesh(g, sphere(0.05, 10, 8), M.steelDark, 0, 0.68, 0);
  addMesh(g, rbox(0.12, 0.02, 0.08, 0.005), M.black, 0, 0.02, 0.2);
  return { root: g, slots: [], height: 0.9 };
}

export function buildFixtureModel(def: FixtureDef): FixtureModel {
  const m = buildRaw(def);
  m.depotBoxes?.forEach((b) => (b.userData.dynamic = true));
  if (m.posDevice) m.posDevice.userData.dynamic = true;
  mergeByMaterial(m.root);
  return m;
}

function buildRaw(def: FixtureDef): FixtureModel {
  switch (def.id) {
    case 'raf': return buildShelf(def);
    case 'gondol': return buildGondola(def);
    case 'dolap': return buildFridge(def);
    case 'acik': return buildOpenChiller(def);
    case 'sepet': return buildBasket(def);
    case 'manav': return buildProduce(def);
    case 'kasa': return buildRegister(def);
    case 'depo': return buildDepot(def);
    case 'saksi': return buildPlant();
    case 'cop': return buildBin();
    case 'kamera': return buildCamera();
    case 'alarm': return buildGate();
    case 'cay': return buildBreak();
    case 'bantkasa': return buildConveyorRegister(def);
    case 'selfkasa': return buildSelfCheckout();
    case 'levha': return buildHangingSign();
    case 'firin': return buildOven();
    case 'araba': return buildCartStation();
    case 'masa': return buildTable();
    case 'oyunalani': return buildPlayArea();
    case 'bank': return buildBench();
  }
  throw new Error('unknown fixture ' + def.id);
}

// price tag textures ---------------------------------------------------------
const tagCache = new Map<string, THREE.Material>();
export function priceTagMaterial(price: number | null, state: 'ok' | 'low' | 'empty' | 'none' | 'sale') {
  const key = `${price}:${state}`;
  let m = tagCache.get(key);
  if (!m) {
    const t = canvasTexture(128, 64, (ctx, w, h) => {
      const bg = state === 'empty' ? '#e5484d' : state === 'low' ? '#f2b33d' : state === 'none' ? '#8a94a6' : state === 'sale' ? '#d6333a' : '#fffdf7';
      ctx.fillStyle = bg; roundRect(ctx, 2, 2, w - 4, h - 4, 10); ctx.fill();
      ctx.fillStyle = state === 'ok' ? '#1f2a44' : state === 'sale' ? '#ffd84a' : '#fff';
      ctx.font = '800 38px "Baloo 2", system-ui'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ctx.fillText(price == null ? '—' : `₺${price}`, w / 2, h / 2 + 3);
    });
    m = new THREE.MeshBasicMaterial({ map: t, toneMapped: false });
    tagCache.set(key, m);
  }
  return m;
}
