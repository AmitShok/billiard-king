extends Node
## All game audio. One-shots come from a small voice pool; the felt-roll loop
## and the per-zone ambience beds are dedicated players.
## Sounds are baked by tools/build_sfx.gd (+ a few CC0 Ninja Adventure cues).

const DIR := "res://assets/audio/"
const AMBIENCE := ["amb_backroom", "amb_neonbar", "amb_royal", "amb_summit"]
const VOICES := 14

var _streams := {}
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _roll: AudioStreamPlayer
var _amb_a: AudioStreamPlayer
var _amb_b: AudioStreamPlayer
var _amb_zone := -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["SFX", "Ambience"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_voices.append(p)
	_roll = AudioStreamPlayer.new()
	_roll.bus = "SFX"
	_roll.volume_db = -80.0
	add_child(_roll)
	_amb_a = AudioStreamPlayer.new()
	_amb_b = AudioStreamPlayer.new()
	for p in [_amb_a, _amb_b]:
		p.bus = "Ambience"
		p.volume_db = -80.0
		add_child(p)
	var roll_stream := _stream("roll_loop")
	if roll_stream:
		_roll.stream = roll_stream
	SaveData.settings_changed.connect(_apply_volumes)
	_apply_volumes()


func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(SaveData.master_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(SaveData.sfx_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), linear_to_db(maxf(SaveData.ambience_volume, 0.0001)))


func _stream(sound: String) -> AudioStream:
	if _streams.has(sound):
		return _streams[sound]
	var stream: AudioStream = null
	for ext in [".wav", ".ogg"]:
		if ResourceLoader.exists(DIR + sound + ext):
			stream = load(DIR + sound + ext)
			break
	if stream is AudioStreamWAV and (sound.begins_with("amb_") or sound.ends_with("_loop")):
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	_streams[sound] = stream
	return stream


## Plays a one-shot. If name_0.. name_2 variants exist, one is picked at random.
func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0, pitch_jitter: float = 0.04) -> void:
	var stream := _stream(sound)
	if stream == null:
		var options: Array[AudioStream] = []
		for i in 4:
			var s := _stream("%s_%d" % [sound, i])
			if s:
				options.append(s)
		if options.is_empty():
			return
		stream = options[_rng.randi() % options.size()]
	var p := _voices[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch * (1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter))
	p.play()


## Impact sounds scale with how hard the ball hit.
func impact(sound: String, impact_speed: float, full_at: float = 500.0) -> void:
	var t := clampf(impact_speed / full_at, 0.0, 1.0)
	play(sound, lerpf(-22.0, 0.0, sqrt(t)), lerpf(1.08, 0.94, t))


## Felt rolling noise follows ground speed.
func set_roll(speed: float, grounded: bool) -> void:
	if _roll.stream == null:
		return
	var target := -80.0
	if grounded and speed > 8.0:
		target = lerpf(-30.0, -8.0, clampf(speed / 300.0, 0.0, 1.0))
	if target > -79.0 and not _roll.playing:
		_roll.play()
	_roll.volume_db = lerpf(_roll.volume_db, target, 0.25)
	_roll.pitch_scale = lerpf(0.8, 1.25, clampf(speed / 400.0, 0.0, 1.0))
	if _roll.volume_db < -70.0 and _roll.playing and target <= -79.0:
		_roll.stop()


func stop_roll() -> void:
	_roll.stop()
	_roll.volume_db = -80.0


## Crossfades the ambience bed to a zone (0..3), or -1 for silence.
func set_ambience(zone: int) -> void:
	if zone == _amb_zone:
		return
	_amb_zone = zone
	var old := _amb_a if _amb_a.playing and _amb_a.volume_db > -60.0 else _amb_b
	var fresh := _amb_b if old == _amb_a else _amb_a
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -80.0, 1.2)
		tw.tween_callback(old.stop)
	if zone >= 0 and zone < AMBIENCE.size():
		var stream := _stream(AMBIENCE[zone])
		if stream:
			fresh.stream = stream
			fresh.volume_db = -60.0
			fresh.play()
			create_tween().tween_property(fresh, "volume_db", 0.0, 1.2)
