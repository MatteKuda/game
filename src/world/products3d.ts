import * as THREE from 'three';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import { RoundedBoxGeometry } from 'three/examples/jsm/geometries/RoundedBoxGeometry.js';
import { PRODUCTS, type ProductDef } from '../data/products';
import { canvasTexture, hex } from './textures';

export interface ProductVisual {
  geometry: THREE.BufferGeometry;
  material: THREE.Material;
  height: number; // approx height for stacking
  footprint: number; // approx width
}

function labelTexture(p: ProductDef) {
  return canvasTexture(128, 128, (ctx, w, h) => {
    ctx.fillStyle = hex(p.color); ctx.fillRect(0, 0, w, h);
    ctx.fillStyle = hex(p.accent);
    switch (p.shape) {
      case 'bag':
        ctx.beginPath(); ctx.arc(w / 2, h * 0.58, w * 0.26, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = '#fff'; ctx.font = '800 26px "Baloo 2", sans-serif'; ctx.textAlign = 'center';
        ctx.fillText(p.brand, w / 2, h * 0.28);
        ctx.fillStyle = '#ffd97a';
        for (let i = 0; i < 5; i++) { ctx.beginPath(); ctx.ellipse(w * 0.36 + i * 9, h * 0.6 + (i % 2) * 6, 7, 5, i, 0, Math.PI * 2); ctx.fill(); }
        break;
      case 'bar':
        ctx.fillRect(0, h * 0.35, w, h * 0.3);
        ctx.fillStyle = hex(p.color); ctx.font = '800 22px "Baloo 2", sans-serif'; ctx.textAlign = 'center';
        ctx.fillText(p.brand, w / 2, h * 0.56);
        break;
      case 'box':
        ctx.fillRect(0, 0, w, h * 0.3);
        ctx.fillStyle = '#e9b86d';
        ctx.beginPath(); ctx.ellipse(w * 0.5, h * 0.66, 30, 18, 0, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = hex(p.color); ctx.font = '800 20px "Baloo 2", sans-serif'; ctx.textAlign = 'center';
        ctx.fillText(p.brand, w / 2, h * 0.21);
        break;
      case 'wedge':
        ctx.fillRect(0, h * 0.25, w, h * 0.5);
        ctx.fillStyle = hex(p.color); ctx.font = '800 22px "Baloo 2", sans-serif'; ctx.textAlign = 'center';
        ctx.fillText(p.brand, w / 2, h * 0.56);
        break;
      case 'bottle':
      case 'cup':
      case 'carton':
      case 'jug':
        ctx.fillRect(0, h * 0.3, w, h * 0.42);
        ctx.fillStyle = hex(p.color); ctx.font = '800 24px "Baloo 2", sans-serif'; ctx.textAlign = 'center';
        ctx.fillText(p.brand, w / 2, h * 0.58);
        break;
      default:
        break;
    }
  });
}

function bake(parts: { g: THREE.BufferGeometry; m: THREE.Matrix4 }[]) {
  const gs = parts.map(({ g, m }) => {
    const c = g.index ? g.toNonIndexed() : g.clone();
    c.applyMatrix4(m);
    // strip to shared attribute set
    for (const k of Object.keys(c.attributes)) if (!['position', 'normal', 'uv'].includes(k)) c.deleteAttribute(k);
    return c;
  });
  return mergeGeometries(gs, false)!;
}

const T = (x = 0, y = 0, z = 0, sx = 1, sy = 1, sz = 1, rx = 0, ry = 0, rz = 0) =>
  new THREE.Matrix4().compose(new THREE.Vector3(x, y, z), new THREE.Quaternion().setFromEuler(new THREE.Euler(rx, ry, rz)), new THREE.Vector3(sx, sy, sz));

function build(p: ProductDef): ProductVisual {
  const tex = labelTexture(p);
  const plain = new THREE.MeshStandardMaterial({ color: p.color, roughness: 0.55 });
  const labeled = new THREE.MeshStandardMaterial({ map: tex, roughness: 0.45 });
  switch (p.shape) {
    case 'bag': {
      // pillow-shaped snack bag
      const g = new RoundedBoxGeometry(0.17, 0.24, 0.07, 3, 0.03);
      const pos = g.attributes.position as THREE.BufferAttribute;
      for (let i = 0; i < pos.count; i++) {
        const y = pos.getY(i); const z = pos.getZ(i);
        const bulge = 1 + 0.5 * (1 - Math.abs(y) / 0.12);
        pos.setZ(i, z * bulge);
      }
      g.computeVertexNormals();
      g.translate(0, 0.12, 0);
      return { geometry: g, material: labeled, height: 0.24, footprint: 0.17 };
    }
    case 'bar': {
      const g = new RoundedBoxGeometry(0.16, 0.035, 0.07, 2, 0.01); g.translate(0, 0.018, 0);
      // stack of 2 bars per unit to read better
      const g2 = bake([{ g, m: T() }, { g, m: T(0.01, 0.036, 0, 1, 1, 1, 0, 0.12) }]);
      return { geometry: g2, material: labeled, height: 0.075, footprint: 0.16 };
    }
    case 'box': {
      const g = new RoundedBoxGeometry(0.15, 0.2, 0.06, 2, 0.01); g.translate(0, 0.1, 0);
      return { geometry: g, material: labeled, height: 0.2, footprint: 0.15 };
    }
    case 'bottle': {
      const pts: THREE.Vector2[] = [];
      const prof = [[0, 0], [0.034, 0], [0.038, 0.01], [0.038, 0.14], [0.032, 0.17], [0.014, 0.21], [0.013, 0.235], [0.016, 0.24], [0, 0.245]];
      for (const [r, y] of prof) pts.push(new THREE.Vector2(r, y));
      const g = new THREE.LatheGeometry(pts, 14);
      return { geometry: g, material: new THREE.MeshPhysicalMaterial({ map: tex, roughness: 0.15, clearcoat: 1, color: 0xffffff }), height: 0.245, footprint: 0.08 };
    }
    case 'cup': {
      const body = new THREE.CylinderGeometry(0.042, 0.034, 0.1, 16, 1, false); body.translate(0, 0.05, 0);
      const lid = new THREE.CylinderGeometry(0.045, 0.045, 0.008, 16); lid.translate(0, 0.104, 0);
      const g = bake([{ g: body, m: T() }, { g: lid, m: T() }]);
      return { geometry: g, material: labeled, height: 0.11, footprint: 0.09 };
    }
    case 'carton': {
      const body = new RoundedBoxGeometry(0.08, 0.18, 0.08, 2, 0.008); body.translate(0, 0.09, 0);
      const top = new THREE.CylinderGeometry(0.0, 0.058, 0.04, 4, 1); top.rotateY(Math.PI / 4); top.translate(0, 0.2, 0);
      const g = bake([{ g: body, m: T() }, { g: top, m: T(0, 0, 0, 1, 1, 0.35) }]);
      return { geometry: g, material: labeled, height: 0.22, footprint: 0.09 };
    }
    case 'jug': {
      const body = new RoundedBoxGeometry(0.12, 0.2, 0.08, 3, 0.03); body.translate(0, 0.1, 0);
      const cap = new THREE.CylinderGeometry(0.02, 0.02, 0.04, 10); cap.translate(0.02, 0.22, 0);
      const g = bake([{ g: body, m: T() }, { g: cap, m: T() }]);
      return { geometry: g, material: labeled, height: 0.24, footprint: 0.12 };
    }
    case 'ring': {
      const g = new THREE.TorusGeometry(0.075, 0.028, 10, 22); g.rotateX(Math.PI / 2); g.translate(0, 0.028, 0);
      const m = new THREE.MeshStandardMaterial({ color: p.color, roughness: 0.75, map: sesameTexture() });
      return { geometry: g, material: m, height: 0.056, footprint: 0.2 };
    }
    case 'loaf': {
      const g = new THREE.CapsuleGeometry(0.055, 0.16, 6, 12); g.rotateZ(Math.PI / 2); g.scale(1, 0.8, 1); g.translate(0, 0.045, 0);
      const cuts = new THREE.MeshStandardMaterial({ color: p.color, roughness: 0.8, map: crustTexture() });
      return { geometry: g, material: cuts, height: 0.09, footprint: 0.27 };
    }
    case 'wedge': {
      // cheese block in a green-labelled tub
      const tub = new RoundedBoxGeometry(0.16, 0.08, 0.12, 2, 0.015); tub.translate(0, 0.04, 0);
      const lid = new RoundedBoxGeometry(0.165, 0.015, 0.125, 2, 0.006); lid.translate(0, 0.085, 0);
      const g = bake([{ g: tub, m: T() }, { g: lid, m: T() }]);
      return { geometry: g, material: labeled, height: 0.095, footprint: 0.16 };
    }
    case 'fruit': {
      const s = new THREE.SphereGeometry(0.045, 14, 10); s.scale(1, 0.9, 1); s.translate(0, 0.04, 0);
      const stem = new THREE.CylinderGeometry(0.004, 0.004, 0.02, 5); stem.translate(0, 0.085, 0);
      const g = bake([{ g: s, m: T() }, { g: stem, m: T() }]);
      return { geometry: g, material: plain, height: 0.085, footprint: 0.09 };
    }
  }
}

function sesameTexture() {
  return canvasTexture(128, 64, (ctx, w, h) => {
    ctx.fillStyle = '#c47a37'; ctx.fillRect(0, 0, w, h);
    ctx.fillStyle = '#f3dfb0';
    for (let i = 0; i < 160; i++) { ctx.beginPath(); ctx.ellipse(Math.random() * w, Math.random() * h * 0.6, 1.6, 0.9, Math.random() * 3, 0, Math.PI * 2); ctx.fill(); }
  });
}
function crustTexture() {
  return canvasTexture(128, 64, (ctx, w, h) => {
    const g = ctx.createLinearGradient(0, 0, 0, h); g.addColorStop(0, '#b56a2b'); g.addColorStop(1, '#e2ae6a');
    ctx.fillStyle = g; ctx.fillRect(0, 0, w, h);
    ctx.strokeStyle = '#f2d59f'; ctx.lineWidth = 4;
    for (let i = 0; i < 4; i++) { ctx.beginPath(); ctx.moveTo(20 + i * 26, 10); ctx.lineTo(34 + i * 26, 30); ctx.stroke(); }
  });
}

export const productVisuals = new Map<string, ProductVisual>();

export function initProductVisuals() {
  for (const p of PRODUCTS) productVisuals.set(p.id, build(p));
}

/** A single product mesh for UI thumbnails / carried boxes */
export function productMesh(id: string) {
  const v = productVisuals.get(id)!;
  return new THREE.Mesh(v.geometry, v.material);
}

/**
 * Global instanced renderer: each product gets an InstancedMesh; fixtures push unit matrices
 * each time their stock changes.
 */
export class ProductInstancer {
  meshes = new Map<string, THREE.InstancedMesh>();
  private dirty = true;
  constructor(private scene: THREE.Scene, private collect: (pid: string, out: THREE.Matrix4[]) => void) {
    for (const p of PRODUCTS) {
      const v = productVisuals.get(p.id)!;
      const im = new THREE.InstancedMesh(v.geometry, v.material, 600);
      im.count = 0; im.castShadow = true; im.receiveShadow = true;
      im.frustumCulled = false;
      scene.add(im);
      this.meshes.set(p.id, im);
    }
  }
  markDirty() { this.dirty = true; }
  update() {
    if (!this.dirty) return;
    this.dirty = false;
    const tmp: THREE.Matrix4[] = [];
    for (const [pid, im] of this.meshes) {
      tmp.length = 0;
      this.collect(pid, tmp);
      const n = Math.min(tmp.length, 600);
      for (let i = 0; i < n; i++) im.setMatrixAt(i, tmp[i]);
      im.count = n;
      im.instanceMatrix.needsUpdate = true;
    }
  }
}
