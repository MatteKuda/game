import * as THREE from 'three';

let maxAniso = 8;
export function setMaxAnisotropy(n: number) { maxAniso = n; }

export function canvasTexture(w: number, h: number, draw: (ctx: CanvasRenderingContext2D, w: number, h: number) => void, opts: { repeat?: [number, number]; srgb?: boolean; mips?: boolean } = {}) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  const ctx = c.getContext('2d')!;
  draw(ctx, w, h);
  const t = new THREE.CanvasTexture(c);
  if (opts.srgb !== false) t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = maxAniso;
  if (opts.repeat) { t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(opts.repeat[0], opts.repeat[1]); }
  t.generateMipmaps = opts.mips !== false;
  if (opts.mips === false) t.minFilter = THREE.LinearFilter;
  return t;
}

// Deterministic PRNG for textures
export function mulberry(seed: number) {
  let a = seed >>> 0;
  return () => {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export const hex = (c: number) => '#' + c.toString(16).padStart(6, '0');

export function shade(c: number, f: number) {
  const r = Math.min(255, Math.max(0, ((c >> 16) & 255) * f));
  const g = Math.min(255, Math.max(0, ((c >> 8) & 255) * f));
  const b = Math.min(255, Math.max(0, (c & 255) * f));
  return `rgb(${r | 0},${g | 0},${b | 0})`;
}

/** Warm terrazzo floor with chips; one texture tile = 2x2 m */
export function terrazzoTexture() {
  return canvasTexture(512, 512, (ctx, w, h) => {
    ctx.fillStyle = '#efe3cf';
    ctx.fillRect(0, 0, w, h);
    const rnd = mulberry(7);
    const chips = ['#d9c3a2', '#c7a27c', '#e7d7bd', '#b8b1a6', '#f7efe2', '#d88c6a', '#8fb8ad'];
    for (let i = 0; i < 1400; i++) {
      ctx.fillStyle = chips[(rnd() * chips.length) | 0];
      const x = rnd() * w, y = rnd() * h, r = 1 + rnd() * 4.5;
      ctx.beginPath();
      ctx.ellipse(x, y, r, r * (0.5 + rnd() * 0.5), rnd() * 3, 0, Math.PI * 2);
      ctx.fill();
    }
    // tile seams (50cm tiles)
    ctx.strokeStyle = 'rgba(120,90,60,0.22)';
    ctx.lineWidth = 2;
    for (let i = 0; i <= 4; i++) {
      ctx.beginPath(); ctx.moveTo(i * w / 4, 0); ctx.lineTo(i * w / 4, h); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(0, i * h / 4); ctx.lineTo(w, i * h / 4); ctx.stroke();
    }
  });
}

export function woodTexture(base = '#c98b52', dark = '#9a6337') {
  return canvasTexture(256, 256, (ctx, w, h) => {
    ctx.fillStyle = base; ctx.fillRect(0, 0, w, h);
    const rnd = mulberry(3);
    for (let i = 0; i < 70; i++) {
      ctx.strokeStyle = `rgba(90,50,20,${0.05 + rnd() * 0.12})`;
      ctx.lineWidth = 1 + rnd() * 2.5;
      const y = rnd() * h;
      ctx.beginPath(); ctx.moveTo(0, y);
      for (let x = 0; x <= w; x += 16) ctx.lineTo(x, y + Math.sin(x * 0.03 + i) * 3);
      ctx.stroke();
    }
    ctx.fillStyle = dark; ctx.globalAlpha = 0.15; ctx.fillRect(0, 0, w, 2); ctx.globalAlpha = 1;
  });
}

export function wainscotTexture() {
  // White metro tiles with teal band at top
  return canvasTexture(256, 256, (ctx, w, h) => {
    ctx.fillStyle = '#f7f3ea'; ctx.fillRect(0, 0, w, h);
    ctx.strokeStyle = '#d8d0c2'; ctx.lineWidth = 3;
    const rows = 8;
    for (let r = 0; r < rows; r++) {
      const y = r * h / rows;
      ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke();
      const off = r % 2 ? w / 4 : 0;
      for (let c = 0; c < 3; c++) {
        const x = off + c * w / 2;
        ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x, y + h / rows); ctx.stroke();
      }
    }
    const g = ctx.createLinearGradient(0, 0, 0, h);
    g.addColorStop(0, 'rgba(255,255,255,0.25)'); g.addColorStop(1, 'rgba(0,0,0,0.05)');
    ctx.fillStyle = g; ctx.fillRect(0, 0, w, h);
  }, { repeat: [1, 1] });
}

export function plasterTexture(color = '#f4e6cf') {
  return canvasTexture(256, 256, (ctx, w, h) => {
    ctx.fillStyle = color; ctx.fillRect(0, 0, w, h);
    const rnd = mulberry(11);
    for (let i = 0; i < 2500; i++) {
      ctx.fillStyle = rnd() > 0.5 ? 'rgba(255,255,255,0.05)' : 'rgba(120,90,60,0.04)';
      ctx.fillRect(rnd() * w, rnd() * h, 2 + rnd() * 3, 2 + rnd() * 3);
    }
  });
}

export function paverTexture() {
  return canvasTexture(512, 512, (ctx, w, h) => {
    ctx.fillStyle = '#b9b2a6'; ctx.fillRect(0, 0, w, h);
    const rnd = mulberry(21);
    const n = 8; const s = w / n;
    for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
      const v = 0.9 + rnd() * 0.16;
      ctx.fillStyle = shade(0xd1c9bb, v);
      ctx.fillRect(x * s + 2, y * s + 2, s - 4, s - 4);
      ctx.fillStyle = 'rgba(255,255,255,0.06)';
      ctx.fillRect(x * s + 2, y * s + 2, s - 4, 3);
    }
  });
}

