extends SceneTree
## Composes and renders Vertical Billiard's four pool-hall jazz loops to
## assets/audio/music/*.wav (mono, 22.05 kHz, seamless).
##   godot --headless --path <project> --script tools/build_music.gd
##
## Instruments are synthesised per note:
##   Rhodes  - two-operator FM (index falls fast: bright bark, mellow body)
##   bass    - upright: sine + 2nd/3rd partials, plucked envelope, finger thump
##   vibes   - sine + 4th partial with motor tremolo
##   strings - detuned partial stacks with slow swells (waltz, summit)
##   kit     - brush swishes and taps, swung ride (inharmonic modes), soft kick
## Swing: off-beat 8ths land two-thirds of the way through the beat.
## The room reverb's tail is wrapped back onto the start, so loops are seamless.
##
## Tracks (one per zone):
##   backroom - "Back Room Blues": 76 BPM, D minor ii-V-i, Rhodes + walking bass + brushes
##   neonbar  - "Neon Shuffle": 108 BPM, 12-bar blues in F, vibes riff, shuffle kit
##   royal    - "Royal Waltz": 3/4 at 132 BPM, C major, strings + music-box vibes
##   summit   - "Moon Over the Table": 60 BPM, floating pads and a sparse Rhodes motif
##   moon     - "Felt of Tranquility": 54 BPM, weightless strings and far-apart vibes
##   storm    - "Rooftop Gale": 92 BPM, E minor, restless walking bass and brushes

const RATE := 22050
const OUT := "res://assets/audio/music/"
const TAIL := 3.0

