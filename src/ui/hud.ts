import * as THREE from 'three';
import type { Game, AlertMsg, DayStats } from '../game';
import type { Fixture } from '../sim/fixture';
import { Customer } from '../sim/agents';
import { Staff, ROLE_LABEL, ROLE_DESC, SHIFT_LABEL, type Shift } from '../sim/staff';
import { Visitor } from '../sim/visitor';
import type { UnitState, ConnectorState } from '../sim/mall';
import { FIXTURES, FIXTURE_MAP } from '../data/fixtures';
import { PRODUCT_MAP, DISPLAY_LABEL } from '../data/products';
import { ARCHETYPES } from '../data/customers';
import { STAGES, UPGRADES, CAMPAIGNS } from '../data/stages';
import { MALL_EVENTS } from '../data/mall';
import { DAY_OPEN, DAY_CLOSE } from '../config';
import { ICON_LABEL, type IconKind } from '../world/icons';
import { icon, stars } from './svg';
import type { Thumbs } from './thumbs';
import { sfx } from './sfx';
import { audio } from '../audio/engine';
import { serialize, writeSave, listSaves, loadAndRestart, deleteSave, newGame, type Slot } from '../sim/save';

type PanelId = 'build' | 'products' | 'supply' | 'staff' | 'campaign' | 'finance' | 'growth' | 'mall' | null;

const fmt = (n: number) => '₺' + Math.round(n).toLocaleString('tr-TR');
const esc = (s: string) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]!));
const clock = (m: number) => { const h = Math.floor(m / 60) % 24, mm = Math.floor(m % 60); return `${String(h).padStart(2, '0')}:${String(mm).padStart(2, '0')}`; };

const ICON_COLOR: Record<IconKind, string> = {
  empty: 'bad', low: 'warn', noproduct: 'mute', price: 'warn', cheap: 'good', wait: 'warn', happy: 'good', angry: 'bad', notfound: 'violet',
  dirty: 'brown', crowd: 'warn', wallet: 'rose', queue: 'warn', nocashier: 'bad', star: 'gold', box: 'blue',
  slip: 'blue', sneak: 'bad', tired: 'mute', food: 'warn', fun: 'violet', alarm: 'bad', wrench: 'warn', shop: 'good',
};
const KIND_TO_SVG: Record<IconKind, string> = {
  empty: 'box', low: 'box', noproduct: 'plus', price: 'tag', cheap: 'tag', wait: 'clock', happy: 'heart', angry: 'alert', notfound: 'info',
  dirty: 'broom', crowd: 'people', wallet: 'coin', queue: 'people', nocashier: 'staff', star: 'star', box: 'box',
  slip: 'drop', sneak: 'eye', tired: 'moon', food: 'food', fun: 'sparkle', alarm: 'alert', wrench: 'wrench', shop: 'cart',
};

const COACH: Record<number, { id: string; t: string }[]> = {
  0: [
    { id: 'assign', t: 'Boş raf bölmesine ürün ata' },
    { id: 'price', t: 'Ürünler panelinde bir fiyatı dene (P)' },
    { id: 'hire', t: 'Reyon görevlisi işe al (H) — kasa boş kalmasın' },
    { id: 'upgrade', t: 'İlk yükseltmeni satın al (U)' },
  ],
  1: [
    { id: 'cleaner', t: 'Temizlik görevlisi al: ıslak zemin ve çöp (H)' },
    { id: 'camera', t: 'Kamera ve alarm kapısı kur (B → Güvenlik)' },
    { id: 'break', t: 'Çay Ocağı kur, vardiyaları böl (H)' },
    { id: 'campaign', t: 'Bir kampanya başlat (K)' },
  ],
  2: [
    { id: 'sign', t: 'Reyon levhası as: müşteri kaybolmasın' },
    { id: 'belt', t: 'Bantlı kasa kur (B → Kasa & Depo)' },
    { id: 'oven', t: 'Fırın tezgâhı + fırıncı: sıcak ekmek' },
    { id: 'carts', t: 'Araba parkı kur: haftalık alışveriş' },
  ],
  3: [
    { id: 'lease', t: 'Boş bir birime kiracı seç (V)' },
    { id: 'upstairs', t: 'Üst kata çık (PageUp) ve masa kur' },
    { id: 'event', t: 'Bir etkinlik planla (V → Etkinlikler)' },
    { id: 'security', t: 'Güvenlik görevlisi al: kalabalık ve hırsızlık' },
  ],
};

export class HUD {
  root: HTMLElement;
  private el: Record<string, HTMLElement> = {};
  panel: PanelId = null;
  private buildTab = 'Teşhir';
  private mallTab: 'units' | 'events' | 'facility' = 'units';
  private lastPanelHtml = '';
  private lastInspectorHtml = '';
  private pointerDown = false;
  private acc = 0;
  private portraitCache = new Map<number, string>();
  private slotPicker: { f: Fixture; i: number } | null = null;
  private dayEndOpen = false;
  private settingsOpen = false;
  started = false;
  private coachDone = new Set<string>();
  private priceTouched = false;
  private discountPick = new Set<string>();
  private touch = false;

  constructor(private game: Game, private thumbs: Thumbs, private opts: { loaded: boolean; onStart: () => void }) {
    this.root = document.getElementById('ui')!;
    this.root.innerHTML = this.skeleton();
    this.root.querySelectorAll<HTMLElement>('[data-el]').forEach((e) => (this.el[e.dataset.el!] = e));
    this.root.addEventListener('pointerdown', () => (this.pointerDown = true));
    window.addEventListener('pointerup', () => setTimeout(() => (this.pointerDown = false), 0));
    this.root.addEventListener('click', (e) => this.onClick(e));
    this.root.addEventListener('input', (e) => this.onInput(e));
    this.bindGame();
    this.bindKeys();
    this.bindCanvas();
    this.renderDock();
    this.renderFloors();
    try { const s = localStorage.getItem('tezgah.uiscale'); if (s) this.setScale(Number(s)); } catch { /* ignore */ }
    if (window.matchMedia('(pointer: coarse)').matches) { this.touch = true; this.root.classList.add('touch'); }
  }

  // ------------------------------------------------------------------ skeleton
  private skeleton() {
    return `
    <div class="hud-top-left">
      <div class="brand card">
        <div class="brand-mark">${icon('store', 22)}</div>
        <div class="brand-text"><div class="brand-name">KÖŞEBAŞI</div><div class="brand-sub" data-el="stage">Mahalle Büfesi · Aşama 1</div></div>
      </div>
      <button class="goal card" data-action="panel" data-id="growth" data-el="goal"></button>
      <div class="coach card" data-el="coach"></div>
    </div>
    <div class="hud-top-center">
      <div class="timebar card">
        <div class="time-main"><span class="time-icon" data-el="sunIcon">${icon('sun', 18)}</span><span class="time-day" data-el="day">Gün 1</span><span class="time-clock" data-el="clock">07:00</span></div>
        <div class="time-progress"><div data-el="dayProg"></div></div>
        <div class="speed" data-el="speed">
          <button data-action="speed" data-v="0" title="Duraklat (Boşluk)">${icon('pause', 16)}</button>
          <button data-action="speed" data-v="1" title="Normal (1)">${icon('play', 16)}</button>
          <button data-action="speed" data-v="2" title="Hızlı (2)">${icon('fast', 16)}</button>
          <button data-action="speed" data-v="4" title="Çok hızlı (3)">${icon('fast', 16)}<span class="x">4</span></button>
        </div>
      </div>
    </div>
    <div class="hud-top-right">
      <div class="stat card cash"><span class="stat-ico">${icon('coin', 18)}</span><div><div class="stat-v" data-el="money">₺0</div><div class="stat-l" data-el="moneyDelta">bugün ₺0</div></div></div>
      <div class="stat card"><div><div class="stat-v stars-row" data-el="rating"></div><div class="stat-l" data-el="ratingL">Mağaza puanı</div></div></div>
      <div class="stat card hide-sm"><span class="stat-ico teal">${icon('people', 18)}</span><div><div class="stat-v" data-el="inside">0</div><div class="stat-l" data-el="insideL">içeride</div></div></div>
      <button class="icon-btn card" data-action="settings" title="Ayarlar & Kayıt (O)">${icon('settings', 18)}</button>
    </div>
    <div class="alerts" data-el="alerts"></div>
    <div class="floors card" data-el="floors"></div>
    <div class="inspector card" data-el="inspector"></div>
    <div class="panel card" data-el="panel"></div>
    <div class="placehint" data-el="placehint"></div>
    <div class="dock" data-el="dock"></div>
    <div class="tooltip" data-el="tooltip"></div>
    <div class="modal-wrap" data-el="modal"></div>
    <div class="modal-wrap" data-el="settings"></div>
    <div class="welcome" data-el="welcome">${this.welcomeHtml()}</div>
    `;
  }

  private welcomeHtml() {
    const auto = listSaves().find((s) => s.slot === 'oto')?.data;
    const loaded = this.opts.loaded;
    return `<div class="welcome-card">
      <div class="welcome-kicker">Perakende yönetim oyunu</div>
      <h1>Tezgâh<span>.</span></h1>
      <p class="welcome-sub">Köşedeki küçük büfeden mahallenin marketine, süpermarkete ve iki katlı bir AVM'ye.</p>
      <div class="welcome-grid">
        <div>${icon('eye', 18)}<b>Önce dünyaya bak</b><span>Boş raflar, ıslak zemin, uzayan kuyruk, şüpheli müşteri ve baloncuklar sorunu gösterir.</span></div>
        <div>${icon('build', 18)}<b>Yerleşim önemli</b><span>Rafların yeri müşterinin yolunu, kuyruğu, kameraların görüşünü ve anlık alımları değiştirir.</span></div>
        <div>${icon('arrowUp', 18)}<b>Büyü</b><span>Büfe → Market → Süpermarket → AVM. Her aşama yeni müşteri, karar ve sorun getirir.</span></div>
      </div>
      <div class="welcome-keys"><span><kbd>Sağ tık</kbd> / tek parmak: kaydır</span><span><kbd>Q</kbd><kbd>E</kbd> / iki parmak: döndür</span><span><kbd>Tekerlek</kbd> / kıstır: yakınlaş</span><span><kbd>B</kbd> inşa · <kbd>M</kbd> akış · <kbd>G</kbd> güvenlik · <kbd>Boşluk</kbd> duraklat</span></div>
      <div class="welcome-actions">
        <button class="btn primary big" data-action="start">${loaded ? 'Kayıttan devam et' : 'Dükkânı Aç'}</button>
        ${!loaded && auto ? `<button class="btn big" data-action="loadSlot" data-slot="oto">${icon('play', 16)} Devam: ${esc(auto.label)}</button>` : ''}
        <button class="btn big ghost" data-action="settings">${icon('settings', 16)} Kayıtlar & Ayarlar</button>
      </div>
    </div>`;
  }

  // ------------------------------------------------------------------ bindings
  private bindGame() {
    const g = this.game;
    g.on('alert', (_a: AlertMsg) => this.renderAlerts());
    g.on('select', () => { this.slotPicker = null; this.lastInspectorHtml = ''; this.renderInspector(true); });
    g.on('placing', (p: unknown) => { this.renderPlaceHint(); this.root.classList.toggle('placing', !!p); });
    g.on('placingUpdate', () => this.renderPlaceHint());
    g.on('dayEnd', (r: DayEndReport) => { writeSave('oto', serialize(g)); this.showDayEnd(r); });
    g.on('changed', () => { this.lastPanelHtml = ''; });
    g.on('mallChanged', () => { this.lastPanelHtml = ''; this.lastInspectorHtml = ''; });
    g.on('stage', () => { this.renderDock(); this.renderFloors(); this.lastPanelHtml = ''; });
    g.on('floor', () => this.renderFloors());
  }

