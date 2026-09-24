import * as THREE from 'three';
import { MAP_W, MAP_H } from '../config';
import { canvasTexture, roundRect } from './textures';
import { mat } from './materials';

interface Floater { sprite: THREE.Sprite; t: number; life: number; vy: number; w: number }

const textCache = new Map<string, { tex: THREE.Texture; aspect: number }>();
function textTexture(text: string, color: string, bg: string | null) {
  const key = text + color + bg;
  let t = textCache.get(key);
  if (t) return t;
  const H = 96;
  const probe = document.createElement('canvas').getContext('2d')!;
  probe.font = '800 54px "Baloo 2", system-ui';
  const W = Math.min(1024, Math.ceil(probe.measureText(text).width + (bg ? 64 : 28)));
  const tex = canvasTexture(W, H, (ctx, w, h) => {
    ctx.font = '800 54px "Baloo 2", system-ui'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    if (bg) {
      ctx.fillStyle = bg; roundRect(ctx, 4, 12, w - 8, h - 24, 30); ctx.fill();
    } else {
      ctx.lineWidth = 12; ctx.strokeStyle = 'rgba(255,255,255,0.96)'; ctx.lineJoin = 'round';
      ctx.strokeText(text, w / 2, h / 2 + 4);
    }
    ctx.fillStyle = color; ctx.fillText(text, w / 2, h / 2 + 4);
  }, { mips: false });
  t = { tex, aspect: W / H };
  textCache.set(key, t);
  return t;
}

export class Overlays {
  group = new THREE.Group();
  private floaters: Floater[] = [];
  heat: THREE.Mesh;
  private heatData: Uint8Array;
  private heatTex: THREE.DataTexture;
  buildGrid: THREE.Mesh;
  selectRing: THREE.Mesh;
  hoverRing: THREE.Mesh;
  queueLine: THREE.Line;

