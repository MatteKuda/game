class_name GameAudio
extends Node
## All sound is synthesised at start-up (no audio files): short effects, two looping music beds
## (day and evening, rendered on a worker thread) and street / crowd / rain / wind ambience.

const RATE := 22050
static var I: GameAudio

var sfx: Dictionary = {} # name -> AudioStreamWAV
var players: Array[AudioStreamPlayer] = []
var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var amb_street: AudioStreamPlayer
var amb_crowd: AudioStreamPlayer
var amb_rain: AudioStreamPlayer
var amb_wind: AudioStreamPlayer
var weather := "gunes" # set by the game each frame; rain and wind loops follow it
var _thunder_t := 20.0
var _music := {} # "day" / "evening" -> AudioStreamWAV
var _cur_music := ""
var _last := {}
var _task := -1
var _rendered := {}

func _ready() -> void:
	I = self
	Settings.ensure_buses()
	for i in 10:
		var p := AudioStreamPlayer.new(); p.bus = "SFX"; add_child(p); players.append(p)
	music_a = _player("Music"); music_b = _player("Music")
	amb_street = _player("Ambience"); amb_crowd = _player("Ambience")
	amb_rain = _player("Ambience"); amb_wind = _player("Ambience")
	_build_sfx()
	amb_street.stream = _loop(_street_noise(6.0)); amb_street.volume_db = -14.0; amb_street.play()
	amb_crowd.stream = _loop(_crowd_noise(5.0)); amb_crowd.volume_db = -60.0; amb_crowd.play()
	amb_rain.stream = _loop(_rain_noise(4.0)); amb_rain.volume_db = -60.0; amb_rain.play()
	amb_wind.stream = _loop(_wind_noise(7.0)); amb_wind.volume_db = -60.0; amb_wind.play()
	_task = WorkerThreadPool.add_task(_render_music)

func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new(); p.bus = bus; add_child(p); return p

static func play(name: String, vol_db := 0.0, throttle := 0.06) -> void:
	if I == null or not I.sfx.has(name): return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(I._last.get(name, -10.0)) < throttle: return
	I._last[name] = now
	for p in I.players:
		if not p.playing:
			p.stream = I.sfx[name]; p.volume_db = vol_db; p.pitch_scale = randf_range(0.97, 1.03); p.play(); return

## called every frame by the game: crossfades day/evening music, crowd murmur follows how busy it is
func update(dt: float, hour: float, busy: float, paused: bool) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task); _task = -1
		for k in _rendered: _music[k] = _loop(_rendered[k])
	var want := "evening" if hour >= 18.5 or hour < 7.0 else "day"
	if _music.has(want) and want != _cur_music:
		_cur_music = want
		var nxt := music_b if music_a.playing and music_a.volume_db > -30.0 else music_a
		var old := music_a if nxt == music_b else music_b
		nxt.stream = _music[want]; nxt.volume_db = -40.0; nxt.play()
		var tw := create_tween(); tw.set_parallel(true)
		tw.tween_property(nxt, "volume_db", -9.0, 3.0)
		if old.playing: tw.tween_property(old, "volume_db", -60.0, 3.0)
	var target := lerpf(-38.0, -12.0, clampf(busy, 0.0, 1.0)) if not paused else -45.0
	amb_crowd.volume_db = lerpf(amb_crowd.volume_db, target, minf(1.0, dt * 1.5))
	# weather beds fade in and out over a couple of seconds
	var rain_db := -13.0 if weather == "yagmur" else -60.0
	var wind_db := -15.0 if weather == "kar" else (-26.0 if weather in ["bulut", "yagmur"] else -60.0)
	amb_rain.volume_db = lerpf(amb_rain.volume_db, rain_db, minf(1.0, dt * 0.6))
	amb_wind.volume_db = lerpf(amb_wind.volume_db, wind_db, minf(1.0, dt * 0.6))
	if weather == "yagmur" and not paused:
		_thunder_t -= dt
		if _thunder_t <= 0.0:
			_thunder_t = randf_range(35.0, 90.0)
			play("thunder", randf_range(-14.0, -6.0), 5.0)

# ------------------------------------------------------------------ synthesis helpers
func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var buf := PackedByteArray(); buf.resize(samples.size() * 2)
	for i in samples.size(): buf.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.stereo = false; w.data = buf
	return w

func _loop(samples: PackedFloat32Array) -> AudioStreamWAV:
	var w := _wav(samples)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_begin = 0; w.loop_end = samples.size()
	return w

func _tone(freqs: Array, dur: float, decay: float, amp := 0.5, harm := 0.3, attack := 0.004) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array(); out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / attack) * exp(-t * decay)
		var v := 0.0
		for f in freqs: v += sin(TAU * f * t) + harm * sin(TAU * f * 2.0 * t)
		out[i] = v / freqs.size() * env * amp
	return out

