import * as THREE from 'three';
import { MAP_W, PAL, SIDEWALK_Z0, SIDEWALK_Z1, ROAD_Z0, ROAD_Z1, FAR_WALK_Z0, FAR_WALK_Z1 } from '../config';
import { M, rbox, cyl, sphere, mat, glow } from './materials';
import { addMesh } from './props';
import { mergeByMaterial } from './merge';
import { paverTexture, asphaltTexture, brickTexture, plasterTexture, awningTexture, shutterTexture, signTexture, canvasTexture, roundRect, mulberry } from './textures';

export interface Occluder { obj: THREE.Object3D; box: THREE.Box3; mats: THREE.Material[]; fade: number }

const litWindow = new THREE.MeshStandardMaterial({ color: 0x3c4a5e, emissive: 0xffc97a, emissiveIntensity: 0, roughness: 0.2, metalness: 0.2 });
const darkWindow = new THREE.MeshStandardMaterial({ color: 0x33475e, roughness: 0.15, metalness: 0.3 });

export class Environment {
  group = new THREE.Group();
  occluders: Occluder[] = [];
  blockedTiles: [number, number][] = [];
  streetLights: THREE.PointLight[] = [];
  lampBulbs: THREE.MeshStandardMaterial;
  neighborShop = new THREE.Group(); // removed on expansion
  backyard = new THREE.Group(); // removed on expansion
  cars: { obj: THREE.Group; lane: number; speed: number; x: number; lights: THREE.MeshStandardMaterial }[] = [];
  van: THREE.Group;
  private rnd = mulberry(42);

  constructor(private scene: THREE.Scene) {
    scene.add(this.group);
    this.lampBulbs = new THREE.MeshStandardMaterial({ color: 0xfff1c9, emissive: 0xffd28a, emissiveIntensity: 0.2 });
    this.buildGround();
    this.buildStreetFurniture();
    this.buildBuildings();
    this.buildNeighborShop();
    this.buildBackyard();
    this.buildTraffic();
    this.van = this.buildVan();
    this.van.visible = false;
    this.group.add(this.van);
    // bake everything static that is left at the top level (street, furniture, trees, lamps)
    this.van.userData.dynamic = true;
    for (const c of this.cars) c.obj.userData.dynamic = true;
    this.neighborShop.userData.dynamic = true;
    this.backyard.userData.dynamic = true;
    for (const o of this.occluders) o.obj.userData.dynamic = true;
    mergeByMaterial(this.group);
    mergeByMaterial(this.backyard);
  }