  constructor(private scene: THREE.Scene) {
    scene.add(this.group);
    // heat map
    this.heatData = new Uint8Array(MAP_W * MAP_H * 4);
    this.heatTex = new THREE.DataTexture(this.heatData, MAP_W, MAP_H, THREE.RGBAFormat);
    this.heatTex.magFilter = THREE.LinearFilter; this.heatTex.minFilter = THREE.LinearFilter;
    this.heatTex.flipY = false;
    this.heatTex.needsUpdate = true;
    const hg = new THREE.PlaneGeometry(MAP_W, MAP_H);
    hg.rotateX(-Math.PI / 2);
    this.heat = new THREE.Mesh(hg, new THREE.MeshBasicMaterial({ map: this.heatTex, transparent: true, depthWrite: false, toneMapped: false }));
    this.heat.position.set(MAP_W / 2, 0.1, MAP_H / 2);
    this.heat.visible = false; this.heat.renderOrder = 5;
    // plane UV: u along x, v along -z after rotation; flip so texel (x,z) maps to tile
    const uv = hg.attributes.uv as THREE.BufferAttribute;
    for (let i = 0; i < uv.count; i++) uv.setY(i, 1 - uv.getY(i));
    this.group.add(this.heat);

    // build grid
    const gt = canvasTexture(64, 64, (ctx, w, h) => {
      ctx.clearRect(0, 0, w, h);
      ctx.strokeStyle = 'rgba(255,255,255,0.55)'; ctx.lineWidth = 2;
      ctx.strokeRect(1, 1, w - 2, h - 2);
    }, { repeat: [MAP_W, MAP_H] });
    this.buildGrid = new THREE.Mesh(new THREE.PlaneGeometry(MAP_W, MAP_H).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ map: gt, transparent: true, depthWrite: false, opacity: 0.6 }));
    this.buildGrid.position.set(MAP_W / 2, 0.095, MAP_H / 2);
    this.buildGrid.visible = false;
    this.group.add(this.buildGrid);

    const ringTex = canvasTexture(128, 128, (ctx, w, h) => {
      ctx.clearRect(0, 0, w, h);
      ctx.strokeStyle = '#ffffff'; ctx.lineWidth = 10;
      ctx.beginPath(); ctx.arc(w / 2, h / 2, w / 2 - 10, 0, Math.PI * 2); ctx.stroke();
      ctx.setLineDash([10, 10]); ctx.lineWidth = 4; ctx.beginPath(); ctx.arc(w / 2, h / 2, w / 2 - 26, 0, Math.PI * 2); ctx.stroke();
    });
    this.selectRing = new THREE.Mesh(new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ map: ringTex, color: 0xf2b33d, transparent: true, depthWrite: false, toneMapped: false }));
    this.selectRing.visible = false; this.selectRing.renderOrder = 6;
    this.group.add(this.selectRing);
    this.hoverRing = new THREE.Mesh(new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ map: ringTex, color: 0xffffff, transparent: true, opacity: 0.6, depthWrite: false, toneMapped: false }));
    this.hoverRing.visible = false; this.hoverRing.renderOrder = 6;
    this.group.add(this.hoverRing);

    this.queueLine = new THREE.Line(new THREE.BufferGeometry(), new THREE.LineDashedMaterial({ color: 0xf2b33d, dashSize: 0.25, gapSize: 0.18, transparent: true, opacity: 0.9, depthTest: false }));
    this.queueLine.renderOrder = 7; this.queueLine.visible = false;
    this.group.add(this.queueLine);
  }

  floatText(pos: THREE.Vector3, text: string, color = '#1f8a86', bg: string | null = null, life = 1.6) {
    const tt = textTexture(text, color, bg);
    const m = new THREE.SpriteMaterial({ map: tt.tex, depthTest: false, depthWrite: false, transparent: true, toneMapped: false });
    const s = new THREE.Sprite(m);
    const h = 0.42;
    s.scale.set(h * tt.aspect, h, 1);
    s.position.copy(pos);
    s.renderOrder = 20;
    this.group.add(s);
    this.floaters.push({ sprite: s, t: 0, life, vy: 0.7, w: h * tt.aspect });
  }

  update(dt: number) {
    for (let i = this.floaters.length - 1; i >= 0; i--) {
      const f = this.floaters[i];
      f.t += dt;
      f.sprite.position.y += f.vy * dt;
      f.vy *= 0.97;
      const k = f.t / f.life;
      const pop = Math.min(1, f.t * 8);
      f.sprite.scale.set(f.w * pop, 0.42 * pop, 1);
      (f.sprite.material as THREE.SpriteMaterial).opacity = k < 0.7 ? 1 : 1 - (k - 0.7) / 0.3;
      if (f.t >= f.life) { f.sprite.removeFromParent(); (f.sprite.material as THREE.Material).dispose(); this.floaters.splice(i, 1); }
    }
    const t = performance.now() * 0.001;
    if (this.selectRing.visible) this.selectRing.rotation.y = t * 0.6;
  }

  updateHeat(traffic: Float32Array, mask: (i: number) => boolean) {
    let max = 4;
    for (let i = 0; i < traffic.length; i++) if (mask(i) && traffic[i] > max) max = traffic[i];
    for (let i = 0; i < traffic.length; i++) {
      const v = mask(i) ? Math.sqrt(Math.min(1, traffic[i] / max)) : 0;
      // ramp: transparent -> teal -> yellow -> red
      let r = 0, g = 0, b = 0;
      if (v < 0.5) { const k = v / 0.5; r = 31 + (242 - 31) * k; g = 138 + (179 - 138) * k; b = 134 + (61 - 134) * k; }
      else { const k = (v - 0.5) / 0.5; r = 242 + (229 - 242) * k; g = 179 + (72 - 179) * k; b = 61 + (77 - 61) * k; }
      this.heatData[i * 4] = r; this.heatData[i * 4 + 1] = g; this.heatData[i * 4 + 2] = b;
      this.heatData[i * 4 + 3] = mask(i) ? (v < 0.05 ? 60 : 150 + v * 105) : 0;
    }
    this.heatTex.needsUpdate = true;
  }

  setQueueLine(points: THREE.Vector3[] | null) {
    if (!points || points.length < 2) { this.queueLine.visible = false; return; }
    this.queueLine.geometry.dispose();
    this.queueLine.geometry = new THREE.BufferGeometry().setFromPoints(points);
    this.queueLine.computeLineDistances();
    this.queueLine.visible = true;
  }
}

/** Litter piece visuals */
export function litterMesh() {
  const g = new THREE.Group();
  const cols = [0xf6b93b, 0xd8352c, 0xf2f0ea, 0x2e6db4];
  const c = cols[(Math.random() * cols.length) | 0];
  const m = new THREE.Mesh(new THREE.IcosahedronGeometry(0.09, 0), mat(c, 0.6));
  m.scale.set(1.2, 0.5, 0.9); m.position.y = 0.1; m.rotation.set(Math.random(), Math.random() * 6, 0); m.castShadow = true;
  g.add(m);
  const m2 = new THREE.Mesh(new THREE.PlaneGeometry(0.16, 0.1), mat(0xf2f0ea, 0.8));
  m2.rotation.x = -Math.PI / 2; m2.rotation.z = Math.random() * 3; m2.position.set(0.1, 0.09, 0.05);
  g.add(m2);
  // stain
  const s = new THREE.Mesh(new THREE.CircleGeometry(0.22, 16), new THREE.MeshStandardMaterial({ color: 0x7a5a3a, transparent: true, opacity: 0.35, depthWrite: false }));
  s.rotation.x = -Math.PI / 2; s.position.y = 0.085; s.scale.set(1, 0.7, 1);
  g.add(s);
  return g;
}
