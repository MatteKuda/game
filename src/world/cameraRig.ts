import * as THREE from 'three';

/** Management camera: smooth orbit around a ground target with pan / rotate / zoom. */
export class CameraRig {
  target = new THREE.Vector3(22, 0, 13);
  yaw = -0.55; // radians around Y
  pitch = 0.86; // radians from horizon
  dist = 30;
  private goal = { target: new THREE.Vector3(22, 0, 13), yaw: -0.55, pitch: 0.86, dist: 30 };
  private keys = new Set<string>();
  private drag: { mode: 'pan' | 'rotate'; x: number; y: number } | null = null;
  // touch: one finger pans (after a small threshold so taps still select), two fingers pinch-zoom / twist-rotate
  private touches = new Map<number, { x: number; y: number; sx: number; sy: number }>();
  private touchPan = false;
  private pinch: { d: number; a: number; mx: number; my: number } | null = null;
  /** true while a touch gesture is moving the camera — the HUD ignores the tap that ends it */
  touchMoved = false;
  bounds = { x0: 2, x1: 42, z0: 0, z1: 30 };
  minDist = 9; maxDist = 62;

  constructor(private cam: THREE.PerspectiveCamera, private el: HTMLElement) {
    window.addEventListener('keydown', (e) => { if ((e.target as HTMLElement).tagName === 'INPUT') return; this.keys.add(e.key.toLowerCase()); });
    window.addEventListener('keyup', (e) => this.keys.delete(e.key.toLowerCase()));
    window.addEventListener('blur', () => this.keys.clear());
    el.addEventListener('wheel', (e) => {
      e.preventDefault();
      this.goal.dist = THREE.MathUtils.clamp(this.goal.dist * Math.pow(1.0015, e.deltaY), this.minDist, this.maxDist);
    }, { passive: false });
    el.addEventListener('pointerdown', (e) => {
      if (e.pointerType === 'touch') { this.touchDown(e); return; }
      if (e.button === 2) this.drag = { mode: 'pan', x: e.clientX, y: e.clientY };
      else if (e.button === 1 || (e.button === 0 && e.altKey)) this.drag = { mode: 'rotate', x: e.clientX, y: e.clientY };
      if (this.drag) el.setPointerCapture(e.pointerId);
    });
    el.addEventListener('pointermove', (e) => {
      if (e.pointerType === 'touch') { this.touchMove(e); return; }
      if (!this.drag) return;
      const dx = e.clientX - this.drag.x, dy = e.clientY - this.drag.y;
      this.drag.x = e.clientX; this.drag.y = e.clientY;
      if (this.drag.mode === 'pan') this.panBy(-dx * this.goal.dist * 0.0016, dy * this.goal.dist * 0.0022);
      else { this.goal.yaw -= dx * 0.006; this.goal.pitch = THREE.MathUtils.clamp(this.goal.pitch + dy * 0.004, 0.45, 1.3); }
    });
    const end = (e: PointerEvent) => {
      if (e.pointerType === 'touch') {
        this.touches.delete(e.pointerId); this.pinch = null;
        if (this.touches.size === 0) { this.touchPan = false; setTimeout(() => (this.touchMoved = false), 0); }
        else this.resetTouchAnchors();
        return;
      }
      this.drag = null;
    };
    el.addEventListener('pointerup', end);
    el.addEventListener('pointercancel', end);
    el.addEventListener('contextmenu', (e) => e.preventDefault());
    this.snap();
  }

  get isDragging() { return !!this.drag || this.touchPan || !!this.pinch; }

  /** freeze one-finger panning (used while dragging a placement ghost) */
  touchPanLocked = false;

  private resetTouchAnchors() {
    for (const t of this.touches.values()) { t.sx = t.x; t.sy = t.y; }
    this.pinch = null;
  }

  private touchDown(e: PointerEvent) {
    this.touches.set(e.pointerId, { x: e.clientX, y: e.clientY, sx: e.clientX, sy: e.clientY });
    try { this.el.setPointerCapture(e.pointerId); } catch { /* synthetic / already released pointer */ }
    if (this.touches.size > 1) this.touchMoved = true;
    this.resetTouchAnchors();
  }