  private buildGround() {
    const g = this.group;
    // base ground far beyond the map
    const base = new THREE.Mesh(new THREE.PlaneGeometry(400, 400), mat(0xcdbfa8, 0.95));
    base.rotation.x = -Math.PI / 2; base.position.set(MAP_W / 2, -0.02, 20); base.receiveShadow = true; g.add(base);
    // near sidewalk
    const pav = paverTexture(); pav.wrapS = pav.wrapT = THREE.RepeatWrapping;
    const swW = MAP_W + 40;
    pav.repeat.set(swW / 2, (SIDEWALK_Z1 - SIDEWALK_Z0) / 2);
    const sw = new THREE.Mesh(new THREE.PlaneGeometry(swW, SIDEWALK_Z1 - SIDEWALK_Z0), new THREE.MeshStandardMaterial({ map: pav, roughness: 0.85 }));
    sw.rotation.x = -Math.PI / 2; sw.position.set(MAP_W / 2, 0.06, (SIDEWALK_Z0 + SIDEWALK_Z1) / 2); sw.receiveShadow = true; g.add(sw);
    // pavement strip behind the shops (so the gap to buildings is not empty)
    const pav2 = paverTexture(); pav2.wrapS = pav2.wrapT = THREE.RepeatWrapping; pav2.repeat.set(swW / 2, 8);
    const back = new THREE.Mesh(new THREE.PlaneGeometry(swW, 16), new THREE.MeshStandardMaterial({ map: pav2, roughness: 0.9, color: 0xe6ddd0 }));
    back.rotation.x = -Math.PI / 2; back.position.set(MAP_W / 2, 0.005, SIDEWALK_Z0 - 8); back.receiveShadow = true; g.add(back);
    // curb
    addMesh(g, new THREE.BoxGeometry(swW, 0.14, 0.22), mat(PAL.curb, 0.8), MAP_W / 2, 0.07, ROAD_Z0 - 0.1, 0, 0, 0, false);
    addMesh(g, new THREE.BoxGeometry(swW, 0.14, 0.22), mat(PAL.curb, 0.8), MAP_W / 2, 0.07, ROAD_Z1 + 0.1, 0, 0, 0, false);
    // road
    const asp = asphaltTexture(); asp.wrapS = asp.wrapT = THREE.RepeatWrapping; asp.repeat.set(swW / 6, 1);
    const road = new THREE.Mesh(new THREE.PlaneGeometry(swW, ROAD_Z1 - ROAD_Z0), new THREE.MeshStandardMaterial({ map: asp, roughness: 0.92 }));
    road.rotation.x = -Math.PI / 2; road.position.set(MAP_W / 2, 0.01, (ROAD_Z0 + ROAD_Z1) / 2); road.receiveShadow = true; g.add(road);
    // lane dashes
    const dash = mat(0xf3efe2, 0.7);
    for (let x = -18; x < MAP_W + 18; x += 3) addMesh(g, new THREE.BoxGeometry(1.5, 0.01, 0.14), dash, x, 0.02, (ROAD_Z0 + ROAD_Z1) / 2, 0, 0, 0, false);
    // parking lane line
    for (let x = -18; x < MAP_W + 18; x += 1) addMesh(g, new THREE.BoxGeometry(0.5, 0.01, 0.08), mat(0xf2b33d, 0.7), x, 0.02, ROAD_Z0 + 2.1, 0, 0, 0, false);
    // zebra crossing
    for (let i = 0; i < 7; i++) addMesh(g, new THREE.BoxGeometry(2.6, 0.012, 0.42), dash, 33.5, 0.021, ROAD_Z0 + 0.6 + i * 0.8, 0, 0, 0, false);
    // far sidewalk
    const pav3 = paverTexture(); pav3.wrapS = pav3.wrapT = THREE.RepeatWrapping; pav3.repeat.set(swW / 2, 1);
    const fw = new THREE.Mesh(new THREE.PlaneGeometry(swW, FAR_WALK_Z1 - FAR_WALK_Z0 + 1), new THREE.MeshStandardMaterial({ map: pav3, roughness: 0.85 }));
    fw.rotation.x = -Math.PI / 2; fw.position.set(MAP_W / 2, 0.06, (FAR_WALK_Z0 + FAR_WALK_Z1 + 1) / 2); fw.receiveShadow = true; g.add(fw);
  }

  private tree(x: number, z: number, s = 1) {
    const t = new THREE.Group(); t.position.set(x, 0, z); t.scale.setScalar(s);
    addMesh(t, rbox(0.9, 0.3, 0.9, 0.05), mat(0x9d8f7c, 0.9), 0, 0.15, 0);
    addMesh(t, rbox(0.72, 0.05, 0.72, 0.02), mat(0x5a4230, 1), 0, 0.3, 0, 0, 0, 0, false);
    addMesh(t, cyl(0.07, 0.1, 2.2, 8), mat(0x6e4f36, 0.9), 0, 1.3, 0);
    const leafs = [mat(0x5fa35a, 0.8), mat(0x74b85f, 0.8), mat(0x4d8f4f, 0.8)];
    for (let i = 0; i < 7; i++) {
      const a = i * 1.7;
      const r = i === 0 ? 0 : 0.55;
      const m = addMesh(t, new THREE.IcosahedronGeometry(0.75 - (i ? 0.15 : 0), 1), leafs[i % 3], Math.cos(a) * r, 2.7 + (i % 3) * 0.25 + (i === 0 ? 0.35 : 0), Math.sin(a) * r);
      (m.material as THREE.MeshStandardMaterial).flatShading = true;
    }
    this.group.add(t);
    this.blockedTiles.push([Math.floor(x), Math.floor(z)]);
  }

  private lamp(x: number, z: number) {
    const l = new THREE.Group(); l.position.set(x, 0, z);
    const pole = mat(0x2d3a4a, 0.5, 0.5);
    addMesh(l, cyl(0.1, 0.13, 0.3, 10), pole, 0, 0.15, 0);
    addMesh(l, cyl(0.05, 0.06, 4.4, 10), pole, 0, 2.4, 0);
    addMesh(l, rbox(0.9, 0.06, 0.08, 0.02), pole, 0.4, 4.55, 0);
    const head = addMesh(l, cyl(0.05, 0.28, 0.2, 14), pole, 0.8, 4.45, 0);
    void head;
    addMesh(l, sphere(0.14, 12, 8), this.lampBulbs, 0.8, 4.34, 0, 0, 0, 0, false);
    const pl = new THREE.PointLight(0xffc98a, 0, 11, 1.6);
    pl.position.set(0.8, 4.1, 0); l.add(pl);
    this.streetLights.push(pl);
    this.group.add(l);
    this.blockedTiles.push([Math.floor(x), Math.floor(z)]);
  }

