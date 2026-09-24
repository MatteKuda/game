import { audio } from './engine';

/**
 * Generative background music with a light Anatolian-pop flavour:
 * warm keys, a plucked "bağlama"-like lead, soft bass and a düm-tek darbuka groove.
 * Intensity follows the time of day and the store stage; it calms down at night and when paused.
 */

type Mode = { root: number; scale: number[]; bpm: number };

const MAJOR_PENTA = [0, 2, 4, 7, 9];
const HICAZ = [0, 1, 4, 5, 7, 8, 10];
const DORIAN = [0, 2, 3, 5, 7, 9, 10];

// chord progressions as scale-relative semitone offsets of chord roots
const PROG_DAY = [[0, 4, 7], [9, 12, 16], [5, 9, 12], [7, 11, 14]]; // I vi IV V
const PROG_NIGHT = [[0, 3, 7], [5, 8, 12], [10, 14, 17], [7, 10, 14]]; // i iv VII v

const mtof = (m: number) => 440 * Math.pow(2, (m - 69) / 12);

export class Music {
  private timer: number | null = null;
  private nextTime = 0;
  private step = 0; // 16th notes
  private leadPos = 2;
  intensity = 1; // 0 calm .. 1 full band
  night = false;
  paused = false;
  stage = 0;
  enabled = true;

  start() {
    if (this.timer !== null || !audio.ctx) return;
    this.nextTime = audio.ctx.currentTime + 0.1;
    this.timer = window.setInterval(() => this.schedule(), 40);
  }

  stop() { if (this.timer !== null) { clearInterval(this.timer); this.timer = null; } }

  private mode(): Mode {
    if (this.night) return { root: 50, scale: DORIAN, bpm: 76 };
    const bpm = [88, 92, 96, 102][Math.min(3, this.stage)];
    return { root: 50, scale: this.stage >= 2 && (Math.floor(this.step / 64) % 4 === 3) ? HICAZ : MAJOR_PENTA, bpm };
  }

  private schedule() {
    const ctx = audio.ctx; if (!ctx || !this.enabled) return;
    const m = this.mode();
    const sixteenth = 60 / m.bpm / 4;
    while (this.nextTime < ctx.currentTime + 0.25) {
      this.playStep(this.step, this.nextTime, m, sixteenth);
      this.nextTime += sixteenth * (this.step % 2 ? 0.92 : 1.08); // a little swing
      this.step++;
    }
  }

  private playStep(s: number, t: number, m: Mode, dur: number) {
    const bar = Math.floor(s / 16), beat = s % 16;
    const prog = this.night ? PROG_NIGHT : PROG_DAY;
    const chord = prog[Math.floor(bar / 2) % prog.length];
    const calm = this.paused ? 0.35 : 1;
    const inten = this.intensity * calm;
    // keys: chord on bar start + offbeat stabs
    if (beat === 0) for (const n of chord) this.keys(mtof(m.root + 12 + n), t, dur * 14, 0.05 * calm);
    if (!this.night && inten > 0.5 && (beat === 6 || beat === 14)) for (const n of chord) this.keys(mtof(m.root + 24 + n), t, dur * 1.6, 0.022 * inten);
    // bass
    if (beat === 0 || beat === 8 || (!this.night && beat === 11)) this.bass(mtof(m.root - 12 + chord[0] + (beat === 11 ? 7 : 0)), t, dur * (beat === 11 ? 2 : 5), 0.12 * calm);
    // darbuka: düm . . tek . tek düm . tek . . .
    if (!this.night && inten > 0.3) {
      const pattern = 'D..T.TD.T...T.T.';
      const c = pattern[beat];
      if (c === 'D') this.dum(t, 0.18 * inten);
      else if (c === 'T') this.tek(t, 0.07 * inten);
      if (inten > 0.7 && beat % 2 === 1) this.shaker(t, 0.02 * inten);
    }
    // plucked lead: random walk over the scale, phrases every other bar
    const phrase = bar % 4 < 2 || this.night;
    const hit = this.night ? beat % 4 === 0 && Math.random() < 0.55 : [0, 3, 6, 8, 10, 12, 14].includes(beat) && Math.random() < 0.62;
    if (phrase && hit && inten > 0.2) {
      this.leadPos += Math.floor(Math.random() * 5) - 2;
      this.leadPos = Math.max(0, Math.min(m.scale.length * 2 - 1, this.leadPos));
      const oct = Math.floor(this.leadPos / m.scale.length), deg = this.leadPos % m.scale.length;
      const midi = m.root + 24 + oct * 12 + m.scale[deg];
      this.pluck(mtof(midi), t, 0.055 * calm);
      if (!this.night && Math.random() < 0.18) this.pluck(mtof(midi), t + dur * 0.5, 0.035 * calm); // tremolo-ish double pick
    }
  }