  private bindKeys() {
    window.addEventListener('keydown', (e) => {
      if ((e.target as HTMLElement).tagName === 'INPUT') return;
      if (!this.started) { if (e.key === 'Enter') this.start(); return; }
      const k = e.key.toLowerCase();
      const g = this.game;
      if (k === 'escape') {
        if (this.settingsOpen) this.closeSettings();
        else if (g.placing) g.cancelPlacement();
        else if (this.slotPicker) { this.slotPicker = null; this.renderInspector(true); }
        else if (this.panel) this.openPanel(null);
        else if (g.selection) g.select(null);
        else this.openSettings();
        return;
      }
      if (this.dayEndOpen || this.settingsOpen) return;
      if (k === 'r' && g.placing) g.rotatePlacement();
      if (k === ' ') { e.preventDefault(); this.setSpeed(g.paused ? (g.speed || 1) : 0); }
      if (k === '1') this.setSpeed(1);
      if (k === '2') this.setSpeed(2);
      if (k === '3') this.setSpeed(4);
      if (k === 'b') this.togglePanel('build');
      if (k === 'p') this.togglePanel('products');
      if (k === 't') this.togglePanel('supply');
      if (k === 'h') this.togglePanel('staff');
      if (k === 'k') this.togglePanel('campaign');
      if (k === 'f') this.togglePanel('finance');
      if (k === 'u') this.togglePanel('growth');
      if (k === 'v' && g.stage >= 3) this.togglePanel('mall');
      if (k === 'o') this.openSettings();
      if (k === 'm') { g.setOverlay('heat'); this.renderDock(); }
      if (k === 'g') { g.setOverlay('security'); this.renderDock(); }
      if (k === 'c') { g.shell.cutaway = !g.shell.cutaway; }
      if (k === 'pageup' || k === ']') { e.preventDefault(); g.setViewFloor(g.viewFloor + 1); }
      if (k === 'pagedown' || k === '[') { e.preventDefault(); g.setViewFloor(g.viewFloor - 1); }
    });
  }

  private bindCanvas() {
    const canvas = document.getElementById('scene')!;
    const ndc = new THREE.Vector2();
    let down: { x: number; y: number; b: number; touch: boolean } | null = null;
    let touches = 0;
    let hoverAcc = 0;
    const setNdc = (e: PointerEvent) => ndc.set((e.clientX / window.innerWidth) * 2 - 1, -(e.clientY / window.innerHeight) * 2 + 1);
    canvas.addEventListener('pointerdown', (e) => {
      if (e.pointerType === 'touch') { touches++; this.touch = true; this.root.classList.add('touch'); }
      down = { x: e.clientX, y: e.clientY, b: e.button, touch: e.pointerType === 'touch' };
      if (touches > 1) down = null;
    });
    canvas.addEventListener('pointermove', (e) => {
      if (e.pointerType === 'touch') return;
      setNdc(e);
      const g = this.game;
      if (g.placing) {
        const hit = g.pick(ndc);
        if (hit.ground) g.updatePlacement(Math.floor(hit.ground.x), Math.floor(hit.ground.z));
        this.hideTooltip();
        return;
      }
      const now = performance.now();
      if (now - hoverAcc < 60 || g.cam.isDragging) return;
      hoverAcc = now;
      this.hover(g.pick(ndc), e.clientX, e.clientY);
    });
    canvas.addEventListener('pointerleave', () => this.hideTooltip());
    const up = (e: PointerEvent) => {
      if (e.pointerType === 'touch') touches = Math.max(0, touches - 1);
      if (!down) return;
      const moved = Math.hypot(e.clientX - down.x, e.clientY - down.y) > (down.touch ? 12 : 6) || (down.touch && this.game.cam.touchMoved);
      const b = down.b; const isTouch = down.touch; down = null;
      const g = this.game;
      if (b === 2 && !moved && g.placing) { g.cancelPlacement(); return; }
      if (b !== 0 || moved || e.altKey) return;
      setNdc(e);
      if (g.placing) {
        const hit = g.pick(ndc);
        if (isTouch) { if (hit.ground) g.updatePlacement(Math.floor(hit.ground.x), Math.floor(hit.ground.z)); return; }
        g.confirmPlacement(e.shiftKey); return;
      }
      const hit = g.pick(ndc);
      if (hit.litter) {
        g.removeLitter(hit.litter);
        g.overlays.floatText(hit.litter.obj.position.clone().setY(hit.litter.obj.position.y + 1), 'Temizlendi', '#1f8a86');
        sfx.play('click');
        return;
      }
      if (hit.puddle) {
        const p = hit.puddle;
        const staff = g.staff.filter((s) => s.present && !s.hidden && (s.role === 'cleaner' || s.role === 'stocker'));
        if (staff.length && !p.claimed) { const s = staff[0]; if (s.task) s.cancelTask(g); s.task = { kind: 'mop', puddle: p, phase: 'go' }; p.claimed = s.id; s.dest = null; g.overlays.floatText(p.obj.position.clone().setY(p.obj.position.y + 1.2), `${s.name} paspaslayacak`, '#2f6fb5'); }
        else g.alert('nomop', 'slip', 'Islak zemini ancak personel paspaslayabilir. Temizlik görevlisi al.', 'warn', p.obj.position.clone(), 10);
        sfx.play('click');
        return;
      }
      if (hit.agent) {
        const a = hit.agent;
        g.select(a instanceof Customer ? { kind: 'customer', c: a } : a instanceof Visitor ? { kind: 'visitor', v: a } : { kind: 'staff', s: a as Staff });
        sfx.play('click'); return;
      }
      if (hit.fixture) { g.select({ kind: 'fixture', f: hit.fixture }); sfx.play('click'); return; }
      if (hit.connector) { g.select({ kind: 'connector', c: hit.connector }); sfx.play('click'); return; }
      if (hit.unit) { g.select({ kind: 'unit', u: hit.unit }); sfx.play('click'); return; }
      g.select(null);
    };
    canvas.addEventListener('pointerup', up);
    canvas.addEventListener('pointercancel', (e) => { if (e.pointerType === 'touch') touches = Math.max(0, touches - 1); down = null; });
  }

  private hover(hit: ReturnType<Game['pick']>, x: number, y: number) {
    const g = this.game;
    const ring = g.overlays.hoverRing;
    let html = '';
    ring.visible = false;
    document.body.style.cursor = '';
    if (hit.agent) {
      const a = hit.agent;
      ring.visible = true; ring.position.set(a.pos.x, a.pos.y + 0.035, a.pos.z); ring.scale.set(1, 1, 1);
      if (a instanceof Customer) {
        const label = a.thief ? (a.suspect ? 'Şüpheli!' : 'Müşteri') : a.arch ? a.arch.name : 'Yoldan geçen';
        html = `<b>${esc(a.name)}</b><span>${label} · ${a.shopper ? a.statusLabel() : 'yürüyor'}</span>${a.shopper && !a.thief ? this.moodBar(a.mood, true) : ''}`;
      } else if (a instanceof Visitor) {
        html = `<b>${esc(a.name)}</b><span>AVM · ${a.arch.name} · ${a.statusLabel()}</span>${this.moodBar(a.mood, true)}`;
      } else {
        const s = a as Staff;
        html = `<b>${esc(s.name)}</b><span>${ROLE_LABEL[s.role]} · ${esc(s.activity)}</span>`;
      }
      document.body.style.cursor = 'pointer';
    } else if (hit.litter) { html = `<b>Çöp</b><span>Tıkla: temizle</span>`; document.body.style.cursor = 'pointer'; }
    else if (hit.puddle) { html = `<b>Islak zemin</b><span>Müşteriler kayabilir. Tıkla: personeli çağır</span>`; document.body.style.cursor = 'pointer'; }
    else if (hit.fixture) {
      const f = hit.fixture;
      const c = f.center; ring.visible = true; ring.position.set(c.x, c.y + 0.115, c.z); const sz = Math.max(f.fp.fw, f.fp.fd) + 0.4; ring.scale.set(sz, 1, sz);
      let sub = f.def.desc;
      if (f.isDisplay) sub = f.slots.map((s) => s.productId ? `${PRODUCT_MAP[s.productId].name} ${s.stock}/${f.cap()}` : 'boş bölme').join(' · ');
      if (f.def.kind === 'register') sub = `Kuyruk: ${f.queue.length} kişi · ${f.def.selfService ? 'self-servis' : f.cashier ? 'Kasiyer: ' + f.cashier.name : 'Kasiyer yok'}`;
      if (f.def.kind === 'depot') sub = `Depo: ${g.backstockTotal()}/${g.depotCapacity()} birim`;
      if (f.def.kind === 'table') sub = `${f.seatsUsed.filter(Boolean).length}/${f.seatsUsed.length} dolu${f.dirty ? ' · kirli!' : ''}`;
      html = `<b>${f.def.name}</b><span>${sub}</span>`;
      if (f.statusKind) html += `<em class="tt-${ICON_COLOR[f.statusKind]}">${ICON_LABEL[f.statusKind]}</em>`;
      document.body.style.cursor = 'pointer';
    } else if (hit.connector) {
      html = `<b>${hit.connector.def.name}</b><span>${hit.connector.broken ? (hit.connector.repairT > 0 ? 'Tamir ediliyor' : 'ARIZALI — tıkla, tamir ettir') : 'Çalışıyor'}</span>`;
      document.body.style.cursor = 'pointer';
    } else if (hit.unit) {
      const u = hit.unit;
      html = u.tenant ? `<b>${esc(u.tenant.def.brand)}</b><span>${u.tenant.def.name} · memnuniyet ${Math.round(u.tenant.sat)}</span>` : `<b>Kiralık birim ${u.def.id}</b><span>Tıkla: kiracı teklifleri</span>`;
      document.body.style.cursor = 'pointer';
    }
    const tt = this.el.tooltip;
    if (!html) { this.hideTooltip(); return; }
    tt.innerHTML = html;
    const k = Number(getComputedStyle(document.documentElement).getPropertyValue('--uis') || 1) || 1;
    tt.style.transform = `translate(${(x + 16) / k}px, ${(y + 14) / k}px)`;
    tt.classList.add('show');
  }
  private hideTooltip() { this.el.tooltip.classList.remove('show'); this.game.overlays.hoverRing.visible = false; document.body.style.cursor = ''; }

  // ------------------------------------------------------------------ actions
  private onInput(e: Event) {
    const t = e.target as HTMLInputElement;
    const a = t.dataset.action;
    if (a === 'volume') audio.setVolume(t.dataset.k as 'master', Number(t.value) / 100);
    if (a === 'scale') this.setScale(Number(t.value) / 100);
  }

  private setScale(v: number) {
    document.documentElement.style.setProperty('--uis', String(v));
    try { localStorage.setItem('tezgah.uiscale', String(v)); } catch { /* ignore */ }
  }