  private buildStreetFurniture() {
    for (const x of [3.5, 11.5, 30.5, 40.5]) this.tree(x, SIDEWALK_Z1 - 0.5, 1);
    for (const x of [7.5, 36.5]) this.lamp(x, SIDEWALK_Z1 - 0.45);
    for (const x of [2, 16, 28, 41]) this.tree(x, FAR_WALK_Z0 + 1.2, 0.9);
    this.lamp(22, FAR_WALK_Z0 + 1.0);
    // bench on far side
    const b = new THREE.Group(); b.position.set(9, 0.06, FAR_WALK_Z0 + 1.3);
    for (let i = 0; i < 4; i++) addMesh(b, rbox(2, 0.05, 0.12, 0.02), M.wood, 0, 0.45, -0.2 + i * 0.13);
    for (let i = 0; i < 3; i++) addMesh(b, rbox(2, 0.12, 0.04, 0.02), M.wood, 0, 0.6 + i * 0.15, -0.3, -0.15);
    for (const s of [-0.85, 0.85]) addMesh(b, rbox(0.06, 0.45, 0.5, 0.02), mat(0x2d3a4a, 0.5, 0.5), s, 0.22, -0.05);
    this.group.add(b);
    // bollards near shop door
    for (const x of [19.5, 26.5]) addMesh(this.group, cyl(0.09, 0.1, 0.8, 12), mat(0x2d3a4a, 0.5, 0.4), x, 0.46, SIDEWALK_Z1 - 0.35);
    // fire hydrant
    const h = new THREE.Group(); h.position.set(14.5, 0.06, SIDEWALK_Z1 - 0.4);
    addMesh(h, cyl(0.12, 0.14, 0.6, 12), mat(0xd6333a, 0.5), 0, 0.3, 0);
    addMesh(h, sphere(0.13, 12, 8), mat(0xd6333a, 0.5), 0, 0.6, 0);
    addMesh(h, cyl(0.05, 0.05, 0.36, 8), mat(0xd6333a, 0.5), 0, 0.4, 0, 0, 0, Math.PI / 2);
    this.group.add(h);
    this.blockedTiles.push([14, SIDEWALK_Z1 - 1]);
  }

