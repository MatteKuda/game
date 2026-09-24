// Models for the systems added after the vertical slice: security, staff break, supermarket and AVM furniture.
import * as THREE from 'three';
import { PAL } from '../config';
import type { FixtureDef } from '../data/fixtures';
import { M, rbox, cyl, sphere, mat, glow } from './materials';
import { canvasTexture, roundRect } from './textures';
import { addMesh, type FixtureModel } from './props';

function signMat(text: string, bg: string, fg: string, w = 512, h = 128, emissive = false) {
  const t = canvasTexture(w, h, (ctx) => {
    ctx.fillStyle = bg; roundRect(ctx, 0, 0, w, h, h * 0.2); ctx.fill();
    ctx.fillStyle = fg; ctx.font = `800 ${h * 0.52}px "Baloo 2", system-ui`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillText(text, w / 2, h * 0.56);
  });
  return new THREE.MeshStandardMaterial({ map: t, roughness: 0.5, emissive: emissive ? 0xffffff : 0, emissiveMap: emissive ? t : null, emissiveIntensity: emissive ? 0.7 : 0 });
}

export function buildCamera(): FixtureModel {
  const g = new THREE.Group();
  const dark = mat(0x2b3448, 0.4, 0.5);
  addMesh(g, cyl(0.02, 0.02, 0.5, 6), M.steel, 0, 2.85, 0, 0, 0, 0, false);
  addMesh(g, cyl(0.09, 0.09, 0.05, 16), dark, 0, 2.6, 0, 0, 0, 0, false);
  const dome = addMesh(g, new THREE.SphereGeometry(0.11, 16, 10, 0, Math.PI * 2, Math.PI / 2, Math.PI / 2), new THREE.MeshPhysicalMaterial({ color: 0x1b1f2a, roughness: 0.05, metalness: 0.2, clearcoat: 1 }), 0, 2.58, 0, 0, 0, 0, false);
  void dome;
  const led = addMesh(g, sphere(0.018, 8, 6), glow(0xff3344, 3), 0.07, 2.53, 0.05, 0, 0, 0, false);
  led.userData.dynamic = true;
  return { root: g, slots: [], height: 2.2, led: led.material as THREE.MeshStandardMaterial };
}

export function buildGate(): FixtureModel {
  const g = new THREE.Group();
  const panel = new THREE.MeshPhysicalMaterial({ color: 0xdfe8ee, roughness: 0.1, transparent: true, opacity: 0.55, clearcoat: 1 });
  for (const x of [-0.32, 0.32]) {
    addMesh(g, rbox(0.12, 1.5, 0.34, 0.04), M.steel, x, 0.75, 0);
    const p = addMesh(g, rbox(0.04, 1.3, 0.3, 0.02), panel, x + (x > 0 ? -0.08 : 0.08), 0.75, 0, 0, 0, 0, false);
    p.renderOrder = 2;
  }
  const lightMat = new THREE.MeshStandardMaterial({ color: 0x8a1f28, emissive: 0xff2d3d, emissiveIntensity: 0.05 });
  const light = new THREE.Group(); light.userData.dynamic = true;
  for (const x of [-0.32, 0.32]) addMesh(light, rbox(0.14, 0.08, 0.36, 0.03), lightMat, x, 1.54, 0, 0, 0, 0, false);
  g.add(light);
  addMesh(g, rbox(0.8, 0.02, 0.4, 0.01), mat(0x2a2d33, 0.8), 0, 0.01, 0, 0, 0, 0, false);
  return { root: g, slots: [], height: 1.8, alarmLight: lightMat };
}

