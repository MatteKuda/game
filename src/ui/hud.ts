import * as THREE from 'three';
import type { Game, Selection, AlertMsg, DayStats } from '../game';
import type { Fixture } from '../sim/fixture';
import { Customer, Staff, ROLE_LABEL } from '../sim/agents';
import { FIXTURES, FIXTURE_MAP } from '../data/fixtures';
import { PRODUCTS, PRODUCT_MAP, DISPLAY_LABEL } from '../data/products';
import { ARCHETYPES, ARCHETYPE_MAP } from '../data/customers';
import { STAGES, UPGRADES, EXPANSION } from '../data/stages';
import { DAY_OPEN, DAY_CLOSE } from '../config';
import { ICON_LABEL, type IconKind } from '../world/icons';
import { icon, stars } from './svg';
import type { Thumbs } from './thumbs';
import { sfx } from './sfx';

type PanelId = 'build' | 'products' | 'supply' | 'staff' | 'finance' | 'growth' | null;

const fmt = (n: number) => '₺' + Math.round(n).toLocaleString('tr-TR');
const esc = (s: string) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]!));
const clock = (m: number) => { const h = Math.floor(m / 60) % 24, mm = Math.floor(m % 60); return `${String(h).padStart(2, '0')}:${String(mm).padStart(2, '0')}`; };

const ICON_COLOR: Record<IconKind, string> = {
  empty: 'bad', low: 'warn', noproduct: 'mute', price: 'warn', cheap: 'good', wait: 'warn', happy: 'good', angry: 'bad', notfound: 'violet',
  dirty: 'brown', crowd: 'warn', wallet: 'rose', queue: 'warn', nocashier: 'bad', star: 'gold', box: 'blue',
};
const KIND_TO_SVG: Record<IconKind, string> = {
  empty: 'box', low: 'box', noproduct: 'plus', price: 'tag', cheap: 'tag', wait: 'clock', happy: 'heart', angry: 'alert', notfound: 'info',
  dirty: 'broom', crowd: 'people', wallet: 'coin', queue: 'people', nocashier: 'staff', star: 'star', box: 'box',
};

export class HUD {
  root: HTMLElement;
  private el: Record<string, HTMLElement> = {};
  panel: PanelId = null;
  private buildTab: string = 'Teşhir';
  private lastPanelHtml = '';
  private lastInspectorHtml = '';
  private pointerDown = false;
  private acc = 0;
  private portraitCache = new Map<number, string>();
  private slotPicker: { f: Fixture; i: number } | null = null;
  private dayEndOpen = false;
  private started = false;
  private coachDone = new Set<string>();
  private priceTouched = false;