export function asphaltTexture() {
  return canvasTexture(512, 512, (ctx, w, h) => {
    ctx.fillStyle = '#51565f'; ctx.fillRect(0, 0, w, h);
    const rnd = mulberry(5);
    for (let i = 0; i < 9000; i++) {
      const v = rnd();
      ctx.fillStyle = v > 0.5 ? `rgba(255,255,255,${rnd() * 0.07})` : `rgba(0,0,0,${rnd() * 0.12})`;
      ctx.fillRect(rnd() * w, rnd() * h, 1.5, 1.5);
    }
    // cracks / patches
    ctx.strokeStyle = 'rgba(30,30,35,0.35)'; ctx.lineWidth = 1.2;
    for (let i = 0; i < 8; i++) {
      let x = rnd() * w, y = rnd() * h; ctx.beginPath(); ctx.moveTo(x, y);
      for (let k = 0; k < 6; k++) { x += (rnd() - 0.5) * 40; y += (rnd() - 0.5) * 40; ctx.lineTo(x, y); }
      ctx.stroke();
    }
  });
}

export function awningTexture(a = '#e0663c', b = '#fff1dc') {
  return canvasTexture(256, 64, (ctx, w, h) => {
    const n = 8;
    for (let i = 0; i < n; i++) { ctx.fillStyle = i % 2 ? b : a; ctx.fillRect(i * w / n, 0, w / n, h); }
    const g = ctx.createLinearGradient(0, 0, 0, h);
    g.addColorStop(0, 'rgba(255,255,255,0.12)'); g.addColorStop(1, 'rgba(0,0,0,0.12)');
    ctx.fillStyle = g; ctx.fillRect(0, 0, w, h);
  });
}