export function buildBreak(): FixtureModel {
  const g = new THREE.Group();
  // counter with a double teapot (çaydanlık), tea glasses and two stools
  addMesh(g, rbox(1.7, 0.9, 0.5, 0.03), M.woodDark, 0, 0.45, -0.2);
  addMesh(g, rbox(1.76, 0.05, 0.56, 0.02), mat(0xf6efe3, 0.4), 0, 0.92, -0.2);
  addMesh(g, rbox(0.4, 0.06, 0.3, 0.02), M.steelDark, -0.45, 0.97, -0.25);
  const steel = mat(0xd8dde2, 0.2, 0.9);
  addMesh(g, cyl(0.13, 0.15, 0.24, 18), steel, -0.45, 1.12, -0.25);
  addMesh(g, cyl(0.09, 0.11, 0.16, 18), steel, -0.45, 1.32, -0.25);
  addMesh(g, cyl(0.02, 0.02, 0.1, 6), steel, -0.33, 1.34, -0.25, 0, 0, -0.9);
  const glass = new THREE.MeshPhysicalMaterial({ color: 0xb8471f, roughness: 0.05, transmission: 0, transparent: true, opacity: 0.85 });
  for (let i = 0; i < 4; i++) {
    addMesh(g, cyl(0.03, 0.022, 0.08, 10), glass, 0.05 + i * 0.12, 0.98, -0.12, 0, 0, 0, false);
    addMesh(g, cyl(0.045, 0.045, 0.005, 12), mat(0xffffff, 0.3), 0.05 + i * 0.12, 0.945, -0.12, 0, 0, 0, false);
  }
  for (const x of [-0.4, 0.4]) {
    addMesh(g, cyl(0.17, 0.17, 0.05, 16), M.terracotta, x, 0.5, 0.25);
    addMesh(g, cyl(0.025, 0.025, 0.48, 8), M.steelDark, x, 0.25, 0.25);
    addMesh(g, cyl(0.14, 0.14, 0.02, 12), M.steelDark, x, 0.02, 0.25);
  }
  const sign = new THREE.Mesh(new THREE.PlaneGeometry(0.8, 0.22), signMat('MOLA', '#b44a28', '#fff1dc'));
  sign.position.set(0.3, 1.5, -0.44); g.add(sign);
  return { root: g, slots: [], height: 1.7 };
}

export function buildConveyorRegister(def: FixtureDef): FixtureModel {
  const g = new THREE.Group();
  const W = def.w - 0.1, D = 0.72, H = 0.9;
  addMesh(g, rbox(W, H - 0.05, D, 0.03), mat(0xf2f0ea, 0.45), 0, (H - 0.05) / 2, 0);
  addMesh(g, rbox(W + 0.02, H * 0.72, 0.03, 0.01), M.teal, 0, H * 0.4, D / 2 + 0.01);
  addMesh(g, rbox(W, 0.08, D, 0.02), M.ink, 0, 0.04, 0);
  // conveyor belt with scrolling texture
  const bt = canvasTexture(64, 256, (ctx, w, h) => {
    ctx.fillStyle = '#23262c'; ctx.fillRect(0, 0, w, h);
    ctx.strokeStyle = '#3a3f48'; ctx.lineWidth = 3;
    for (let y = 0; y < h; y += 16) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke(); }
  }, { repeat: [1, 4] });
  const belt = new THREE.Mesh(new THREE.PlaneGeometry(0.5, W * 0.62), new THREE.MeshStandardMaterial({ map: bt, roughness: 0.8 }));
  belt.rotation.set(-Math.PI / 2, 0, Math.PI / 2); belt.position.set(-W * 0.18, H + 0.012, 0.02);
  belt.userData.dynamic = true; g.add(belt);
  addMesh(g, rbox(W * 0.64, 0.05, 0.06, 0.02), M.steel, -W * 0.18, H + 0.02, 0.29, 0, 0, 0, false);
  addMesh(g, rbox(W * 0.64, 0.05, 0.06, 0.02), M.steel, -W * 0.18, H + 0.02, -0.25, 0, 0, 0, false);
  // divider bars
  addMesh(g, rbox(0.04, 0.05, 0.4, 0.01), mat(0xf2b33d, 0.5), -W * 0.3, H + 0.04, 0.02, 0, 0, 0, false);
  // register terminal + scanner
  const t = new THREE.Group(); t.position.set(W * 0.3, H, -0.05); g.add(t);
  addMesh(t, rbox(0.3, 0.08, 0.3, 0.02), M.ink, 0, 0.04, 0);
  const scr = addMesh(t, rbox(0.3, 0.2, 0.03, 0.01), M.ink, 0, 0.32, -0.1, -0.25);
  const disp = new THREE.Mesh(new THREE.PlaneGeometry(0.26, 0.15), glow(0x7fe3c8, 1.2)); disp.position.z = 0.017; scr.add(disp);
  addMesh(t, cyl(0.02, 0.02, 0.18, 8), M.steelDark, 0, 0.17, -0.1);
  addMesh(g, rbox(0.3, 0.02, 0.22, 0.01), mat(0x1b1f2a, 0.2), W * 0.1, H + 0.012, 0.05, 0, 0, 0, false);
  addMesh(g, rbox(0.2, 0.01, 0.1, 0.005), glow(0xff4a4a, 0.8), W * 0.1, H + 0.024, 0.05, 0, 0, 0, false);
  // lane number pole
  addMesh(g, cyl(0.025, 0.025, 1.3, 8), M.steelDark, -W / 2 + 0.1, H + 0.65, -0.3);
  const lane = new THREE.Mesh(new THREE.CylinderGeometry(0.16, 0.16, 0.08, 20), glow(0x1f8a86, 0.9));
  lane.rotation.x = Math.PI / 2; lane.position.set(-W / 2 + 0.1, H + 1.35, -0.3); g.add(lane);
  const pos = new THREE.Group(); pos.position.set(W * 0.3 + 0.2, H, 0.24); pos.visible = false;
  addMesh(pos, rbox(0.09, 0.16, 0.05, 0.015), M.ink, 0, 0.08, 0, -0.35); g.add(pos);
  return { root: g, slots: [], height: 1.6, posDevice: pos, belt: bt };
}

