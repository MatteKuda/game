// Tiny synthesized sound kit (no audio assets needed).
type Sfx = 'coin' | 'click' | 'place' | 'error' | 'fanfare' | 'alert' | 'delivery' | 'dayend';

class SoundKit {
  private ctx: AudioContext | null = null;
  muted = false;
  private last = new Map<string, number>();

  private ac() {
    if (!this.ctx) this.ctx = new AudioContext();
    if (this.ctx.state === 'suspended') this.ctx.resume();
    return this.ctx;
  }

  private tone(freq: number, t0: number, dur: number, type: OscillatorType, vol: number, slide = 0) {
    const ac = this.ac();
    const o = ac.createOscillator(); const g = ac.createGain();
    o.type = type; o.frequency.setValueAtTime(freq, ac.currentTime + t0);
    if (slide) o.frequency.exponentialRampToValueAtTime(freq * slide, ac.currentTime + t0 + dur);
    g.gain.setValueAtTime(0.0001, ac.currentTime + t0);
    g.gain.exponentialRampToValueAtTime(vol, ac.currentTime + t0 + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, ac.currentTime + t0 + dur);
    o.connect(g).connect(ac.destination);
    o.start(ac.currentTime + t0); o.stop(ac.currentTime + t0 + dur + 0.05);
  }

  play(s: Sfx) {
    if (this.muted) return;
    const now = performance.now();
    if (now - (this.last.get(s) ?? 0) < (s === 'coin' ? 90 : 40)) return;
    this.last.set(s, now);
    try {
      switch (s) {
        case 'coin': this.tone(1320, 0, 0.09, 'triangle', 0.05); this.tone(1760, 0.07, 0.16, 'triangle', 0.045); break;
        case 'click': this.tone(900, 0, 0.04, 'square', 0.02); break;
        case 'place': this.tone(220, 0, 0.12, 'sine', 0.12, 0.6); this.tone(660, 0.02, 0.08, 'triangle', 0.03); break;
        case 'error': this.tone(180, 0, 0.18, 'sawtooth', 0.04, 0.8); break;
        case 'alert': this.tone(740, 0, 0.1, 'sine', 0.05); this.tone(560, 0.12, 0.14, 'sine', 0.05); break;
        case 'delivery': this.tone(392, 0, 0.12, 'triangle', 0.05); this.tone(523, 0.12, 0.2, 'triangle', 0.05); break;
        case 'fanfare': [523, 659, 784, 1046].forEach((f, i) => this.tone(f, i * 0.09, 0.25, 'triangle', 0.06)); break;
        case 'dayend': [784, 659, 523].forEach((f, i) => this.tone(f, i * 0.14, 0.3, 'sine', 0.05)); break;
      }
    } catch { /* audio unavailable */ }
  }
}

export const sfx = new SoundKit();