  private onClick(e: MouseEvent) {
    const t = (e.target as HTMLElement).closest<HTMLElement>('[data-action]');
    if (!t) return;
    const a = t.dataset.action!;
    const g = this.game;
    const fx = () => (g.selection?.kind === 'fixture' ? g.selection.f : null);
    switch (a) {
      case 'start': this.start(); break;
      case 'speed': this.setSpeed(Number(t.dataset.v)); break;
      case 'panel': this.togglePanel(t.dataset.id as PanelId); break;
      case 'closePanel': this.openPanel(null); break;
      case 'overlay': g.setOverlay(t.dataset.id as 'heat'); this.renderDock(); break;
      case 'floor': g.setViewFloor(Number(t.dataset.f)); break;
      case 'settings': this.openSettings(); break;
      case 'closeSettings': this.closeSettings(); break;
      case 'quality': g.r.setQuality(t.dataset.q as 'high'); this.renderSettings(); break;
      case 'cutawayToggle': g.shell.cutaway = !g.shell.cutaway; this.renderSettings(); break;
      case 'mute': sfx.muted = !sfx.muted; this.renderSettings(); break;
      case 'saveSlot': { if (!this.started) break; const ok = writeSave(t.dataset.slot as Slot, serialize(g)); g.alert('saved', 'star', ok ? 'Oyun kaydedildi.' : 'Kayıt başarısız (tarayıcı depolaması kapalı olabilir).', ok ? 'good' : 'bad', undefined, 0); this.renderSettings(); break; }
      case 'loadSlot': loadAndRestart(t.dataset.slot as Slot); break;
      case 'deleteSlot': deleteSave(t.dataset.slot as Slot); this.renderSettings(); break;
      case 'newGame': newGame(); break;
      case 'buildTab': this.buildTab = t.dataset.id!; this.lastPanelHtml = ''; break;
      case 'mallTab': this.mallTab = t.dataset.id as 'units'; this.lastPanelHtml = ''; break;
      case 'place': {
        const def = FIXTURE_MAP[t.dataset.id!];
        if (def.stage > g.stage) { sfx.play('error'); break; }
        g.startPlacement(def.id); sfx.play('click');
        break;
      }
      case 'move': { const f = fx(); if (f) g.startPlacement(f.def.id, f); break; }
      case 'rotate': { const f = fx(); if (f) { g.startPlacement(f.def.id, f); g.rotatePlacement(); g.updatePlacement(f.x, f.z, true); if (g.placing?.valid) g.confirmPlacement(); else { g.cancelPlacement(); sfx.play('error'); } } break; }
      case 'sell': { const f = fx(); if (f) g.sellFixture(f); break; }
      case 'phRotate': g.rotatePlacement(); break;
      case 'phPlace': g.confirmPlacement(); break;
      case 'phCancel': g.cancelPlacement(); break;
      case 'slotPick': { const f = fx(); if (f) { this.slotPicker = { f, i: Number(t.dataset.i) }; this.renderInspector(true); } break; }
      case 'slotSet': {
        const f = fx(); if (f && this.slotPicker) { g.assignSlot(f, this.slotPicker.i, t.dataset.pid === 'none' ? null : t.dataset.pid!); this.slotPicker = null; this.coachDone.add('assign'); sfx.play('place'); this.renderInspector(true); }
        break;
      }
      case 'slotCancel': this.slotPicker = null; this.renderInspector(true); break;
      case 'price': {
        const pid = t.dataset.pid!; const d = Number(t.dataset.d);
        g.setPrice(pid, g.prices[pid] + d); this.priceTouched = true; sfx.play('click'); this.lastPanelHtml = '';
        break;
      }
      case 'priceReset': { const pid = t.dataset.pid!; g.setPrice(pid, PRODUCT_MAP[pid].basePrice); this.lastPanelHtml = ''; break; }
      case 'order': { g.order(t.dataset.pid!, Number(t.dataset.q)); this.lastPanelHtml = ''; break; }
      case 'auto': { const pid = t.dataset.pid!; g.auto[pid] = !g.auto[pid]; sfx.play('click'); this.lastPanelHtml = ''; break; }
      case 'hire': { const c = g.candidates[Number(t.dataset.i)]; if (c) g.hire(c, false, (t.dataset.shift as Shift) ?? 'full'); this.lastPanelHtml = ''; break; }
      case 'fire': {
        const s = g.staff.find((x) => x.id === Number(t.dataset.id)) ?? (g.selection?.kind === 'staff' ? g.selection.s : null);
        if (s) g.fire(s); this.lastPanelHtml = ''; break;
      }
      case 'shift': { const s = g.staff.find((x) => x.id === Number(t.dataset.id)); if (s) { g.setShift(s, t.dataset.shift as Shift); this.coachDone.add('break'); sfx.play('click'); } this.lastPanelHtml = ''; this.lastInspectorHtml = ''; break; }
      case 'upgrade': g.buyUpgrade(t.dataset.id!); this.lastPanelHtml = ''; break;
      case 'expand': g.expand(); this.lastPanelHtml = ''; break;
      case 'campaign': {
        const id = t.dataset.id!;
        if (g.startCampaign(id, [...this.discountPick])) { this.discountPick.clear(); this.coachDone.add('campaign'); }
        this.lastPanelHtml = ''; break;
      }
      case 'discountPick': { const pid = t.dataset.pid!; if (this.discountPick.has(pid)) this.discountPick.delete(pid); else if (this.discountPick.size < 3) this.discountPick.add(pid); this.lastPanelHtml = ''; break; }
      case 'lease': {
        const u = g.mall?.units[Number(t.dataset.u)]; if (!u) break;
        g.mall!.lease(u, Number(t.dataset.o)); this.coachDone.add('lease'); sfx.play('fanfare');
        g.overlays.floatText(new THREE.Vector3((u.def.rect.x0 + u.def.rect.x1) / 2, u.def.floor * 4.4 + 3, (u.def.rect.z0 + u.def.rect.z1) / 2), `${u.tenant?.def.brand} açıldı!`, '#1f8a86', '#ffffff', 2.5);
        this.lastInspectorHtml = ''; break;
      }
      case 'evict': { const u = g.mall?.units[Number(t.dataset.u)]; if (u) g.mall!.evict(u, 'Sözleşmeyi sen feshettin'); break; }
      case 'focusUnit': {
        const u = g.mall?.units[Number(t.dataset.u)]; if (!u) break;
        g.setViewFloor(u.def.floor); g.cam.focus((u.def.rect.x0 + u.def.rect.x1) / 2, (u.def.rect.z0 + u.def.rect.z1) / 2, 18); g.select({ kind: 'unit', u }); break;
      }
      case 'event': { if (g.mall?.schedule(t.dataset.id!, t.dataset.when as 'today')) { this.coachDone.add('event'); g.mallShell?.setEvent(g.mall.event?.def.id ?? null); sfx.play('fanfare'); } this.lastPanelHtml = ''; break; }
      case 'repair': { const c = g.mall?.connectors.find((x) => x.def.id === t.dataset.id); if (c) g.mall!.repair(c); this.lastPanelHtml = ''; this.lastInspectorHtml = ''; break; }
      case 'focusAlert': {
        const al = g.alerts.find((x) => x.id === Number(t.dataset.id));
        if (al?.focus) { if (g.stage >= 3) g.setViewFloor(al.focus.y > 2 ? 1 : 0); g.cam.focus(al.focus.x, al.focus.z, 18); }
        break;
      }
      case 'dismissAlert': { g.alerts = g.alerts.filter((x) => x.id !== Number(t.dataset.id)); this.renderAlerts(); e.stopPropagation(); break; }
      case 'nextDay': this.el.modal.classList.remove('show'); this.dayEndOpen = false; g.startNextDay(); break;
      case 'deselect': g.select(null); break;
      case 'focusSel': {
        const s = g.selection; if (!s) break;
        const p = s.kind === 'fixture' ? s.f.center : s.kind === 'customer' ? s.c.pos : s.kind === 'staff' ? s.s.pos : s.kind === 'visitor' ? s.v.pos : null;
        if (p) g.cam.focus(p.x, p.z, 14); break;
      }
    }
  }

  private start() {
    if (this.started) return;
    this.started = true;
    audio.unlock();
    this.opts.onStart();
    this.el.welcome.classList.add('hide');
    setTimeout(() => this.el.welcome.remove(), 700);
    if (this.settingsOpen) this.closeSettings();
    this.game.paused = false;
    this.setSpeed(1);
    sfx.play('fanfare');
    if (!this.opts.loaded) {
      this.game.cam.set({ dist: 20, yaw: -0.22, pitch: 0.88 });
      setTimeout(() => this.game.alert('hello', 'star', 'Hoş geldin! Soldaki raftaki boş bölmeye tıklayıp ürün ata. Sorunları önce dükkânın içinde gör.', 'good', undefined, 0), 900);
    }
  }

  private setSpeed(v: number) {
    const g = this.game;
    if (v === 0) g.paused = true; else { g.paused = false; g.speed = v; }
    this.el.speed.querySelectorAll('button').forEach((b) => b.classList.toggle('on', (g.paused && b.dataset.v === '0') || (!g.paused && Number(b.dataset.v) === g.speed)));
  }

  togglePanel(id: PanelId) { this.openPanel(this.panel === id ? null : id); }
  openPanel(id: PanelId) {
    this.panel = id;
    this.lastPanelHtml = '';
    this.el.panel.classList.toggle('show', !!id);
    this.el.panel.classList.toggle('wide', id === 'products' || id === 'supply');
    this.el.panel.classList.toggle('mid', id === 'mall');
    this.el.panel.classList.toggle('build', id === 'build');
    this.renderDock();
    this.renderPanel();
    sfx.play('click');
  }

  // ------------------------------------------------------------------ settings
  openSettings() { this.settingsOpen = true; this.renderSettings(); this.el.settings.classList.add('show'); }
  closeSettings() { this.settingsOpen = false; this.el.settings.classList.remove('show'); }

  private renderSettings() {
    const g = this.game;
    const saves = listSaves();
    const q = g.r.quality;
    const vol = (k: 'master' | 'music' | 'sfx' | 'ambience', label: string) => `<label class="slider"><span>${label}</span><input type="range" min="0" max="100" value="${Math.round(audio.vol[k] * 100)}" data-action="volume" data-k="${k}"/></label>`;
    const scale = Number(getComputedStyle(document.documentElement).getPropertyValue('--uis') || 1) || 1;
    const slotRow = (s: { slot: Slot; data: ReturnType<typeof listSaves>[number]['data'] }) => `<div class="save-row">
      <div class="save-ico">${icon(s.slot === 'oto' ? 'clock' : 'box', 16)}</div>
      <div class="save-main"><b>${s.slot === 'oto' ? 'Otomatik kayıt' : 'Yuva ' + s.slot}</b><span>${s.data ? `${esc(s.data.label)} · ${fmt(s.data.money)} · ${new Date(s.data.savedAt).toLocaleString('tr-TR', { dateStyle: 'short', timeStyle: 'short' })}` : 'Boş'}</span></div>
      ${s.slot !== 'oto' && this.started ? `<button class="btn small" data-action="saveSlot" data-slot="${s.slot}">Kaydet</button>` : ''}
      ${s.data ? `<button class="btn small primary" data-action="loadSlot" data-slot="${s.slot}">Yükle</button><button class="icon-btn ghost" data-action="deleteSlot" data-slot="${s.slot}" title="Sil">${icon('trash', 14)}</button>` : ''}
    </div>`;
    this.el.settings.innerHTML = `<div class="modal card settings">
      <div class="p-head"><span class="p-ico">${icon('settings', 20)}</span><div><b>Ayarlar & Kayıtlar</b><span>Oyun her gün sonunda otomatik kaydedilir.</span></div><button class="icon-btn ghost" data-action="closeSettings">${icon('close', 16)}</button></div>
      <div class="set-grid">
        <div>
          <div class="sec-h">Kayıtlar</div>
          ${saves.map(slotRow).join('')}
          <button class="btn ghost small" data-action="newGame">${icon('plus', 14)} Yeni oyun</button>
        </div>
        <div>
          <div class="sec-h">Grafik</div>
          <div class="seg">${(['high', 'balanced', 'low'] as const).map((x) => `<button class="${q === x ? 'on' : ''}" data-action="quality" data-q="${x}">${{ high: 'Yüksek', balanced: 'Dengeli', low: 'Düşük' }[x]}</button>`).join('')}</div>
          <label class="check"><button class="toggle ${g.shell.cutaway ? 'on' : ''}" data-action="cutawayToggle"><span></span></button>Kameraya bakan duvarları indir (C)</label>
          <div class="sec-h">Ses</div>
          ${vol('master', 'Genel')}${vol('music', 'Müzik')}${vol('sfx', 'Efektler')}${vol('ambience', 'Ortam')}
          <div class="sec-h">Arayüz ölçeği</div>
          <label class="slider"><span>${Math.round(scale * 100)}%</span><input type="range" min="80" max="140" step="5" value="${Math.round(scale * 100)}" data-action="scale"/></label>
          <div class="sec-h">Kısayollar</div>
          <div class="keys-list"><span><kbd>B</kbd> İnşa</span><span><kbd>P</kbd> Ürün</span><span><kbd>T</kbd> Tedarik</span><span><kbd>H</kbd> Personel</span><span><kbd>K</kbd> Kampanya</span><span><kbd>F</kbd> Finans</span><span><kbd>U</kbd> Gelişim</span><span><kbd>V</kbd> AVM</span><span><kbd>M</kbd> Akış</span><span><kbd>G</kbd> Güvenlik</span><span><kbd>PgUp/PgDn</kbd> Kat</span><span><kbd>R</kbd> Döndür</span></div>
        </div>
      </div>
    </div>`;
  }