export function buildSelfCheckout(): FixtureModel {
  const g = new THREE.Group();
  addMesh(g, rbox(0.62, 0.9, 0.5, 0.04), mat(0xf2f0ea, 0.4), 0, 0.45, -0.1);
  addMesh(g, rbox(0.64, 0.06, 0.55, 0.02), M.teal, 0, 0.92, -0.08);
  addMesh(g, rbox(0.08, 0.7, 0.08, 0.02), M.ink, 0, 1.3, -0.3);
  const scr = addMesh(g, rbox(0.42, 0.3, 0.04, 0.02), M.ink, 0, 1.55, -0.22, -0.3);
  const disp = new THREE.Mesh(new THREE.PlaneGeometry(0.36, 0.24), glow(0x61d4ff, 1.1)); disp.position.z = 0.022; scr.add(disp);
  addMesh(g, rbox(0.22, 0.02, 0.18, 0.01), mat(0x1b1f2a, 0.2), -0.1, 0.96, 0.02, 0, 0, 0, false);
  addMesh(g, rbox(0.14, 0.01, 0.06, 0.005), glow(0xff4a4a, 0.8), -0.1, 0.972, 0.02, 0, 0, 0, false);
  addMesh(g, rbox(0.03, 0.4, 0.03, 0.01), M.steel, 0.24, 1.15, 0.1, 0, 0, 0, false);
  addMesh(g, rbox(0.2, 0.28, 0.02, 0.01), mat(0xfaf6ea, 0.9), 0.24, 1.05, 0.12, 0, 0, 0, false);
  const top = new THREE.Mesh(new THREE.PlaneGeometry(0.5, 0.14), signMat('KENDİN ÖDE', '#1f8a86', '#fff', 512, 128, true));
  top.position.set(0, 1.9, -0.24); g.add(top);
  return { root: g, slots: [], height: 2.0 };
}

