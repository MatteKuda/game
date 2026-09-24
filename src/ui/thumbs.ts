import * as THREE from 'three';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';
import { FIXTURES } from '../data/fixtures';
import { PRODUCTS } from '../data/products';
import { buildFixtureModel } from '../world/props';
import { productMesh } from '../world/products3d';
import { CharacterView, type Look } from '../world/characters';

/** Renders small 3D thumbnails (build cards, product chips, portraits) once at boot. */
export class Thumbs {
  fixtures: Record<string, string> = {};
  products: Record<string, string> = {};
  private r: THREE.WebGLRenderer;
  private scene = new THREE.Scene();
  private cam = new THREE.PerspectiveCamera(30, 1, 0.05, 50);

  constructor() {
    this.r = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
    this.r.setPixelRatio(1);
    this.r.outputColorSpace = THREE.SRGBColorSpace;
    this.r.toneMapping = THREE.NeutralToneMapping;
    const pm = new THREE.PMREMGenerator(this.r);
    this.scene.environment = pm.fromScene(new RoomEnvironment(), 0.04).texture;
    this.scene.environmentIntensity = 0.7;
    const key = new THREE.DirectionalLight(0xfff2e0, 2.6); key.position.set(3, 5, 4);
    const fill = new THREE.HemisphereLight(0xdfefff, 0xa08060, 1.0);
    this.scene.add(key, fill);
  }

  private shot(obj: THREE.Object3D, size: number, pitch = 0.5, yaw = -0.6, pad = 1.25) {
    this.r.setSize(size, size);
    this.scene.add(obj);
    const box = new THREE.Box3().setFromObject(obj);
    const c = box.getCenter(new THREE.Vector3());
    const s = box.getSize(new THREE.Vector3()).length();
    const d = (s * pad) / (2 * Math.tan((this.cam.fov * Math.PI) / 360));
    this.cam.position.set(c.x + Math.sin(yaw) * Math.cos(pitch) * d, c.y + Math.sin(pitch) * d, c.z + Math.cos(yaw) * Math.cos(pitch) * d);
    this.cam.lookAt(c);
    this.r.setClearColor(0x000000, 0);
    this.r.render(this.scene, this.cam);
    const url = toObjectURL(this.r.domElement.toDataURL('image/png'));
    this.scene.remove(obj);
    return url;
  }

  build() {
    for (const f of FIXTURES) {
      const m = buildFixtureModel(f);
      this.fixtures[f.id] = this.shot(m.root, 160, 0.42, -0.65, 1.05);
    }
    for (const p of PRODUCTS) {
      const m = productMesh(p.id);
      this.products[p.id] = this.shot(m, 96, 0.35, -0.5, 1.2);
    }
  }

  portrait(look: Look) {
    const v = new CharacterView(look);
    v.setFace('happy');
    const g = new THREE.Group(); g.add(v.root);
    this.r.setSize(120, 120);
    this.scene.add(g);
    const headY = 1.38 * look.height;
    this.cam.position.set(0.35, headY + 0.1, 1.25);
    this.cam.lookAt(0, headY - 0.05, 0);
    this.r.setClearColor(0x000000, 0);
    this.r.render(this.scene, this.cam);
    const url = toObjectURL(this.r.domElement.toDataURL('image/png'));
    this.scene.remove(g);
    return url;
  }
}

/** short blob: URLs keep the frequently diffed panel HTML small */
function toObjectURL(dataUrl: string) {
  const bin = atob(dataUrl.split(',')[1]);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return URL.createObjectURL(new Blob([bytes], { type: 'image/png' }));
}
