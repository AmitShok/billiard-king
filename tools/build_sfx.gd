extends SceneTree
## Designs Vertical Billiard's foley and ambience and bakes 16-bit mono WAVs to
## assets/audio/. Deterministic (fixed seeds).
##   godot --headless --path <project> --script tools/build_sfx.gd
##
## Struck objects use modal synthesis: a short excitation rings a few
## inharmonic, exponentially damped sine modes (phenolic balls ring high and
## short, walnut rails low and woody, rubber barely rings at all).
## Ambience beds are long noise/hum textures whose ends are crossfaded so
## they loop without a seam.

const RATE := 44100
const OUT := "res://assets/audio/"

var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for v in 3:
		rng.seed = 100 + v
		_save(_cue(v), "cue_%d" % v)
		rng.seed = 200 + v
		_save(_clack(v), "clack_%d" % v)
		rng.seed = 300 + v
		_save(_rail(v), "rail_%d" % v)
		rng.seed = 400 + v
		_save(_land(v), "land_%d" % v)
	for v in 2:
		rng.seed = 500 + v
		_save(_cushion(v), "cushion_%d" % v)
	rng.seed = 7
	_save(_splat(), "splat")
	_save(_pocket(), "pocket")
	_save(_bumper(), "bumper")
	_save(_lost_ball(), "lost_ball")
	_save(_tick(), "aim_tick")
	_save(_chalk(), "chalk")
	_save(_glass_break(), "glass_break")
	for v in 3:
		rng.seed = 600 + v
		_save(_tinkle(v), "tinkle_%d" % v)
		rng.seed = 700 + v
		_save(_clatter(v), "clatter_%d" % v)
	rng.seed = 800
	_save(_zap(), "zap")
	_save(_chime(), "chime")
	_save(_trap_hit(), "trap_hit")
	_save(_platform_clank(), "platform_clank")
	_save(_loop(_roll_bed(2.0), 0.25), "roll_loop")
	_save(_loop(_amb_backroom(10.0), 1.0), "amb_backroom")
	_save(_loop(_amb_neonbar(10.0), 1.0), "amb_neonbar")
	_save(_loop(_amb_royal(8.0), 0.5), "amb_royal")
	_save(_loop(_amb_moon(10.0), 1.0), "amb_moon")
	_save(_loop(_amb_storm(10.0), 1.0), "amb_storm")
	print("sfx baked")
	quit()


# --- Building blocks ------------------------------------------------------------