const CATS = ['KAHVALTILIK', 'İÇECEKLER', 'ATIŞTIRMALIK', 'TEMEL GIDA', 'TEMİZLİK', 'MANAV', 'SÜT ÜRÜNLERİ', 'FIRIN'];
const CAT_COL = ['#f2b33d', '#1f8a86', '#e0663c', '#6c4ab6', '#2f6fb5', '#3f8f3a', '#136361', '#b44a28'];
let signCounter = 0;
export function buildHangingSign(): FixtureModel {
  const g = new THREE.Group();
  const i = signCounter++ % CATS.length;
  addMesh(g, cyl(0.006, 0.006, 0.7, 4), M.steelDark, -0.35, 2.95, 0, 0, 0, 0, false);
  addMesh(g, cyl(0.006, 0.006, 0.7, 4), M.steelDark, 0.35, 2.95, 0, 0, 0, 0, false);
  const board = new THREE.Group(); board.position.y = 2.45;
  const m = signMat(CATS[i], CAT_COL[i], '#ffffff', 512, 128, true);
  addMesh(board, rbox(0.95, 0.3, 0.04, 0.03), M.cream, 0, 0, 0, 0, 0, 0, false);
  for (const z of [0.022, -0.022]) {
    const face = new THREE.Mesh(new THREE.PlaneGeometry(0.9, 0.26), m);
    face.position.z = z; if (z < 0) face.rotation.y = Math.PI; board.add(face);
  }
  g.add(board);
  return { root: g, slots: [], height: 2.2 };
}

export function buildOven(): FixtureModel {
  const g = new THREE.Group();
  // stone/tile oven with glowing mouth + dough table
  const tile = mat(0xe8dccb, 0.6);
  addMesh(g, rbox(1.1, 1.0, 0.8, 0.05), tile, -0.4, 0.5, -0.05);
  const dome = addMesh(g, new THREE.SphereGeometry(0.55, 20, 12, 0, Math.PI * 2, 0, Math.PI / 2), mat(0xb44a28, 0.8), -0.4, 1.0, -0.05);
  dome.scale.set(1, 0.8, 0.75);
  addMesh(g, cyl(0.09, 0.09, 0.9, 12), mat(0x5b5f68, 0.5, 0.4), -0.4, 1.7, -0.25);
  const glowMat = new THREE.MeshStandardMaterial({ color: 0x2a0f05, emissive: 0xff7a2a, emissiveIntensity: 0.4 });
  const mouth = new THREE.Mesh(new THREE.CircleGeometry(0.22, 20, 0, Math.PI), glowMat);
  mouth.position.set(-0.4, 0.78, 0.36); mouth.userData.dynamic = true; g.add(mouth);
  addMesh(g, rbox(0.62, 0.05, 0.3, 0.02), mat(0x5b3a24, 0.7), -0.4, 0.74, 0.46, 0, 0, 0, false);
  // wooden dough table with simit rings
  addMesh(g, rbox(0.8, 0.85, 0.6, 0.03), M.wood, 0.5, 0.425, 0);
  addMesh(g, rbox(0.84, 0.04, 0.64, 0.02), mat(0xf3e6cc, 0.9), 0.5, 0.87, 0);
  const ring = new THREE.TorusGeometry(0.07, 0.026, 8, 16); ring.rotateX(Math.PI / 2);
  for (let i = 0; i < 6; i++) addMesh(g, ring, mat(0xf0d7a5, 0.9), 0.3 + (i % 3) * 0.2, 0.91, -0.1 + Math.floor(i / 3) * 0.2, 0, 0, 0, false);
  addMesh(g, rbox(0.9, 0.03, 0.12, 0.01), M.woodDark, 0.5, 1.05, -0.2, 0.3, 0.3, 0, false);
  const sign = new THREE.Mesh(new THREE.PlaneGeometry(0.9, 0.24), signMat('TAŞ FIRIN', '#b44a28', '#fff1dc', 512, 128, true));
  sign.position.set(0, 2.0, -0.4); g.add(sign);
  return { root: g, slots: [], height: 2.2, ovenGlow: glowMat };
}