  private apartment(x0: number, z0: number, w: number, d: number, floors: number, color: number, face: 1 | -1, opts: { shopFront?: boolean; roofExtras?: boolean } = {}) {
    const b = new THREE.Group();
    const fh = 3.1;
    const H = floors * fh + 0.6;
    const pt = plasterTexture('#' + color.toString(16).padStart(6, '0'));
    pt.wrapS = pt.wrapT = THREE.RepeatWrapping; pt.repeat.set(w / 3, H / 3);
    const wallM = new THREE.MeshStandardMaterial({ map: pt, roughness: 0.92 });
    const trim = mat(0xf6efe3, 0.8);
    const cx = x0 + w / 2, cz = z0 + d / 2;
    b.position.set(cx, 0, cz);
    addMesh(b, new THREE.BoxGeometry(w, H, d), wallM, 0, H / 2, 0);
    // base plinth
    addMesh(b, new THREE.BoxGeometry(w + 0.06, 0.6, d + 0.06), mat(0x9b8d7a, 0.9), 0, 0.3, 0);
    // roof parapet
    addMesh(b, new THREE.BoxGeometry(w + 0.2, 0.25, d + 0.2), trim, 0, H + 0.12, 0);
    addMesh(b, new THREE.BoxGeometry(w - 0.4, 0.05, d - 0.4), mat(0x8b8178, 0.95), 0, H + 0.02, 0, 0, 0, 0, false);
    const fz = face * (d / 2);
    const cols = Math.max(1, Math.floor(w / 2.4));
    const startFloor = opts.shopFront ? 1 : 0;
    for (let f = startFloor; f < floors; f++) {
      const y = f * fh + 1.6;
      addMesh(b, new THREE.BoxGeometry(w, 0.12, 0.12), trim, 0, f * fh + 0.05, fz + face * 0.06, 0, 0, 0, false);
      for (let c = 0; c < cols; c++) {
        const x = -w / 2 + (c + 0.5) * (w / cols);
        const lit = this.rnd() < 0.45;
        const win = addMesh(b, new THREE.BoxGeometry(1.1, 1.4, 0.06), lit ? litWindow : darkWindow, x, y, fz + face * 0.02, 0, 0, 0, false);
        void win;
        addMesh(b, new THREE.BoxGeometry(1.3, 0.1, 0.16), trim, x, y - 0.75, fz + face * 0.08, 0, 0, 0, false);
        // shutters
        if ((c + f) % 3 === 0) for (const s of [-1, 1]) addMesh(b, new THREE.BoxGeometry(0.34, 1.4, 0.05), mat(0x3f8f86, 0.7), x + s * 0.75, y, fz + face * 0.05, 0, 0, 0, false);
        // balcony
        if (f > 0 && (c % 2 === 1) && w > 5) {
          addMesh(b, new THREE.BoxGeometry(1.8, 0.12, 0.8), trim, x, f * fh + 0.4, fz + face * 0.42);
          for (let r = 0; r < 7; r++) addMesh(b, new THREE.BoxGeometry(0.03, 0.8, 0.03), mat(0x2d3a4a, 0.5, 0.4), x - 0.85 + r * 0.283, f * fh + 0.85, fz + face * 0.8, 0, 0, 0, false);
          addMesh(b, new THREE.BoxGeometry(1.8, 0.05, 0.05), mat(0x2d3a4a, 0.5, 0.4), x, f * fh + 1.25, fz + face * 0.8, 0, 0, 0, false);
          // potted flowers
          addMesh(b, sphere(0.16, 8, 6), mat([0xe76f51, 0xf2b33d, 0xe05a8a][r3(this.rnd)], 0.8), x - 0.5, f * fh + 0.62, fz + face * 0.6);
        }
        // AC unit
        if (this.rnd() < 0.2) {
          addMesh(b, rbox(0.7, 0.45, 0.3, 0.03), mat(0xf1f1ee, 0.5), x + 0.9, y + 0.2, fz + face * 0.18);
        }
      }
    }
    if (opts.roofExtras) {
      addMesh(b, cyl(0.5, 0.5, 1.1, 14), mat(0xd8d4cc, 0.5, 0.3), -w / 4, H + 0.7, -d / 4);
      addMesh(b, new THREE.BoxGeometry(1.4, 0.05, 1.4), mat(0x2d3a4a, 0.6), w / 5, H + 0.2, 0);
      const dish = addMesh(b, new THREE.SphereGeometry(0.35, 12, 8, 0, Math.PI * 2, 0, Math.PI / 3), mat(0xe8e8e8, 0.4), w / 4, H + 0.6, d / 4, 0.8, 0.4, 0);
      void dish;
    }
    this.group.add(b);
    this.pendingBuildings.push(b);
    return b;
  }

  /** bake + make fadeable (called once the facade incl. shop front is complete) */
  private finalizeBuilding(b: THREE.Group) {
    mergeByMaterial(b);
    b.updateMatrixWorld(true);
    const mats: THREE.Material[] = [];
    b.traverse((o) => {
      const m = o as THREE.Mesh;
      if (m.isMesh) {
        // private material clones so the whole building can fade when it hides the shop
        const src = m.material as THREE.MeshStandardMaterial;
        const c = src.clone(); c.transparent = false; c.opacity = 1; m.material = c; mats.push(c);
        if (src === litWindow) (c as THREE.MeshStandardMaterial).userData.lit = true;
        if (src.userData.shopWindow) this.windowMats.push(c as THREE.MeshStandardMaterial);
      }
    });
    this.occluders.push({ obj: b, box: new THREE.Box3().setFromObject(b), mats, fade: 1 });
  }

  windowMats: THREE.MeshStandardMaterial[] = [];