  private env(g: GainNode, t: number, a: number, peak: number, d: number) {
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(Math.max(0.0002, peak), t + a);
    g.gain.exponentialRampToValueAtTime(0.0001, t + a + d);
  }

  private keys(f: number, t: number, len: number, v: number) {
    const ctx = audio.ctx!;
    const o = ctx.createOscillator(), o2 = ctx.createOscillator(), g = ctx.createGain(), lp = ctx.createBiquadFilter();
    o.type = 'triangle'; o2.type = 'sine'; o.frequency.value = f; o2.frequency.value = f * 2.002;
    lp.type = 'lowpass'; lp.frequency.value = 1400;
    this.env(g, t, 0.03, v, len);
    o.connect(lp); o2.connect(lp); lp.connect(g).connect(audio.music);
    o.start(t); o2.start(t); o.stop(t + len + 0.1); o2.stop(t + len + 0.1);
  }

  private bass(f: number, t: number, len: number, v: number) {
    const ctx = audio.ctx!;
    const o = ctx.createOscillator(), g = ctx.createGain();
    o.type = 'sine'; o.frequency.value = f;
    this.env(g, t, 0.01, v, len);
    o.connect(g).connect(audio.music);
    o.start(t); o.stop(t + len + 0.05);
  }

  private pluck(f: number, t: number, v: number) {
    // bright saw through a resonant filter with a quick decay and a tiny pitch drop = plucked string
    const ctx = audio.ctx!;
    const o = ctx.createOscillator(), g = ctx.createGain(), bp = ctx.createBiquadFilter();
    o.type = 'sawtooth';
    o.frequency.setValueAtTime(f * 1.01, t); o.frequency.exponentialRampToValueAtTime(f, t + 0.05);
    bp.type = 'lowpass'; bp.Q.value = 6;
    bp.frequency.setValueAtTime(f * 6, t); bp.frequency.exponentialRampToValueAtTime(f * 1.5, t + 0.35);
    this.env(g, t, 0.004, v, 0.55);
    o.connect(bp).connect(g).connect(audio.music);
    o.start(t); o.stop(t + 0.65);
  }

  private dum(t: number, v: number) {
    const ctx = audio.ctx!;
    const o = ctx.createOscillator(), g = ctx.createGain();
    o.type = 'sine'; o.frequency.setValueAtTime(150, t); o.frequency.exponentialRampToValueAtTime(58, t + 0.18);
    this.env(g, t, 0.004, v, 0.28);
    o.connect(g).connect(audio.music); o.start(t); o.stop(t + 0.35);
  }

  private tek(t: number, v: number) {
    const ctx = audio.ctx!;
    const n = ctx.createBufferSource(); n.buffer = audio.noise();
    const bp = ctx.createBiquadFilter(); bp.type = 'bandpass'; bp.frequency.value = 2400; bp.Q.value = 1.6;
    const g = ctx.createGain(); this.env(g, t, 0.002, v, 0.07);
    const o = ctx.createOscillator(); o.type = 'triangle'; o.frequency.value = 720;
    const g2 = ctx.createGain(); this.env(g2, t, 0.002, v * 0.6, 0.05);
    n.connect(bp).connect(g).connect(audio.music); o.connect(g2).connect(audio.music);
    n.start(t, Math.random()); n.stop(t + 0.1); o.start(t); o.stop(t + 0.08);
  }

  private shaker(t: number, v: number) {
    const ctx = audio.ctx!;
    const n = ctx.createBufferSource(); n.buffer = audio.noise();
    const hp = ctx.createBiquadFilter(); hp.type = 'highpass'; hp.frequency.value = 6000;
    const g = ctx.createGain(); this.env(g, t, 0.005, v, 0.05);
    n.connect(hp).connect(g).connect(audio.music); n.start(t, Math.random()); n.stop(t + 0.08);
  }
}

/** street + store ambience layers */
export class Ambience {
  private street: GainNode | null = null;
  private crowd: GainNode | null = null;
  private crowdLfo: OscillatorNode | null = null;
  private acc = 0;
  private nextCar = 4;
  private nextBird = 2;
  private nextCricket = 1;