  // ------------------------------------------------------------------ per-frame
  update(dt: number) {
    this.acc += dt;
    if (this.acc < 0.12) return;
    this.acc = 0;
    const g = this.game;
    this.el.money.textContent = fmt(g.money);
    const net = g.stats.revenue + g.stats.mallIncome - g.stats.purchases - g.stats.other;
    this.el.moneyDelta.innerHTML = `bugün <b class="${net >= 0 ? 'pos' : 'neg'}">${net >= 0 ? '+' : '−'}${fmt(Math.abs(net))}</b>`;
    this.el.rating.innerHTML = `${stars(g.rating, 15)}<span class="num">${g.rating.toFixed(1)}</span>`;
    const inside = g.customersInside() + (g.mall?.visitors.length ?? 0);
    const q = g.fixtures.filter((f) => f.def.kind === 'register').reduce((s, f) => s + f.queue.length, 0);
    this.el.inside.textContent = `${inside}`;
    this.el.insideL.innerHTML = `${g.mall ? 'mağaza + AVM' : 'içeride'} · <span class="${q >= 6 ? 'neg' : ''}">kuyruk ${q}</span>`;
    this.el.day.textContent = `Gün ${g.day}`;
    this.el.clock.textContent = clock(g.clock);
    const prog = Math.max(0, Math.min(1, (g.clock - DAY_OPEN) / (DAY_CLOSE - DAY_OPEN)));
    this.el.dayProg.style.width = `${prog * 100}%`;
    const isNight = g.clock > 19.5 * 60 || g.clock < 6.5 * 60;
    this.el.sunIcon.innerHTML = icon(isNight ? 'moon' : 'sun', 18);
    this.el.sunIcon.classList.toggle('night', isNight);
    this.el.stage.textContent = `${STAGES[g.stage].name} · Aşama ${g.stage + 1}`;
    this.renderGoal();
    this.renderCoach();
    this.renderPanel();
    this.renderInspector(false);
    this.pruneAlerts();
  }

  private renderGoal() {
    const g = this.game;
    const e = g.expansion();
    if (!e) {
      const m = g.mall;
      this.el.goal.classList.remove('ready');
      this.el.goal.innerHTML = `<div class="goal-head">${icon('sparkle', 16)}<span>Köşebaşı AVM açık</span></div><div class="goal-sub">AVM keyfi ${m ? m.mood.toFixed(1) : '—'}★ · ${m ? m.units.filter((u) => u.tenant).length : 0}/${m?.units.length ?? 0} birim dolu</div>`;
      return;
    }
    const goals = g.goals();
    const done = goals.filter((x) => x.done).length;
    const rows = goals.map((x) => {
      const pct = Math.min(1, x.value / x.target) * 100;
      const val = x.id === 'rating' ? x.value.toFixed(1) + '★' : x.id === 'cash' ? fmt(x.value) : Math.floor(x.value).toString();
      const tgt = x.id === 'rating' ? x.target.toFixed(1) + '★' : x.id === 'cash' ? fmt(x.target) : x.target.toString();
      return `<div class="goal-row ${x.done ? 'done' : ''}"><span class="gl">${x.label}</span><span class="gv">${val} / ${tgt}</span><div class="bar"><div style="width:${pct}%"></div></div></div>`;
    }).join('');
    const ready = g.canExpand();
    this.el.goal.classList.toggle('ready', ready);
    this.el.goal.innerHTML = `<div class="goal-head">${icon('arrowUp', 16)}<span>${ready ? 'Genişlemeye hazır!' : 'Hedef: ' + e.title}</span><em>${done}/3</em></div>${rows}`;
  }

  private renderCoach() {
    const g = this.game;
    const has = (k: string) => g.fixtures.some((f) => f.def.kind === k || f.def.id === k);
    if (g.fixtures.every((f) => f.slots.every((s) => s.productId))) this.coachDone.add('assign');
    if (this.priceTouched) this.coachDone.add('price');
    if (g.staff.some((s) => s.role === 'stocker')) this.coachDone.add('hire');
    if (g.upgrades.size > 0) this.coachDone.add('upgrade');
    if (g.staff.some((s) => s.role === 'cleaner')) this.coachDone.add('cleaner');
    if (has('camera') && has('gate')) this.coachDone.add('camera');
    if (has('break')) this.coachDone.add('break');
    if (has('sign')) this.coachDone.add('sign');
    if (has('bantkasa')) this.coachDone.add('belt');
    if (has('oven') && g.staff.some((s) => s.role === 'baker')) this.coachDone.add('oven');
    if (has('carts')) this.coachDone.add('carts');
    if (g.mall?.units.some((u) => u.tenant)) this.coachDone.add('lease');
    if (g.viewFloor === 1 && has('table')) this.coachDone.add('upstairs');
    if (g.staff.some((s) => s.role === 'security')) this.coachDone.add('security');
    const steps = COACH[g.stage] ?? [];
    const open = steps.filter((s) => !this.coachDone.has(s.id));
    if (!open.length) { this.el.coach.style.display = 'none'; return; }
    this.el.coach.style.display = '';
    const html = `<div class="coach-h">${g.stage === 0 ? 'İlk adımlar' : STAGES[g.stage].short + ' için öneriler'}</div>` + steps.map((s) => `<div class="coach-row ${this.coachDone.has(s.id) ? 'done' : ''}"><span class="cb">${this.coachDone.has(s.id) ? icon('check', 12) : ''}</span>${s.t}</div>`).join('');
    if (this.el.coach.innerHTML !== html) this.el.coach.innerHTML = html;
  }

  // ------------------------------------------------------------------ dock & floors
  private renderDock() {
    const g = this.game;
    const b = (id: string, ic: string, label: string, key: string, on = false, action = 'panel') =>
      `<button class="dock-btn ${on ? 'on' : ''}" data-action="${action}" data-id="${id}" title="${label} (${key})">${icon(ic, 22)}<span>${label}</span><kbd>${key}</kbd></button>`;
    this.el.dock.innerHTML = `
      ${b('build', 'build', 'İnşa', 'B', this.panel === 'build')}
      ${b('products', 'tag', 'Ürün & Fiyat', 'P', this.panel === 'products')}
      ${b('supply', 'truck', 'Tedarik', 'T', this.panel === 'supply')}
      ${b('staff', 'staff', 'Personel', 'H', this.panel === 'staff')}
      ${b('campaign', 'megaphone', 'Kampanya', 'K', this.panel === 'campaign')}
      ${g.stage >= 3 ? b('mall', 'mall', 'AVM', 'V', this.panel === 'mall') : ''}
      ${b('finance', 'chart', 'Finans', 'F', this.panel === 'finance')}
      ${b('growth', 'arrowUp', 'Gelişim', 'U', this.panel === 'growth')}
      <div class="dock-sep"></div>
      ${b('heat', 'route', 'Akış', 'M', g.overlayMode === 'heat', 'overlay')}
      ${g.stage >= 1 ? b('security', 'shield', 'Güvenlik', 'G', g.overlayMode === 'security', 'overlay') : ''}`;
  }

  private renderFloors() {
    const g = this.game;
    const el = this.el.floors;
    if (g.stage < 3) { el.style.display = 'none'; return; }
    el.style.display = '';
    el.innerHTML = `<div class="fl-h">Kat</div>${[1, 0].map((f) => `<button class="${g.viewFloor === f ? 'on' : ''}" data-action="floor" data-f="${f}">${f === 0 ? 'Zemin' : '1. Kat'}<small>${f === 0 ? 'Süpermarket' : 'Yemek katı'}</small></button>`).join('')}<div class="fl-k"><kbd>PgUp</kbd><kbd>PgDn</kbd></div>`;
  }

  private renderPlaceHint() {
    const p = this.game.placing;
    const el = this.el.placehint;
    if (!p) { el.classList.remove('show'); return; }
    el.classList.add('show');
    el.innerHTML = `<div class="ph-title"><img src="${this.thumbs.fixtures[p.def.id]}"/><div><b>${p.def.name}</b><span>${p.moving ? 'Taşınıyor — ücretsiz' : fmt(p.def.cost)}</span></div></div>
      <div class="ph-status ${p.valid ? 'ok' : 'bad'}">${p.valid ? icon('check', 14) + ' Yerleştirilebilir' : icon('alert', 14) + ' ' + (p.reason || 'Bir konum seç')}</div>
      <div class="ph-legend"><span class="lg fp"></span>Eşya <span class="lg acc"></span>Erişim ${p.def.kind === 'register' ? '<span class="lg back"></span>Kasiyer' : ''}${p.def.kind === 'camera' ? '<span class="lg cam"></span>Görüş' : ''}</div>
      <div class="ph-keys"><kbd>R</kbd> Döndür <kbd>Sol tık</kbd> Yerleştir <kbd>Shift</kbd> Çoklu <kbd>Esc</kbd> İptal</div>
      <div class="ph-btns"><button class="btn small" data-action="phRotate">${icon('rotate', 14)} Döndür</button><button class="btn small primary" data-action="phPlace">${icon('check', 14)} Yerleştir</button><button class="btn small" data-action="phCancel">${icon('close', 14)}</button></div>`;
  }

  // ------------------------------------------------------------------ alerts
  private renderAlerts() {
    const g = this.game;
    this.el.alerts.innerHTML = g.alerts.map((a) => `
      <div class="alert ${a.severity}" data-action="focusAlert" data-id="${a.id}">
        <span class="al-ico ${ICON_COLOR[a.icon]}">${icon(KIND_TO_SVG[a.icon], 16)}</span>
        <span class="al-text">${esc(a.text)}</span>
        <button class="al-x" data-action="dismissAlert" data-id="${a.id}">${icon('close', 12)}</button>
      </div>`).join('');
  }
  private pruneAlerts() {
    const g = this.game;
    const before = g.alerts.length;
    g.alerts = g.alerts.filter((a) => g.realTime - a.t < 14);
    if (g.alerts.length !== before) this.renderAlerts();
  }

  // ------------------------------------------------------------------ inspector
  private moodBar(m: number, compact = false) {
    const face = m >= 70 ? 'Memnun' : m >= 45 ? 'İdare eder' : m >= 25 ? 'Keyifsiz' : 'Sinirli';
    const col = m >= 70 ? 'good' : m >= 45 ? 'warn' : 'bad';
    return `<div class="mood ${compact ? 'compact' : ''}"><div class="mood-bar"><div class="${col}" style="width:${Math.max(4, m)}%"></div></div><span class="${col}">${face}</span></div>`;
  }

  private renderInspector(force: boolean) {
    const g = this.game;
    const s = g.selection;
    const el = this.el.inspector;
    if (!s) { el.classList.remove('show'); this.lastInspectorHtml = ''; return; }
    el.classList.add('show');
    let html = '';
    switch (s.kind) {
      case 'fixture': html = this.fixtureInspector(s.f); break;
      case 'customer': html = this.customerInspector(s.c); break;
      case 'staff': html = this.staffInspector(s.s); break;
      case 'visitor': html = this.visitorInspector(s.v); break;
      case 'unit': html = this.unitInspector(s.u); break;
      case 'connector': html = this.connectorInspector(s.c); break;
    }
    if (!force && (html === this.lastInspectorHtml || this.pointerDown)) return;
    this.lastInspectorHtml = html;
    el.innerHTML = html;
  }

  private insHead(img: string, title: string, sub: string, round = false) {
    return `<div class="ins-head"><div class="ins-img ${round ? 'round' : ''}">${img.startsWith('<') ? img : img ? `<img src="${img}"/>` : ''}</div><div class="ins-title"><b>${esc(title)}</b><span>${sub}</span></div>
      <button class="icon-btn ghost" data-action="focusSel" title="Kamerayı odakla">${icon('camera', 16)}</button><button class="icon-btn ghost" data-action="deselect">${icon('close', 16)}</button></div>`;
  }