  private shopFront(b: THREE.Group, w: number, d: number, face: 1 | -1, name: string, sub: string, colA: string, colB: string, glowCol: number) {
    const fz = face * (d / 2) + face * 0.03;
    const win = new THREE.Mesh(new THREE.BoxGeometry(w - 1.2, 2.0, 0.05), new THREE.MeshStandardMaterial({ color: 0x3b3f48, emissive: glowCol, emissiveIntensity: 0.35, roughness: 0.2 }));
    win.position.set(0, 1.55, fz); b.add(win);
    (win.material as THREE.MeshStandardMaterial).userData.shopWindow = true;
    const aw = new THREE.Mesh(new THREE.BoxGeometry(w - 0.6, 0.08, 1.4), new THREE.MeshStandardMaterial({ map: awningTexture(colA, colB), roughness: 0.8 }));
    aw.position.set(0, 2.85, fz + face * 0.65); aw.rotation.x = face * 0.3; aw.castShadow = true; b.add(aw);
    const signM = new THREE.MeshStandardMaterial({ map: signTexture(name, sub, { bg: colA, fg: '#fff', accent: colB, w: 512, h: 128 }), roughness: 0.6 });
    const sign = new THREE.Mesh(new THREE.BoxGeometry(w * 0.7, 0.6, 0.08), signM);
    sign.position.set(0, 3.45, fz + face * 0.05); if (face < 0) sign.rotation.y = Math.PI; b.add(sign);
  }

  private buildBuildings() {
    // left flank
    const a1 = this.apartment(0, 6, 10, 10, 4, 0xf3c9a4, 1, { roofExtras: true });
    void a1;
    // right: bakery (2 storeys) + apartment
    const bakery = this.apartment(26.2, 9, 7.8, 7, 2, 0xf6e1b5, 1, { shopFront: true });
    this.shopFront(bakery, 7.8, 7, 1, 'FIRIN', 'SICAK EKMEK', '#8a5a35', '#f2b33d', 0xffb45c);
    const a2 = this.apartment(34.2, 7, 9.8, 9, 5, 0xbfd8d2, 1, { roofExtras: true });
    void a2;
    // back row
    this.apartment(-4, -6, 11, 9, 5, 0xe8b7a6, 1, { roofExtras: true });
    this.apartment(8, -6, 10, 9, 6, 0xd9d2e9, 1, { roofExtras: true });
    this.apartment(19, -6, 12, 8.5, 5, 0xf2d7a0, 1, { roofExtras: true });
    this.apartment(32, -6, 13, 9, 4, 0xc9e0f0, 1, { roofExtras: true });
    // across the street (facing -z)
    const x1 = this.apartment(-2, FAR_WALK_Z1 + 0.6, 11, 8, 3, 0xe5c1d0, -1, { shopFront: true });
    this.shopFront(x1, 11, 8, -1, 'ECZANE', 'NÖBETÇİ', '#d6333a', '#ffffff', 0xd8fff0);
    const x2 = this.apartment(10, FAR_WALK_Z1 + 0.6, 9, 8, 4, 0xf0dcc2, -1, { shopFront: true });
    this.shopFront(x2, 9, 8, -1, 'BERBER', 'CEMAL USTA', '#1f5fa8', '#ffffff', 0xfff0c8);
    const x3 = this.apartment(20, FAR_WALK_Z1 + 0.6, 12, 8, 3, 0xcfe3c5, -1, { shopFront: true });
    this.shopFront(x3, 12, 8, -1, 'ÇAY OCAĞI', 'DEMLİ ÇAY', '#b44a28', '#f2b33d', 0xffc27a);
    const x4 = this.apartment(33, FAR_WALK_Z1 + 0.6, 12, 8, 5, 0xe9d8a6, -1, { shopFront: true });
    this.shopFront(x4, 12, 8, -1, 'KIRTASİYE', 'OKUL İHTİYAÇLARI', '#6c4ab6', '#f2b33d', 0xfff0c8);
    for (const b of this.pendingBuildings) this.finalizeBuilding(b);
  }
  private pendingBuildings: THREE.Group[] = [];

