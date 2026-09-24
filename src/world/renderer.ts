import * as THREE from 'three';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
import { GTAOPass } from 'three/examples/jsm/postprocessing/GTAOPass.js';
import { ShaderPass } from 'three/examples/jsm/postprocessing/ShaderPass.js';
import { OutputPass } from 'three/examples/jsm/postprocessing/OutputPass.js';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';
import { setMaxAnisotropy } from './textures';

export type Quality = 'high' | 'balanced' | 'low';

const GradeShader = {
  uniforms: {
    tDiffuse: { value: null },
    uVignette: { value: 0.32 },
    uWarm: { value: new THREE.Vector3(1.03, 1.0, 0.96) },
    uSat: { value: 1.14 },
  },
  vertexShader: `varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }`,
  fragmentShader: `
    uniform sampler2D tDiffuse; uniform float uVignette; uniform vec3 uWarm; uniform float uSat; varying vec2 vUv;
    void main(){
      vec4 c = texture2D(tDiffuse, vUv);
      vec3 col = c.rgb * uWarm;
      float l = dot(col, vec3(0.2126,0.7152,0.0722));
      col = mix(vec3(l), col, uSat);
      vec2 d = vUv - 0.5; float v = 1.0 - dot(d,d) * uVignette * 2.2;
      col *= clamp(v, 0.0, 1.0);
      gl_FragColor = vec4(col, c.a);
    }`,
};

// GTAO renders its own depth/normal pre-pass with an override material. Sprites would appear there as
// un-billboarded quads and see-through meshes (glass, faded buildings, overlays) would cast phantom AO,
// so we hide them from that pass.
(GTAOPass.prototype as unknown as { _overrideVisibility: () => void })._overrideVisibility = function (this: { scene: THREE.Scene; _visibilityCache: THREE.Object3D[] }) {
  const cache = this._visibilityCache;
  this.scene.traverse((o) => {
    if (!o.visible) return;
    const m = (o as THREE.Mesh).material as THREE.Material | undefined;
    const seeThrough = !!m && !Array.isArray(m) && m.transparent && m.opacity < 0.6;
    if ((o as THREE.Sprite).isSprite || (o as THREE.Points).isPoints || (o as THREE.Line).isLine || seeThrough || o.userData.noAO) {
      o.visible = false; cache.push(o);
    }
  });
};

interface Key { h: number; sun: THREE.Color; sunI: number; sky: THREE.Color; ground: THREE.Color; hemiI: number; top: THREE.Color; bottom: THREE.Color; fog: THREE.Color; exp: number }
const C = (h: number) => new THREE.Color(h);
const KEYS: Key[] = [
  { h: 5.0, sun: C(0x6d7bd6), sunI: 0.25, sky: C(0x33406e), ground: C(0x2a2433), hemiI: 0.55, top: C(0x1a2248), bottom: C(0x4c4a7a), fog: C(0x3b4170), exp: 1.0 },
  { h: 7.0, sun: C(0xffb07a), sunI: 1.6, sky: C(0xf7c9a8), ground: C(0x8c7a6a), hemiI: 0.9, top: C(0x8fb8e8), bottom: C(0xffd0b0), fog: C(0xf2d2bd), exp: 1.0 },
  { h: 10.0, sun: C(0xfff0d8), sunI: 2.7, sky: C(0xcfe6ff), ground: C(0xb59a7c), hemiI: 1.05, top: C(0x74b2ea), bottom: C(0xdcefff), fog: C(0xdfeaf2), exp: 1.0 },
  { h: 14.0, sun: C(0xfff6e8), sunI: 3.0, sky: C(0xd6ebff), ground: C(0xb59a7c), hemiI: 1.1, top: C(0x6eaee8), bottom: C(0xe0f0ff), fog: C(0xe2ecf3), exp: 1.0 },
  { h: 17.5, sun: C(0xffcf8f), sunI: 2.5, sky: C(0xffe2c0), ground: C(0xa98b70), hemiI: 1.0, top: C(0x7aa8de), bottom: C(0xffdcb8), fog: C(0xf1dcc6), exp: 1.0 },
  { h: 19.5, sun: C(0xff8a5c), sunI: 1.3, sky: C(0xf4a58a), ground: C(0x6e5a60), hemiI: 0.8, top: C(0x4d5ca8), bottom: C(0xff9e7a), fog: C(0xd99a8c), exp: 1.0 },
  { h: 21.0, sun: C(0x7f8fe0), sunI: 0.4, sky: C(0x3e4c8a), ground: C(0x24223a), hemiI: 0.5, top: C(0x1d2552), bottom: C(0x5a5a9a), fog: C(0x3f4478), exp: 1.05 },
  { h: 24.0, sun: C(0x6d7bd6), sunI: 0.3, sky: C(0x2c3868), ground: C(0x201d30), hemiI: 0.42, top: C(0x141b3d), bottom: C(0x3c3c70), fog: C(0x2f3560), exp: 1.05 },
];

