import '@fontsource/baloo-2/600.css';
import '@fontsource/baloo-2/700.css';
import '@fontsource/baloo-2/800.css';
import '@fontsource-variable/inter';
import './styles.css';
import { Game } from './game';
import { HUD } from './ui/hud';
import { Thumbs } from './ui/thumbs';

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
  const game = new Game(canvas);
  game.init();
  const thumbs = new Thumbs();
  thumbs.build();
  const hud = new HUD(game, thumbs);
  game.paused = true; // until the player presses "Dükkânı Aç"

  const params = new URLSearchParams(location.search);
  if (params.get('q') === 'balanced' || params.get('q') === 'low') game.r.setQuality(params.get('q') as 'balanced' | 'low');
  (window as unknown as { game: Game; hud: HUD }).game = game;
  (window as unknown as { game: Game; hud: HUD }).hud = hud;

  let last = performance.now();
  const loop = (now: number) => {
    const dt = Math.max(0, (now - last) / 1000); last = now;
    game.frame(dt);
    hud.update(dt);
    requestAnimationFrame(loop);
  };
  requestAnimationFrame(loop);
}

boot();