  private buildNeighborShop() {
    // closed shop at x 10..18, z 10..16 plus the upper storey band
    const g = this.neighborShop;
    const w = 8, d = 6, H = 3.2;
    g.position.set(14, 0, 13);
    const pt = plasterTexture('#e9d9c3'); pt.wrapS = pt.wrapT = THREE.RepeatWrapping; pt.repeat.set(3, 1);
    addMesh(g, new THREE.BoxGeometry(w - 0.1, H, d - 0.1), new THREE.MeshStandardMaterial({ map: pt, roughness: 0.9 }), 0, H / 2, 0);
    addMesh(g, new THREE.BoxGeometry(w + 0.1, 0.25, d + 0.1), mat(0xf6efe3, 0.8), 0, H + 0.12, 0);
    addMesh(g, new THREE.BoxGeometry(w - 0.5, 0.05, d - 0.5), mat(0x8b8178, 0.95), 0, H + 0.02, 0, 0, 0, 0, false);
    const sh = shutterTexture();
    const shutter = new THREE.Mesh(new THREE.BoxGeometry(w - 1.2, 2.4, 0.08), new THREE.MeshStandardMaterial({ map: sh, roughness: 0.5, metalness: 0.5 }));
    shutter.position.set(0, 1.25, d / 2 + 0.02); shutter.castShadow = true; g.add(shutter);
    addMesh(g, new THREE.BoxGeometry(w - 1.0, 0.3, 0.3), mat(0x7d868f, 0.4, 0.6), 0, 2.6, d / 2 + 0.1);
    // old faded sign
    const oldSign = new THREE.MeshStandardMaterial({ map: signTexture('TUHAFİYE', 'NUR', { bg: '#b8b0a4', fg: '#f3ede3', accent: '#8f877a', w: 512, h: 128 }), roughness: 0.9 });
    addMesh(g, new THREE.BoxGeometry(w * 0.72, 0.55, 0.08), oldSign, 0, 3.0, d / 2 + 0.06, 0, 0, 0, false);
    // "Devren Kiralık" poster
    const poster = canvasTexture(256, 180, (ctx, W, Hh) => {
      ctx.fillStyle = '#fff8e8'; ctx.fillRect(0, 0, W, Hh);
      ctx.fillStyle = '#d6333a'; ctx.fillRect(0, 0, W, 54);
      ctx.fillStyle = '#fff'; ctx.font = '800 40px "Baloo 2", system-ui'; ctx.textAlign = 'center'; ctx.fillText('DEVREN', W / 2, 42);
      ctx.fillStyle = '#d6333a'; ctx.font = '800 52px "Baloo 2", system-ui'; ctx.fillText('KİRALIK', W / 2, 108);
      ctx.fillStyle = '#1f2a44'; ctx.font = '600 22px "Baloo 2", system-ui'; ctx.fillText('0 5XX XXX XX XX', W / 2, 150);
    });
    const p = new THREE.Mesh(new THREE.PlaneGeometry(1.1, 0.78), new THREE.MeshStandardMaterial({ map: poster, roughness: 0.8 }));
    p.position.set(1.2, 1.4, d / 2 + 0.07); p.rotation.z = 0.04; g.add(p);
    // leftover crates & a sleeping cat
    const cat = new THREE.Group(); cat.position.set(-2.4, 0.06, d / 2 + 0.6);
    const fur = mat(0xe89b4f, 0.9);
    addMesh(cat, sphere(0.2, 12, 10), fur, 0, 0.14, 0).scale.set(1.3, 0.7, 0.9);
    addMesh(cat, sphere(0.12, 12, 10), fur, 0.22, 0.16, 0.05);
    for (const s of [-1, 1]) addMesh(cat, new THREE.ConeGeometry(0.04, 0.08, 4), fur, 0.25, 0.28, 0.05 + s * 0.06);
    addMesh(cat, new THREE.TorusGeometry(0.16, 0.035, 6, 12, Math.PI * 1.2), fur, -0.1, 0.08, 0.12, Math.PI / 2, 0, 0);
    g.add(cat);
    this.group.add(g);
    this.registerOccluder(g);
  }

  private registerOccluder(b: THREE.Object3D) {
    mergeByMaterial(b);
    b.updateMatrixWorld(true);
    const mats: THREE.Material[] = [];
    b.traverse((o) => {
      const m = o as THREE.Mesh;
      if (m.isMesh) { const c = (m.material as THREE.Material).clone(); c.transparent = false; m.material = c; mats.push(c); }
    });
    this.occluders.push({ obj: b, box: new THREE.Box3().setFromObject(b), mats, fade: 1 });
  }