  private touchMove(e: PointerEvent) {
    const t = this.touches.get(e.pointerId);
    if (!t) return;
    const px = t.x, py = t.y;
    t.x = e.clientX; t.y = e.clientY;
    if (this.touches.size === 1) {
      if (this.touchPanLocked) return;
      if (!this.touchPan && Math.hypot(t.x - t.sx, t.y - t.sy) > 9) { this.touchPan = true; this.touchMoved = true; }
      if (this.touchPan) this.panBy(-(t.x - px) * this.goal.dist * 0.0022, (t.y - py) * this.goal.dist * 0.003);
      return;
    }
    const [a, b] = [...this.touches.values()];
    const d = Math.hypot(b.x - a.x, b.y - a.y);
    const ang = Math.atan2(b.y - a.y, b.x - a.x);
    const mx = (a.x + b.x) / 2, my = (a.y + b.y) / 2;
    if (this.pinch) {
      if (d > 10) this.goal.dist = THREE.MathUtils.clamp(this.goal.dist * (this.pinch.d / d), this.minDist, this.maxDist);
      let da = ang - this.pinch.a;
      if (da > Math.PI) da -= Math.PI * 2; if (da < -Math.PI) da += Math.PI * 2;
      this.goal.yaw += da;
      this.panBy(-(mx - this.pinch.mx) * this.goal.dist * 0.0022, (my - this.pinch.my) * this.goal.dist * 0.003);
    }
    this.pinch = { d, a: ang, mx, my };
  }

  panBy(right: number, fwd: number) {
    const f = new THREE.Vector3(-Math.sin(this.goal.yaw), 0, -Math.cos(this.goal.yaw));
    const r = new THREE.Vector3(-f.z, 0, f.x);
    this.goal.target.addScaledVector(r, right).addScaledVector(f, fwd);
    this.clamp();
  }

  rotateBy(a: number) { this.goal.yaw += a; }
  zoomBy(f: number) { this.goal.dist = THREE.MathUtils.clamp(this.goal.dist * f, this.minDist, this.maxDist); }

  setFloorY(y: number) { this.goal.target.y = y; }

  focus(x: number, z: number, dist?: number) {
    this.goal.target.set(x, this.goal.target.y, z);
    if (dist) this.goal.dist = dist;
    this.clamp();
  }

  private clamp() {
    const b = this.bounds;
    this.goal.target.x = THREE.MathUtils.clamp(this.goal.target.x, b.x0, b.x1);
    this.goal.target.z = THREE.MathUtils.clamp(this.goal.target.z, b.z0, b.z1);
  }

  snap() {
    this.target.copy(this.goal.target); this.yaw = this.goal.yaw; this.pitch = this.goal.pitch; this.dist = this.goal.dist;
    this.apply();
  }

  set(o: { yaw?: number; pitch?: number; dist?: number; x?: number; z?: number }) {
    if (o.yaw !== undefined) this.goal.yaw = o.yaw;
    if (o.pitch !== undefined) this.goal.pitch = o.pitch;
    if (o.dist !== undefined) this.goal.dist = o.dist;
    if (o.x !== undefined) this.goal.target.x = o.x;
    if (o.z !== undefined) this.goal.target.z = o.z;
  }

  update(dt: number) {
    const k = this.keys;
    const sp = this.goal.dist * 0.9 * dt;
    let px = 0, pz = 0;
    if (k.has('w') || k.has('arrowup')) pz += sp;
    if (k.has('s') || k.has('arrowdown')) pz -= sp;
    if (k.has('a') || k.has('arrowleft')) px -= sp;
    if (k.has('d') || k.has('arrowright')) px += sp;
    if (px || pz) this.panBy(px, pz);
    if (k.has('q')) this.goal.yaw += dt * 1.6;
    if (k.has('e')) this.goal.yaw -= dt * 1.6;
    if (k.has('+') || k.has('=')) this.zoomBy(1 - dt);
    if (k.has('-')) this.zoomBy(1 + dt);
    const a = 1 - Math.exp(-dt * 8);
    this.target.lerp(this.goal.target, a);
    this.yaw += (this.goal.yaw - this.yaw) * a;
    this.pitch += (this.goal.pitch - this.pitch) * a;
    this.dist += (this.goal.dist - this.dist) * a;
    this.apply();
  }

  private apply() {
    const cp = Math.cos(this.pitch), sp = Math.sin(this.pitch);
    this.cam.position.set(
      this.target.x + Math.sin(this.yaw) * cp * this.dist,
      this.target.y + sp * this.dist,
      this.target.z + Math.cos(this.yaw) * cp * this.dist,
    );
    this.cam.lookAt(this.target);
  }

  /** 0 when close, 1 when zoomed far out (used to raise cut-away walls) */
  get farFactor() { return THREE.MathUtils.clamp((this.dist - 38) / 9, 0, 1); }
}
