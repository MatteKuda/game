import * as THREE from 'three';
import { mat, rbox, sphere, capsule, cyl } from './materials';
import { addMesh } from './props';
import { productVisuals } from './products3d';
import { mergeRigidPart } from './merge';
import type { Accessory } from '../data/customers';

export type HairStyle = 'short' | 'long' | 'bun' | 'bald' | 'curly' | 'spiky';
export type Anim = 'idle' | 'walk' | 'reach' | 'pay' | 'angry' | 'happy' | 'carry' | 'sweep' | 'work' | 'fall' | 'push' | 'sit' | 'rest' | 'play';
export type Face = 'neutral' | 'happy' | 'sad' | 'angry' | 'surprised';

export interface Look {
  skin: number;
  hair: number;
  hairStyle: HairStyle;
  top: number;
  bottom: number;
  shoes: number;
  height: number; // scale
  girth: number;
  accessory?: Accessory | 'apron' | 'cap' | 'chef';
  accent?: number;
  glasses?: boolean;
  beard?: boolean;
}

/** Procedurally animated chunky little person */
export class CharacterView {
  root = new THREE.Group();
  body = new THREE.Group(); // bobbing part
  private hips = new THREE.Group();
  private legL = new THREE.Group();
  private legR = new THREE.Group();
  private armL = new THREE.Group();
  private armR = new THREE.Group();
  private head = new THREE.Group();
  private mouth: THREE.Mesh;
  private browL: THREE.Mesh;
  private browR: THREE.Mesh;
  private basket: THREE.Group | null = null;
  private basketItems: THREE.Mesh[] = [];
  private box: THREE.Group;
  private broom: THREE.Group;
  anim: Anim = 'idle';
  face: Face = 'neutral';
  private t = Math.random() * 10;
  private animT = 0;
  walkSpeed = 1.4;
  private faceSet: Face | null = null;
  readonly headY: number;