  constructor(private game: Game, private thumbs: Thumbs) {
    this.root = document.getElementById('ui')!;
    this.root.innerHTML = this.skeleton();
    this.root.querySelectorAll<HTMLElement>('[data-el]').forEach((e) => (this.el[e.dataset.el!] = e));
    this.root.addEventListener('pointerdown', () => (this.pointerDown = true));
    window.addEventListener('pointerup', () => setTimeout(() => (this.pointerDown = false), 0));
    this.root.addEventListener('click', (e) => this.onClick(e));
    this.bindGame();
    this.bindKeys();
    this.bindCanvas();
    this.renderDock();
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
      <div class="stat card"><span class="stat-ico teal">${icon('people', 18)}</span><div><div class="stat-v" data-el="inside">0</div><div class="stat-l" data-el="insideL">içeride</div></div></div>
      <button class="icon-btn card" data-action="mute" title="Ses" data-el="mute">${icon('volume', 18)}</button>
    </div>
    <div class="alerts" data-el="alerts"></div>
    <div class="inspector card" data-el="inspector"></div>
    <div class="panel card" data-el="panel"></div>
    <div class="placehint" data-el="placehint"></div>
    <div class="dock" data-el="dock"></div>
    <div class="tooltip" data-el="tooltip"></div>
    <div class="modal-wrap" data-el="modal"></div>
    <div class="welcome" data-el="welcome">${this.welcomeHtml()}</div>
    `;
  }

  private welcomeHtml() {
    return `<div class="welcome-card">
      <div class="welcome-kicker">Perakende yönetim oyunu · Dikey kesit</div>
      <h1>Tezgâh<span>.</span></h1>
      <p class="welcome-sub">Köşedeki küçük büfeden mahallenin marketine, oradan çok katlı bir AVM'ye.</p>
      <div class="welcome-grid">
        <div>${icon('eye', 18)}<b>Önce dünyaya bak</b><span>Boş raflar, uzayan kuyruk, yerdeki çöp ve müşterilerin baloncukları sorunu gösterir.</span></div>
        <div>${icon('build', 18)}<b>Yerleşim önemli</b><span>Rafların yeri müşterinin yolunu, kuyruğu ve anlık alımları değiştirir.</span></div>
        <div>${icon('arrowUp', 18)}<b>Büyü</b><span>Hedeflere ulaş, yan dükkânı devral ve Mahalle Marketi'ni aç.</span></div>
      </div>
      <div class="welcome-keys"><span><kbd>Sağ tık</kbd> sürükle: kaydır</span><span><kbd>Q</kbd><kbd>E</kbd> / <kbd>Orta tık</kbd>: döndür</span><span><kbd>Tekerlek</kbd>: yakınlaş</span><span><kbd>B</kbd> inşa · <kbd>M</kbd> akış haritası · <kbd>Boşluk</kbd> duraklat</span></div>
      <button class="btn primary big" data-action="start">Dükkânı Aç</button>
    </div>`;
  }

  // ------------------------------------------------------------------ bindings
  private bindGame() {
    const g = this.game;
    g.on('alert', (a: AlertMsg) => this.renderAlerts());
    g.on('select', () => { this.slotPicker = null; this.lastInspectorHtml = ''; this.renderInspector(true); });
    g.on('placing', (p: unknown) => { this.renderPlaceHint(); if (p) this.root.classList.add('placing'); else this.root.classList.remove('placing'); });
    g.on('placingUpdate', () => this.renderPlaceHint());
    g.on('dayEnd', (r: { day: number; stats: DayStats; costs: number; rating: number; money: number }) => this.showDayEnd(r));
    g.on('changed', () => { this.lastPanelHtml = ''; });
    g.on('stage', () => { this.renderDock(); this.lastPanelHtml = ''; });
  }

  private bindKeys() {
    window.addEventListener('keydown', (e) => {
      if (!this.started) { if (e.key === 'Enter') this.start(); return; }
      const k = e.key.toLowerCase();
      const g = this.game;
      if (k === 'escape') {
        if (g.placing) g.cancelPlacement();
        else if (this.slotPicker) { this.slotPicker = null; this.renderInspector(true); }
        else if (this.panel) this.openPanel(null);
        else g.select(null);
      }
      if (this.dayEndOpen) return;
      if (k === 'r' && g.placing) g.rotatePlacement();
      if (k === ' ') { e.preventDefault(); this.setSpeed(g.paused ? (g.speed || 1) : 0); }
      if (k === '1') this.setSpeed(1);
      if (k === '2') this.setSpeed(2);
      if (k === '3') this.setSpeed(4);
      if (k === 'b') this.togglePanel('build');
      if (k === 'p') this.togglePanel('products');
      if (k === 't') this.togglePanel('supply');
      if (k === 'h') this.togglePanel('staff');
      if (k === 'f') this.togglePanel('finance');
      if (k === 'u') this.togglePanel('growth');
      if (k === 'm') { g.setHeat(!g.heatVisible); this.renderDock(); }
      if (k === 'c') { g.shell.cutaway = !g.shell.cutaway; }
    });
  }

  private bindCanvas() {
    const canvas = document.getElementById('scene')!;
    const ndc = new THREE.Vector2();
    let down: { x: number; y: number; b: number } | null = null;
    let hoverAcc = 0;
    const setNdc = (e: PointerEvent) => ndc.set((e.clientX / window.innerWidth) * 2 - 1, -(e.clientY / window.innerHeight) * 2 + 1);
    canvas.addEventListener('pointerdown', (e) => { down = { x: e.clientX, y: e.clientY, b: e.button }; });
    canvas.addEventListener('pointermove', (e) => {
      setNdc(e);
      const g = this.game;
      if (g.placing) {
        const hit = g.pick(ndc);
        if (hit.ground) g.updatePlacement(Math.floor(hit.ground.x), Math.floor(hit.ground.z));
        this.hideTooltip();
        return;
      }
      const now = performance.now();
      if (now - hoverAcc < 60 || this.game.cam.isDragging) return;
      hoverAcc = now;
      const hit = g.pick(ndc);
      this.hover(hit, e.clientX, e.clientY);
    });
    canvas.addEventListener('pointerleave', () => this.hideTooltip());
    canvas.addEventListener('pointerup', (e) => {
      if (!down) return;
      const moved = Math.hypot(e.clientX - down.x, e.clientY - down.y) > 6;
      const b = down.b; down = null;
      const g = this.game;
      if (b === 2 && !moved && g.placing) { g.cancelPlacement(); return; }
      if (b !== 0 || moved || e.altKey) return;
      setNdc(e);
      if (g.placing) { g.confirmPlacement(e.shiftKey); return; }
      const hit = g.pick(ndc);
      if (hit.litter) {
        g.removeLitter(hit.litter);
        g.overlays.floatText(hit.litter.obj.position.clone().setY(1), 'Temizlendi', '#1f8a86');
        sfx.play('click');
        return;
      }
      if (hit.agent) { g.select(hit.agent instanceof Customer ? { kind: 'customer', c: hit.agent } : { kind: 'staff', s: hit.agent as Staff }); sfx.play('click'); return; }
      if (hit.fixture) { g.select({ kind: 'fixture', f: hit.fixture }); sfx.play('click'); return; }
      g.select(null);
    });
  }

  private hover(hit: ReturnType<Game['pick']>, x: number, y: number) {
    const g = this.game;
    const ring = g.overlays.hoverRing;
    let html = '';
    ring.visible = false;
    document.body.style.cursor = '';
    if (hit.agent) {
      const a = hit.agent;
      ring.visible = true; ring.position.set(a.pos.x, 0.115, a.pos.z); ring.scale.set(1, 1, 1);
      if (a instanceof Customer) {
        html = `<b>${esc(a.name)}</b><span>${a.arch ? a.arch.name : 'Yoldan geçen'} · ${a.shopper ? a.statusLabel() : 'yürüyor'}</span>${a.shopper ? this.moodBar(a.mood, true) : ''}`;
      } else {
        const s = a as Staff;
        html = `<b>${esc(s.name)}</b><span>${ROLE_LABEL[s.role]} · ${s.activity}</span>`;
      }
      document.body.style.cursor = 'pointer';
    } else if (hit.litter) {
      html = `<b>Çöp</b><span>Tıkla: temizle</span>`;
      document.body.style.cursor = 'pointer';
    } else if (hit.fixture) {
      const f = hit.fixture;
      const c = f.center; ring.visible = true; ring.position.set(c.x, 0.115, c.z); const sz = Math.max(f.fp.fw, f.fp.fd) + 0.4; ring.scale.set(sz, 1, sz);
      let sub = f.def.desc;
      if (f.isDisplay) sub = f.slots.map((s) => s.productId ? `${PRODUCT_MAP[s.productId].name} ${s.stock}/${f.cap()}` : 'boş bölme').join(' · ');
      if (f.def.kind === 'register') sub = `Kuyruk: ${f.queue.length} kişi · ${f.cashier ? 'Kasiyer: ' + f.cashier.name : 'Kasiyer yok'}`;
      if (f.def.kind === 'depot') sub = `Depo: ${g.backstockTotal()}/${g.depotCapacity()} birim`;
      html = `<b>${f.def.name}</b><span>${sub}</span>`;
      if (f.statusKind) html += `<em class="tt-${ICON_COLOR[f.statusKind]}">${ICON_LABEL[f.statusKind]}</em>`;
      document.body.style.cursor = 'pointer';
    }
    const tt = this.el.tooltip;
    if (!html) { this.hideTooltip(); return; }
    tt.innerHTML = html;
    tt.style.transform = `translate(${x + 16}px, ${y + 14}px)`;
    tt.classList.add('show');
  }
  private hideTooltip() { this.el.tooltip.classList.remove('show'); this.game.overlays.hoverRing.visible = false; document.body.style.cursor = ''; }

  // ------------------------------------------------------------------ actions
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
      case 'heat': g.setHeat(!g.heatVisible); this.renderDock(); break;
      case 'mute': sfx.muted = !sfx.muted; this.el.mute.innerHTML = icon(sfx.muted ? 'mute' : 'volume', 18); break;
      case 'buildTab': this.buildTab = t.dataset.id!; this.lastPanelHtml = ''; break;
      case 'place': {
        const def = FIXTURE_MAP[t.dataset.id!];
        if (def.stage > g.stage) { sfx.play('error'); break; }
        g.startPlacement(def.id); sfx.play('click');
        break;
      }
      case 'move': { const f = fx(); if (f) g.startPlacement(f.def.id, f); break; }
      case 'rotate': { const f = fx(); if (f) { g.startPlacement(f.def.id, f); g.rotatePlacement(); g.updatePlacement(f.x, f.z, true); if (g.placing?.valid) g.confirmPlacement(); else sfx.play('error'); } break; }
      case 'sell': { const f = fx(); if (f) g.sellFixture(f); break; }
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
      case 'hire': { const c = g.candidates[Number(t.dataset.i)]; if (c) g.hire(c); this.lastPanelHtml = ''; break; }
      case 'fire': {
        const s = g.selection?.kind === 'staff' ? g.selection.s : g.staff.find((x) => x.id === Number(t.dataset.id));
        if (s) g.fire(s); this.lastPanelHtml = ''; break;
      }
      case 'upgrade': g.buyUpgrade(t.dataset.id!); this.lastPanelHtml = ''; break;
      case 'expand': g.expand(); this.lastPanelHtml = ''; break;
      case 'focusAlert': {
        const al = g.alerts.find((x) => x.id === Number(t.dataset.id));
        if (al?.focus) g.cam.focus(al.focus.x, al.focus.z, 18);
        break;
      }
      case 'dismissAlert': { g.alerts = g.alerts.filter((x) => x.id !== Number(t.dataset.id)); this.renderAlerts(); e.stopPropagation(); break; }
      case 'nextDay': this.el.modal.classList.remove('show'); this.dayEndOpen = false; g.startNextDay(); break;
      case 'deselect': g.select(null); break;
      case 'focusSel': {
        const s = g.selection; if (!s) break;
        const p = s.kind === 'fixture' ? s.f.center : s.kind === 'customer' ? s.c.pos : s.s.pos;
        g.cam.focus(p.x, p.z, 14); break;
      }
      case 'cutaway': g.shell.cutaway = !g.shell.cutaway; break;
    }
  }

  private start() {
    if (this.started) return;
    this.started = true;
    this.el.welcome.classList.add('hide');
    setTimeout(() => this.el.welcome.remove(), 700);
    this.game.paused = false;
    this.setSpeed(1);
    sfx.play('fanfare');
    this.game.cam.set({ dist: 20, yaw: -0.22, pitch: 0.88 });
    setTimeout(() => this.game.alert('hello', 'star', 'Hoş geldin! Soldaki raftaki boş bölmeye tıklayıp ürün ata. Sorunları önce dükkânın içinde gör.', 'good', undefined, 0), 900);
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
    this.el.panel.classList.toggle('build', id === 'build');
    this.renderDock();
    this.renderPanel();
    sfx.play('click');
  }

  // ------------------------------------------------------------------ per-frame
  update(dt: number) {
    this.acc += dt;
    if (this.acc < 0.12) return;
    this.acc = 0;
    const g = this.game;
    this.el.money.textContent = fmt(g.money);
    const net = g.stats.revenue - g.stats.purchases - g.stats.other;
    this.el.moneyDelta.innerHTML = `bugün <b class="${net >= 0 ? 'pos' : 'neg'}">${net >= 0 ? '+' : '−'}${fmt(Math.abs(net)).replace('₺', '₺')}</b>`;
    this.el.rating.innerHTML = `${stars(g.rating, 15)}<span class="num">${g.rating.toFixed(1)}</span>`;
    const inside = g.customersInside();
    const q = g.fixtures.filter((f) => f.def.kind === 'register').reduce((s, f) => s + f.queue.length, 0);
    this.el.inside.textContent = `${inside}`;
    this.el.insideL.innerHTML = `içeride · <span class="${q >= 4 ? 'neg' : ''}">kuyruk ${q}</span>`;
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
    if (g.stage >= 1) {
      this.el.goal.innerHTML = `<div class="goal-head">${icon('sparkle', 16)}<span>Mahalle Marketi açık</span></div><div class="goal-sub">Sonraki: Süpermarket (yol haritası)</div>`;
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
    this.el.goal.innerHTML = `<div class="goal-head">${icon('arrowUp', 16)}<span>${ready ? 'Genişlemeye hazır!' : 'Hedef: Yan dükkânı devral'}</span><em>${done}/3</em></div>${rows}`;
  }

  private renderCoach() {
    const g = this.game;
    const allAssigned = g.fixtures.every((f) => f.slots.every((s) => s.productId));
    if (allAssigned) this.coachDone.add('assign');
    if (this.priceTouched) this.coachDone.add('price');
    if (g.hasRole('stocker')) this.coachDone.add('hire');
    if (g.upgrades.size > 0) this.coachDone.add('upgrade');
    const steps = [
      { id: 'assign', t: 'Boş raf bölmesine ürün ata' },
      { id: 'price', t: 'Ürünler panelinde bir fiyatı dene (P)' },
      { id: 'hire', t: 'Reyon görevlisi işe al (H) — kasa boş kalmasın' },
      { id: 'upgrade', t: 'İlk yükseltmeni satın al (U)' },
    ];
    const open = steps.filter((s) => !this.coachDone.has(s.id));
    if (!open.length || g.stage > 0) { this.el.coach.style.display = 'none'; return; }
    this.el.coach.style.display = '';
    const html = `<div class="coach-h">İlk adımlar</div>` + steps.map((s) => `<div class="coach-row ${this.coachDone.has(s.id) ? 'done' : ''}"><span class="cb">${this.coachDone.has(s.id) ? icon('check', 12) : ''}</span>${s.t}</div>`).join('');
    if (this.el.coach.innerHTML !== html) this.el.coach.innerHTML = html;
  }

  // ------------------------------------------------------------------ dock
  private renderDock() {
    const g = this.game;
    const b = (id: string, ic: string, label: string, key: string, on = false, action = 'panel') =>
      `<button class="dock-btn ${on ? 'on' : ''}" data-action="${action}" data-id="${id}" title="${label} (${key})">${icon(ic, 22)}<span>${label}</span><kbd>${key}</kbd></button>`;
    this.el.dock.innerHTML = `
      ${b('build', 'build', 'İnşa', 'B', this.panel === 'build')}
      ${b('products', 'tag', 'Ürün & Fiyat', 'P', this.panel === 'products')}
      ${b('supply', 'truck', 'Tedarik', 'T', this.panel === 'supply')}
      ${b('staff', 'staff', 'Personel', 'H', this.panel === 'staff')}
      ${b('finance', 'chart', 'Finans', 'F', this.panel === 'finance')}
      ${b('growth', 'arrowUp', 'Gelişim', 'U', this.panel === 'growth')}
      <div class="dock-sep"></div>
      ${b('heat', 'route', 'Akış', 'M', g.heatVisible, 'heat')}`;
  }

  private renderPlaceHint() {
    const p = this.game.placing;
    const el = this.el.placehint;
    if (!p) { el.classList.remove('show'); return; }
    el.classList.add('show');
    el.innerHTML = `<div class="ph-title"><img src="${this.thumbs.fixtures[p.def.id]}"/><div><b>${p.def.name}</b><span>${p.moving ? 'Taşınıyor — ücretsiz' : fmt(p.def.cost)}</span></div></div>
      <div class="ph-status ${p.valid ? 'ok' : 'bad'}">${p.valid ? icon('check', 14) + ' Yerleştirilebilir' : icon('alert', 14) + ' ' + (p.reason || 'Bir konum seç')}</div>
      <div class="ph-legend"><span class="lg fp"></span>Eşya <span class="lg acc"></span>Müşteri erişimi ${p.def.kind === 'register' ? '<span class="lg back"></span>Kasiyer' : ''}</div>
      <div class="ph-keys"><kbd>R</kbd> Döndür <kbd>Sol tık</kbd> Yerleştir <kbd>Shift</kbd> Çoklu <kbd>Esc</kbd> İptal</div>`;
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
    if (s.kind === 'fixture') html = this.fixtureInspector(s.f);
    else if (s.kind === 'customer') html = this.customerInspector(s.c);
    else html = this.staffInspector(s.s);
    if (!force && (html === this.lastInspectorHtml || this.pointerDown)) return;
    this.lastInspectorHtml = html;
    el.innerHTML = html;
  }

  private insHead(img: string, title: string, sub: string, round = false) {
    return `<div class="ins-head"><div class="ins-img ${round ? 'round' : ''}"><img src="${img}"/></div><div class="ins-title"><b>${esc(title)}</b><span>${sub}</span></div>
      <button class="icon-btn ghost" data-action="focusSel" title="Kamerayı odakla">${icon('camera', 16)}</button><button class="icon-btn ghost" data-action="deselect">${icon('close', 16)}</button></div>`;
  }

  private fixtureInspector(f: Fixture) {
    const g = this.game;
    let body = '';
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
          return `<button class="slot" data-action="slotPick" data-i="${i}"><img src="${this.thumbs.products[p.id]}"/><div class="slot-main"><div class="slot-top"><b>${p.name}</b><span class="price">${fmt(g.prices[p.id])}</span></div>
            <div class="bar ${st}"><div style="width:${pct * 100}%"></div></div><div class="slot-sub"><span>${s.stock}/${f.cap()}</span><span class="${st}">${note}</span></div></div></button>`;
        }).join('');
        const sold = f.slots.reduce((n, s) => n + (s.productId ? g.stats.soldBy[s.productId] ?? 0 : 0), 0);
        body += `<div class="kv"><span>Bugün bu ürünlerden satılan</span><b>${sold}</b></div>`;
      }
    } else if (f.def.kind === 'register') {
      const pat = f.queue.length;
      body = `<div class="big-stat"><div><b class="${pat >= 4 ? 'neg' : ''}">${pat}</b><span>kişi kuyrukta</span></div><div><b>${f.cashier ? esc(f.cashier.name) : '—'}</b><span>${f.cashier ? 'kasiyer' : 'kasiyer yok!'}</span></div></div>
        <div class="kv"><span>Ödeme hızı</span><b>${g.upgrades.has('pos') ? 'Temassız POS (−%35)' : 'Standart'}</b></div>
        <div class="kv"><span>Kuyruk kapasitesi (içeride)</span><b>${f.queueSlots.filter((t) => g.grid.isInterior(t.x, t.z)).length} kişi</b></div>
        <p class="hint">${icon('route', 14)} Sarı kesikli çizgi kuyruğun uzayacağı yolu gösterir. Kasa kapıya çok yakınsa kuyruk kaldırıma taşar; çikolata rafını kuyruk yoluna koyarsan anlık alımlar artar.</p>`;
    } else if (f.def.kind === 'depot') {
      const cap = g.depotCapacity(); const tot = g.backstockTotal();
      body = `<div class="kv"><span>Toplam depo</span><b>${tot} / ${cap}</b></div><div class="bar ${tot / cap > 0.9 ? 'warn' : 'good'}"><div style="width:${(tot / Math.max(1, cap)) * 100}%"></div></div>
        <div class="mini-list">${g.unlockedProducts().filter((p) => g.isStocked(p.id) || g.backstock[p.id]).map((p) => `<div><img src="${this.thumbs.products[p.id]}"/><span>${p.name}</span><b>${g.backstock[p.id]}</b>${g.incoming(p.id) ? `<em>+${g.incoming(p.id)} yolda</em>` : ''}</div>`).join('')}</div>
        <button class="btn ghost small" data-action="panel" data-id="supply">${icon('truck', 14)} Tedarik paneli</button>`;
    } else {
      body = `<p class="hint">${f.def.desc}</p>`;
    }
    const refund = Math.round(f.def.cost * 0.5);
    return `${this.insHead(this.thumbs.fixtures[f.def.id], f.def.name, f.def.category)}
      ${f.statusKind ? `<div class="flag ${ICON_COLOR[f.statusKind]}">${icon(KIND_TO_SVG[f.statusKind], 14)} ${ICON_LABEL[f.statusKind]}</div>` : ''}
      <div class="ins-body">${body}</div>
      <div class="ins-actions"><button class="btn" data-action="move">${icon('move', 15)} Taşı</button><button class="btn" data-action="rotate">${icon('rotate', 15)} Döndür</button><button class="btn danger" data-action="sell">${icon('trash', 15)} Sat +${fmt(refund)}</button></div>`;
  }

  private portrait(a: Customer | Staff) {
    let p = this.portraitCache.get(a.id);
    if (!p) { p = this.thumbs.portrait(a.view.look); this.portraitCache.set(a.id, p); }
    return p;
  }

  private customerInspector(c: Customer) {
    if (!c.shopper) {
      return `${this.insHead(this.portrait(c), c.name, 'Yoldan geçen', true)}<div class="ins-body"><p class="hint">Mahallede yürüyor. Tabelanın, vitrinin ve mağaza puanının onu içeri çekmesi gerekiyor.</p></div>`;
    }
    const a = c.arch!;
    const statusIcon: Record<string, [string, string, string]> = {
      pending: ['clock', 'mute', 'Arıyor'], got: ['check', 'good', 'Sepette'], oos: ['box', 'bad', 'Stok yok'], notfound: ['info', 'violet', 'Satılmıyor'],
      expensive: ['tag', 'warn', 'Pahalı'], budget: ['coin', 'rose', 'Bütçe yetmedi'],
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
        <div class="chips"><span class="chip">${icon('coin', 13)} Bütçe ${fmt(c.budget)}</span><span class="chip">${icon('cart', 13)} Sepet ${fmt(c.spent)}</span><span class="chip">${icon('tag', 13)} Tolerans +%${Math.round(a.priceTolerance * 100)}</span></div>
        ${c.state === 'queue' || c.state === 'toQueue' ? `<div class="kv"><span>Sabır</span><b>${Math.round(c.wait)} / ${Math.round(patience)} sn</b></div><div class="bar ${waitPct > 0.7 ? 'bad' : waitPct > 0.4 ? 'warn' : 'good'}"><div style="width:${(1 - waitPct) * 100}%"></div></div>` : ''}
        <div class="sec-h">Alışveriş listesi</div>${list}${imp}
        <div class="sec-h">Aklından geçenler</div><div class="thoughts">${thoughts}</div>
        <p class="hint small">${esc(a.blurb)}</p>
      </div>`;
  }