  start() {
    const ctx = audio.ctx; if (!ctx || this.street) return;
    const mk = (freq: number, type: BiquadFilterType, q: number) => {
      const src = ctx.createBufferSource(); src.buffer = audio.noise(); src.loop = true;
      const f = ctx.createBiquadFilter(); f.type = type; f.frequency.value = freq; f.Q.value = q;
      const g = ctx.createGain(); g.gain.value = 0;
      src.connect(f).connect(g).connect(audio.amb); src.start();
      return g;
    };
    this.street = mk(380, 'lowpass', 0.3);
    this.crowd = mk(650, 'bandpass', 0.7);
    this.crowdLfo = ctx.createOscillator(); this.crowdLfo.frequency.value = 0.35;
    const depth = ctx.createGain(); depth.gain.value = 0.004;
    this.crowdLfo.connect(depth).connect(this.crowd.gain); this.crowdLfo.start();
  }

  /** hour 0..24, crowd 0..1 (people inside), zoom 0 close .. 1 far */
  update(dt: number, hour: number, crowd: number, zoom: number, paused: boolean) {
    const ctx = audio.ctx; if (!ctx || !this.street || !this.crowd) return;
    const t = ctx.currentTime;
    const dayK = hour > 6.5 && hour < 21 ? 1 : 0.45;
    this.street.gain.setTargetAtTime((0.045 + zoom * 0.03) * dayK, t, 0.5);
    this.crowd.gain.setTargetAtTime(paused ? 0 : 0.004 + crowd * 0.03 * (1 - zoom * 0.6), t, 0.6);
    if (paused) return;
    this.acc += dt;
    if (this.acc > this.nextCar) { this.acc = 0; this.nextCar = 6 + Math.random() * 12; this.carPass(); }
    this.nextBird -= dt;
    if (hour > 6.5 && hour < 11 && this.nextBird <= 0) { this.nextBird = 1.5 + Math.random() * 4; this.chirp(); }
    this.nextCricket -= dt;
    if ((hour > 20.5 || hour < 6) && this.nextCricket <= 0) { this.nextCricket = 0.6 + Math.random() * 1.2; this.cricket(); }
  }

  private carPass() {
    const ctx = audio.ctx!; const t = ctx.currentTime;
    const n = ctx.createBufferSource(); n.buffer = audio.noise();
    const f = ctx.createBiquadFilter(); f.type = 'bandpass'; f.Q.value = 0.8;
    f.frequency.setValueAtTime(220, t); f.frequency.linearRampToValueAtTime(520, t + 1.2); f.frequency.linearRampToValueAtTime(260, t + 2.6);
    const g = ctx.createGain(); g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.06, t + 1.2); g.gain.exponentialRampToValueAtTime(0.0001, t + 2.8);
    const pan = ctx.createStereoPanner(); pan.pan.setValueAtTime(-0.8, t); pan.pan.linearRampToValueAtTime(0.8, t + 2.8);
    n.connect(f).connect(g).connect(pan).connect(audio.amb); n.start(t, Math.random()); n.stop(t + 3);
  }

  private chirp() {
    const ctx = audio.ctx!; let t = ctx.currentTime;
    const base = 2600 + Math.random() * 1600;
    const pan = ctx.createStereoPanner(); pan.pan.value = Math.random() * 2 - 1; pan.connect(audio.amb);
    for (let i = 0; i < 2 + Math.floor(Math.random() * 3); i++) {
      const o = ctx.createOscillator(), g = ctx.createGain();
      o.frequency.setValueAtTime(base, t); o.frequency.exponentialRampToValueAtTime(base * 1.35, t + 0.07);
      g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.012, t + 0.01); g.gain.exponentialRampToValueAtTime(0.0001, t + 0.09);
      o.connect(g).connect(pan); o.start(t); o.stop(t + 0.1);
      t += 0.12 + Math.random() * 0.05;
    }
  }

  private cricket() {
    const ctx = audio.ctx!; let t = ctx.currentTime;
    for (let i = 0; i < 3; i++) {
      const o = ctx.createOscillator(), g = ctx.createGain();
      o.frequency.value = 4400; o.type = 'triangle';
      g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.006, t + 0.01); g.gain.exponentialRampToValueAtTime(0.0001, t + 0.05);
      o.connect(g).connect(audio.amb); o.start(t); o.stop(t + 0.06);
      t += 0.07;
    }
  }
}