  constructor(public look: Look, withBasket = false) {
    const L = look;
    const skin = mat(L.skin, 0.65);
    const top = mat(L.top, 0.78);
    const bottom = mat(L.bottom, 0.8);
    const shoes = mat(L.shoes, 0.6);
    const hairM = mat(L.hair, 0.85);
    this.root.add(this.body);
    this.body.scale.setScalar(L.height);

    // legs
    for (const [leg, side] of [[this.legL, -1], [this.legR, 1]] as const) {
      leg.position.set(side * 0.095, 0.56, 0);
      addMesh(leg, capsule(0.078, 0.3, 4, 10), bottom, 0, -0.24, 0);
      addMesh(leg, rbox(0.14, 0.09, 0.22, 0.04), shoes, 0, -0.52, 0.035);
      this.body.add(leg);
    }
    // hips
    addMesh(this.hips, rbox(0.34 * L.girth, 0.2, 0.24, 0.08), bottom, 0, 0, 0);
    this.hips.position.y = 0.62; this.body.add(this.hips);
    // torso
    const torso = addMesh(this.body, capsule(0.19, 0.26, 6, 14), top, 0, 0.92, 0);
    torso.scale.set(L.girth, 1, 0.78);
    if (L.accessory === 'apron' || L.accessory === 'chef') {
      const apron = addMesh(this.body, rbox(0.3, 0.56, 0.04, 0.03), mat(L.accessory === 'chef' ? 0xffffff : L.accent ?? 0x1f8a86, 0.8), 0, 0.84, 0.14);
      apron.scale.x = L.girth;
      addMesh(this.body, rbox(0.08, 0.05, 0.01, 0.01), mat(0xffffff, 0.4), 0.07, 1.0, 0.165, 0, 0, 0, false);
    }
    // arms
    for (const [arm, side] of [[this.armL, -1], [this.armR, 1]] as const) {
      arm.position.set(side * (0.215 * L.girth + 0.03), 1.1, 0);
      addMesh(arm, capsule(0.058, 0.28, 4, 8), top, 0, -0.17, 0);
      addMesh(arm, sphere(0.058, 10, 8), skin, 0, -0.38, 0);
      this.body.add(arm);
    }
    // head
    this.head.position.y = 1.38;
    this.body.add(this.head);
    addMesh(this.head, sphere(0.2, 20, 16), skin, 0, 0, 0);
    addMesh(this.head, cyl(0.07, 0.08, 0.1, 10), skin, 0, -0.2, 0);
    addMesh(this.head, sphere(0.035, 8, 6), mat(shadeNum(L.skin, 0.92), 0.6), 0, -0.02, 0.2, 0, 0, 0, false);
    const eyeM = mat(0x1d1a22, 0.3);
    for (const s of [-1, 1]) {
      addMesh(this.head, sphere(0.024, 8, 6), eyeM, s * 0.075, 0.035, 0.178, 0, 0, 0, false);
      addMesh(this.head, sphere(0.008, 6, 4), mat(0xffffff, 0.2), s * 0.075 + 0.008, 0.045, 0.199, 0, 0, 0, false);
      addMesh(this.head, sphere(0.03, 8, 6), mat(0xf29a8a, 0.8), s * 0.12, -0.04, 0.155, 0, 0, 0, false).scale.set(1, 0.6, 0.4);
    }
    this.browL = addMesh(this.head, rbox(0.06, 0.014, 0.012, 0.006), mat(shadeNum(L.hair, 0.9), 0.8), -0.075, 0.09, 0.182, 0, 0, 0, false);
    this.browR = addMesh(this.head, rbox(0.06, 0.014, 0.012, 0.006), mat(shadeNum(L.hair, 0.9), 0.8), 0.075, 0.09, 0.182, 0, 0, 0, false);
    const mouthGeo = new THREE.TorusGeometry(0.04, 0.009, 6, 12, Math.PI);
    this.mouth = addMesh(this.head, mouthGeo, mat(0x6b2a2a, 0.6), 0, -0.075, 0.178, 0, 0, Math.PI, false);
    if (L.glasses) {
      const gm = mat(0x222222, 0.3, 0.3);
      for (const s of [-1, 1]) { const r = addMesh(this.head, new THREE.TorusGeometry(0.038, 0.007, 6, 16), gm, s * 0.075, 0.035, 0.19, 0, 0, 0, false); void r; }
      addMesh(this.head, rbox(0.05, 0.008, 0.008, 0.003), gm, 0, 0.04, 0.195, 0, 0, 0, false);
    }
    if (L.beard) {
      const b = addMesh(this.head, sphere(0.16, 14, 10), hairM, 0, -0.1, 0.06, 0, 0, 0, false);
      b.scale.set(1.05, 0.7, 0.85);
    }
    this.buildHair(L.hairStyle, hairM);
    this.buildAccessory(L.accessory, L);

    // blob shadow handled globally; carried box (staff)
    this.box = new THREE.Group();
    addMesh(this.box, rbox(0.4, 0.28, 0.3, 0.02), mat(0xc89b63, 0.85), 0, 0, 0);
    addMesh(this.box, rbox(0.06, 0.004, 0.31, 0.002), mat(0xe8d6b2, 0.7), 0, 0.142, 0, 0, 0, 0, false);
    this.box.position.set(0, 0.95, 0.32); this.box.visible = false;
    this.body.add(this.box);
    this.broom = new THREE.Group();
    addMesh(this.broom, cyl(0.015, 0.015, 1.2, 6), mat(0x8a5a35, 0.7), 0, 0.6, 0);
    addMesh(this.broom, rbox(0.3, 0.08, 0.08, 0.02), mat(0xf2b33d, 0.8), 0, 0.02, 0);
    this.broom.position.set(0.25, 0.05, 0.3); this.broom.rotation.x = 0.35; this.broom.visible = false;
    this.body.add(this.broom);
    if (withBasket) this.ensureBasket();
    this.headY = 1.38 * L.height + 0.3;
    // bake rigid parts into single vertex-coloured meshes (expression parts stay live)
    this.mouth.userData.dynamic = true; this.browL.userData.dynamic = true; this.browR.userData.dynamic = true;
    for (const part of [this.body, this.hips, this.legL, this.legR, this.armL, this.armR, this.head, this.box, this.broom]) mergeRigidPart(part);

    this.root.traverse((o) => { if ((o as THREE.Mesh).isMesh) { o.castShadow = true; } });
  }