  private fixtureInspector(f: Fixture) {
    const g = this.game;
    let body = '';
    const k = f.def.kind;
    if (f.isDisplay) {
      if (this.slotPicker && this.slotPicker.f === f) {
        const opts = g.unlockedProducts().filter((p) => p.display === f.def.display);
        body = `<div class="sec-h">Bölme ${this.slotPicker.i + 1} için ürün seç <small>${DISPLAY_LABEL[f.def.display!]} ürünleri</small></div>
          <div class="pick-grid">${opts.map((p) => `<button class="pick" data-action="slotSet" data-pid="${p.id}"><img src="${this.thumbs.products[p.id]}"/><b>${p.name}</b><span>${fmt(g.prices[p.id])} · depo ${g.backstock[p.id]}</span></button>`).join('')}
          <button class="pick empty" data-action="slotSet" data-pid="none">${icon('close', 18)}<b>Boşalt</b><span>Stok depoya döner</span></button></div>
          <button class="btn ghost small" data-action="slotCancel">Vazgeç</button>`;
      } else {
        body = `<div class="sec-h">Raf bölmeleri <small>Kapasite ${f.cap()} / bölme</small></div>` + f.slots.map((s, i) => {
          if (!s.productId) return `<button class="slot empty" data-action="slotPick" data-i="${i}"><span class="slot-plus">${icon('plus', 18)}</span><div><b>Boş bölme</b><span>Ürün atamak için tıkla</span></div></button>`;
          const p = PRODUCT_MAP[s.productId];
          const pct = s.stock / f.cap();
          const st = s.stock === 0 ? 'bad' : pct < 0.34 ? 'warn' : 'good';
          const back = g.backstock[p.id];
          const note = s.stock === 0 ? (back ? 'Görevli dolduracak' : 'Depoda yok — sipariş ver!') : s.claimed ? 'Dolduruluyor…' : `Depoda ${back}`;
          return `<button class="slot" data-action="slotPick" data-i="${i}"><img src="${this.thumbs.products[p.id]}"/><div class="slot-main"><div class="slot-top"><b>${p.name}${g.isDiscounted(p.id) ? ' <em class="sale">İNDİRİM</em>' : ''}</b><span class="price">${fmt(g.effectivePrice(p.id))}</span></div>
            <div class="bar ${st}"><div style="width:${pct * 100}%"></div></div><div class="slot-sub"><span>${s.stock}/${f.cap()}</span><span class="${st}">${note}</span></div></div></button>`;
        }).join('');
        const sold = f.slots.reduce((n, s) => n + (s.productId ? g.stats.soldBy[s.productId] ?? 0 : 0), 0);
        body += `<div class="kv"><span>Bugün bu ürünlerden satılan</span><b>${sold}</b></div>`;
        if (g.stage >= 2) body += `<div class="kv"><span>Reyon levhası</span><b class="${g.signNear(f) ? 'good' : 'warn'}">${g.signNear(f) ? 'Var — kolay bulunur' : 'Yok — müşteri arar'}</b></div>`;
      }
    } else if (k === 'register') {
      const pat = f.queue.length;
      body = `<div class="big-stat"><div><b class="${pat >= 4 ? 'neg' : ''}">${pat}</b><span>kişi kuyrukta</span></div><div><b>${f.def.selfService ? 'Self' : f.cashier ? esc(f.cashier.name) : '—'}</b><span>${f.def.selfService ? 'kasiyersiz' : f.cashier ? (f.cashier.present ? 'kasiyer' : 'vardiyada değil') : 'kasiyer yok!'}</span></div></div>
        <div class="kv"><span>Ödeme hızı</span><b>${f.def.serviceMul && f.def.serviceMul < 1 ? 'Bantlı (−%35)' : f.def.selfService ? 'Yavaş (+%35)' : 'Standart'}${g.upgrades.has('pos') ? ' · POS' : ''}</b></div>
        <div class="kv"><span>Kuyruk kapasitesi (içeride)</span><b>${f.queueSlots.filter((t) => g.grid.isInterior(t.x, t.z)).length} kişi</b></div>
        <p class="hint">${icon('route', 14)} Sarı kesikli çizgi kuyruğun uzayacağı yolu gösterir. Kasa kapıya çok yakınsa kuyruk kaldırıma taşar; çikolata rafını kuyruk yoluna koyarsan anlık alımlar artar.${f.def.selfService ? ' Self-servis kasada arada bir ürün okutulmadan çıkar.' : ''}</p>`;
    } else if (k === 'depot') {
      const cap = g.depotCapacity(); const tot = g.backstockTotal();
      body = `<div class="kv"><span>Toplam depo</span><b>${tot} / ${cap}</b></div><div class="bar ${tot / cap > 0.9 ? 'warn' : 'good'}"><div style="width:${(tot / Math.max(1, cap)) * 100}%"></div></div>
        <div class="mini-list">${g.unlockedProducts().filter((p) => g.isStocked(p.id) || g.backstock[p.id]).map((p) => `<div><img src="${this.thumbs.products[p.id]}"/><span>${p.name}</span><b>${g.backstock[p.id]}</b>${g.incoming(p.id) ? `<em>+${g.incoming(p.id)} yolda</em>` : ''}</div>`).join('')}</div>
        <button class="btn ghost small" data-action="panel" data-id="supply">${icon('truck', 14)} Tedarik paneli</button>`;
    } else if (k === 'camera') {
      body = `<div class="kv"><span>Görüş alanı</span><b>${f.covers.size} karo</b></div><div class="kv"><span>Bugün görülen şüpheli</span><b>${g.stats.theftSeen}</b></div>
        <p class="hint">${icon('shield', 14)} Kamera koni içinde ürün cebine atanı kaydeder. Hırsızların yarısı kameradan çekinir. Güvenlik görevlisi varsa kaydı görüp peşine düşer. <b>G</b> ile kapsamı gör.</p>`;
    } else if (k === 'gate') {
      body = `<div class="kv"><span>Bugün öten alarm</span><b>${g.stats.alarms}</b></div><div class="kv"><span>Yakalanan</span><b>${g.stats.caught}</b></div><p class="hint">${icon('alert', 14)} Ödenmemiş ürünle geçenlerin %85'inde öter. Yakında güvenlik görevlisi varsa hırsız yakalanır, yoksa malı bırakıp kaçar.</p>`;
    } else if (k === 'break') {
      const resting = g.staff.filter((s) => s.task?.kind === 'rest');
      body = `<div class="kv"><span>Şu an molada</span><b>${resting.map((s) => esc(s.name)).join(', ') || '—'}</b></div><p class="hint">${icon('clock', 14)} Enerjisi %30'un altına düşen personel buraya gelip çay içer. Tam gün vardiyası daha çok yorar.</p>`;
    } else if (k === 'oven') {
      body = `<div class="kv"><span>Fırıncı</span><b class="${g.hasRole('baker') ? 'good' : 'bad'}">${g.hasRole('baker') ? 'Var' : 'Yok — Personel panelinden al'}</b></div><div class="kv"><span>Depoda simit / ekmek</span><b>${g.backstock.simit ?? 0} / ${g.backstock.ekmek ?? 0}</b></div><p class="hint">${icon('sparkle', 14)} Fırın varken simit ve ekmek toptancıdan alınmaz, burada ₺2'ye pişer. Sıcak ekmek müşteriyi mutlu eder.</p>`;
    } else if (k === 'table') {
      body = `<div class="kv"><span>Dolu koltuk</span><b>${f.seatsUsed.filter(Boolean).length} / ${f.seatsUsed.length}</b></div><div class="kv"><span>Durum</span><b class="${f.dirty ? 'bad' : 'good'}">${f.dirty ? 'Kirli — temizlik bekliyor' : 'Temiz'}</b></div>`;
    } else {
      body = `<p class="hint">${f.def.desc}</p>`;
    }
    const refund = Math.round(f.def.cost * 0.5);
    return `${this.insHead(this.thumbs.fixtures[f.def.id], f.def.name, f.def.category + (f.floor ? ' · 1. kat' : ''))}
      ${f.statusKind ? `<div class="flag ${ICON_COLOR[f.statusKind]}">${icon(KIND_TO_SVG[f.statusKind], 14)} ${ICON_LABEL[f.statusKind]}</div>` : ''}
      <div class="ins-body">${body}</div>
      <div class="ins-actions"><button class="btn" data-action="move">${icon('move', 15)} Taşı</button><button class="btn" data-action="rotate">${icon('rotate', 15)} Döndür</button><button class="btn danger" data-action="sell">${icon('trash', 15)} Sat +${fmt(refund)}</button></div>`;
  }

  private portrait(a: Customer | Staff | Visitor) {
    let p = this.portraitCache.get(a.id);
    if (!p) { p = this.thumbs.portrait(a.view.look); this.portraitCache.set(a.id, p); }
    return p;
  }

  private customerInspector(c: Customer) {
    if (!c.shopper) return `${this.insHead(this.portrait(c), c.name, 'Yoldan geçen', true)}<div class="ins-body"><p class="hint">Mahallede yürüyor. Tabelanın, vitrinin ve mağaza puanının onu içeri çekmesi gerekiyor.</p></div>`;
    const a = c.arch!;
    if (c.thief && !c.suspect) {
      return `${this.insHead(this.portrait(c), c.name, `Müşteri · ${c.statusLabel()}`, true)}<div class="ins-body"><p class="hint">${icon('eye', 14)} Rafların arasında dolaşıyor. Elinde sepet var ama pek bir şey koymuyor… Kamera ya da personel görmeden emin olamazsın.</p></div>`;
    }
    if (c.thief) {
      return `${this.insHead(this.portrait(c), c.name, `Şüpheli · ${c.statusLabel()}`, true)}<div class="flag bad">${icon('eye', 14)} Kamerada ürün cebine atarken görüldü</div>
        <div class="ins-body"><div class="kv"><span>Cebindeki ürün</span><b>${c.stolen.map((p) => PRODUCT_MAP[p].name).join(', ') || '—'}</b></div>
        <p class="hint">${esc(a.blurb)} ${this.game.hasRole('security') ? 'Güvenlik görevlisi peşinde.' : 'Güvenlik görevlisi yok — alarm kapısı son şans.'}</p></div>`;
    }
    const statusIcon: Record<string, [string, string, string]> = {
      pending: ['clock', 'mute', 'Arıyor'], got: ['check', 'good', 'Sepette'], oos: ['box', 'bad', 'Stok yok'], notfound: ['info', 'violet', 'Satılmıyor'],
      expensive: ['tag', 'warn', 'Pahalı'], budget: ['coin', 'rose', 'Bütçe yetmedi'], stolen: ['eye', 'bad', 'Çalındı'], skipped: ['close', 'mute', 'Vazgeçti'],
    };
    const list = c.wants.map((w) => { const [ic, col, lab] = statusIcon[w.status]; return `<div class="want"><img src="${this.thumbs.products[w.pid]}"/><span>${PRODUCT_MAP[w.pid].name}${w.qty > 1 ? ' ×' + w.qty : ''}</span><em class="${col}">${icon(ic, 12)} ${lab}</em></div>`; }).join('');
    const extras = c.basket.filter((b) => !c.wants.some((w) => w.pid === b.pid));
    const imp = extras.length ? `<div class="want"><img src="${this.thumbs.products[extras[0].pid]}"/><span>${PRODUCT_MAP[extras[0].pid].name}</span><em class="violet">${icon('sparkle', 12)} Anlık alım</em></div>` : '';
    const thoughts = c.thoughts.map((t) => `<div class="thought"><span class="al-ico ${ICON_COLOR[t.icon]}">${icon(KIND_TO_SVG[t.icon], 13)}</span><span>“${esc(t.text)}”</span></div>`).join('') || '<div class="thought muted">Henüz bir şey düşünmedi.</div>';
    const patience = a.patience * this.game.patienceMul();
    const waitPct = Math.min(1, c.wait / patience);
    return `${this.insHead(this.portrait(c), c.name, `${a.name} · ${c.statusLabel()}`, true)}
      <div class="ins-body">
        ${this.moodBar(c.mood)}
        <div class="chips"><span class="chip">${icon('coin', 13)} Bütçe ${fmt(c.budget)}</span><span class="chip">${icon('cart', 13)} Sepet ${fmt(c.spent)}</span><span class="chip">${icon('tag', 13)} Tolerans +%${Math.round(a.priceTolerance * 100)}</span>${c.hasCart ? `<span class="chip">${icon('cart', 13)} Arabalı</span>` : ''}</div>
        ${c.state === 'queue' || c.state === 'toQueue' ? `<div class="kv"><span>Sabır</span><b>${Math.round(c.wait)} / ${Math.round(patience)} sn</b></div><div class="bar ${waitPct > 0.7 ? 'bad' : waitPct > 0.4 ? 'warn' : 'good'}"><div style="width:${(1 - waitPct) * 100}%"></div></div>` : ''}
        <div class="sec-h">Alışveriş listesi</div>${list}${imp}
        <div class="sec-h">Aklından geçenler</div><div class="thoughts">${thoughts}</div>
        <p class="hint small">${esc(a.blurb)}</p>
      </div>`;
  }