  private buildBackyard() {
    // courtyard at x 10..26, z 6..10 behind the büfe, plus back strip x 10..18 behind neighbor
    const g = this.backyard;
    const conc = mat(0xbdb4a6, 0.95);
    const ground = new THREE.Mesh(new THREE.PlaneGeometry(16, 4), conc);
    ground.rotation.x = -Math.PI / 2; ground.position.set(18, 0.015, 8); ground.receiveShadow = true; g.add(ground);
    const bricks = brickTexture(0xb86a4a); bricks.wrapS = bricks.wrapT = THREE.RepeatWrapping; bricks.repeat.set(8, 1);
    const wallM = new THREE.MeshStandardMaterial({ map: bricks, roughness: 0.9 });
    addMesh(g, new THREE.BoxGeometry(16, 1.8, 0.25), wallM, 18, 0.9, 6.1);
    addMesh(g, new THREE.BoxGeometry(0.25, 1.8, 4), wallM, 10.1, 0.9, 8);
    addMesh(g, new THREE.BoxGeometry(16.2, 0.1, 0.35), mat(0xe8dccb, 0.8), 18, 1.85, 6.1, 0, 0, 0, false);
    // crates, gas cylinder, clothesline
    const card = mat(0xc89b63, 0.85);
    for (let i = 0; i < 5; i++) addMesh(g, rbox(0.6, 0.45, 0.45, 0.03), i % 2 ? card : mat(0x4f8a5b, 0.7), 12 + i * 0.7, 0.23 + (i === 2 ? 0.45 : 0), 7 + (i % 2) * 0.1, 0, i * 0.2, 0);
    addMesh(g, cyl(0.2, 0.2, 0.8, 14), mat(0x2f6fb5, 0.4, 0.3), 24.5, 0.4, 7);
    addMesh(g, cyl(0.2, 0.2, 0.8, 14), mat(0x2f6fb5, 0.4, 0.3), 24.1, 0.4, 7.3);
    // clothesline with laundry
    const pole = mat(0x6b6f76, 0.5, 0.5);
    addMesh(g, cyl(0.03, 0.03, 2.2, 6), pole, 13, 1.1, 8.8);
    addMesh(g, cyl(0.03, 0.03, 2.2, 6), pole, 17, 1.1, 8.8);
    addMesh(g, cyl(0.005, 0.005, 4, 4), pole, 15, 2.1, 8.8, 0, 0, Math.PI / 2, false);
    const cloth = [0xe0663c, 0xf2f0ea, 0x1f8a86, 0xf2b33d, 0x86a8e7];
    for (let i = 0; i < 5; i++) addMesh(g, new THREE.BoxGeometry(0.5, 0.6 + (i % 2) * 0.2, 0.02), mat(cloth[i], 0.9), 13.6 + i * 0.75, 1.75 - (i % 2) * 0.1, 8.8);
    this.group.add(g);
  }

  private carModel(color: number) {
    const c = new THREE.Group();
    const body = mat(color, 0.35, 0.3);
    addMesh(c, rbox(3.6, 0.7, 1.7, 0.2, 3), body, 0, 0.6, 0);
    addMesh(c, rbox(2.1, 0.62, 1.5, 0.22, 3), body, -0.2, 1.15, 0);
    const glass = mat(0x2a3a4e, 0.1, 0.5);
    addMesh(c, rbox(2.0, 0.5, 1.52, 0.18, 2), glass, -0.2, 1.17, 0, 0, 0, 0, false);
    for (const x of [-1.15, 1.15]) for (const z of [-0.8, 0.8]) {
      const w = addMesh(c, cyl(0.34, 0.34, 0.24, 16), mat(0x1c1d22, 0.8), x, 0.34, z, Math.PI / 2, 0, 0);
      void w;
      addMesh(c, cyl(0.18, 0.18, 0.25, 12), M.steel, x, 0.34, z, Math.PI / 2, 0, 0, false);
    }
    const lights = new THREE.MeshStandardMaterial({ color: 0xfff6d8, emissive: 0xfff0c0, emissiveIntensity: 0.1 });
    for (const z of [-0.55, 0.55]) addMesh(c, rbox(0.06, 0.16, 0.34, 0.03), lights, 1.8, 0.72, z, 0, 0, 0, false);
    for (const z of [-0.6, 0.6]) addMesh(c, rbox(0.06, 0.14, 0.3, 0.03), glow(0xd6333a, 0.8), -1.8, 0.75, z, 0, 0, 0, false);
    return { c, lights };
  }

  private buildTraffic() {
    const colors = [0xe0663c, 0x2f6fb5, 0xf2f0ea, 0xf2b33d, 0x3f8f86, 0x6c4ab6];
    const lanes = [ROAD_Z0 + 3.6, ROAD_Z1 - 1.3];
    for (let i = 0; i < 4; i++) {
      const { c, lights } = this.carModel(colors[i % colors.length]);
      const lane = i % 2;
      c.rotation.y = lane === 0 ? 0 : Math.PI;
      c.position.set(-20 + i * 22, 0, lanes[lane]);
      this.group.add(c);
      this.cars.push({ obj: c, lane, speed: 5 + i, x: -20 + i * 22, lights });
    }
    // parked cars
    for (const [x, col] of [[6, 0x9aa5b1], [31, 0xd6333a]] as const) {
      const { c } = this.carModel(col); c.position.set(x, 0, ROAD_Z0 + 1.05); this.group.add(c);
    }
  }