  private buildHair(style: HairStyle, hairM: THREE.Material) {
    const h = this.head;
    const cap = (sy = 1) => {
      const g = new THREE.SphereGeometry(0.212, 18, 12, 0, Math.PI * 2, 0, Math.PI * 0.55);
      const m = addMesh(h, g, hairM, 0, 0.01, -0.012, -0.2, 0, 0);
      m.scale.set(1, sy, 1.02);
      return m;
    };
    switch (style) {
      case 'short': cap(0.95); break;
      case 'spiky': {
        cap(0.9);
        for (let i = 0; i < 7; i++) addMesh(h, new THREE.ConeGeometry(0.05, 0.12, 6), hairM, Math.cos(i * 0.9) * 0.1, 0.19, Math.sin(i * 0.9) * 0.1 - 0.02, Math.sin(i) * 0.5, 0, Math.cos(i) * 0.5);
        break;
      }
      case 'long': {
        cap(1);
        const back = addMesh(h, capsule(0.18, 0.22, 6, 12), hairM, 0, -0.14, -0.08);
        back.scale.set(1.12, 1, 0.7);
        break;
      }
      case 'bun': cap(1); addMesh(h, sphere(0.09, 12, 10), hairM, 0, 0.2, -0.12); break;
      case 'curly':
        for (let i = 0; i < 16; i++) {
          const a = i * 2.39996, r = 0.15 + (i % 3) * 0.02;
          addMesh(h, sphere(0.075, 10, 8), hairM, Math.cos(a) * r * 0.9, 0.1 + ((i * 7) % 5) * 0.025, Math.sin(a) * r * 0.8 - 0.04);
        }
        break;
      case 'bald': {
        for (const s of [-1, 1]) addMesh(h, sphere(0.08, 10, 8), hairM, s * 0.17, 0.0, -0.06).scale.set(0.5, 0.9, 1.2);
        addMesh(h, sphere(0.1, 10, 8), hairM, 0, -0.02, -0.15).scale.set(1.5, 0.8, 0.6);
        break;
      }
    }
  }

  private buildAccessory(acc: Look['accessory'], L: Look) {
    const accent = mat(L.accent ?? 0xe0663c, 0.7);
    switch (acc) {
      case 'backpack': {
        addMesh(this.body, rbox(0.32, 0.4, 0.18, 0.07), accent, 0, 0.95, -0.2);
        addMesh(this.body, rbox(0.22, 0.14, 0.06, 0.04), mat(shadeNum(L.accent ?? 0xe0663c, 0.8), 0.7), 0, 0.85, -0.3);
        for (const s of [-1, 1]) addMesh(this.body, rbox(0.04, 0.36, 0.3, 0.015), mat(0x2b2b2b, 0.7), s * 0.12, 1.0, -0.03).scale.set(1, 1, 0.9);
        break;
      }
      case 'flatcap': {
        const c = addMesh(this.head, cyl(0.2, 0.215, 0.08, 18), accent, 0, 0.16, -0.01, -0.12);
        void c;
        addMesh(this.head, rbox(0.2, 0.02, 0.12, 0.01), accent, 0, 0.13, 0.19, -0.2);
        break;
      }
      case 'cane': break;
      case 'briefcase': {
        const b = addMesh(this.armR, rbox(0.1, 0.28, 0.36, 0.03), mat(0x5b3a24, 0.5), 0.03, -0.52, 0);
        void b;
        addMesh(this.armR, rbox(0.03, 0.05, 0.12, 0.01), mat(0x2a2a2a, 0.5), 0.03, -0.37, 0);
        // tie
        addMesh(this.body, rbox(0.06, 0.3, 0.02, 0.02), accent, 0, 0.98, 0.15, 0.05);
        break;
      }
      case 'totebag': {
        const bag = addMesh(this.body, rbox(0.3, 0.34, 0.1, 0.05), mat(0xf0e2c8, 0.9), -0.3, 0.72, 0.02, 0, 0, 0.08);
        void bag;
        addMesh(this.body, new THREE.TorusGeometry(0.2, 0.012, 6, 16, Math.PI), mat(0xd8c4a0, 0.9), -0.27, 0.9, 0.02, 0, Math.PI / 2, 0.2);
        break;
      }
      case 'hood': {
        // hoodie hood pulled up + kangaroo pocket
        const hood = addMesh(this.head, new THREE.SphereGeometry(0.235, 16, 12, 0, Math.PI * 2, 0, Math.PI * 0.62), accent, 0, 0.0, -0.03, -0.35);
        hood.scale.set(1.05, 1.05, 1.08);
        addMesh(this.body, rbox(0.24, 0.12, 0.04, 0.03), mat(shadeNum(L.top, 0.8), 0.9), 0, 0.78, 0.15);
        break;
      }
      case 'cap': {
        // security: peaked cap + badge
        addMesh(this.head, cyl(0.2, 0.22, 0.12, 16), mat(0x1b2130, 0.6), 0, 0.17, 0, -0.1);
        addMesh(this.head, rbox(0.24, 0.02, 0.15, 0.01), mat(0x11151e, 0.4), 0, 0.12, 0.2, -0.25);
        addMesh(this.head, rbox(0.06, 0.05, 0.02, 0.01), mat(0xf2b33d, 0.3, 0.6), 0, 0.2, 0.2, -0.1);
        addMesh(this.body, rbox(0.08, 0.1, 0.02, 0.01), mat(0xf2b33d, 0.3, 0.6), 0.09, 1.02, 0.155);
        addMesh(this.body, rbox(0.1, 0.04, 0.02, 0.01), mat(0xffffff, 0.5), -0.08, 1.04, 0.155);
        break;
      }
      case 'chef': {
        const hat = new THREE.Group(); hat.position.y = 0.16; this.head.add(hat);
        addMesh(hat, cyl(0.17, 0.17, 0.14, 16), mat(0xffffff, 0.8), 0, 0.05, 0);
        for (let i = 0; i < 5; i++) addMesh(hat, sphere(0.09, 10, 8), mat(0xffffff, 0.85), Math.cos(i * 1.26) * 0.09, 0.17, Math.sin(i * 1.26) * 0.09);
        addMesh(hat, sphere(0.11, 10, 8), mat(0xffffff, 0.85), 0, 0.2, 0);
        mergeRigidPart(hat);
        break;
      }
      case 'apron': {
        // visor cap for staff
        const c = addMesh(this.head, new THREE.SphereGeometry(0.215, 16, 10, 0, Math.PI * 2, 0, Math.PI * 0.42), accent, 0, 0.03, 0, -0.1);
        void c;
        addMesh(this.head, rbox(0.22, 0.02, 0.14, 0.01), accent, 0, 0.12, 0.2, -0.15);
        break;
      }
    }
  }