  private staffInspector(s: Staff) {
    const g = this.game;
    return `${this.insHead(this.portrait(s), s.name, ROLE_LABEL[s.role], true)}
      <div class="ins-body">
        <div class="big-stat"><div><b>${s.wage ? fmt(s.wage) : '—'}</b><span>günlük maaş</span></div><div><b>${Math.round(s.skill * 100)}</b><span>beceri</span></div></div>
        <div class="kv"><span>Şu an</span><b>${esc(s.activity)}</b></div>
        <p class="hint small">${s.role === 'owner' ? 'Kemal Usta kasaya bakar. Kuyruk yokken ve reyon görevlisi yoksa rafları kendisi doldurur — bu sırada kasa boş kalır.' : s.role === 'stocker' ? 'Depodan koli alıp azalan rafları doldurur, boş kaldığında çöpleri toplar.' : s.role === 'cashier' ? 'Boş bir kasaya geçer ve ödemeleri alır.' : 'Yerlerdeki çöpleri toplar.'}</p>
      </div>
      ${s.role !== 'owner' ? `<div class="ins-actions"><button class="btn danger" data-action="fire">${icon('close', 15)} İşten çıkar</button></div>` : ''}`;
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
      case 'finance': html = this.financePanel(); break;
      case 'growth': html = this.growthPanel(); break;
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
    const cats = ['Teşhir', 'Kasa & Depo', 'Ortam'];
    const tabs = cats.map((c) => `<button class="tab ${this.buildTab === c ? 'on' : ''}" data-action="buildTab" data-id="${c}">${c}</button>`).join('');
    const cards = FIXTURES.filter((f) => f.category === this.buildTab).map((f) => {
      const locked = f.stage > g.stage;
      const poor = g.money < f.cost;
      return `<button class="bcard ${locked ? 'locked' : ''} ${poor ? 'poor' : ''}" data-action="place" data-id="${f.id}" title="${esc(f.desc)}">
        <div class="bimg"><img src="${this.thumbs.fixtures[f.id]}"/>${locked ? `<span class="lock">${icon('lock', 14)} Market</span>` : ''}</div>
        <b>${f.name}</b><span class="bsize">${f.w}×${f.d} m${f.slots ? ` · ${f.slots} bölme` : ''}</span><span class="bprice">${fmt(f.cost)}</span></button>`;
    }).join('');
    return `<div class="build-inner"><div class="tabs">${tabs}</div><div class="bcards">${cards}</div></div>`;
  }