  private staffInspector(s: Staff) {
    const en = Math.round(s.energy);
    return `${this.insHead(this.portrait(s), s.name, ROLE_LABEL[s.role], true)}
      <div class="ins-body">
        <div class="big-stat"><div><b>${s.wage ? fmt(s.wage) : '—'}</b><span>günlük maaş</span></div><div><b>${Math.round(s.skill * 100)}</b><span>beceri</span></div></div>
        <div class="kv"><span>Şu an</span><b>${s.present ? esc(s.activity) : 'Vardiyada değil'}</b></div>
        <div class="kv"><span>Enerji</span><b class="${en < 30 ? 'bad' : en < 55 ? 'warn' : 'good'}">${en}%${s.tired ? ' · yorgun' : ''}</b></div>
        <div class="bar ${en < 30 ? 'bad' : en < 55 ? 'warn' : 'good'}"><div style="width:${en}%"></div></div>
        ${s.role !== 'owner' ? `<div class="sec-h">Vardiya</div>${this.shiftSeg(s)}` : ''}
        <p class="hint small">${ROLE_DESC[s.role]}</p>
      </div>
      ${s.role !== 'owner' ? `<div class="ins-actions"><button class="btn danger" data-action="fire" data-id="${s.id}">${icon('close', 15)} İşten çıkar</button></div>` : ''}`;
  }

  private shiftSeg(s: Staff) {
    return `<div class="seg small">${(['full', 'morning', 'evening'] as Shift[]).map((x) => `<button class="${s.shift === x ? 'on' : ''}" data-action="shift" data-id="${s.id}" data-shift="${x}" title="${SHIFT_LABEL[x]}">${{ full: 'Tam', morning: 'Sabah', evening: 'Akşam' }[x]}</button>`).join('')}</div>`;
  }

  private visitorInspector(v: Visitor) {
    const thoughts = v.thoughts.map((t) => `<div class="thought"><span class="al-ico ${ICON_COLOR[t.icon]}">${icon(KIND_TO_SVG[t.icon], 13)}</span><span>“${esc(t.text)}”</span></div>`).join('') || '<div class="thought muted">Henüz bir şey düşünmedi.</div>';
    const stops = v.stops.map((s) => s.kind === 'unit' ? (s.unit.tenant?.def.brand ?? 'Mağaza') : s.kind === 'food' ? 'Yemek katı' : s.kind === 'play' ? 'Oyun alanı' : 'Bank').join(' → ') || '—';
    return `${this.insHead(this.portrait(v), v.name, `AVM ziyaretçisi · ${v.arch.name}${v.child ? ' + çocuk' : ''}`, true)}
      <div class="ins-body">${this.moodBar(v.mood)}
        <div class="kv"><span>Şu an</span><b>${esc(v.statusLabel())}</b></div>
        <div class="kv"><span>Harcadı</span><b>${fmt(v.spent)}</b></div>
        <div class="kv"><span>Sıradaki</span><b>${esc(stops)}</b></div>
        <div class="sec-h">Aklından geçenler</div><div class="thoughts">${thoughts}</div></div>`;
  }

  private unitInspector(u: UnitState) {
    const g = this.game;
    const t = u.tenant;
    const head = this.insHead(`<div class="ins-badge" style="background:${t ? t.def.color : '#c9c2b6'};color:${t ? t.def.accent : '#fff'}">${icon(u.def.food ? 'food' : 'shop', 28)}</div>`, t ? t.def.brand : `Birim ${u.def.id}`, `${u.def.floor ? '1. kat' : 'Zemin kat'} · ${(u.def.rect.x1 - u.def.rect.x0) * (u.def.rect.z1 - u.def.rect.z0)} m²${u.def.food ? ' · yemek katı' : ''}`);
    if (!t) {
      const offers = u.offers.map((o, i) => `<div class="offer" style="--c:${o.def.color}">
          <div class="offer-top"><span class="offer-brand" style="background:${o.def.color};color:${o.def.accent}">${esc(o.def.brand)}</span><em>${o.def.name}</em></div>
          <div class="kv"><span>Kira</span><b>${fmt(o.rent)}/gün</b></div><div class="kv"><span>Ciro payı</span><b>%${Math.round(o.def.share * 100)}</b></div>
          <p class="hint small">${icon('info', 12)} ${esc(o.def.rule)}${o.def.noisy ? ' · gürültülü' : ''}</p>
          <button class="btn primary small" data-action="lease" data-u="${u.idx}" data-o="${i}">Kirala</button></div>`).join('');
      return `${head}<div class="ins-body"><p class="hint">${icon('shop', 14)} Kiralık birim. Kiracının kuralları ve konumu memnuniyetini belirler; memnun olmayan kiracı iki gün sonra çıkar. Teklifler her sabah yenilenir.</p>${offers || '<p class="hint">Bugün teklif yok.</p>'}</div>`;
    }
    const reasons = t.reasons.map((r) => `<div class="reason ${r.v >= 0 ? 'pos' : 'neg'}"><span>${esc(r.text)}</span><b>${r.v >= 0 ? '+' : ''}${r.v}</b></div>`).join('');
    const sat = Math.round(t.sat);
    return `${head}
      <div class="flag ${sat < 30 ? 'bad' : sat < 55 ? 'warn' : 'blue'}">${icon('heart', 14)} Memnuniyet ${sat}${t.lowDays ? ' · ayrılmayı düşünüyor' : ''}</div>
      <div class="ins-body">
        <div class="big-stat"><div><b>${fmt(t.salesToday)}</b><span>bugünkü ciro</span></div><div><b>${t.visitorsToday}</b><span>ziyaretçi</span></div></div>
        <div class="kv"><span>Günlük gelirin</span><b>${fmt(t.rent)} kira + %${Math.round(t.def.share * 100)} pay (${fmt(t.salesToday * t.def.share)})</b></div>
        <div class="sec-h">Memnuniyet nereden geliyor?</div><div class="reasons">${reasons}</div>
        <p class="hint small">${esc(t.def.rule)}</p>
      </div>
      <div class="ins-actions"><button class="btn danger" data-action="evict" data-u="${u.idx}">${icon('close', 15)} Sözleşmeyi feshet</button></div>`;
    void g;
  }

  private connectorInspector(c: ConnectorState) {
    const st = c.broken ? (c.repairT > 0 ? `Tamirde (${Math.ceil(c.repairT)} dk)` : 'ARIZALI') : 'Çalışıyor';
    return `${this.insHead(`<div class="ins-badge" style="background:#1f2a44;color:#fff">${icon(c.def.kind === 'escalator' ? 'route' : 'arrowUp', 28)}</div>`, c.def.name, c.def.kind === 'escalator' ? 'Katlar arası ulaşım' : 'Engelli ve bebek arabası dostu')}
      <div class="flag ${c.broken ? 'bad' : 'blue'}">${icon(c.broken ? 'wrench' : 'check', 14)} ${st}</div>
      <div class="ins-body"><p class="hint">${icon('route', 14)} Arızalı merdiven yüzünden ziyaretçiler asansöre yönelir ya da vazgeçer; üst kat kiracıları memnuniyet kaybeder. Emekliler asansörü tercih eder.</p></div>
      ${c.broken && c.repairT <= 0 ? `<div class="ins-actions"><button class="btn primary" data-action="repair" data-id="${c.def.id}">${icon('wrench', 15)} Teknisyen çağır · ₺600</button></div>` : ''}`;
  }

  // ------------------------------------------------------------------ panels
  private renderPanel() {
    if (!this.panel) { this.el.panel.innerHTML = ''; this.lastPanelHtml = ''; return; }
    let html = '';
    switch (this.panel) {
      case 'build': html = this.buildPanel(); break;
      case 'products': html = this.productsPanel(); break;
      case 'supply': html = this.supplyPanel(); break;
      case 'staff': html = this.staffPanel(); break;
      case 'campaign': html = this.campaignPanel(); break;
      case 'finance': html = this.financePanel(); break;
      case 'growth': html = this.growthPanel(); break;
      case 'mall': html = this.mallPanel(); break;
    }
    if (html === this.lastPanelHtml || this.pointerDown) return;
    const sc = this.el.panel.querySelector('.p-scroll')?.scrollTop ?? 0;
    this.lastPanelHtml = html;
    this.el.panel.innerHTML = html;
    const ns = this.el.panel.querySelector('.p-scroll'); if (ns) ns.scrollTop = sc;
  }

  private pHead(title: string, sub: string, ic: string) {
    return `<div class="p-head"><span class="p-ico">${icon(ic, 20)}</span><div><b>${title}</b><span>${sub}</span></div><button class="icon-btn ghost" data-action="closePanel">${icon('close', 16)}</button></div>`;
  }

  private buildPanel() {
    const g = this.game;
    const cats = g.stage >= 3 && g.viewFloor === 1 ? ['AVM', 'Ortam', 'Güvenlik & Personel'] : ['Teşhir', 'Kasa & Depo', 'Ortam', 'Güvenlik & Personel', ...(g.stage >= 3 ? ['AVM'] : [])];
    if (!cats.includes(this.buildTab)) this.buildTab = cats[0];
    const tabs = cats.map((c) => `<button class="tab ${this.buildTab === c ? 'on' : ''}" data-action="buildTab" data-id="${c}">${c}</button>`).join('');
    const stageName = ['Büfe', 'Market', 'Süpermarket', 'AVM'];
    const cards = FIXTURES.filter((f) => f.category === this.buildTab).map((f) => {
      const locked = f.stage > g.stage;
      const poor = g.money < f.cost;
      const wrongFloor = g.stage >= 3 && ((f.zone ?? 'store') === 'store' && g.viewFloor === 1);
      return `<button class="bcard ${locked || wrongFloor ? 'locked' : ''} ${poor ? 'poor' : ''}" data-action="place" data-id="${f.id}" title="${esc(f.desc)}">
        <div class="bimg"><img src="${this.thumbs.fixtures[f.id]}"/>${locked ? `<span class="lock">${icon('lock', 14)} ${stageName[f.stage]}</span>` : wrongFloor ? `<span class="lock">Zemin kat</span>` : ''}</div>
        <b>${f.name}</b><span class="bsize">${f.w}×${f.d} m${f.slots ? ` · ${f.slots} bölme` : ''}${f.noBlock ? ' · tavan' : ''}</span><span class="bprice">${fmt(f.cost)}</span></button>`;
    }).join('');
    return `<div class="build-inner"><div class="tabs">${tabs}</div><div class="bcards">${cards}</div></div>`;
  }

  private accept(pid: string, price: number) {
    const p = PRODUCT_MAP[pid];
    return ARCHETYPES.filter((a) => a.stage <= this.game.stage && a.wants[pid] && !a.thief).map((a) => {
      const ok = price <= p.basePrice * (1 + a.priceTolerance + this.game.toleranceBonus());
      return `<span class="acc ${ok ? 'good' : 'bad'}" title="${a.name}: ${ok ? 'alır' : 'pahalı bulur'} (tolerans +%${Math.round(a.priceTolerance * 100)})">${ok ? icon('check', 11) : icon('close', 11)}${a.name.split(' ')[0]}</span>`;
    }).join('');
  }

  private productsPanel() {
    const g = this.game;
    const rows = g.unlockedProducts().map((p) => {
      const price = g.prices[p.id];
      const margin = price - p.cost;
      const markup = Math.round((price / p.basePrice - 1) * 100);
      const shelf = g.shelfStock(p.id), cap = g.shelfCap(p.id);
      const stocked = cap > 0;
      const sold = g.stats.soldBy[p.id] ?? 0, missed = g.stats.missed[p.id] ?? 0, exp = g.stats.tooExpensive[p.id] ?? 0;
      return `<div class="prow ${stocked ? '' : 'dim'}">
        <img src="${this.thumbs.products[p.id]}"/>
        <div class="pname"><b>${p.name}${g.isDiscounted(p.id) ? ' <em class="sale">−%15</em>' : ''}</b><span>${DISPLAY_LABEL[p.display]}${p.impulse ? ' · anlık alım' : ''}</span></div>
        <div class="pprice">
          <button class="step" data-action="price" data-pid="${p.id}" data-d="-1">${icon('minus', 14)}</button>
          <div class="pv"><b>${fmt(price)}</b><span class="${markup > 0 ? 'warn' : markup < 0 ? 'good' : ''}" data-action="priceReset" data-pid="${p.id}" title="Önerilen fiyata dön">${markup === 0 ? 'önerilen' : (markup > 0 ? '+' : '') + markup + '%'}</span></div>
          <button class="step" data-action="price" data-pid="${p.id}" data-d="1">${icon('plus', 14)}</button>
        </div>
        <div class="pacc">${this.accept(p.id, price)}</div>
        <div class="pnum"><b class="${margin <= 0 ? 'neg' : ''}">${fmt(margin)}</b><span>kâr/adet</span></div>
        <div class="pnum"><b>${stocked ? `${shelf}/${cap}` : '—'}</b><span>${stocked ? 'rafta' : 'rafta yok'}</span></div>
        <div class="pnum"><b>${sold}</b><span>satış</span></div>
        <div class="pnum ${missed + exp ? 'negc' : ''}"><b>${missed + exp}</b><span>kaçan</span></div>
      </div>`;
    }).join('');
    return `${this.pHead('Ürün & Fiyat', 'Fiyat, müşteri tipine göre kabul edilir ya da “çok pahalı” tepkisi alır.', 'tag')}
      <div class="p-scroll"><div class="phead-row"><span></span><span>Ürün</span><span>Fiyat</span><span>Kim alır?</span><span>Marj</span><span>Raf</span><span>Bugün</span><span>Kaçan</span></div>${rows}</div>`;
  }

