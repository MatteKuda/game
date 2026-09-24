import * as THREE from 'three';

export type IconKind =
  | 'empty' | 'low' | 'noproduct' | 'price' | 'cheap' | 'wait' | 'happy' | 'angry' | 'notfound'
  | 'dirty' | 'crowd' | 'wallet' | 'queue' | 'nocashier' | 'star' | 'box';

const COLORS: Record<IconKind, string> = {
  empty: '#e5484d', low: '#f2a93b', noproduct: '#7b8698', price: '#e0663c', cheap: '#2fae7a',
  wait: '#f2a93b', happy: '#2fae7a', angry: '#d6333a', notfound: '#7a5ae0', dirty: '#8a6a3c',
  crowd: '#d9822b', wallet: '#b0546a', queue: '#e0663c', nocashier: '#d6333a', star: '#f2b33d', box: '#2f5d8a',
};

function glyph(ctx: CanvasRenderingContext2D, k: IconKind, s: number) {
  // draws white glyph centred at (0,0) in a ~s sized box
  ctx.strokeStyle = '#fff'; ctx.fillStyle = '#fff';
  ctx.lineWidth = s * 0.09; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
  const u = s / 2;
  switch (k) {
    case 'empty': case 'low': case 'box': {
      // open box
      ctx.beginPath();
      ctx.moveTo(-u * 0.7, -u * 0.15); ctx.lineTo(-u * 0.7, u * 0.6); ctx.lineTo(u * 0.7, u * 0.6); ctx.lineTo(u * 0.7, -u * 0.15); ctx.closePath(); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(-u * 0.7, -u * 0.15); ctx.lineTo(-u * 0.95, -u * 0.5); ctx.moveTo(u * 0.7, -u * 0.15); ctx.lineTo(u * 0.95, -u * 0.5); ctx.stroke();
      if (k === 'empty') { ctx.beginPath(); ctx.moveTo(-u * 0.3, u * 0.05); ctx.lineTo(u * 0.3, u * 0.45); ctx.moveTo(u * 0.3, u * 0.05); ctx.lineTo(-u * 0.3, u * 0.45); ctx.stroke(); }
      if (k === 'low') { ctx.fillRect(-u * 0.5, u * 0.25, u * 1.0, u * 0.22); }
      if (k === 'box') { ctx.beginPath(); ctx.moveTo(0, -u * 0.15); ctx.lineTo(0, u * 0.6); ctx.stroke(); }
      break;
    }
    case 'noproduct': {
      ctx.beginPath(); ctx.moveTo(0, -u * 0.55); ctx.lineTo(0, u * 0.55); ctx.moveTo(-u * 0.55, 0); ctx.lineTo(u * 0.55, 0); ctx.stroke(); break;
    }
    case 'price': case 'cheap': {
      ctx.save(); ctx.rotate(-Math.PI / 4);
      ctx.beginPath();
      ctx.moveTo(-u * 0.75, -u * 0.35); ctx.lineTo(u * 0.35, -u * 0.35); ctx.lineTo(u * 0.75, 0); ctx.lineTo(u * 0.35, u * 0.35); ctx.lineTo(-u * 0.75, u * 0.35); ctx.closePath(); ctx.stroke();
      ctx.beginPath(); ctx.arc(u * 0.3, 0, u * 0.08, 0, Math.PI * 2); ctx.fill();
      ctx.restore();
      // arrow
      ctx.lineWidth = s * 0.08;
      const up = k === 'price';
      const x = u * 0.62, yA = up ? u * 0.75 : u * 0.1, yB = up ? u * 0.1 : u * 0.75;
      ctx.beginPath(); ctx.moveTo(x, yA); ctx.lineTo(x, yB);
      ctx.moveTo(x - u * 0.2, yB + (up ? u * 0.2 : -u * 0.2)); ctx.lineTo(x, yB); ctx.lineTo(x + u * 0.2, yB + (up ? u * 0.2 : -u * 0.2));
      ctx.stroke();
      break;
    }
    case 'wait': {
      ctx.beginPath(); ctx.arc(0, 0, u * 0.62, 0, Math.PI * 2); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(0, -u * 0.38); ctx.moveTo(0, 0); ctx.lineTo(u * 0.3, u * 0.12); ctx.stroke(); break;
    }
    case 'happy': {
      // heart
      ctx.beginPath();
      ctx.moveTo(0, u * 0.6);
      ctx.bezierCurveTo(-u * 0.95, -u * 0.05, -u * 0.55, -u * 0.8, 0, -u * 0.32);
      ctx.bezierCurveTo(u * 0.55, -u * 0.8, u * 0.95, -u * 0.05, 0, u * 0.6);
      ctx.fill(); break;
    }
    case 'angry': {
      // lightning bolt / zigzag
      ctx.beginPath();
      ctx.moveTo(u * 0.15, -u * 0.75); ctx.lineTo(-u * 0.4, u * 0.1); ctx.lineTo(0, u * 0.1); ctx.lineTo(-u * 0.15, u * 0.75); ctx.lineTo(u * 0.45, -u * 0.12); ctx.lineTo(u * 0.05, -u * 0.12); ctx.closePath();
      ctx.fill(); break;
    }
    case 'notfound': {
      ctx.beginPath(); ctx.arc(-u * 0.12, -u * 0.12, u * 0.42, 0, Math.PI * 2); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(u * 0.2, u * 0.2); ctx.lineTo(u * 0.6, u * 0.6); ctx.stroke();
      ctx.font = `800 ${s * 0.42}px "Baloo 2", system-ui`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ctx.fillText('?', -u * 0.12, -u * 0.06); break;
    }
    case 'dirty': {
      // crumpled wrapper + stink waves
      ctx.beginPath(); ctx.moveTo(-u * 0.5, u * 0.55); ctx.lineTo(-u * 0.2, u * 0.2); ctx.lineTo(u * 0.1, u * 0.5); ctx.lineTo(u * 0.5, u * 0.25); ctx.lineTo(u * 0.35, u * 0.6); ctx.closePath(); ctx.fill();
      ctx.lineWidth = s * 0.06;
      for (const x of [-0.35, 0, 0.35]) { ctx.beginPath(); ctx.moveTo(x * u, 0); ctx.bezierCurveTo((x - 0.2) * u, -0.2 * u, (x + 0.2) * u, -0.4 * u, x * u, -0.65 * u); ctx.stroke(); }
      break;
    }
    case 'crowd': {
      for (const [x, r] of [[-0.35, 0.22], [0.35, 0.22], [0, 0.27]] as const) {
        ctx.beginPath(); ctx.arc(x * u, -0.25 * u, r * u, 0, Math.PI * 2); ctx.fill();
        ctx.beginPath(); ctx.ellipse(x * u, 0.45 * u, r * 1.6 * u, r * 1.3 * u, 0, Math.PI, 0); ctx.fill();
      }
      break;
    }
    case 'wallet': {
      ctx.beginPath(); ctx.rect(-u * 0.7, -u * 0.35, u * 1.4, u * 0.95); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(-u * 0.6, -u * 0.35); ctx.lineTo(u * 0.3, -u * 0.7); ctx.lineTo(u * 0.45, -u * 0.35); ctx.stroke();
      ctx.beginPath(); ctx.arc(u * 0.42, u * 0.12, u * 0.1, 0, Math.PI * 2); ctx.fill(); break;
    }
    case 'queue': {
      for (let i = 0; i < 3; i++) { ctx.beginPath(); ctx.arc((-0.55 + i * 0.55) * u, -0.2 * u, 0.17 * u, 0, Math.PI * 2); ctx.fill(); ctx.fillRect((-0.55 + i * 0.55 - 0.17) * u, 0.05 * u, 0.34 * u, 0.5 * u); }
      break;
    }
    case 'nocashier': {
      ctx.beginPath(); ctx.arc(0, -u * 0.25, u * 0.25, 0, Math.PI * 2); ctx.fill();
      ctx.beginPath(); ctx.ellipse(0, u * 0.5, u * 0.45, u * 0.35, 0, Math.PI, 0); ctx.fill();
      ctx.strokeStyle = '#fff'; ctx.beginPath(); ctx.moveTo(-u * 0.7, u * 0.7); ctx.lineTo(u * 0.7, -u * 0.7); ctx.stroke(); break;
    }
    case 'star': {
      ctx.beginPath();
      for (let i = 0; i < 10; i++) { const r = i % 2 ? u * 0.32 : u * 0.7; const a = -Math.PI / 2 + i * Math.PI / 5; ctx.lineTo(Math.cos(a) * r, Math.sin(a) * r); }
      ctx.closePath(); ctx.fill(); break;
    }
  }
}