export function buildCartStation(): FixtureModel {
  const g = new THREE.Group();
  const wire = mat(0xd9dfe6, 0.3, 0.7), red = mat(0xe0453a, 0.5), dark = mat(0x2a2d33, 0.8);
  addMesh(g, rbox(1.8, 0.05, 0.7, 0.02), mat(0x4a4f58, 0.8), 0, 0.03, 0, 0, 0, 0, false);
  for (const z of [-0.33, 0.33]) addMesh(g, rbox(1.8, 0.04, 0.04, 0.01), M.steel, 0, 0.9, z);
  for (const x of [-0.88, 0.88]) for (const z of [-0.33, 0.33]) addMesh(g, cyl(0.02, 0.02, 0.9, 6), M.steel, x, 0.45, z);
  for (let i = 0; i < 4; i++) {
    const c = new THREE.Group(); c.position.set(-0.55 + i * 0.3, 0, 0);
    addMesh(c, rbox(0.4, 0.32, 0.58, 0.03), wire, 0, 0.72, 0);
    addMesh(c, rbox(0.46, 0.04, 0.04, 0.02), red, 0, 0.96, 0.32);
    for (const [x, z] of [[-0.16, -0.22], [0.16, -0.22], [-0.16, 0.22], [0.16, 0.22]]) addMesh(c, cyl(0.045, 0.045, 0.04, 10), dark, x, 0.05, z, 0, 0, Math.PI / 2);
    c.rotation.y = Math.PI / 2;
    g.add(c);
  }
  const sign = new THREE.Mesh(new THREE.PlaneGeometry(0.7, 0.2), signMat('ARABA', '#e0453a', '#fff'));
  sign.position.set(0, 1.25, -0.34); g.add(sign);
  addMesh(g, cyl(0.015, 0.015, 0.35, 6), M.steelDark, 0, 1.08, -0.34, 0, 0, 0, false);
  return { root: g, slots: [], height: 1.4 };
}

export function buildTable(): FixtureModel {
  const g = new THREE.Group();
  const top = mat(0xfaf6ea, 0.35);
  addMesh(g, cyl(0.55, 0.55, 0.05, 28), top, 0, 0.74, 0);
  addMesh(g, cyl(0.56, 0.56, 0.02, 28), M.wood, 0, 0.71, 0, 0, 0, 0, false);
  addMesh(g, cyl(0.05, 0.05, 0.7, 10), M.steelDark, 0, 0.36, 0);
  addMesh(g, cyl(0.3, 0.3, 0.03, 20), M.steelDark, 0, 0.02, 0);
  const seatCols = [0xe0663c, 0x1f8a86, 0xf2b33d, 0x6c4ab6];
  const chairs: THREE.Vector3[] = [];
  for (let i = 0; i < 4; i++) {
    const a = i * Math.PI / 2 + Math.PI / 4;
    const c = new THREE.Group(); c.position.set(Math.cos(a) * 0.82, 0, Math.sin(a) * 0.82); c.rotation.y = -a - Math.PI / 2;
    addMesh(c, rbox(0.4, 0.05, 0.4, 0.02), mat(seatCols[i], 0.6), 0, 0.46, 0);
    addMesh(c, rbox(0.4, 0.4, 0.04, 0.02), mat(seatCols[i], 0.6), 0, 0.68, -0.19);
    for (const [x, z] of [[-0.16, -0.16], [0.16, -0.16], [-0.16, 0.16], [0.16, 0.16]]) addMesh(c, cyl(0.015, 0.015, 0.45, 6), M.steelDark, x, 0.22, z, 0, 0, 0, false);
    g.add(c);
    chairs.push(new THREE.Vector3(Math.cos(a) * 0.82, 0, Math.sin(a) * 0.82));
  }
  // dirty trays (shown when the table needs clearing)
  const trays = new THREE.Group(); trays.userData.dynamic = true; trays.visible = false;
  for (let i = 0; i < 2; i++) {
    const t = new THREE.Group(); t.position.set(-0.15 + i * 0.3, 0.77, (i ? 0.1 : -0.12)); t.rotation.y = i * 0.8;
    addMesh(t, rbox(0.32, 0.02, 0.24, 0.01), mat(0xd6333a, 0.5), 0, 0, 0, 0, 0, 0, false);
    addMesh(t, cyl(0.035, 0.03, 0.1, 10), mat(0xffffff, 0.5), 0.08, 0.06, 0, 0, 0, 0, false);
    addMesh(t, rbox(0.12, 0.02, 0.08, 0.01), mat(0xf2d9a0, 0.8), -0.06, 0.02, 0.03, 0, 0.4, 0, false);
    addMesh(t, sphere(0.02, 6, 4), mat(0xb88a4a, 0.8), -0.1, 0.02, -0.06, 0, 0, 0, false);
    trays.add(t);
  }
  g.add(trays);
  return { root: g, slots: [], height: 1.1, trays, seats: chairs };
}