  private buildVan() {
    const v = new THREE.Group();
    const body = mat(0xf7f5f0, 0.4, 0.2);
    addMesh(v, rbox(4.4, 2.0, 1.9, 0.18, 3), body, -0.3, 1.35, 0);
    addMesh(v, rbox(1.3, 1.3, 1.85, 0.22, 3), body, 2.3, 1.0, 0);
    addMesh(v, rbox(0.1, 0.7, 1.6, 0.05), mat(0x2a3a4e, 0.1, 0.5), 2.95, 1.3, 0, 0, 0, 0.3, false);
    const logo = canvasTexture(512, 200, (ctx, w, h) => {
      ctx.fillStyle = '#f7f5f0'; ctx.fillRect(0, 0, w, h);
      ctx.fillStyle = '#1f8a86'; roundRect(ctx, 20, 30, w - 40, h - 60, 30); ctx.fill();
      ctx.fillStyle = '#fff'; ctx.font = '800 76px "Baloo 2", system-ui'; ctx.textAlign = 'center'; ctx.fillText('TOPTANCI', w / 2, 118);
      ctx.font = '600 30px "Baloo 2", system-ui'; ctx.fillText('HIZLI TEDARİK', w / 2, 152);
    });
    const lm = new THREE.MeshStandardMaterial({ map: logo, roughness: 0.6 });
    const side = new THREE.Mesh(new THREE.PlaneGeometry(3.6, 1.4), lm); side.position.set(-0.3, 1.45, 0.96); v.add(side);
    const side2 = side.clone(); side2.position.z = -0.96; side2.rotation.y = Math.PI; v.add(side2);
    for (const x of [-1.6, 1.9]) for (const z of [-0.85, 0.85]) addMesh(v, cyl(0.38, 0.38, 0.26, 16), mat(0x1c1d22, 0.8), x, 0.38, z, Math.PI / 2, 0, 0);
    return v;
  }

  removeNeighbor() {
    this.neighborShop.removeFromParent();
    this.backyard.removeFromParent();
  }

  /** night = 0..1 */
  /** points of interest (shop interior corners) the camera must be able to see */
  focusPoints: THREE.Vector3[] = [];

  update(dt: number, realDt: number, night: number, camPos: THREE.Vector3, target: THREE.Vector3) {
    for (const l of this.streetLights) l.intensity = night * 14;
    this.lampBulbs.emissiveIntensity = 0.2 + night * 4;
    for (const w of this.windowMats) w.emissiveIntensity = 0.25 + night * 1.2;
    for (const car of this.cars) {
      const dir = car.lane === 0 ? 1 : -1;
      car.x += dir * car.speed * dt;
      if (car.x > MAP_W + 30) car.x = -30;
      if (car.x < -30) car.x = MAP_W + 30;
      car.obj.position.x = car.x;
      car.lights.emissiveIntensity = 0.1 + night * 3;
    }
    // occluder fading: buildings between camera and focus become see-through
    const pts = [target, ...this.focusPoints];
    const rays = pts.map((p) => ({ ray: new THREE.Ray(camPos, p.clone().sub(camPos).normalize()), dist: camPos.distanceTo(p) }));
    const hit = new THREE.Vector3();
    for (const o of this.occluders) {
      if (!o.obj.parent) continue;
      let blocking = false;
      for (const r of rays) {
        const p = r.ray.intersectBox(o.box, hit);
        if (p && camPos.distanceTo(hit) < r.dist - 0.5) { blocking = true; break; }
      }
      const targetFade = blocking ? 0 : 1;
      o.fade += (targetFade - o.fade) * Math.min(1, realDt * 6);
      o.obj.visible = o.fade > 0.1;
      const fading = o.fade < 0.99;
      for (const m of o.mats) {
        if (m.transparent !== fading) { m.transparent = fading; m.needsUpdate = true; }
        m.opacity = o.fade;
        m.depthWrite = o.fade > 0.95;
        const sm = m as THREE.MeshStandardMaterial;
        if (sm.userData.lit) sm.emissiveIntensity = night * 1.1;
      }
    }
  }
}

function r3(r: () => number) { return Math.floor(r() * 3); }