func _buffer(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


func _mix(dst: PackedFloat32Array, src: PackedFloat32Array, at: float, gain: float = 1.0) -> void:
	var o := int(at * RATE)
	for i in src.size():
		if o + i < dst.size():
			dst[o + i] += src[i] * gain


## Modal strike: modes = [[freq, decay_s, amp], ...]
func _modes(modes: Array, length: float, jitter: float = 0.0) -> PackedFloat32Array:
	var out := _buffer(length)
	for m in modes:
		var f: float = m[0] * (1.0 + rng.randf_range(-jitter, jitter))
		var ph := rng.randf() * TAU
		for i in out.size():
			var t := float(i) / RATE
			out[i] += sin(TAU * f * t + ph) * m[2] * exp(-t / m[1])
	return out


func _noise_burst(length: float, decay: float, lowpass: float = 1.0) -> PackedFloat32Array:
	var out := _buffer(length)
	var y := 0.0
	for i in out.size():
		var t := float(i) / RATE
		y += (rng.randf_range(-1.0, 1.0) - y) * lowpass
		out[i] = y * exp(-t / decay)
	return out


func _thump(f0: float, f1: float, decay: float, length: float) -> PackedFloat32Array:
	var out := _buffer(length)
	var ph := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var f := f1 + (f0 - f1) * exp(-t / (decay * 0.5))
		ph += TAU * f / RATE
		out[i] = sin(ph) * exp(-t / decay)
	return out


func _lowpass(buf: PackedFloat32Array, k: float) -> PackedFloat32Array:
	var y := 0.0
	for i in buf.size():
		y += (buf[i] - y) * k
		buf[i] = y
	return buf


func _normalize(buf: PackedFloat32Array, peak: float = 0.9) -> PackedFloat32Array:
	var m := 0.0001
	for s in buf:
		m = maxf(m, absf(s))
	for i in buf.size():
		buf[i] = buf[i] / m * peak
	return buf


## Crossfades the tail into the head so the buffer loops seamlessly.
func _loop(buf: PackedFloat32Array, fade: float) -> PackedFloat32Array:
	var n := int(fade * RATE)
	var out := buf.slice(0, buf.size() - n)
	for i in n:
		var t := float(i) / n
		out[i] = out[i] * t + buf[buf.size() - n + i] * (1.0 - t)
	return out


func _save(buf: PackedFloat32Array, name: String) -> void:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	wav.save_to_wav(OUT + name + ".wav")


# --- Sounds -----------------------------------------------------------------------

## Leather cue tip on a phenolic ball: a soft "tock" with a bright ring.
func _cue(v: int) -> PackedFloat32Array:
	var out := _buffer(0.25)
	_mix(out, _noise_burst(0.01, 0.0015, 0.5), 0.0, 0.6)
	_mix(out, _modes([[1750.0, 0.018, 0.8], [3150.0, 0.012, 0.5], [4800.0, 0.008, 0.3], [6900.0, 0.005, 0.2]], 0.12, 0.04), 0.0)
	_mix(out, _thump(320.0, 170.0, 0.03, 0.12), 0.0, 0.5 + v * 0.05)
	return _normalize(out, 0.85)


## Ball on ball: the hard, glassy billiard clack.
func _clack(v: int) -> PackedFloat32Array:
	var out := _buffer(0.15)
	_mix(out, _noise_burst(0.004, 0.0006, 0.9), 0.0, 0.8)
	_mix(out, _modes([[2900.0, 0.016, 1.0], [4350.0, 0.011, 0.7], [6150.0, 0.007, 0.45], [8400.0, 0.004, 0.25]], 0.1, 0.05), 0.0)
	return _normalize(out, 0.8 + v * 0.03)


## Ball into a walnut rail: woody knock.
func _rail(v: int) -> PackedFloat32Array:
	var out := _buffer(0.3)
	_mix(out, _noise_burst(0.02, 0.003, 0.35), 0.0, 0.7)
	_mix(out, _modes([[210.0, 0.07, 0.9], [530.0, 0.045, 0.7], [960.0, 0.03, 0.5], [1640.0, 0.018, 0.35], [2700.0, 0.01, 0.25]], 0.25, 0.06), 0.0)
	_mix(out, _modes([[2900.0, 0.01, 0.3]], 0.05, 0.05), 0.0)
	return _normalize(out, 0.85 - v * 0.03)


## Rubber cushion: deep, damped bump.
func _cushion(v: int) -> PackedFloat32Array:
	var out := _buffer(0.3)
	_mix(out, _thump(190.0, 95.0, 0.06, 0.25), 0.0, 1.0)
	_mix(out, _lowpass(_noise_burst(0.06, 0.012, 0.25), 0.3), 0.0, 0.5)
	_mix(out, _modes([[2900.0, 0.008, 0.25]], 0.04, 0.05), 0.0)
	return _normalize(out, 0.85 - v * 0.05)


## Landing on felt over slate.
func _land(v: int) -> PackedFloat32Array:
	var out := _buffer(0.3)
	_mix(out, _thump(140.0, 70.0, 0.05, 0.22), 0.0, 1.0)
	_mix(out, _lowpass(_noise_burst(0.08, 0.02, 0.2), 0.4), 0.0, 0.7)
	_mix(out, _modes([[2400.0 + v * 150.0, 0.01, 0.25]], 0.05, 0.05), 0.0)
	return _normalize(out, 0.85)


## The big fall: heavy thud, slate rumble, a rattle of the table frame.
func _splat() -> PackedFloat32Array:
	var out := _buffer(0.9)
	_mix(out, _thump(110.0, 42.0, 0.14, 0.7), 0.0, 1.0)
	_mix(out, _lowpass(_noise_burst(0.4, 0.09, 0.12), 0.5), 0.0, 0.8)
	_mix(out, _modes([[180.0, 0.12, 0.5], [410.0, 0.08, 0.35], [760.0, 0.05, 0.2]], 0.5, 0.05), 0.01)
	_mix(out, _modes([[2600.0, 0.012, 0.3]], 0.05, 0.05), 0.0)
	return _normalize(out, 0.95)


## Into the pocket: leather thunk, then the ball rattles down the return.
func _pocket() -> PackedFloat32Array:
	var out := _buffer(1.4)
	_mix(out, _thump(150.0, 80.0, 0.06, 0.2), 0.0, 0.9)
	_mix(out, _lowpass(_noise_burst(0.1, 0.03, 0.2), 0.3), 0.0, 0.5)
	var t := 0.18
	var gap := 0.11
	for i in 9:
		var g := 0.55 * pow(0.86, i)
		_mix(out, _modes([[2700.0 + rng.randf_range(-200, 200), 0.012, 1.0], [4100.0, 0.007, 0.5]], 0.06, 0.03), t, g)
		_mix(out, _modes([[260.0, 0.03, 1.0]], 0.08, 0.05), t, g * 0.6)
		t += gap
		gap *= 0.84
	return _normalize(out, 0.85)


## Brass bumper bell.
func _bumper() -> PackedFloat32Array:
	var out := _modes([[880.0, 0.35, 1.0], [2428.0, 0.18, 0.5], [4752.0, 0.08, 0.3], [1320.0, 0.25, 0.4]], 0.7, 0.0)
	_mix(out, _noise_burst(0.005, 0.0008, 0.9), 0.0, 0.4)
	return _normalize(out, 0.7)


## Finding a lost ball: a little bell arpeggio.
func _lost_ball() -> PackedFloat32Array:
	var out := _buffer(1.3)
	var notes := [1046.5, 1318.5, 1568.0, 2093.0]
	for i in notes.size():
		var f: float = notes[i]
		_mix(out, _modes([[f, 0.3, 1.0], [f * 2.0, 0.12, 0.3], [f * 3.01, 0.06, 0.15]], 0.8, 0.0), i * 0.09, 0.8)
	return _normalize(out, 0.7)


func _tick() -> PackedFloat32Array:
	var out := _modes([[3200.0, 0.004, 1.0], [5100.0, 0.002, 0.5]], 0.03, 0.0)
	return _normalize(out, 0.6)


## Chalking up / settling the cue: dry grainy scrape.
func _chalk() -> PackedFloat32Array:
	var out := _buffer(0.16)
	var y := 0.0
	var hp := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var n := rng.randf_range(-1.0, 1.0)
		y += (n - y) * 0.5
		var hpo := y - hp
		hp += (y - hp) * 0.08
		var grain := 0.5 + 0.5 * sin(TAU * 38.0 * t + sin(TAU * 7.0 * t) * 3.0)
		out[i] = hpo * grain * sin(PI * t / 0.16)
	return _normalize(out, 0.5)


## Felt roll: low rumbling noise with a slow wobble.
func _roll_bed(seconds: float) -> PackedFloat32Array:
	var out := _buffer(seconds)
	var y := 0.0
	var y2 := 0.0
	for i in out.size():
		var t := float(i) / RATE
		y += (rng.randf_range(-1.0, 1.0) - y) * 0.06
		y2 += (y - y2) * 0.15
		out[i] = y2 * (0.8 + 0.2 * sin(TAU * 11.0 * t))
	return _normalize(out, 0.7)


func _brown(seconds: float, k: float) -> PackedFloat32Array:
	var out := _buffer(seconds)
	var y := 0.0
	for i in out.size():
		y += (rng.randf_range(-1.0, 1.0) - y) * k
		out[i] = y
	return out


## Back room: still air, a fluorescent hum, distant traffic.
func _amb_backroom(seconds: float) -> PackedFloat32Array:
	var out := _normalize(_brown(seconds, 0.01), 0.25)
	for i in out.size():
		var t := float(i) / RATE
		out[i] += 0.035 * sin(TAU * 60.0 * t) + 0.02 * sin(TAU * 120.0 * t) + 0.01 * sin(TAU * 180.0 * t)
	# A far-off game in the next room: a few soft clacks.
	for c in [1.3, 1.45, 4.8, 7.2, 7.31, 7.4]:
		_mix(out, _lowpass(_clack(0), 0.25), c, 0.06)
	return out


## Neon bar: tube buzz and a jukebox thumping through the wall.
func _amb_neonbar(seconds: float) -> PackedFloat32Array:
	var out := _normalize(_brown(seconds, 0.015), 0.22)
	for i in out.size():
		var t := float(i) / RATE
		var buzz := sin(TAU * 120.0 * t)
		out[i] += 0.03 * signf(buzz) * absf(buzz) ** 0.3 * (0.6 + 0.4 * sin(TAU * 0.3 * t))
	var beat := 60.0 / 96.0
	var t2 := 0.0
	while t2 < seconds - 0.3:
		_mix(out, _thump(90.0, 50.0, 0.08, 0.25), t2, 0.12)
		t2 += beat
	return out


## Royal club: hushed room and a slow long-case clock.
func _amb_royal(seconds: float) -> PackedFloat32Array:
	var out := _normalize(_brown(seconds, 0.006), 0.18)
	var t := 0.25
	var i := 0
	while t < seconds - 0.2:
		_mix(out, _modes([[1900.0 if i % 2 == 0 else 1650.0, 0.012, 1.0], [3700.0, 0.006, 0.4]], 0.05, 0.0), t, 0.05)
		t += 1.0
		i += 1
	return out


# --- Reactive decor -----------------------------------------------------------------

## A window giving way: crack, a burst of glass, then shards tinkling down.
func _glass_break() -> PackedFloat32Array:
	var out := _buffer(1.6)
	_mix(out, _noise_burst(0.02, 0.004, 0.95), 0.0, 1.0)
	_mix(out, _modes([[3100.0, 0.05, 0.8], [4700.0, 0.04, 0.6], [6900.0, 0.03, 0.5], [9100.0, 0.02, 0.35]], 0.25, 0.05), 0.0, 0.8)
	_mix(out, _noise_burst(0.3, 0.08, 0.7), 0.005, 0.35)
	for i in 22:
		var t := 0.06 + pow(rng.randf(), 1.6) * 1.2
		var f := rng.randf_range(3500.0, 9500.0)
		_mix(out, _modes([[f, 0.03, 1.0], [f * 1.53, 0.02, 0.5]], 0.08, 0.0), t, rng.randf_range(0.08, 0.3) * (1.0 - t / 1.4))
	return _normalize(out, 0.85)


## Chandelier crystals knocking together.
func _tinkle(v: int) -> PackedFloat32Array:
	var out := _buffer(1.2)
	var base: float = [2637.0, 3136.0, 3520.0][v]
	for i in 5:
		var f: float = base * [1.0, 1.26, 1.5, 1.68, 2.0][rng.randi() % 5]
		_mix(out, _modes([[f, 0.25, 1.0], [f * 2.76, 0.08, 0.3]], 0.6, 0.01), i * rng.randf_range(0.04, 0.09), rng.randf_range(0.35, 0.8))
	return _normalize(out, 0.55)


## Cues or wood rattling: a quick run of small knocks.
func _clatter(v: int) -> PackedFloat32Array:
	var out := _buffer(0.5)
	var t := 0.0
	for i in 5 + v:
		_mix(out, _modes([[rng.randf_range(600.0, 1400.0), 0.025, 1.0], [rng.randf_range(2000.0, 3200.0), 0.01, 0.4]], 0.08, 0.0), t, rng.randf_range(0.4, 1.0) * (1.0 - t * 1.6))
		t += rng.randf_range(0.025, 0.07)
	return _normalize(out, 0.7)


## Neon tube shorting out: a buzzing crackle.
func _zap() -> PackedFloat32Array:
	var out := _buffer(0.45)
	var ph := 0.0
	for i in out.size():
		var t := float(i) / RATE
		ph += TAU * 120.0 / RATE
		var buzz := signf(sin(ph)) * 0.35 + sin(ph * 7.0) * 0.15
		var crackle := rng.randf_range(-1.0, 1.0) if rng.randf() < 0.25 else 0.0
		var env := exp(-t / 0.12) * (0.6 + 0.4 * signf(sin(TAU * 31.0 * t)))
		out[i] = (buzz + crackle * 0.8) * env
	return _normalize(out, 0.6)


## A knocked wall clock's bell.
func _chime() -> PackedFloat32Array:
	var out := _modes([[1567.0, 0.5, 1.0], [3134.0, 0.2, 0.35], [4322.0, 0.12, 0.2]], 1.2, 0.0)
	_mix(out, _modes([[2900.0, 0.01, 0.3]], 0.05, 0.0), 0.0)
	return _normalize(out, 0.5)


## Struck by a trap: a harsh metal clang with a downward zing.
func _trap_hit() -> PackedFloat32Array:
	var out := _buffer(0.7)
	_mix(out, _noise_burst(0.02, 0.004, 0.9), 0.0, 1.0)
	_mix(out, _modes([[740.0, 0.12, 1.0], [1187.0, 0.09, 0.8], [1963.0, 0.06, 0.6], [3210.0, 0.04, 0.5]], 0.5, 0.0), 0.0, 0.9)
	var ph := 0.0
	var zing := _buffer(0.35)
	for i in zing.size():
		var t := float(i) / RATE
		ph += TAU * (2400.0 * exp(-t / 0.09) + 200.0) / RATE
		zing[i] = signf(sin(ph)) * exp(-t / 0.1)
	_mix(out, zing, 0.0, 0.25)
	_mix(out, _thump(150.0, 60.0, 0.08, 0.25), 0.0, 0.6)
	return _normalize(out, 0.85)


## Landing on a brass carriage: a short metallic clank.
func _platform_clank() -> PackedFloat32Array:
	var out := _modes([[520.0, 0.05, 1.0], [1310.0, 0.03, 0.6], [2470.0, 0.015, 0.35]], 0.2, 0.02)
	_mix(out, _thump(140.0, 70.0, 0.04, 0.15), 0.0, 0.5)
	return _normalize(out, 0.7)


## Moon and space: near silence, a low suit-radio hum, the odd soft beep.
func _amb_moon(seconds: float) -> PackedFloat32Array:
	var out := _normalize(_brown(seconds, 0.004), 0.1)
	for i in out.size():
		var t := float(i) / RATE
		out[i] += 0.03 * sin(TAU * 48.0 * t) * (0.7 + 0.3 * sin(TAU * 0.2 * t))
	for b in [1.7, 5.2, 8.1]:
		_mix(out, _modes([[1320.0, 0.09, 1.0], [2640.0, 0.04, 0.2]], 0.3, 0.0), b, 0.03)
	return out


## Storm: rain hiss, a low wind moan and thunder a long way off.
func _amb_storm(seconds: float) -> PackedFloat32Array:
	var out := _buffer(seconds)
	var y := 0.0
	var hp := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var n := rng.randf_range(-1.0, 1.0)
		y += (n - y) * 0.03
		var hiss := n - hp
		hp += (n - hp) * 0.5
		out[i] = y * (0.9 + 0.5 * sin(TAU * 0.13 * t)) * 0.8 + hiss * 0.02
	_mix(out, _lowpass(_noise_burst(2.5, 0.8, 0.05), 0.08), 3.5, 2.2)
	return out