  ensureBasket() {
    if (this.basket) return;
    const b = new THREE.Group();
    const red = mat(0xe0453a, 0.55);
    addMesh(b, rbox(0.34, 0.16, 0.24, 0.03), red, 0, 0, 0);
    addMesh(b, new THREE.TorusGeometry(0.1, 0.012, 6, 12, Math.PI), mat(0x1f2a44, 0.5), 0, 0.08, 0, 0, Math.PI / 2, 0);
    b.position.set(0, -0.48, 0.03);
    b.rotation.y = Math.PI / 2;
    this.armL.add(b);
    this.basket = b;
    b.traverse((o) => { if ((o as THREE.Mesh).isMesh) o.castShadow = true; });
  }

  setBasketItems(pids: string[]) {
    if (!this.basket) this.ensureBasket();
    for (const m of this.basketItems) m.removeFromParent();
    this.basketItems = [];
    pids.slice(0, 4).forEach((pid, i) => {
      const v = productVisuals.get(pid); if (!v) return;
      const m = new THREE.Mesh(v.geometry, v.material);
      const s = 0.14 / Math.max(v.height, v.footprint) + 0.35;
      m.scale.setScalar(Math.min(0.9, s));
      m.position.set(-0.09 + (i % 2) * 0.16, 0.03 + Math.floor(i / 2) * 0.05, ((i % 3) - 1) * 0.04);
      m.rotation.set(0.3 * (i % 2 ? 1 : -1), i, 0.2);
      this.basket!.add(m);
      this.basketItems.push(m);
    });
  }