export function shutterTexture() {
  return canvasTexture(256, 256, (ctx, w, h) => {
    ctx.fillStyle = '#9aa3ab'; ctx.fillRect(0, 0, w, h);
    for (let y = 0; y < h; y += 10) {
      const g = ctx.createLinearGradient(0, y, 0, y + 10);
      g.addColorStop(0, '#c4cbd1'); g.addColorStop(0.5, '#9aa3ab'); g.addColorStop(1, '#6f7880');
      ctx.fillStyle = g; ctx.fillRect(0, y, w, 10);
    }
    // graffiti tag
    ctx.strokeStyle = 'rgba(214,64,100,0.75)'; ctx.lineWidth = 7; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(40, 190); ctx.bezierCurveTo(70, 120, 110, 220, 140, 150); ctx.bezierCurveTo(160, 110, 190, 200, 215, 160); ctx.stroke();
    ctx.strokeStyle = 'rgba(40,150,200,0.7)'; ctx.lineWidth = 4;
    ctx.beginPath(); ctx.moveTo(50, 205); ctx.lineTo(210, 185); ctx.stroke();
  });
}

export function brickTexture(base = 0xc4704f) {
  return canvasTexture(256, 256, (ctx, w, h) => {
    ctx.fillStyle = '#d9c7b0'; ctx.fillRect(0, 0, w, h);
    const rnd = mulberry(base & 0xff);
    const bh = 16, bw = 48;
    for (let y = 0; y < h; y += bh) {
      const off = (y / bh) % 2 ? bw / 2 : 0;
      for (let x = -bw; x < w + bw; x += bw) {
        ctx.fillStyle = shade(base, 0.85 + rnd() * 0.3);
        ctx.fillRect(x + off + 1.5, y + 1.5, bw - 3, bh - 3);
      }
    }
  });
}

/** Text sign with custom lettering */
export function signTexture(text: string, sub: string, opts: { bg: string; fg: string; accent: string; w?: number; h?: number; neon?: boolean }) {
  const W = opts.w ?? 1024, H = opts.h ?? 256;
  return canvasTexture(W, H, (ctx) => {
    ctx.fillStyle = opts.bg; ctx.fillRect(0, 0, W, H);
    // inner frame
    ctx.strokeStyle = opts.accent; ctx.lineWidth = H * 0.04;
    roundRect(ctx, H * 0.06, H * 0.08, W - H * 0.12, H - H * 0.16, H * 0.12); ctx.stroke();
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.font = `800 ${H * 0.46}px "Baloo 2", system-ui, sans-serif`;
    if (opts.neon) { ctx.shadowColor = opts.fg; ctx.shadowBlur = H * 0.12; }
    ctx.fillStyle = opts.fg;
    ctx.fillText(text, W / 2, H * (sub ? 0.43 : 0.52));
    ctx.shadowBlur = 0;
    if (sub) {
      ctx.font = `700 ${H * 0.16}px "Baloo 2", system-ui, sans-serif`;
      ctx.fillStyle = opts.accent;
      ctx.fillText(sub, W / 2, H * 0.76);
    }
  });
}

export function roundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

export function posterTexture(title: string, line: string, bg: string, fg: string, art: (ctx: CanvasRenderingContext2D, w: number, h: number) => void) {
  return canvasTexture(256, 360, (ctx, w, h) => {
    ctx.fillStyle = bg; ctx.fillRect(0, 0, w, h);
    art(ctx, w, h);
    ctx.fillStyle = fg; ctx.textAlign = 'center';
    ctx.font = '800 46px "Baloo 2", system-ui'; ctx.fillText(title, w / 2, h - 80);
    ctx.font = '600 22px "Baloo 2", system-ui'; ctx.fillText(line, w / 2, h - 44);
  });
}

/** Radial soft blob for fake contact shadows */
export function blobTexture() {
  return canvasTexture(128, 128, (ctx, w, h) => {
    const g = ctx.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, w / 2);
    g.addColorStop(0, 'rgba(0,0,0,0.55)'); g.addColorStop(0.6, 'rgba(0,0,0,0.18)'); g.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = g; ctx.fillRect(0, 0, w, h);
  }, { srgb: false });
}