  private supplyPanel() {
    const g = this.game;
    const cap = g.depotCapacity(), tot = g.backstockTotal(), inc = g.incomingTotal();
    const rows = g.unlockedProducts().map((p) => {
      const stocked = g.isStocked(p.id);
      const baked = (p.id === 'simit' || p.id === 'ekmek') && g.hasOven();
      return `<div class="srow ${stocked ? '' : 'dim'}"><img src="${this.thumbs.products[p.id]}"/><div class="pname"><b>${p.name}</b><span>${baked ? 'Kendi fırınında pişiyor' : `Toptan ${fmt(p.cost)}/adet`}</span></div>
        <div class="pnum"><b>${g.backstock[p.id]}</b><span>depoda</span></div><div class="pnum"><b>${g.incoming(p.id) || '—'}</b><span>yolda</span></div>
        <div class="orders">${[6, 12, 24].map((q) => `<button class="btn small" data-action="order" data-pid="${p.id}" data-q="${q}">+${q}<em>${fmt(q * p.cost)}</em></button>`).join('')}</div>
        <button class="toggle ${g.auto[p.id] ? 'on' : ''}" data-action="auto" data-pid="${p.id}" title="Otomatik sipariş"><span></span>Oto</button></div>`;
    }).join('');
    const pending = [...g.orders].sort((a, b) => a.eta - b.eta).slice(0, 6).map((o) => `<span class="chip">${PRODUCT_MAP[o.pid].name} ×${o.qty} · ${clock(o.eta % 1440)}</span>`).join('');
    return `${this.pHead('Tedarik', 'Toptancı minibüsü ~50 dakikada gelir. Oto: stok azalınca kendiliğinden sipariş verir.', 'truck')}
      <div class="p-sub"><div class="kv"><span>Depo doluluğu</span><b>${tot} + ${inc} yolda / ${cap}</b></div><div class="bar ${tot + inc > cap * 0.9 ? 'warn' : 'good'}"><div style="width:${Math.min(100, ((tot + inc) / Math.max(1, cap)) * 100)}%"></div></div>
      ${pending ? `<div class="chips">${icon('truck', 14)} ${pending}</div>` : ''}${g.van.state !== 'idle' ? `<div class="flag blue">${icon('truck', 14)} Minibüs ${g.van.state === 'unloading' ? 'boşaltıyor' : g.van.state === 'arriving' ? 'yolda' : 'ayrılıyor'}</div>` : ''}</div>
      <div class="p-scroll">${rows}</div>`;
  }

  private staffPanel() {
    const g = this.game;
    const mine = g.staff.map((s) => {
      const en = Math.round(s.energy);
      return `<div class="person"><img src="${this.portrait(s)}"/><div class="pmain"><b>${esc(s.name)}</b><span>${ROLE_LABEL[s.role]} · ${s.present ? esc(s.activity) : 'vardiya dışı'}</span>
        <div class="energy"><div class="bar ${en < 30 ? 'bad' : en < 55 ? 'warn' : 'good'}"><div style="width:${en}%"></div></div><small>${en}%</small></div></div>
        ${s.role !== 'owner' ? this.shiftSeg(s) : '<em class="owner">sahip</em>'}
        <em>${s.wage ? fmt(s.wage) : ''}</em>${s.role !== 'owner' ? `<button class="icon-btn ghost" data-action="fire" data-id="${s.id}" title="İşten çıkar">${icon('close', 14)}</button>` : ''}</div>`;
    }).join('');
    const cands = g.candidates.map((c, i) => `<div class="cand"><div class="cand-role">${ROLE_LABEL[c.role]}</div><b>${esc(c.name)}</b><div class="skill"><div style="width:${Math.min(100, c.skill * 80)}%"></div></div><span>${ROLE_DESC[c.role]}</span>
      <div class="cand-btns"><button class="btn primary small" data-action="hire" data-i="${i}" data-shift="full">Tam gün · ${fmt(c.wage)}</button><button class="btn small" data-action="hire" data-i="${i}" data-shift="morning">Sabah · ${fmt(c.wage * 0.6)}</button><button class="btn small" data-action="hire" data-i="${i}" data-shift="evening">Akşam · ${fmt(c.wage * 0.6)}</button></div></div>`).join('');
    const breakRoom = g.fixtures.some((f) => f.def.kind === 'break');
    return `${this.pHead('Personel', `Günlük maaş toplamı ${fmt(g.wagesPerDay())} — gün sonunda ödenir.`, 'staff')}
      <div class="p-scroll">
      <p class="hint small">${icon('clock', 13)} Tam gün vardiyası (07–22) personeli yorar; enerji %30'un altına inince yavaşlar. Sabah + akşam vardiyası %60 maaşla günü böler. ${breakRoom ? 'Çay ocağın var: yorulan personel mola verir.' : '<b>Çay Ocağı</b> kurarsan yorulan personel dinlenir.'}</p>
      <div class="sec-h">Ekip</div>${mine}<div class="sec-h">Adaylar <small>her sabah yenilenir</small></div><div class="cands">${cands || '<p class="hint">Bugün başka aday yok.</p>'}</div></div>`;
  }

  private campaignPanel() {
    const g = this.game;
    const stocked = g.unlockedProducts().filter((p) => g.isStocked(p.id));
    const cards = CAMPAIGNS.filter((c) => c.stage <= g.stage).map((c) => {
      const on = g.campaigns.has(c.id);
      let extra = '';
      if (c.id === 'indirim' && !on) extra = `<div class="disc-pick">${stocked.map((p) => `<button class="dchip ${this.discountPick.has(p.id) ? 'on' : ''}" data-action="discountPick" data-pid="${p.id}"><img src="${this.thumbs.products[p.id]}"/>${p.name}</button>`).join('')}</div><small class="muted">${this.discountPick.size}/3 ürün seçildi</small>`;
      if (c.id === 'indirim' && on) extra = `<div class="chips">${g.discounts.map((p) => `<span class="chip">${PRODUCT_MAP[p].name} −%15</span>`).join('')}</div>`;
      const can = !on && g.money >= c.cost && (c.id !== 'indirim' || this.discountPick.size > 0);
      return `<div class="camp ${on ? 'on' : ''}"><div class="camp-top"><div class="up-ico">${icon(c.id === 'brosur' ? 'megaphone' : c.id === 'indirim' ? 'tag' : c.id === 'kasaonu' ? 'cart' : 'food', 20)}</div><div class="up-main"><b>${c.name}</b><span>${c.desc}</span><em>${c.effect}</em></div></div>${extra}
        ${on ? `<span class="owned-badge">${icon('check', 14)} Bugün aktif</span>` : `<button class="btn ${can ? 'primary' : ''} small" data-action="campaign" data-id="${c.id}" ${can ? '' : 'disabled'}>${c.cost ? fmt(c.cost) + ' · ' : ''}Başlat</button>`}</div>`;
    }).join('');
    return `${this.pHead('Kampanyalar', 'Kampanyalar gün sonuna kadar sürer. Etkisi dükkânda görünür: tanıtımcı, kırmızı etiketler, stantlar.', 'megaphone')}<div class="p-scroll">${cards}</div>`;
  }

  private financePanel() {
    const g = this.game;
    const st = g.stats;
    const projCosts = st.purchases + st.other + g.wagesPerDay() + g.rent() + g.utilities();
    const mallProj = g.mall ? g.mall.units.reduce((s, u) => s + (u.tenant ? u.tenant.rent + u.tenant.salesToday * u.tenant.def.share : 0), 0) : 0;
    const net = st.revenue + mallProj - projCosts;
    const hist = g.history.slice(-8);
    const max = Math.max(100, ...hist.map((h) => Math.max(h.revenue, h.costs)));
    const bars = hist.map((h, i) => {
      const x = 12 + i * 38, hr = (h.revenue / max) * 90, hc = (h.costs / max) * 90;
      return `<g><rect x="${x}" y="${100 - hr}" width="13" height="${hr}" rx="3" class="b-rev"/><rect x="${x + 15}" y="${100 - hc}" width="13" height="${hc}" rx="3" class="b-cost"/><text x="${x + 14}" y="114">G${h.day}</text></g>`;
    }).join('');
    const top = Object.entries(st.soldBy).sort((a, b) => b[1] - a[1]).slice(0, 4).map(([pid, n]) => `<span class="chip"><img src="${this.thumbs.products[pid]}"/>${PRODUCT_MAP[pid].name} ×${n}</span>`).join('') || '<span class="muted">Henüz satış yok</span>';
    const lostMap = [['Kuyruk', st.lostReasons.queue ?? 0], ['Kalabalık', st.lostReasons.crowd ?? 0], ['Kayma', st.slips]] as const;
    return `${this.pHead('Finans', `Gün ${g.day} · ${clock(g.clock)}`, 'chart')}
      <div class="p-scroll">
      <div class="fin-grid">
        <div><span>Satış</span><b class="pos">${fmt(st.revenue)}</b></div>
        ${g.mall ? `<div><span>AVM kira + pay*</span><b class="pos">${fmt(mallProj)}</b></div>` : ''}
        <div><span>Mal alımı</span><b>${fmt(st.purchases)}</b></div>
        <div><span>Maaşlar*</span><b>${fmt(g.wagesPerDay())}</b></div>
        <div><span>Kira*</span><b>${fmt(g.rent())}</b></div>
        ${g.utilities() ? `<div><span>Elektrik & bakım*</span><b>${fmt(g.utilities())}</b></div>` : ''}
        <div><span>Yatırım</span><b>${fmt(st.other)}</b></div>
        <div><span>Kayıp (hırsızlık)</span><b class="${st.theft + st.shrink ? 'neg' : ''}">${fmt(st.theft + st.shrink)}</b></div>
        <div class="total"><span>Tahmini net</span><b class="${net >= 0 ? 'pos' : 'neg'}">${fmt(net)}</b></div>
      </div>
      <p class="hint small">* Gün sonunda hesaplanır. Hırsızlık kaybı, zaten ödenmiş malın rafta satılamamasıdır.</p>
      <div class="sec-h">Günlük geçmiş <small><i class="lg rev"></i>gelir <i class="lg cost"></i>gider</small></div>
      ${hist.length ? `<svg class="chart" viewBox="0 0 320 120">${bars}</svg>` : '<p class="hint">İlk gün bitince burada grafik oluşur.</p>'}
      <div class="sec-h">En çok satanlar</div><div class="chips">${top}</div>
      <div class="sec-h">Müşteri akışı</div>
      <div class="fin-grid small"><div><span>Gelen</span><b>${st.visitors}</b></div><div><span>Ödeyen</span><b>${st.served}</b></div><div><span>Mutlu</span><b class="pos">${st.happyServed}</b></div><div><span>Kaybedilen</span><b class="neg">${st.lost}</b></div><div><span>Anlık alım</span><b>${st.impulse}</b></div><div><span>Ort. memnuniyet</span><b>${st.moodN ? Math.round(st.moodSum / st.moodN) : '—'}</b></div></div>
      <div class="chips">${lostMap.map(([l, n]) => `<span class="chip ${n ? 'badc' : ''}">${l}: ${n}</span>`).join('')}</div>
      </div>`;
  }

