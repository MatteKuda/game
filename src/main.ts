import '@fontsource/baloo-2/600.css';
import '@fontsource/baloo-2/700.css';
import '@fontsource/baloo-2/800.css';
import '@fontsource-variable/inter';
import './styles.css';
import { Game } from './game';
import { HUD } from './ui/hud';
import { Thumbs } from './ui/thumbs';
import { readSave } from './sim/save';
import { Music, Ambience } from './audio/music';
import { FIXTURE_MAP } from './data/fixtures';
import { audio } from './audio/engine';

async function boot() {
  // Canvas textures use the display font — make sure it is ready before we paint signage.
  try {
    await Promise.all([
      document.fonts.load('800 40px "Baloo 2"'),
      document.fonts.load('700 40px "Baloo 2"'),
      document.fonts.load('600 40px "Baloo 2"'),
    ]);
  } catch { /* fall back to system font */ }

  const canvas = document.getElementById('scene') as HTMLCanvasElement;
  const params = new URLSearchParams(location.search);
  const slot = params.get('load');
  const save = slot ? readSave(slot) : null;
  if (slot) history.replaceState(null, '', location.pathname + (params.get('q') ? '?q=' + params.get('q') : ''));

  const game = new Game(canvas);
  game.init(save);
  const thumbs = new Thumbs();
  thumbs.build();
  const music = new Music();
  const amb = new Ambience();
  const hud = new HUD(game, thumbs, { loaded: !!save, onStart: () => { music.start(); amb.start(); } });
  game.paused = true; // until the player presses "Dükkânı Aç"
  if (params.get('q') === 'balanced' || params.get('q') === 'low') game.r.setQuality(params.get('q') as 'balanced' | 'low');
  (window as unknown as { game: Game; hud: HUD }).game = game;
  (window as unknown as { game: Game; hud: HUD }).hud = hud;
  if (import.meta.env.DEV) Object.assign(window, { FIX: FIXTURE_MAP, AUDIO: audio }); // for scripted tests

  let last = performance.now();
  // Browsers stop requestAnimationFrame in background tabs and throttle timers on the page,
  // so while the tab is hidden a worker's timer (not throttled the same way) keeps the shop running.
  const bgTimer = new Worker(URL.createObjectURL(new Blob(['setInterval(() => postMessage(0), 200);'], { type: 'text/javascript' })));
  bgTimer.onmessage = () => {
    if (!document.hidden) return;
    const now = performance.now();
    let dt = Math.min(2, Math.max(0, (now - last) / 1000)); last = now;
    while (dt > 0) { const step = Math.min(dt, 0.1); game.simulate(step); dt -= step; }
    hud.update(1); // keep the HUD (and the tab title) current
    document.title = `₺${Math.round(game.money).toLocaleString('tr-TR')} · Gün ${game.day} — Tezgâh`;
  };
  const baseTitle = document.title;
  document.addEventListener('visibilitychange', () => { last = performance.now(); if (!document.hidden) document.title = baseTitle; });
  const loop = (now: number) => {
    const dt = Math.max(0, (now - last) / 1000); last = now;
    game.frame(dt);
    hud.update(dt);
    const h = game.hour();
    const crowd = Math.min(1, (game.customersInside() + (game.mall?.visitors.length ?? 0) * 0.5) / 30);
    const halted = game.paused || game.dayEnded;
    music.night = h >= 19.5;
    music.stage = game.stage;
    music.paused = halted;
    music.intensity = 0.45 + crowd * 0.55;
    amb.update(dt, h, crowd, game.cam.farFactor, halted);
    requestAnimationFrame(loop);
  };
  requestAnimationFrame(loop);
}

boot();
