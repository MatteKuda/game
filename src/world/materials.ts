import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/examples/jsm/geometries/RoundedBoxGeometry.js';
import { PAL } from '../config';
import { woodTexture, plasterTexture, wainscotTexture, terrazzoTexture } from './textures';

const geoCache = new Map<string, THREE.BufferGeometry>();

/** Cached rounded box geometry (friendly bevels everywhere) */
export function rbox(w: number, h: number, d: number, r = 0.03, seg = 2) {
  const k = `rb:${w.toFixed(3)}:${h.toFixed(3)}:${d.toFixed(3)}:${r}:${seg}`;
  let g = geoCache.get(k);
  if (!g) {
    g = new RoundedBoxGeometry(w, h, d, seg, Math.min(r, w / 2 - 0.001, h / 2 - 0.001, d / 2 - 0.001));
    geoCache.set(k, g);
  }
  return g;
}

export function cyl(rt: number, rb: number, h: number, seg = 16) {
  const k = `cy:${rt}:${rb}:${h}:${seg}`;
  let g = geoCache.get(k);
  if (!g) { g = new THREE.CylinderGeometry(rt, rb, h, seg); geoCache.set(k, g); }
  return g;
}

export function sphere(r: number, ws = 16, hs = 12) {
  const k = `sp:${r}:${ws}:${hs}`;
  let g = geoCache.get(k);
  if (!g) { g = new THREE.SphereGeometry(r, ws, hs); geoCache.set(k, g); }
  return g;
}

export function capsule(r: number, len: number, cs = 6, rs = 12) {
  const k = `ca:${r}:${len}:${cs}:${rs}`;
  let g = geoCache.get(k);
  if (!g) { g = new THREE.CapsuleGeometry(r, len, cs, rs); geoCache.set(k, g); }
  return g;
}

const matCache = new Map<string, THREE.Material>();

export function mat(color: number, rough = 0.7, metal = 0, extra: Partial<THREE.MeshStandardMaterialParameters> = {}) {
  const k = `m:${color}:${rough}:${metal}:${JSON.stringify(extra)}`;
  let m = matCache.get(k);
  if (!m) { m = new THREE.MeshStandardMaterial({ color, roughness: rough, metalness: metal, ...extra }); matCache.set(k, m); }
  return m as THREE.MeshStandardMaterial;
}

export function glow(color: number, intensity = 2) {
  const k = `g:${color}:${intensity}`;
  let m = matCache.get(k);
  if (!m) { m = new THREE.MeshStandardMaterial({ color, emissive: color, emissiveIntensity: intensity, roughness: 0.4 }); matCache.set(k, m); }
  return m as THREE.MeshStandardMaterial;
}

export class Materials {
  wood: THREE.MeshStandardMaterial;
  woodDark: THREE.MeshStandardMaterial;
  floor: THREE.MeshStandardMaterial;
  wall: THREE.MeshStandardMaterial;
  wainscot: THREE.MeshStandardMaterial;
  glass: THREE.MeshPhysicalMaterial;
  steel = mat(PAL.steel, 0.35, 0.75);
  steelDark = mat(PAL.steelDark, 0.45, 0.6);
  teal = mat(PAL.teal, 0.55);
  tealDark = mat(PAL.tealDark, 0.55);
  terracotta = mat(PAL.terracotta, 0.6);
  cream = mat(PAL.cream, 0.75);
  ink = mat(PAL.ink, 0.6);
  white = mat(0xffffff, 0.5);
  black = mat(0x1b1d22, 0.6);
  rubber = mat(0x2a2d33, 0.9);
  mustard = mat(PAL.mustard, 0.55);

  constructor() {
    const wt = woodTexture();
    this.wood = new THREE.MeshStandardMaterial({ map: wt, roughness: 0.62, color: 0xffffff });
    const wtd = woodTexture('#8a5a35', '#5a3920');
    this.woodDark = new THREE.MeshStandardMaterial({ map: wtd, roughness: 0.6 });
    const ft = terrazzoTexture();
    ft.wrapS = ft.wrapT = THREE.RepeatWrapping;
    this.floor = new THREE.MeshStandardMaterial({ map: ft, roughness: 0.42, metalness: 0.0 });
    const pt = plasterTexture();
    pt.wrapS = pt.wrapT = THREE.RepeatWrapping;
    this.wall = new THREE.MeshStandardMaterial({ map: pt, roughness: 0.9, color: 0xffffff });
    const ws = wainscotTexture();
    this.wainscot = new THREE.MeshStandardMaterial({ map: ws, roughness: 0.25, color: 0xffffff });
    this.glass = new THREE.MeshPhysicalMaterial({
      color: 0xcfeef0, roughness: 0.05, metalness: 0, transparent: true, opacity: 0.22,
      envMapIntensity: 1.6, depthWrite: false, clearcoat: 1,
    });
  }
}

export let M: Materials;
export function initMaterials() { M = new Materials(); }