  private growthPanel() {
    const g = this.game;
    const ups = UPGRADES.filter((u) => u.stage <= g.stage).map((u) => {
      const owned = g.upgrades.has(u.id);
      return `<div class="up ${owned ? 'owned' : ''}"><div class="up-ico">${icon(u.id === 'neon' ? 'sparkle' : u.id === 'pos' ? 'coin' : 'store', 20)}</div><div class="up-main"><b>${u.name}</b><span>${u.desc}</span><em>${u.effect}</em></div>
        ${owned ? `<span class="owned-badge">${icon('check', 14)} Alındı</span>` : `<button class="btn ${g.money >= u.cost ? 'primary' : ''} small" data-action="upgrade" data-id="${u.id}">${fmt(u.cost)}</button>`}</div>`;
    }).join('');
    const e = g.expansion();
    let exp = '';
    if (e) {
      const goals = g.goals();
      const ready = g.canExpand();
      exp = `<div class="expand ${ready ? 'ready' : ''}">
        <div class="exp-top"><div><div class="kicker">Aşama ${e.toStage + 1} · ${STAGES[e.toStage].name}</div><b>${e.title}</b></div><span class="exp-cost">${fmt(e.cost)}</span></div>
        <p>${e.pitch}</p>
        ${goals.map((x) => `<div class="goal-row ${x.done ? 'done' : ''}"><span class="gl">${x.done ? icon('check', 12) : ''} ${x.label}</span><span class="gv">${x.id === 'rating' ? x.value.toFixed(1) : x.id === 'cash' ? fmt(x.value) : Math.floor(x.value)} / ${x.id === 'cash' ? fmt(x.target) : x.target}${x.unit === '★' ? '★' : ''}</span><div class="bar"><div style="width:${Math.min(100, (x.value / x.target) * 100)}%"></div></div></div>`).join('')}
        <div class="unlocks"><span>Açılacaklar:</span> ${e.unlocks}</div>
        <button class="btn ${ready ? 'primary' : ''} big" data-action="expand" ${ready ? '' : 'disabled'}>${ready ? 'Genişlet!' : icon('lock', 15) + ' Hedefler tamamlanınca'}</button></div>`;
    } else {
      exp = `<div class="expand done"><div class="kicker">Tüm aşamalar açık</div><b>Köşebaşı AVM</b><p>Kiracılarını mutlu et, etkinliklerle AVM'yi doldur, yemek katını temiz tut.</p></div>`;
    }
    const road = STAGES.map((s, i) => `<div class="road ${i <= g.stage ? 'done' : ''}"><span class="road-n">${i <= g.stage ? icon('check', 14) : i + 1}</span><div><b>${s.name}</b><span>${s.pitch}</span></div></div>`).join('');
    return `${this.pHead('Gelişim', 'Yükseltmeler ve genişleme', 'arrowUp')}<div class="p-scroll">${exp}<div class="sec-h">Yükseltmeler</div>${ups}<div class="sec-h">Yolculuk</div>${road}</div>`;
  }

  private mallPanel() {
    const g = this.game;
    const m = g.mall; if (!m) return '';
    const tabs = [['units', 'Kiracılar'], ['events', 'Etkinlikler'], ['facility', 'Tesis']].map(([id, l]) => `<button class="tab ${this.mallTab === id ? 'on' : ''}" data-action="mallTab" data-id="${id}">${l}</button>`).join('');
    let body = '';
    if (this.mallTab === 'units') {
      body = [1, 0].map((fl) => `<div class="sec-h">${fl ? '1. kat' : 'Zemin kat'}</div>` + m.units.filter((u) => u.def.floor === fl).map((u) => {
        const t = u.tenant;
        const sat = t ? Math.round(t.sat) : 0;
        return `<div class="unit-row" data-action="focusUnit" data-u="${u.idx}">
          <span class="unit-id">${u.def.id}</span>
          ${t ? `<span class="offer-brand" style="background:${t.def.color};color:${t.def.accent}">${esc(t.def.brand)}</span><span class="u-cat">${t.def.name}</span>
            <div class="u-sat"><div class="bar ${sat < 30 ? 'bad' : sat < 55 ? 'warn' : 'good'}"><div style="width:${sat}%"></div></div><small>${sat}</small></div>
            <span class="u-num">${fmt(t.salesToday)}<small>ciro</small></span>` : `<span class="u-vacant">${icon('shop', 14)} Kiralık · ${u.offers.length} teklif${u.def.food ? ' (yemek)' : ''}</span>`}
          ${icon('arrowUp', 14, 'u-go')}</div>`;
      }).join('')).join('');
    } else if (this.mallTab === 'events') {
      const todayOk = g.clock < 14 * 60 && !m.event;
      body = `<p class="hint small">${icon('fun', 13)} Bir günde tek etkinlik. Kalabalık etkinliklerde güvenlik görevlisi yoksa arbede çıkabilir.</p>` + MALL_EVENTS.map((e) => {
        const sch = m.scheduled.find((s) => s.id === e.id);
        const active = m.event?.def.id === e.id;
        return `<div class="camp ${active ? 'on' : ''}"><div class="camp-top"><div class="up-ico">${icon('sparkle', 20)}</div><div class="up-main"><b>${e.name}</b><span>${e.desc}</span><em>Ziyaretçi ×${e.visitorMul}${e.tenantMul > 1 ? ` · kiracı satışı ×${e.tenantMul}` : ''}${e.storeMul > 1 ? ` · süpermarket ×${e.storeMul}` : ''}</em></div></div>
          ${active ? `<span class="owned-badge">${icon('check', 14)} Bugün!</span>` : sch ? `<span class="owned-badge">${icon('clock', 14)} Gün ${sch.day} planlandı</span>` : `<div class="cand-btns"><button class="btn small ${todayOk ? 'primary' : ''}" data-action="event" data-id="${e.id}" data-when="today" ${todayOk ? '' : 'disabled'}>Bugün · ${fmt(e.cost)}</button><button class="btn small" data-action="event" data-id="${e.id}" data-when="tomorrow">Yarın · ${fmt(e.cost)}</button></div>`}</div>`;
      }).join('');
    } else {
      body = `<div class="fin-grid small"><div><span>AVM keyfi</span><b>${m.mood.toFixed(1)}★</b></div><div><span>Şu an ziyaretçi</span><b>${m.visitors.length}</b></div><div><span>Bugün gelen</span><b>${m.stats.visitors}</b></div><div><span>Kiracı cirosu</span><b>${fmt(m.stats.tenantSales)}</b></div><div><span>Yemekte ayakta kalan</span><b class="${m.stats.noSeat ? 'neg' : ''}">${m.stats.noSeat}</b></div><div><span>Olay</span><b class="${m.stats.incidents ? 'neg' : ''}">${m.stats.incidents}</b></div></div>
        <div class="sec-h">Katlar arası ulaşım</div>` + m.connectors.map((c) => `<div class="unit-row"><span class="unit-id">${icon(c.def.kind === 'escalator' ? 'route' : 'arrowUp', 14)}</span><span class="u-cat">${c.def.name}</span><span class="${c.broken ? 'neg' : 'pos'}">${c.broken ? (c.repairT > 0 ? 'Tamirde' : 'Arızalı') : 'Çalışıyor'}</span>${c.broken && c.repairT <= 0 ? `<button class="btn small primary" data-action="repair" data-id="${c.def.id}">Tamir · ₺600</button>` : ''}</div>`).join('') +
        `<div class="kv"><span>Günlük elektrik & bakım</span><b>${fmt(g.utilities())}</b></div><div class="kv"><span>Masa / koltuk</span><b>${g.fixtures.filter((f) => f.def.kind === 'table').length} / ${g.fixtures.filter((f) => f.def.kind === 'table').length * 4}</b></div>`;
    }
    return `${this.pHead('Köşebaşı AVM', `${m.units.filter((u) => u.tenant).length}/${m.units.length} birim dolu · bugün ${m.event ? m.event.def.name : 'etkinlik yok'}`, 'mall')}<div class="build-inner"><div class="tabs">${tabs}</div></div><div class="p-scroll">${body}</div>`;
  }

  // ------------------------------------------------------------------ day end
  private showDayEnd(r: DayEndReport) {
    this.dayEndOpen = true;
    const st = r.stats;
    const income = st.revenue + st.mallIncome;
    const profit = income - r.costs;
    const insights: string[] = [];
    const missed = Object.entries(st.missed).sort((a, b) => b[1] - a[1])[0];
    if (missed && missed[1] >= 2) insights.push(`${icon('box', 14)} <b>${PRODUCT_MAP[missed[0]].name}</b> ${missed[1]} kez bulunamadı. ${this.game.isStocked(missed[0]) ? 'Stok ve rafa doldurma hızına bak.' : 'Rafa eklemeyi düşün.'}`);
    const exp = Object.entries(st.tooExpensive).sort((a, b) => b[1] - a[1])[0];
    if (exp && exp[1] >= 2) insights.push(`${icon('tag', 14)} <b>${PRODUCT_MAP[exp[0]].name}</b> için ${exp[1]} müşteri “çok pahalı” dedi.`);
    if (st.abandoned >= 2) insights.push(`${icon('clock', 14)} ${st.abandoned} müşteri kuyrukta beklemekten sıkılıp sepeti bıraktı. Hızlı POS, bantlı kasa ya da ek kasa düşün.`);
    if ((st.lostReasons.crowd ?? 0) >= 3) insights.push(`${icon('people', 14)} ${st.lostReasons.crowd} kişi kapıdan kalabalık yüzünden döndü.`);
    if (st.theft + st.shrink > 0) insights.push(`${icon('eye', 14)} Sayımda ₺${Math.round(st.theft + st.shrink)} değerinde ${st.theftCount} ürün eksik çıktı${st.theftSeen ? ` (${st.theftSeen} olay kamerada)` : ''}. Kamera, alarm kapısı ve güvenlik caydırır.`);
    if (st.caught) insights.push(`${icon('shield', 14)} ${st.caught} hırsız yakalandı.`);
    if (st.slips) insights.push(`${icon('drop', 14)} ${st.slips} müşteri ıslak zeminde kaydı. Temizlik görevlisi paspaslayıp uyarı levhası koyar.`);
    if (st.impulse >= 3) insights.push(`${icon('sparkle', 14)} Kasa yolundaki raflardan ${st.impulse} anlık alım yapıldı.`);
    if (r.mall) insights.push(`${icon('mall', 14)} AVM: ${r.mall.visitors} ziyaretçi, kiracı cirosu ${fmt(r.mall.sales)} → sana ${fmt(r.mall.rent)} kira + ${fmt(r.mall.share)} pay.${r.mall.incidents ? ` ${r.mall.incidents} olay yaşandı.` : ''}`);
    if (!insights.length) insights.push(`${icon('heart', 14)} Sakin, dengeli bir gün. Müşteriler memnun.`);
    this.el.modal.innerHTML = `<div class="modal card">
      <div class="modal-kicker">${icon('moon', 16)} Gün ${r.day} kapandı · otomatik kaydedildi</div>
      <h2 class="${profit >= 0 ? 'pos' : 'neg'}">${profit >= 0 ? '+' : '−'}${fmt(Math.abs(profit))}</h2>
      <div class="modal-sub">günlük net kâr · kasada ${fmt(r.money)}</div>
      <div class="fin-grid">
        <div><span>Satış</span><b class="pos">${fmt(st.revenue)}</b></div>${st.mallIncome ? `<div><span>AVM geliri</span><b class="pos">${fmt(st.mallIncome)}</b></div>` : ''}<div><span>Mal alımı</span><b>${fmt(st.purchases)}</b></div><div><span>Maaş + kira${st.utilities ? ' + gider' : ''}</span><b>${fmt(st.wages + st.rent + st.utilities)}</b></div>
        <div><span>Ödeyen müşteri</span><b>${st.served}</b></div><div><span>Mutlu ayrılan</span><b class="pos">${st.happyServed}</b></div><div><span>Kaybedilen</span><b class="neg">${st.lost}</b></div>
      </div>
      <div class="modal-rating">${stars(r.rating, 20)} <b>${r.rating.toFixed(2)}</b></div>
      <div class="insights">${insights.slice(0, 5).map((s) => `<div>${s}</div>`).join('')}</div>
      <button class="btn primary big" data-action="nextDay">Yeni güne başla ${icon('sun', 16)}</button>
    </div>`;
    this.el.modal.classList.add('show');
  }
}

interface DayEndReport { day: number; stats: DayStats; costs: number; rating: number; money: number; mall: { rent: number; share: number; visitors: number; sales: number; incidents: number; mood: number } | null }