export function buildPlayArea(): FixtureModel {
  const g = new THREE.Group();
  const soft = mat(0x86d6b4, 0.95);
  addMesh(g, rbox(2.9, 0.08, 2.9, 0.04), soft, 0, 0.04, 0);
  for (let i = 0; i < 4; i++) {
    const a = i * Math.PI / 2;
    addMesh(g, rbox(2.9, 0.35, 0.1, 0.05), mat([0xe0663c, 0xf2b33d, 0x1f8a86, 0x6c4ab6][i], 0.8), Math.sin(a) * 1.4, 0.2, Math.cos(a) * 1.4, 0, a, 0);
  }
  // ball pit
  addMesh(g, cyl(0.6, 0.6, 0.35, 24, ), mat(0x2f6fb5, 0.7), -0.6, 0.2, -0.6);
  const bc = [0xe5484d, 0xf2b33d, 0x2fae7a, 0x61b3ff, 0xf08f86];
  for (let i = 0; i < 26; i++) {
    const a = i * 2.4, r = (i % 5) * 0.1;
    addMesh(g, sphere(0.07, 8, 6), mat(bc[i % bc.length], 0.4), -0.6 + Math.cos(a) * r, 0.4 + (i % 3) * 0.03, -0.6 + Math.sin(a) * r, 0, 0, 0, false);
  }
  // slide tower
  addMesh(g, rbox(0.8, 1.2, 0.8, 0.05), mat(0xf2b33d, 0.6), 0.7, 0.7, 0.6);
  addMesh(g, rbox(0.9, 0.15, 0.9, 0.05), mat(0xe0663c, 0.6), 0.7, 1.35, 0.6);
  const roof = addMesh(g, new THREE.ConeGeometry(0.7, 0.6, 4), mat(0x1f8a86, 0.6), 0.7, 1.75, 0.6, 0, Math.PI / 4, 0);
  void roof;
  const slide = addMesh(g, rbox(0.5, 0.06, 1.6, 0.03), mat(0xe5484d, 0.35), 0.7, 0.7, -0.45, -0.62, 0, 0);
  void slide;
  for (const x of [0.46, 0.94]) addMesh(g, rbox(0.04, 0.16, 1.6, 0.02), mat(0xe5484d, 0.35), x, 0.78, -0.45, -0.62, 0, 0, false);
  const sign = new THREE.Mesh(new THREE.PlaneGeometry(1.2, 0.3), signMat('OYUN ALANI', '#6c4ab6', '#fff', 512, 128, true));
  sign.position.set(-0.4, 1.5, 1.42); g.add(sign);
  addMesh(g, cyl(0.02, 0.02, 1.3, 6), M.steelDark, -0.95, 0.75, 1.42, 0, 0, 0, false);
  addMesh(g, cyl(0.02, 0.02, 1.3, 6), M.steelDark, 0.15, 0.75, 1.42, 0, 0, 0, false);
  return { root: g, slots: [], height: 2.2 };
}

export function buildBench(): FixtureModel {
  const g = new THREE.Group();
  for (let i = 0; i < 3; i++) addMesh(g, rbox(1.3, 0.05, 0.13, 0.02), M.wood, -0.25, 0.45, -0.15 + i * 0.15);
  for (let i = 0; i < 2; i++) addMesh(g, rbox(1.3, 0.12, 0.04, 0.02), M.wood, -0.25, 0.62 + i * 0.16, -0.26, -0.12);
  for (const x of [-0.8, 0.3]) addMesh(g, rbox(0.06, 0.45, 0.4, 0.02), mat(0x2d3a4a, 0.5, 0.5), x, 0.22, -0.05);
  addMesh(g, rbox(0.46, 0.5, 0.46, 0.04), M.terracotta, 0.68, 0.25, 0);
  const leaf = new THREE.IcosahedronGeometry(0.28, 1);
  addMesh(g, leaf, mat(0x5fa35a, 0.8), 0.68, 0.72, 0);
  addMesh(g, new THREE.IcosahedronGeometry(0.2, 1), mat(0x74b85f, 0.8), 0.6, 0.9, 0.08);
  return { root: g, slots: [], height: 1.1 };
}

export { PAL };