  private accept(pid: string, price: number) {
    const p = PRODUCT_MAP[pid];
    return ARCHETYPES.filter((a) => a.stage <= this.game.stage && a.wants[pid]).map((a) => {
      const ok = price <= p.basePrice * (1 + a.priceTolerance);
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
        <div class="pname"><b>${p.name}</b><span>${DISPLAY_LABEL[p.display]}${p.impulse ? ' · anlık alım' : ''}</span></div>
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
      return `<div class="srow ${stocked ? '' : 'dim'}"><img src="${this.thumbs.products[p.id]}"/><div class="pname"><b>${p.name}</b><span>Toptan ${fmt(p.cost)}/adet</span></div>
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
    const mine = g.staff.map((s) => `<div class="person"><img src="${this.portrait(s)}"/><div><b>${esc(s.name)}</b><span>${ROLE_LABEL[s.role]} · ${esc(s.activity)}</span></div><em>${s.wage ? fmt(s.wage) + '/gün' : 'sahip'}</em>${s.role !== 'owner' ? `<button class="icon-btn ghost" data-action="fire" data-id="${s.id}" title="İşten çıkar">${icon('close', 14)}</button>` : ''}</div>`).join('');
    const cands = g.candidates.map((c, i) => {
      const desc = c.role === 'stocker' ? 'Rafları depodan doldurur, çöpleri toplar.' : c.role === 'cashier' ? (g.fixtures.filter((f) => f.def.kind === 'register').length > 1 ? 'Boştaki kasaya geçer.' : 'Tek kasa varken sahibin yerine geçmez; ikinci kasa için.') : 'Temizlikten sorumlu.';
      return `<div class="cand"><div class="cand-role">${ROLE_LABEL[c.role]}</div><b>${esc(c.name)}</b><div class="skill"><div style="width:${Math.min(100, c.skill * 80)}%"></div></div><span>${desc}</span><button class="btn primary small" data-action="hire" data-i="${i}">İşe al · ${fmt(c.wage)}/gün</button></div>`;
    }).join('');
    return `${this.pHead('Personel', `Günlük maaş toplamı ${fmt(g.wagesPerDay())} — gün sonunda ödenir.`, 'staff')}
      <div class="p-scroll"><div class="sec-h">Ekip</div>${mine}<div class="sec-h">Adaylar <small>her sabah yenilenir</small></div><div class="cands">${cands || '<p class="hint">Bugün başka aday yok.</p>'}</div></div>`;
  }

  private financePanel() {
    const g = this.game;
    const st = g.stats;
    const projCosts = st.purchases + st.other + g.wagesPerDay() + g.rent();
    const net = st.revenue - projCosts;
    const hist = g.history.slice(-8);
    const max = Math.max(100, ...hist.map((h) => Math.max(h.revenue, h.costs)));
    const bars = hist.map((h, i) => {
      const x = 12 + i * 38, hr = (h.revenue / max) * 90, hc = (h.costs / max) * 90;
      return `<g><rect x="${x}" y="${100 - hr}" width="13" height="${hr}" rx="3" class="b-rev"/><rect x="${x + 15}" y="${100 - hc}" width="13" height="${hc}" rx="3" class="b-cost"/><text x="${x + 14}" y="114">G${h.day}</text></g>`;
    }).join('');
    const top = Object.entries(st.soldBy).sort((a, b) => b[1] - a[1]).slice(0, 4).map(([pid, n]) => `<span class="chip"><img src="${this.thumbs.products[pid]}"/>${PRODUCT_MAP[pid].name} ×${n}</span>`).join('') || '<span class="muted">Henüz satış yok</span>';
    const lostMap = [['Kuyruk', st.lostReasons.queue ?? 0], ['Kalabalık', st.lostReasons.crowd ?? 0]] as const;
    return `${this.pHead('Finans', `Gün ${g.day} · ${clock(g.clock)}`, 'chart')}
      <div class="p-scroll">
      <div class="fin-grid">
        <div><span>Satış</span><b class="pos">${fmt(st.revenue)}</b></div>
        <div><span>Mal alımı</span><b>${fmt(st.purchases)}</b></div>
        <div><span>Maaşlar*</span><b>${fmt(g.wagesPerDay())}</b></div>
        <div><span>Kira*</span><b>${fmt(g.rent())}</b></div>
        <div><span>Yatırım</span><b>${fmt(st.other)}</b></div>
        <div class="total"><span>Tahmini net</span><b class="${net >= 0 ? 'pos' : 'neg'}">${fmt(net)}</b></div>
      </div>
      <p class="hint small">* Gün sonunda ödenir.</p>
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
    let exp = '';
    if (g.stage === 0) {
      const goals = g.goals();
      const ready = g.canExpand();
      exp = `<div class="expand ${ready ? 'ready' : ''}">
        <div class="exp-top"><div><div class="kicker">Aşama 2</div><b>${EXPANSION.title}</b></div><span class="exp-cost">${fmt(EXPANSION.cost)}</span></div>
        <p>${EXPANSION.pitch}</p>
        ${goals.map((x) => `<div class="goal-row ${x.done ? 'done' : ''}"><span class="gl">${x.done ? icon('check', 12) : ''} ${x.label}</span><span class="gv">${x.id === 'rating' ? x.value.toFixed(1) : x.id === 'cash' ? fmt(x.value) : Math.floor(x.value)} / ${x.id === 'cash' ? fmt(x.target) : x.target}${x.unit === '★' ? '★' : ''}</span><div class="bar"><div style="width:${Math.min(100, (x.value / x.target) * 100)}%"></div></div></div>`).join('')}
        <div class="unlocks"><span>Açılacaklar:</span> Manav tezgâhı · Orta gondol · Açık soğutucu · 3 kasa · Süt, deterjan, domates, elma · Aile alışverişçileri · Temizlik görevlisi · 2. kapı</div>
        <button class="btn ${ready ? 'primary' : ''} big" data-action="expand" ${ready ? '' : 'disabled'}>${ready ? 'Duvarı yık, marketi aç!' : icon('lock', 15) + ' Hedefler tamamlanınca'}</button></div>`;
    } else {
      exp = `<div class="expand done"><div class="kicker">Aşama 2 tamamlandı</div><b>Mahalle Marketi açık</b><p>Yeni reyonları İnşa panelinden kur, aileler için manav ve süt ürünleri ekle.</p></div>`;
    }
    const road = [
      ['Süpermarket', 'Kasa bantları, reyon kategorileri, fırın & şarküteri, otopark, vardiya sistemi, hırsızlık & güvenlik.'],
      ['Çok Katlı AVM', 'Kiracı mağazalar, yemek katı, eğlence alanı, yürüyen merdiven & asansör, etkinlik takvimi.'],
    ].map(([n, d], i) => `<div class="road"><span class="road-n">${i + 3}</span><div><b>${n} ${icon('lock', 12)}</b><span>${d}</span></div></div>`).join('');
    return `${this.pHead('Gelişim', 'Yükseltmeler ve genişleme', 'arrowUp')}<div class="p-scroll">${exp}<div class="sec-h">Yükseltmeler</div>${ups}<div class="sec-h">Yol haritası <small>henüz uygulanmadı</small></div>${road}</div>`;
  }

  // ------------------------------------------------------------------ day end
  private showDayEnd(r: { day: number; stats: DayStats; costs: number; rating: number; money: number }) {
    this.dayEndOpen = true;
    const st = r.stats;
    const profit = st.revenue - r.costs;
    const insights: string[] = [];
    const missed = Object.entries(st.missed).sort((a, b) => b[1] - a[1])[0];
    if (missed && missed[1] >= 2) insights.push(`${icon('box', 14)} <b>${PRODUCT_MAP[missed[0]].name}</b> ${missed[1]} kez bulunamadı. ${this.game.isStocked(missed[0]) ? 'Stok ve rafa doldurma hızına bak.' : 'Rafa eklemeyi düşün.'}`);
    const exp = Object.entries(st.tooExpensive).sort((a, b) => b[1] - a[1])[0];
    if (exp && exp[1] >= 2) insights.push(`${icon('tag', 14)} <b>${PRODUCT_MAP[exp[0]].name}</b> için ${exp[1]} müşteri “çok pahalı” dedi.`);
    if (st.abandoned >= 2) insights.push(`${icon('clock', 14)} ${st.abandoned} müşteri kuyrukta beklemekten sıkılıp sepeti bıraktı. Hızlı POS veya ikinci kasa düşün.`);
    if ((st.lostReasons.crowd ?? 0) >= 3) insights.push(`${icon('people', 14)} ${st.lostReasons.crowd} kişi kapıdan kalabalık yüzünden döndü.`);
    if (st.impulse >= 3) insights.push(`${icon('sparkle', 14)} Kasa yolundaki raflardan ${st.impulse} anlık alım yapıldı.`);
    if (!insights.length) insights.push(`${icon('heart', 14)} Sakin, dengeli bir gün. Müşteriler memnun.`);
    this.el.modal.innerHTML = `<div class="modal card">
      <div class="modal-kicker">${icon('moon', 16)} Gün ${r.day} kapandı</div>
      <h2 class="${profit >= 0 ? 'pos' : 'neg'}">${profit >= 0 ? '+' : '−'}${fmt(Math.abs(profit))}</h2>
      <div class="modal-sub">günlük net kâr · kasada ${fmt(r.money)}</div>
      <div class="fin-grid">
        <div><span>Satış</span><b class="pos">${fmt(st.revenue)}</b></div><div><span>Mal alımı</span><b>${fmt(st.purchases)}</b></div><div><span>Maaş + kira</span><b>${fmt(st.wages + st.rent)}</b></div>
        <div><span>Ödeyen müşteri</span><b>${st.served}</b></div><div><span>Mutlu ayrılan</span><b class="pos">${st.happyServed}</b></div><div><span>Kaybedilen</span><b class="neg">${st.lost}</b></div>
      </div>
      <div class="modal-rating">${stars(r.rating, 20)} <b>${r.rating.toFixed(2)}</b></div>
      <div class="insights">${insights.map((s) => `<div>${s}</div>`).join('')}</div>
      <button class="btn primary big" data-action="nextDay">Yeni güne başla ${icon('sun', 16)}</button>
    </div>`;
    this.el.modal.classList.add('show');
  }
}