  private cart: THREE.Group | null = null;
  setCart(on: boolean) {
    if (on && !this.cart) {
      const c = new THREE.Group();
      const wire = mat(0xc3cad2, 0.35, 0.8), red = mat(0xe0453a, 0.5), dark = mat(0x2a2d33, 0.8);
      addMesh(c, rbox(0.46, 0.34, 0.66, 0.03), mat(0xd9dfe6, 0.3, 0.7), 0, 0.72, 0);
      addMesh(c, rbox(0.4, 0.3, 0.6, 0.02), mat(0x9aa3ab, 0.4, 0.6), 0, 0.74, 0);
      addMesh(c, rbox(0.5, 0.04, 0.04, 0.02), red, 0, 0.98, -0.36);
      for (const [x, z] of [[-0.18, -0.26], [0.18, -0.26], [-0.18, 0.26], [0.18, 0.26]]) {
        addMesh(c, cyl(0.012, 0.012, 0.5, 6), wire, x, 0.3, z);
        addMesh(c, cyl(0.05, 0.05, 0.04, 10), dark, x, 0.05, z, 0, 0, Math.PI / 2);
      }
      addMesh(c, rbox(0.42, 0.02, 0.6, 0.01), wire, 0, 0.22, 0);
      c.position.set(0, 0, 0.72);
      mergeRigidPart(c);
      c.traverse((o) => { if ((o as THREE.Mesh).isMesh) o.castShadow = true; o.userData.agentPart = true; });
      this.root.add(c);
      this.cart = c;
    }
    if (this.cart) this.cart.visible = on;
    if (this.basket) this.basket.visible = !on;
    if (on && this.basket && this.cart) {
      // move basket items into the cart
      for (const m of this.basketItems) { this.cart.add(m); m.position.y += 0.78; m.position.x *= 1.4; }
    }
  }

  private bags = 0;
  addBag(color: number) {
    if (this.bags >= 2) return;
    const b = new THREE.Group();
    addMesh(b, rbox(0.22, 0.26, 0.09, 0.02), mat(color, 0.85), 0, -0.12, 0);
    addMesh(b, new THREE.TorusGeometry(0.06, 0.008, 6, 10, Math.PI), mat(0x2a2d33, 0.6), 0, 0.01, 0);
    b.position.set(0, -0.44, 0.02 + this.bags * 0.05);
    b.rotation.y = Math.PI / 2 + this.bags * 0.3;
    (this.bags ? this.armL : this.armR).add(b);
    b.traverse((o) => { if ((o as THREE.Mesh).isMesh) o.castShadow = true; });
    this.bags++;
  }

  setCarry(on: boolean) { this.box.visible = on; }
  setBroom(on: boolean) { this.broom.visible = on; }

  play(a: Anim) {
    if (this.anim !== a) { this.anim = a; this.animT = 0; }
  }

  setFace(f: Face) {
    if (this.faceSet === f) return;
    this.faceSet = f; this.face = f;
    const m = this.mouth;
    switch (f) {
      case 'happy': m.rotation.z = Math.PI; m.scale.set(1.1, 1.2, 1); m.position.y = -0.07; break;
      case 'neutral': m.rotation.z = Math.PI; m.scale.set(0.8, 0.35, 1); m.position.y = -0.08; break;
      case 'sad': m.rotation.z = 0; m.scale.set(0.8, 0.6, 1); m.position.y = -0.1; break;
      case 'angry': m.rotation.z = 0; m.scale.set(1.0, 0.8, 1); m.position.y = -0.1; break;
      case 'surprised': m.rotation.z = Math.PI; m.scale.set(0.5, 1.6, 1); m.position.y = -0.075; break;
    }
    const tilt = f === 'angry' ? 0.45 : f === 'sad' ? -0.35 : f === 'surprised' ? 0 : 0;
    this.browL.rotation.z = -tilt; this.browR.rotation.z = tilt;
    this.browL.position.y = this.browR.position.y = f === 'surprised' ? 0.11 : f === 'angry' ? 0.08 : 0.09;
  }