func _cat(parts: Array, gap := 0.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
		if gap > 0.0:
			var z := PackedFloat32Array(); z.resize(int(gap * RATE)); out.append_array(z)
	return out

func _mix(a: PackedFloat32Array, b: PackedFloat32Array, offset := 0.0) -> PackedFloat32Array:
	var o := int(offset * RATE)
	var out := a.duplicate(); out.resize(maxi(a.size(), b.size() + o))
	for i in b.size(): out[i + o] += b[i]
	return out

func _build_sfx() -> void:
	# cash register: drawer click + two bright bells
	var click := PackedFloat32Array(); click.resize(int(0.03 * RATE))
	for i in click.size(): click[i] = randf_range(-1, 1) * exp(-float(i) / RATE * 120.0) * 0.4
	sfx["cash"] = _wav(_mix(_mix(click, _tone([1318.5], 0.45, 9.0, 0.35, 0.2), 0.03), _tone([1760.0, 2637.0], 0.6, 7.0, 0.3, 0.1), 0.1))
	sfx["pop"] = _wav(_sweep(520.0, 900.0, 0.07, 0.35))
	sfx["ui"] = _wav(_tone([1900.0], 0.03, 90.0, 0.25, 0.0, 0.001))
	var thud := _tone([110.0, 165.0], 0.22, 18.0, 0.7, 0.4)
	for i in 600: thud[i] += randf_range(-1, 1) * exp(-float(i) / RATE * 60.0) * 0.25
	sfx["place"] = _wav(thud)
	sfx["bell"] = _wav(_cat([_tone([987.8], 0.4, 5.0, 0.35, 0.15), _tone([783.99], 0.7, 4.0, 0.35, 0.15)]))
	sfx["coin"] = _wav(_cat([_tone([1567.98], 0.06, 30.0, 0.3), _tone([2093.0], 0.18, 18.0, 0.3)]))
	sfx["good"] = _wav(_cat([_tone([523.25], 0.1, 12.0, 0.3), _tone([659.25], 0.1, 12.0, 0.3), _tone([783.99], 0.35, 6.0, 0.32)]))
	sfx["bad"] = _wav(_square(196.0, 0.22, 10.0, 0.18))
	var al := PackedFloat32Array()
	for k in 6: al.append_array(_square(880.0 if k % 2 == 0 else 660.0, 0.16, 1.0, 0.16))
	sfx["alarm"] = _wav(al)
	sfx["slip"] = _wav(_sweep(900.0, 260.0, 0.35, 0.3))
	sfx["whoosh"] = _wav(_noise_burst(0.35, 0.25))
	sfx["meow"] = _wav(_meow())
	sfx["purr"] = _wav(_purr(1.2))
	sfx["jingle"] = _wav(_jingle())
	sfx["whistle"] = _wav(_cat([_vib_tone(2600.0, 0.12, 0.28), _vib_tone(2600.0, 0.45, 0.28)], 0.05))
	sfx["thunder"] = _wav(_thunder(2.6))
	sfx["paper"] = _wav(_scribble())
	sfx["door"] = _wav(_mix(_tone([1318.5, 1975.5], 0.5, 6.0, 0.22, 0.25), _tone([1661.2], 0.45, 7.0, 0.18, 0.2), 0.07))
	sfx["levelup"] = _wav(_cat([_tone([523.25, 659.25], 0.12, 10.0, 0.28), _tone([659.25, 783.99], 0.12, 10.0, 0.28), _tone([783.99, 1046.5], 0.12, 10.0, 0.28), _tone([1046.5, 1318.5, 1567.98], 0.8, 3.5, 0.3, 0.2)]))

## a cat: a nasal vowel gliding up and down ("mi-yaav")
func _meow() -> PackedFloat32Array:
	var dur := 0.62
	var n := int(dur * RATE)
	var out := PackedFloat32Array(); out.resize(n)
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		var f := 520.0 + 380.0 * sin(PI * pow(k, 0.7)) + 12.0 * sin(float(i) / RATE * TAU * 6.0)
		ph += TAU * f / RATE
		var env := minf(1.0, k * 14.0) * pow(1.0 - k, 0.8)
		# odd-heavy harmonics with a moving "mouth" filter make it sound like a voice
		var open := sin(PI * minf(1.0, k * 1.4))
		out[i] = (sin(ph) + 0.55 * open * sin(ph * 2.0) + 0.4 * sin(ph * 3.0) + 0.2 * open * sin(ph * 4.0)) * env * 0.16
	return out

func _purr(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array(); out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (randf_range(-1, 1) - lp) * 0.08
		var pulse := pow(maxf(0.0, sin(t * TAU * 24.0)), 3.0)
		out[i] = lp * pulse * 1.6 * sin(PI * t / dur)
	return out

## the neighbourhood radio: a crackle, then a bright three-note station chime
func _jingle() -> PackedFloat32Array:
	var crack := PackedFloat32Array(); crack.resize(int(0.35 * RATE))
	for i in crack.size():
		var k := float(i) / crack.size()
		crack[i] = (randf_range(-1, 1) * 0.05 + (randf_range(-1, 1) * 0.35 if randf() < 0.004 else 0.0)) * (1.0 - k * 0.5)
	var notes := _cat([_tone([783.99, 1567.98], 0.16, 8.0, 0.26, 0.35), _tone([987.77, 1975.5], 0.16, 8.0, 0.26, 0.35), _tone([1174.66, 1567.98, 2349.3], 0.7, 3.5, 0.28, 0.3)], 0.02)
	# a touch of AM-radio wobble on the chime
	for i in notes.size(): notes[i] *= 0.85 + 0.15 * sin(float(i) / RATE * TAU * 5.0)
	return _mix(crack, notes, 0.18)

func _vib_tone(f: float, dur: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array(); out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * (f + 90.0 * sin(t * TAU * 38.0)) / RATE
		out[i] = sin(ph) * amp * minf(1.0, t * 80.0) * minf(1.0, (dur - t) * 40.0)
	return out

func _thunder(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array(); out.resize(n)
	var a := 0.0; var b := 0.0
	for i in n:
		var t := float(i) / RATE
		a += (randf_range(-1, 1) - a) * 0.03
		b += (a - b) * 0.05
		var env := minf(1.0, t * 6.0) * exp(-t * 1.4) * (0.7 + 0.3 * sin(t * 7.0) * sin(t * 2.3))
		out[i] = b * env * 7.0
	return out

func _scribble() -> PackedFloat32Array:
	var n := int(0.45 * RATE)
	var out := PackedFloat32Array(); out.resize(n)
	var hp := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := randf_range(-1, 1)
		var v := x - hp; hp = x * 0.6 + hp * 0.4
		out[i] = v * 0.12 * (0.5 + 0.5 * sin(t * TAU * 11.0)) * sin(PI * t / 0.45)
	return out

## steady rain: bright hiss with scattered drops on the awning
func _rain_noise(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array(); out.resize(n)
	var lp := 0.0; var lp2 := 0.0
	for i in n:
		var x := randf_range(-1, 1)
		lp += (x - lp) * 0.5
		lp2 += (lp - lp2) * 0.04
		out[i] = (lp - lp2) * 0.35
	for k in int(dur * 60):
		var at := randi() % n
		var f := randf_range(1800.0, 4200.0)
		var a := randf_range(0.02, 0.07)
		for j in 220:
			if at + j >= n: break
			out[at + j] += sin(float(j) / RATE * TAU * f) * a * exp(-float(j) / RATE * 180.0)
	for i in 2000:
		var k := float(i) / 2000.0
		out[i] = out[i] * k + out[n - 2000 + i] * (1.0 - k)
	return out

## wind: low noise swelling and whistling slowly
func _wind_noise(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array(); out.resize(n)
	var a := 0.0; var b := 0.0
	for i in n:
		var t := float(i) / RATE
		var gust := 0.45 + 0.35 * sin(t * TAU / dur) + 0.2 * sin(t * TAU * 2.0 / dur + 1.3)
		var cut := 0.01 + 0.03 * gust
		a += (randf_range(-1, 1) - a) * cut
		b += (a - b) * cut
		out[i] = b * gust * 6.0
	for i in 3000:
		var k := float(i) / 3000.0
		out[i] = out[i] * k + out[n - 3000 + i] * (1.0 - k)
	return out

func _sweep(f0: float, f1: float, dur: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array(); out.resize(n)
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		ph += TAU * lerpf(f0, f1, k) / RATE
		out[i] = sin(ph) * amp * sin(PI * k)
	return out

func _square(f: float, dur: float, decay: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array(); out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = (1.0 if fmod(t * f, 1.0) < 0.5 else -1.0) * amp * exp(-t * decay) * minf(1.0, t * 200.0)
	return out

func _noise_burst(dur: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array(); out.resize(n)
	var lp := 0.0
	for i in n:
		lp += (randf_range(-1, 1) - lp) * 0.15
		out[i] = lp * amp * sin(PI * float(i) / n) * 3.0
	return out

## soft traffic rumble + the odd bird
func _street_noise(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array(); out.resize(n)
	var b := 0.0
	for i in n:
		b = b * 0.995 + randf_range(-1, 1) * 0.02
		out[i] = b * 0.9
	for k in 4:
		var at := int(randf_range(0.2, dur - 0.5) * RATE)
		var chirp := _sweep(3200.0, 4200.0, 0.08, 0.05)
		for j in 2:
			for i in chirp.size():
				var idx := at + j * int(0.12 * RATE) + i
				if idx < n: out[idx] += chirp[i]
	# smooth loop seam
	for i in 2000:
		var k := float(i) / 2000.0
		out[i] = out[i] * k + out[n - 2000 + i] * (1.0 - k)
	return out

## many voices far away: band-limited noise with slow syllable-rate wobble
func _crowd_noise(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array(); out.resize(n)
	var a := 0.0; var b := 0.0
	for i in n:
		var t := float(i) / RATE
		a += (randf_range(-1, 1) - a) * 0.25
		b += (a - b) * 0.2
		var wob := 0.6 + 0.25 * sin(t * 9.0) * sin(t * 3.7) + 0.15 * sin(t * 13.3)
		out[i] = (a - b) * wob * 0.9
	for i in 2000:
		var k := float(i) / 2000.0
		out[i] = out[i] * k + out[n - 2000 + i] * (1.0 - k)
	return out

# ------------------------------------------------------------------ music (worker thread)
func _render_music() -> void:
	_rendered["day"] = _song(96.0, [[0, 4, 7, 11], [9, 12, 16, 19], [2, 5, 9, 12], [7, 11, 14, 17]], 60, false)
	_rendered["evening"] = _song(78.0, [[5, 9, 12, 16], [4, 7, 11, 14], [2, 5, 9, 12], [0, 4, 7, 11]], 57, true)

## 8 bars: electric-piano chords, walking bass, soft shaker; midi root = key
func _song(bpm: float, prog: Array, key: int, soft: bool) -> PackedFloat32Array:
	var beat := 60.0 / bpm
	var bars := 8
	var n := int(bars * 4 * beat * RATE)
	var out := PackedFloat32Array(); out.resize(n)
	var mtof := func(m: float) -> float: return 440.0 * pow(2.0, (m - 69.0) / 12.0)
	var rng := RandomNumberGenerator.new(); rng.seed = 7 if soft else 3
	for bar in bars:
		var ch: Array = prog[bar % prog.size()]
		var t0 := bar * 4 * beat
		# chord stabs on 1 and the "and" of 2
		for hit in ([0.0, 1.5, 3.0] if not soft else [0.0, 2.0]):
			var s := int((t0 + hit * beat) * RATE)
			var len := int(beat * (1.6 if not soft else 2.4) * RATE)
			for note in ch:
				var f: float = mtof.call(key + note)
				for i in len:
					var idx := s + i
					if idx >= n: break
					var t := float(i) / RATE
					var env := minf(1.0, t / 0.01) * exp(-t * (2.2 if not soft else 1.2))
					out[idx] += (sin(TAU * f * t) + 0.35 * sin(TAU * f * 2.0 * t) * exp(-t * 6.0)) * env * 0.045
		# bass: root, fifth, octave, approach
		var root: int = key - 24 + int(ch[0])
		var line := [root, root + 7, root + 12, root + 7]
		for bi in 4:
			var s2 := int((t0 + bi * beat) * RATE)
			var f2: float = mtof.call(float(line[bi]))
			var len2 := int(beat * 0.9 * RATE)
			for i in len2:
				var idx2 := s2 + i
				if idx2 >= n: break
				var t2 := float(i) / RATE
				out[idx2] += sin(TAU * f2 * t2) * minf(1.0, t2 / 0.01) * exp(-t2 * 3.0) * 0.16
		# melody: a few pentatonic notes over the bar
		if bar % 2 == 1 or soft:
			var pent := [0, 2, 4, 7, 9, 12, 14]
			for m in 3:
				var s3 := int((t0 + (m * 1.25 + 0.5) * beat) * RATE)
				var f3: float = mtof.call(key + 12 + pent[rng.randi() % pent.size()])
				var len3 := int(beat * 0.8 * RATE)
				for i in len3:
					var idx3 := s3 + i
					if idx3 >= n: break
					var t3 := float(i) / RATE
					out[idx3] += sin(TAU * f3 * t3 + 0.6 * sin(TAU * f3 * 2.0 * t3)) * minf(1.0, t3 / 0.008) * exp(-t3 * 4.0) * 0.05
		# shaker on eighths
		if not soft:
			for e in 8:
				var s4 := int((t0 + e * beat * 0.5) * RATE)
				for i in 700:
					var idx4 := s4 + i
					if idx4 >= n: break
					out[idx4] += rng.randf_range(-1, 1) * exp(-float(i) / RATE * 70.0) * (0.03 if e % 2 else 0.018)
	return out
