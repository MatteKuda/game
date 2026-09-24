// Shared WebAudio graph: master -> {music, sfx, ambience} buses. Everything is synthesized (no audio files).

export interface Volumes { master: number; music: number; sfx: number; ambience: number }

const SETTINGS_KEY = 'tezgah.audio';

class AudioEngine {
  ctx: AudioContext | null = null;
  master!: GainNode;
  music!: GainNode;
  sfx!: GainNode;
  amb!: GainNode;
  vol: Volumes = { master: 0.8, music: 0.55, sfx: 0.8, ambience: 0.6 };
  private noiseBuf: AudioBuffer | null = null;

  constructor() {
    try { const s = localStorage.getItem(SETTINGS_KEY); if (s) Object.assign(this.vol, JSON.parse(s)); } catch { /* ignore */ }
  }

  get ready() { return !!this.ctx; }

  /** must be called from a user gesture */
  unlock() {
    if (!this.ctx) {
      const AC = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      if (!AC) return;
      this.ctx = new AC();
      this.master = this.ctx.createGain();
      const comp = this.ctx.createDynamicsCompressor();
      comp.threshold.value = -14; comp.ratio.value = 3;
      const makeup = this.ctx.createGain(); makeup.gain.value = 2.6; // synth voices are mixed conservatively; lift the bus after the compressor
      this.master.connect(comp).connect(makeup).connect(this.ctx.destination);
      this.music = this.ctx.createGain(); this.sfx = this.ctx.createGain(); this.amb = this.ctx.createGain();
      this.music.connect(this.master); this.sfx.connect(this.master); this.amb.connect(this.master);
      this.applyVolumes();
    }
    if (this.ctx.state === 'suspended') this.ctx.resume();
  }

  setVolume(k: keyof Volumes, v: number) {
    this.vol[k] = Math.max(0, Math.min(1, v));
    this.applyVolumes();
    try { localStorage.setItem(SETTINGS_KEY, JSON.stringify(this.vol)); } catch { /* ignore */ }
  }

  applyVolumes() {
    if (!this.ctx) return;
    const t = this.ctx.currentTime;
    this.master.gain.setTargetAtTime(this.vol.master, t, 0.05);
    this.music.gain.setTargetAtTime(this.vol.music * 0.75, t, 0.05);
    this.sfx.gain.setTargetAtTime(this.vol.sfx, t, 0.05);
    this.amb.gain.setTargetAtTime(this.vol.ambience * 0.8, t, 0.05);
  }

  noise() {
    if (this.noiseBuf || !this.ctx) return this.noiseBuf!;
    const len = this.ctx.sampleRate * 2;
    const b = this.ctx.createBuffer(1, len, this.ctx.sampleRate);
    const d = b.getChannelData(0);
    let last = 0;
    for (let i = 0; i < len; i++) { const w = Math.random() * 2 - 1; last = (last + 0.02 * w) / 1.02; d[i] = last * 3.5 * 0.5 + w * 0.5 * 0.3; }
    this.noiseBuf = b;
    return b;
  }
}

export const audio = new AudioEngine();