  update(dt: number, moving: number) {
    this.t += dt; this.animT += dt;
    const t = this.t;
    const a = this.anim;
    // reset
    let legSwing = 0, armSwing = 0, bob = 0, lean = 0;
    let armLx = 0, armRx = 0, armLz = 0.08, armRz = -0.08;
    let headY = 0, headX = 0, bodyY = 0;
    if (a === 'walk' || a === 'carry' || (a === 'push' && moving > 0.05)) {
      const f = 7.5 * (this.walkSpeed / 1.4) * Math.max(0.35, moving);
      const ph = t * f;
      legSwing = Math.sin(ph) * 0.55;
      armSwing = Math.sin(ph) * 0.5;
      bob = Math.abs(Math.cos(ph)) * 0.045;
      lean = 0.06;
      headY = Math.sin(ph * 0.5) * 0.05;
    } else {
      bob = Math.sin(t * 2) * 0.006;
      headY = Math.sin(t * 0.6) * 0.25 * (a === 'idle' ? 1 : 0.2);
    }
    armLx = armSwing; armRx = -armSwing;
    switch (a) {
      case 'reach': {
        const k = Math.min(1, this.animT / 0.35);
        armRx = -1.6 * k + Math.sin(this.animT * 8) * 0.1; armRz = -0.1;
        headX = -0.15 * k; break;
      }
      case 'pay': armRx = -1.1 + Math.sin(this.animT * 6) * 0.15; break;
      case 'work': armRx = -0.9 + Math.sin(t * 9) * 0.25; armLx = -0.7 + Math.cos(t * 7) * 0.2; headX = 0.25; break;
      case 'angry': {
        armLx = -0.3; armRx = -0.3; armLz = 0.7 + Math.sin(t * 20) * 0.15; armRz = -0.7 - Math.sin(t * 20) * 0.15;
        bodyY = Math.abs(Math.sin(t * 10)) * 0.04; headX = -0.1; break;
      }
      case 'happy': {
        const hop = Math.max(0, Math.sin(this.animT * 9));
        bodyY = hop * 0.12 * Math.max(0, 1 - this.animT / 1.6);
        armRx = -2.6; armRz = -0.3; break;
      }
      case 'carry': armLx = -1.25; armRx = -1.25; armLz = 0.25; armRz = -0.25; break;
      case 'sweep': armLx = -0.8 + Math.sin(t * 6) * 0.3; armRx = -0.7 + Math.sin(t * 6) * 0.3; this.broom.rotation.z = Math.sin(t * 6) * 0.4; break;
      case 'push': armLx = -1.15; armRx = -1.15; armLz = 0.18; armRz = -0.18; lean = 0.12; break;
      case 'fall': {
        const k = Math.min(1, this.animT / 0.25);
        lean = -1.35 * k; bodyY = -0.5 * k; armLx = -2.4 * k; armRx = -2.2 * k; armLz = 0.6; armRz = -0.6;
        legSwing = -0.6 * k; headX = 0.3;
        break;
      }
      case 'sit': {
        this.legL.rotation.x = this.legR.rotation.x = -1.45;
        bodyY = -0.34; armLx = -0.6; armRx = -0.9 + Math.max(0, Math.sin(t * 2.5)) * -0.7; headX = 0.15;
        this.body.position.y = bodyY; this.body.rotation.x = 0;
        this.armL.rotation.x = armLx; this.armR.rotation.x = armRx;
        this.head.rotation.y = headY; this.head.rotation.x = headX;
        return;
      }
      case 'rest': {
        const sip = Math.max(0, Math.sin(t * 1.6));
        armRx = -1.2 - sip * 0.9; armRz = -0.25; headX = -0.1 * sip;
        break;
      }
      case 'play': {
        bodyY = Math.abs(Math.sin(t * 7)) * 0.14;
        armLx = -2.4 + Math.sin(t * 7) * 0.4; armRx = -2.4 - Math.sin(t * 7) * 0.4; armLz = 0.4; armRz = -0.4;
        break;
      }
    }
    this.legL.rotation.x = a === 'fall' ? legSwing : legSwing; this.legR.rotation.x = a === 'fall' ? legSwing * 0.6 : -legSwing;
    this.armL.rotation.x = armLx; this.armR.rotation.x = armRx;
    this.armL.rotation.z = -armLz; this.armR.rotation.z = -armRz;
    this.body.position.y = bob + bodyY;
    this.body.rotation.x = lean;
    this.head.rotation.y = headY;
    this.head.rotation.x = headX;
  }

  dispose() { this.root.removeFromParent(); }
}

export function shadeNum(c: number, f: number) {
  const r = Math.min(255, ((c >> 16) & 255) * f), g = Math.min(255, ((c >> 8) & 255) * f), b = Math.min(255, (c & 255) * f);
  return ((r | 0) << 16) | ((g | 0) << 8) | (b | 0);
}