const texCache = new Map<string, THREE.Texture>();

/** Bubble-style icon texture (with little tail) */
export function iconTexture(k: IconKind, style: 'bubble' | 'badge' = 'bubble') {
  const key = k + style;
  let t = texCache.get(key);
  if (t) return t;
  const S = 128;
  const c = document.createElement('canvas'); c.width = S; c.height = S;
  const ctx = c.getContext('2d')!;
  ctx.translate(S / 2, S / 2 - (style === 'bubble' ? 6 : 0));
  const R = S * 0.36;
  ctx.shadowColor = 'rgba(20,20,40,0.35)'; ctx.shadowBlur = 10; ctx.shadowOffsetY = 4;
  ctx.fillStyle = '#ffffff';
  ctx.beginPath();
  if (style === 'bubble') {
    ctx.arc(0, 0, R + 6, 0, Math.PI * 2);
    ctx.moveTo(-12, R); ctx.lineTo(0, R + 22); ctx.lineTo(12, R);
  } else {
    const r = R + 6;
    ctx.moveTo(-r + 14, -r); ctx.arcTo(r, -r, r, r, 18); ctx.arcTo(r, r, -r, r, 18); ctx.arcTo(-r, r, -r, -r, 18); ctx.arcTo(-r, -r, r, -r, 18);
  }
  ctx.fill();
  ctx.shadowColor = 'transparent';
  ctx.fillStyle = COLORS[k];
  ctx.beginPath();
  if (style === 'bubble') ctx.arc(0, 0, R, 0, Math.PI * 2);
  else { const r = R; ctx.moveTo(-r + 12, -r); ctx.arcTo(r, -r, r, r, 14); ctx.arcTo(r, r, -r, r, 14); ctx.arcTo(-r, r, -r, -r, 14); ctx.arcTo(-r, -r, r, -r, 14); }
  ctx.fill();
  glyph(ctx, k, R * 1.25);
  t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  texCache.set(key, t);
  return t;
}

const matCache = new Map<string, THREE.SpriteMaterial>();
export function iconMaterial(k: IconKind, style: 'bubble' | 'badge' = 'bubble') {
  const key = k + style;
  let m = matCache.get(key);
  if (!m) {
    m = new THREE.SpriteMaterial({ map: iconTexture(k, style), depthTest: false, depthWrite: false, toneMapped: false, transparent: true });
    matCache.set(key, m);
  }
  return m;
}

export const ICON_LABEL: Record<IconKind, string> = {
  empty: 'Raf boş', low: 'Stok azalıyor', noproduct: 'Ürün atanmamış', price: 'Çok pahalı', cheap: 'Uygun fiyat!',
  wait: 'Bekliyor', happy: 'Memnun', angry: 'Sinirli', notfound: 'Aradığını bulamadı', dirty: 'Ortam kirli',
  crowd: 'Çok kalabalık', wallet: 'Bütçe yetmedi', queue: 'Uzun kuyruk', nocashier: 'Kasiyer yok', star: 'Harika', box: 'Stok',
};