export class Renderer {
  renderer: THREE.WebGLRenderer;
  scene = new THREE.Scene();
  camera: THREE.PerspectiveCamera;
  composer: EffectComposer;
  sun: THREE.DirectionalLight;
  hemi: THREE.HemisphereLight;
  private gtao: GTAOPass;
  private bloom: UnrealBloomPass;
  private grade: ShaderPass;
  private skyMat: THREE.ShaderMaterial;
  quality: Quality = 'high';
  night = 0;

  constructor(canvas: HTMLCanvasElement) {
    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: false, powerPreference: 'high-performance', preserveDrawingBuffer: false });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.setSize(window.innerWidth, window.innerHeight);
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFShadowMap;
    this.renderer.toneMapping = THREE.NeutralToneMapping;
    this.renderer.toneMappingExposure = 1.0;
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    setMaxAnisotropy(this.renderer.capabilities.getMaxAnisotropy());

    this.camera = new THREE.PerspectiveCamera(32, window.innerWidth / window.innerHeight, 0.5, 400);

    const pmrem = new THREE.PMREMGenerator(this.renderer);
    this.scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
    this.scene.environmentIntensity = 0.45;

    // sky dome
    this.skyMat = new THREE.ShaderMaterial({
      side: THREE.BackSide, depthWrite: false,
      uniforms: { top: { value: new THREE.Color() }, bottom: { value: new THREE.Color() } },
      vertexShader: `varying vec3 vP; void main(){ vP = normalize(position); gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }`,
      fragmentShader: `uniform vec3 top; uniform vec3 bottom; varying vec3 vP; void main(){ float t = smoothstep(-0.05, 0.6, vP.y); gl_FragColor = vec4(mix(bottom, top, t), 1.0); }`,
    });
    const sky = new THREE.Mesh(new THREE.SphereGeometry(300, 24, 16), this.skyMat);
    sky.frustumCulled = false;
    this.scene.add(sky);
    this.scene.fog = new THREE.Fog(0xdfeaf2, 70, 180);

    this.hemi = new THREE.HemisphereLight(0xcfe6ff, 0xb59a7c, 1.0);
    this.scene.add(this.hemi);
    this.sun = new THREE.DirectionalLight(0xfff0d8, 2.6);
    this.sun.castShadow = true;
    this.sun.shadow.mapSize.set(2048, 2048);
    const sc = this.sun.shadow.camera;
    sc.left = -26; sc.right = 26; sc.top = 26; sc.bottom = -26; sc.near = 1; sc.far = 120;
    this.sun.shadow.bias = -0.0004;
    this.sun.shadow.normalBias = 0.03;
    this.sun.shadow.radius = 3;
    this.scene.add(this.sun, this.sun.target);

    const rt = new THREE.WebGLRenderTarget(window.innerWidth, window.innerHeight, { type: THREE.HalfFloatType, samples: 4 });
    this.composer = new EffectComposer(this.renderer, rt);
    this.composer.addPass(new RenderPass(this.scene, this.camera));
    this.gtao = new GTAOPass(this.scene, this.camera, window.innerWidth, window.innerHeight);
    this.gtao.output = GTAOPass.OUTPUT.Default;
    this.gtao.blendIntensity = 0.85;
    this.gtao.updateGtaoMaterial({ radius: 0.55, distanceExponent: 1.4, thickness: 1.2, scale: 1.0, samples: 12 });
    this.gtao.updatePdMaterial({ lumaPhi: 10, depthPhi: 2, normalPhi: 3, radius: 6, rings: 2, samples: 12 });
    this.composer.addPass(this.gtao);
    this.bloom = new UnrealBloomPass(new THREE.Vector2(window.innerWidth, window.innerHeight), 0.3, 0.45, 1.25);
    this.composer.addPass(this.bloom);
    this.grade = new ShaderPass(GradeShader);
    this.composer.addPass(this.grade);
    this.composer.addPass(new OutputPass());

    window.addEventListener('resize', () => this.resize());
    this.resize();
  }

  setQuality(q: Quality) {
    this.quality = q;
    this.gtao.enabled = q === 'high';
    this.bloom.enabled = q !== 'low';
    this.renderer.shadowMap.enabled = true;
    this.sun.shadow.mapSize.set(q === 'low' ? 1024 : 2048, q === 'low' ? 1024 : 2048);
    this.sun.shadow.map?.dispose(); (this.sun.shadow as unknown as { map: null }).map = null;
    this.renderer.setPixelRatio(q === 'high' ? Math.min(window.devicePixelRatio, 2) : q === 'balanced' ? Math.min(window.devicePixelRatio, 1.25) : 1);
    this.resize();
  }

  resize() {
    const w = window.innerWidth, h = window.innerHeight;
    this.camera.aspect = w / h; this.camera.updateProjectionMatrix();
    this.renderer.setSize(w, h);
    this.composer.setPixelRatio(this.renderer.getPixelRatio());
    this.composer.setSize(w, h);
  }

  /** hour: fractional 0..24 */
  setTimeOfDay(hour: number, focus: THREE.Vector3) {
    let a = KEYS[0], b = KEYS[KEYS.length - 1];
    for (let i = 0; i < KEYS.length - 1; i++) if (hour >= KEYS[i].h && hour <= KEYS[i + 1].h) { a = KEYS[i]; b = KEYS[i + 1]; break; }
    if (hour < KEYS[0].h) { a = KEYS[0]; b = KEYS[0]; }
    const t = a === b ? 0 : (hour - a.h) / (b.h - a.h);
    const lc = (x: THREE.Color, y: THREE.Color) => x.clone().lerp(y, t);
    this.sun.color.copy(lc(a.sun, b.sun));
    this.sun.intensity = (a.sunI + (b.sunI - a.sunI) * t) * 0.8;
    this.hemi.color.copy(lc(a.sky, b.sky));
    this.hemi.groundColor.copy(lc(a.ground, b.ground));
    this.hemi.intensity = (a.hemiI + (b.hemiI - a.hemiI) * t) * 0.7;
    (this.skyMat.uniforms.top.value as THREE.Color).copy(lc(a.top, b.top));
    (this.skyMat.uniforms.bottom.value as THREE.Color).copy(lc(a.bottom, b.bottom));
    (this.scene.fog as THREE.Fog).color.copy(lc(a.fog, b.fog));
    // sun path: rises east (-x), sets west (+x), always from the street side so the storefront is lit
    const dayT = THREE.MathUtils.clamp((hour - 6) / 14, 0, 1);
    const az = THREE.MathUtils.lerp(-1.1, 1.1, dayT);
    const el = Math.max(0.25, Math.sin(dayT * Math.PI) * 1.05);
    const dir = new THREE.Vector3(Math.sin(az) * Math.cos(el), Math.sin(el), Math.cos(az) * Math.cos(el) * 0.9 + 0.35).normalize();
    if (hour > 20.5 || hour < 6) dir.set(-0.3, 0.9, 0.4).normalize(); // moonlight from above
    this.sun.position.copy(focus).addScaledVector(dir, 60);
    this.sun.target.position.copy(focus);
    this.night = THREE.MathUtils.clamp(hour < 12 ? (6.5 - hour) / 1.5 : (hour - 19) / 1.6, 0, 1);
    this.scene.environmentIntensity = 0.32 - this.night * 0.2;
    (this.grade.uniforms.uWarm.value as THREE.Vector3).set(1.03 + this.night * 0.0, 1.0, 0.96 + this.night * 0.08);
    this.bloom.strength = 0.18 + this.night * 0.34;
    this.bloom.threshold = 1.25 - this.night * 0.3;
  }

  render() { this.composer.render(); }
}