var buf := PackedFloat32Array()
var beat := 0.5
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var t0 := Time.get_ticks_msec()
	_backroom()
	_neonbar()
	_royal()
	_summit()
	_moon()
	_storm()
	print("music baked in %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit()


# --- Tracks ---------------------------------------------------------------------------

func _backroom() -> void:
	rng.seed = 11
	_start(76.0, 16 * 4)
	# Rootless jazz voicings (midi) and the bass root for each bar.
	var chords := [
		[[55, 58, 62, 64], 40], [[55, 58, 61, 64], 33], [[53, 57, 60, 64], 38], [[53, 57, 60, 62], 38],
		[[53, 58, 62, 65], 43], [[52, 58, 62, 64], 36], [[52, 57, 60, 64], 41], [[55, 58, 61, 64], 33],
	]
	var melody := [
		[[0, 1.5, 76], [1.5, 0.5, 74], [2, 2, 70]],
		[[0, 1, 73], [1, 1, 76], [2, 2, 79]],
		[[0, 3, 77], [3, 1, 76]],
		[[0, 4, 74]],
		[[0, 1.5, 74], [1.5, 0.5, 77], [2, 1, 79], [3, 1, 81]],
		[[0, 2, 82], [2, 1, 81], [3, 1, 79]],
		[[0, 3, 77], [3, 1, 76]],
		[[0, 2, 73], [2, 2, 69]],
	]
	for bar in 16:
		var t := bar * 4 * beat
		var ch: Array = chords[bar % 8]
		var next_root: int = chords[(bar + 1) % 8][1]
		_comp(t, ch[0], [0.0, 1.667] if bar % 2 == 0 else [0.0, 2.667], 0.32)
		_walk(t, ch[1], next_root, 4, 0.75)
		_brushes(t, 4, 0.55)
		if bar >= 8:
			for n in melody[bar - 8]:
				_vibes(t + n[0] * beat, n[2], n[1] * beat, 0.42)
	_finish("music_backroom")


func _neonbar() -> void:
	rng.seed = 22
	_start(108.0, 24 * 4)
	var f7 := [[57, 63, 67, 69], 41]
	var bb7 := [[56, 62, 65, 68], 46]
	var c7 := [[52, 58, 62, 64], 36]
	var form := [f7, bb7, f7, f7, bb7, bb7, f7, f7, c7, bb7, f7, c7]
	var riff := [[0, 0.667, 72], [0.667, 0.333, 75], [1, 1, 77], [2.667, 0.333, 75], [3, 1, 72]]
	for bar in 24:
		var t := bar * 4 * beat
		var ch: Array = form[bar % 12]
		var next_root: int = form[(bar + 1) % 12][1]
		_comp(t, ch[0], [1.667, 3.667], 0.3)
		_walk(t, ch[1], next_root, 4, 0.85)
		_shuffle_kit(t, 0.7)
		if bar % 2 == 0:
			var shift := 0
			if ch == bb7:
				shift = 5
			elif ch == c7:
				shift = 7
			var up := 12 if bar >= 12 and bar % 4 == 0 else 0
			for n in riff:
				_vibes(t + n[0] * beat, n[2] + shift + up - 12, n[1] * beat, 0.38)
	_finish("music_neonbar")


func _royal() -> void:
	rng.seed = 33
	_start(132.0, 16 * 3 * 2)
	var chords := [
		[[60, 64, 67, 71], 36], [[57, 60, 64, 67], 45], [[57, 62, 65, 69], 38], [[59, 62, 65, 67], 43],
		[[59, 62, 64, 67], 40], [[57, 61, 64, 67], 45], [[57, 62, 65, 69], 38], [[59, 62, 65, 67], 43],
		[[60, 64, 67, 71], 36], [[58, 60, 64, 67], 36], [[57, 60, 64, 65], 41], [[56, 60, 62, 65], 41],
		[[59, 62, 64, 67], 40], [[57, 61, 64, 67], 45], [[57, 62, 65, 69], 38], [[59, 62, 65, 67], 43],
	]
	var melody := [
		[[0, 2, 76], [2, 1, 79]], [[0, 2, 81], [2, 1, 79]], [[0, 3, 77]], [[0, 1, 74], [1, 1, 76], [2, 1, 77]],
		[[0, 2, 79], [2, 1, 83]], [[0, 2, 81], [2, 1, 79]], [[0, 3, 77]], [[0, 1, 76], [1, 1, 74], [2, 1, 71]],
		[[0, 2, 72], [2, 1, 76]], [[0, 2, 79], [2, 1, 82]], [[0, 3, 81]], [[0, 1, 80], [1, 1, 77], [2, 1, 74]],
		[[0, 2, 76], [2, 1, 79]], [[0, 2, 73], [2, 1, 76]], [[0, 2, 74], [2, 1, 77]], [[0, 2, 71], [2, 1, 74]],
	]
	for pass_i in 2:
		for bar in 16:
			var t := (pass_i * 16 + bar) * 3 * beat
			var ch: Array = chords[bar]
			_bass(t, ch[1], beat * 1.4, 0.8)
			for b in [1, 2]:
				_rhodes_chord(t + b * beat, ch[0], beat * 0.7, 0.18)
			_strings(t, ch[0], 3 * beat, 0.16)
			for n in melody[bar]:
				_vibes(t + n[0] * beat, n[2] + (12 if pass_i == 1 and bar < 8 else 0), n[1] * beat, 0.34 if pass_i == 0 else 0.3)
			_brush_tap(t, 0.12)
	_finish("music_royal")


func _summit() -> void:
	rng.seed = 44
	_start(60.0, 8 * 4)
	var chords := [
		[[57, 60, 64, 67], 41], [[55, 59, 62, 66], 40], [[53, 57, 60, 64], 38], [[55, 59, 62, 64], 36],
		[[57, 62, 65, 69], 34], [[55, 60, 64, 67], 33], [[53, 58, 62, 65], 31], [[55, 59, 62, 64], 33],
	]
	var motif := [[0, 1, 76], [1.5, 0.5, 79], [2, 2, 81]]
	for bar in 8:
		var t := bar * 4 * beat
		var ch: Array = chords[bar]
		_strings(t, ch[0], 4 * beat, 0.22)
		_bass(t, ch[1] + 12, 3.5 * beat, 0.4)
		if bar % 2 == 1:
			for n in motif:
				_rhodes(t + n[0] * beat, n[2] - (2 if bar >= 4 else 0), n[1] * beat, 0.3)
	_finish("music_summit")


func _moon() -> void:
	rng.seed = 55
	_start(54.0, 8 * 4)
	var chords := [
		[[60, 64, 67, 74], 36], [[56, 60, 63, 70], 32], [[58, 62, 65, 72], 34], [[53, 57, 60, 67], 29],
		[[60, 64, 67, 74], 36], [[61, 65, 68, 75], 37], [[58, 62, 65, 72], 34], [[55, 59, 62, 69], 31],
	]
	var phrases := [
		[[0, 2, 79], [2.5, 1.5, 84]], [], [[1, 3, 82]], [],
		[[0, 1.5, 86], [2, 2, 79]], [], [[0.5, 3, 77]], [[2, 2, 74]],
	]
	for bar in 8:
		var t := bar * 4 * beat
		var ch: Array = chords[bar]
		_strings(t, ch[0], 4 * beat, 0.2)
		_bass(t, ch[1] + 12, 3.0 * beat, 0.32)
		for n in phrases[bar]:
			_vibes(t + n[0] * beat, n[2], n[1] * beat, 0.3)
	_finish("music_moon")


func _storm() -> void:
	rng.seed = 66
	_start(92.0, 16 * 4)
	var chords := [
		[[55, 59, 62, 66], 40], [[55, 59, 62, 66], 40], [[52, 55, 60, 64], 36], [[54, 57, 60, 66], 35],
		[[55, 59, 62, 66], 40], [[57, 60, 64, 67], 33], [[54, 58, 61, 64], 42], [[54, 57, 60, 63], 35],
	]
	var cry := [[0, 1.5, 76], [1.5, 0.5, 79], [2, 2, 83]]
	for bar in 16:
		var t := bar * 4 * beat
		var ch: Array = chords[bar % 8]
		var next_root: int = chords[(bar + 1) % 8][1]
		_comp(t, ch[0], [0.667, 2.667], 0.26)
		_walk(t, ch[1], next_root, 4, 0.9)
		_brushes(t, 4, 0.6)
		_kick(t + 2.0 * beat, 0.25)
		_strings(t, [ch[0][0] - 12, ch[0][2] - 12], 4 * beat, 0.08)
		if bar % 4 == 3:
			for n in cry:
				_vibes(t + n[0] * beat, n[2] - (5 if bar % 8 == 7 else 0), n[1] * beat, 0.3)
	_finish("music_storm")


# --- Arrangement helpers ----------------------------------------------------------------

func _start(bpm: float, beats: int) -> void:
	beat = 60.0 / bpm
	buf = PackedFloat32Array()
	buf.resize(int((beats * beat + TAIL) * RATE))


## Rhodes comping on the given beat offsets, with humanised velocity.
func _comp(t: float, notes: Array, hits: Array, vel: float) -> void:
	for h in hits:
		var v := vel * rng.randf_range(0.8, 1.05)
		_rhodes_chord(t + h * beat + rng.randf_range(0.0, 0.012), notes, beat * (1.2 if h < 1.0 else 0.8), v)


## Walking bass: root, third or fifth, fifth or sixth, chromatic approach to the next root.
func _walk(t: float, root: int, next_root: int, beats: int, vel: float) -> void:
	var line := [root, root + (3 if rng.randf() < 0.5 else 4), root + 7, next_root + (1 if rng.randf() < 0.5 else -1)]
	if rng.randf() < 0.3:
		line[2] = root + 9
	for i in beats:
		_bass(t + i * beat, line[i % 4], beat * 0.92, vel * (1.0 if i == 0 else 0.85))


func _brushes(t: float, beats: int, vel: float) -> void:
	for i in beats:
		_ride(t + i * beat, vel * (0.55 if i % 2 == 0 else 0.45))
		if i % 2 == 1:
			_ride(t + (i + 0.667) * beat, vel * 0.3)
			_brush_tap(t + i * beat, vel * 0.5)
	_swish(t, 2.0 * beat, vel * 0.35)
	_swish(t + 2.0 * beat, 2.0 * beat, vel * 0.35)
	_kick(t, vel * 0.35)


func _shuffle_kit(t: float, vel: float) -> void:
	for i in 4:
		_kick(t + i * beat, vel * (0.55 if i % 2 == 0 else 0.3))
		_hat(t + i * beat, vel * 0.35)
		_hat(t + (i + 0.667) * beat, vel * 0.25)
		if i % 2 == 1:
			_brush_tap(t + i * beat, vel * 0.8)
	_ride(t, vel * 0.3)


# --- Instruments ------------------------------------------------------------------------

func _hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


func _range(t: float, length: float) -> Array:
	var a := int(t * RATE)
	var b := mini(buf.size(), a + int(length * RATE))
	return [a, b]


func _rhodes_chord(t: float, notes: Array, dur: float, vel: float) -> void:
	for i in notes.size():
		_rhodes(t + i * 0.004, notes[i], dur, vel * (0.85 if i > 0 else 1.0))


func _rhodes(t: float, note: float, dur: float, vel: float) -> void:
	var f := _hz(note)
	var r := _range(t, dur + 0.9)
	var trem_ph := rng.randf() * TAU
	for i in range(r[0], r[1]):
		var tt := float(i - r[0]) / RATE
		var idx := 1.4 * exp(-tt / 0.18) + 0.35
		var env := (1.0 - exp(-tt / 0.003)) * exp(-tt / 1.6)
		if tt > dur:
			env *= exp(-(tt - dur) / 0.12)
		var s := sin(TAU * f * tt + idx * sin(TAU * f * tt))
		s += 0.12 * sin(TAU * f * 7.0 * tt) * exp(-tt / 0.03)  # tine ping
		buf[i] += s * env * vel * (1.0 + 0.06 * sin(TAU * 4.5 * tt + trem_ph))


func _bass(t: float, note: float, dur: float, vel: float) -> void:
	var f := _hz(note)
	var r := _range(t, dur + 0.25)
	var y := 0.0
	for i in range(r[0], r[1]):
		var tt := float(i - r[0]) / RATE
		var bend := 1.0 + 0.02 * exp(-tt / 0.02)
		var ph := TAU * f * bend * tt
		var env := (1.0 - exp(-tt / 0.004)) * exp(-tt / 0.9)
		if tt > dur:
			env *= exp(-(tt - dur) / 0.05)
		var s := sin(ph) + 0.35 * sin(2.0 * ph) + 0.12 * sin(3.0 * ph)
		# Finger thump: a little low-passed noise at the pluck.
		y += (rng.randf_range(-1.0, 1.0) - y) * 0.08
		s += y * 2.5 * exp(-tt / 0.015)
		buf[i] += s * env * vel * 0.55


func _vibes(t: float, note: float, dur: float, vel: float) -> void:
	var f := _hz(note)
	var r := _range(t, dur + 1.6)
	for i in range(r[0], r[1]):
		var tt := float(i - r[0]) / RATE
		var env := (1.0 - exp(-tt / 0.002)) * exp(-tt / 1.4)
		if tt > dur + 0.2:
			env *= exp(-(tt - dur - 0.2) / 0.25)
		var trem := 1.0 - 0.3 * (0.5 + 0.5 * sin(TAU * 5.5 * tt))
		var s := sin(TAU * f * tt) + 0.25 * sin(TAU * f * 4.0 * tt) * exp(-tt / 0.15)
		buf[i] += s * env * trem * vel


func _strings(t: float, notes: Array, dur: float, vel: float) -> void:
	for note in notes:
		var f := _hz(note)
		var r := _range(t, dur + 1.0)
		var detune := [0.997, 1.0, 1.004]
		for i in range(r[0], r[1]):
			var tt := float(i - r[0]) / RATE
			var env := minf(tt / 0.5, 1.0)
			if tt > dur:
				env *= exp(-(tt - dur) / 0.4)
			var s := 0.0
			for d in detune:
				var ph: float = TAU * f * d * tt
				s += sin(ph) + 0.3 * sin(2.0 * ph) + 0.15 * sin(3.0 * ph)
			buf[i] += s * env * vel * 0.12


func _ride(t: float, vel: float) -> void:
	var r := _range(t, 1.0)
	var modes := [[3230.0, 0.6, 1.0], [4410.0, 0.45, 0.7], [5870.0, 0.35, 0.5], [7340.0, 0.25, 0.35]]
	for i in range(r[0], r[1]):
		var tt := float(i - r[0]) / RATE
		var s := 0.0
		for m in modes:
			s += sin(TAU * m[0] * tt) * m[2] * exp(-tt / m[1])
		s += rng.randf_range(-1.0, 1.0) * 0.6 * exp(-tt / 0.006)
		buf[i] += s * vel * 0.06


func _hat(t: float, vel: float) -> void:
	var r := _range(t, 0.08)
	var prev := 0.0
	for i in range(r[0], r[1]):
		var tt := float(i - r[0]) / RATE
		var n := rng.randf_range(-1.0, 1.0)
		buf[i] += (n - prev) * exp(-tt / 0.018) * vel * 0.12
		prev = n


func _brush_tap(t: float, vel: float) -> void:
	var r := _range(t, 0.2)
	var y := 0.0
	for i in range(r[0], r[1]):
		var tt := float(i - r[0]) / RATE
		y += (rng.randf_range(-1.0, 1.0) - y) * 0.45
		buf[i] += y * exp(-tt / 0.06) * vel * 0.35


func _swish(t: float, length: float, vel: float) -> void:
	var r := _range(t, length)
	var y := 0.0
	for i in range(r[0], r[1]):
		var tt := float(i - r[0]) / RATE
		y += (rng.randf_range(-1.0, 1.0) - y) * 0.3
		var env := sin(PI * clampf(tt / length, 0.0, 1.0))
		buf[i] += y * env * vel * 0.12


func _kick(t: float, vel: float) -> void:
	var r := _range(t, 0.3)
	var ph := 0.0
	for i in range(r[0], r[1]):
		var tt := float(i - r[0]) / RATE
		ph += TAU * (48.0 + 50.0 * exp(-tt / 0.03)) / RATE
		buf[i] += sin(ph) * exp(-tt / 0.14) * vel * 0.6


# --- Mixdown ----------------------------------------------------------------------------

func _finish(name: String) -> void:
	# A small room: four feedback combs and an all-pass, mixed in quietly.
	var wet := PackedFloat32Array()
	wet.resize(buf.size())
	for spec in [[1116, 0.78], [1188, 0.77], [1277, 0.76], [1356, 0.75]]:
		var d := int(spec[0] * RATE / 44100.0)
		var line := PackedFloat32Array()
		line.resize(d)
		var k := 0
		var lp := 0.0
		for i in buf.size():
			var out := line[k]
			lp = out * 0.6 + lp * 0.4
			line[k] = buf[i] + lp * spec[1]
			k = (k + 1) % d
			wet[i] += out * 0.25
	var loop_len := buf.size() - int(TAIL * RATE)
	var mix := PackedFloat32Array()
	mix.resize(loop_len)
	for i in buf.size():
		var s := buf[i] + wet[i] * 0.22
		mix[i % loop_len] += s
	# Soft saturation and normalise to -1 dBFS.
	var peak := 0.0001
	for i in mix.size():
		mix[i] = tanh(mix[i] * 0.9)
		peak = maxf(peak, absf(mix[i]))
	var data := PackedByteArray()
	data.resize(mix.size() * 2)
	for i in mix.size():
		data.encode_s16(i * 2, int(clampf(mix[i] / peak * 0.89, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	wav.save_to_wav(OUT + name + ".wav")
	print("  %s: %.1fs loop" % [name, float(loop_len) / RATE])
