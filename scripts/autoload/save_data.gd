extends Node
## Settings and the run in progress. Like Jump King, the climb is saved where
## you stand: quitting and returning puts the ball back on the same felt.
## Tests pass --save-profile=<name> to use an isolated file.

signal settings_changed

const VERSION := 1
const CLASSIC := "classic"
const HARDCORE := "hardcore"

var path := "user://vertical_billiard.cfg"

# Settings
var master_volume := 0.8
var sfx_volume := 0.9
var ambience_volume := 0.7
var music_volume := 0.6
var fullscreen := false
var screen_shake := true

# Which climb is being played. Each mode keeps its own run.
var mode := CLASSIC
var level := 1

# Run in progress
var has_run := false
var ball_pos := Vector2.ZERO
var white_pos := Vector2.ZERO   # Hardcore: where the white ball rests
var world_time := 0.0           # where the moving platforms and traps are
var aim_deg := 0.0
var spin_level := 0
var run_time := 0.0
var strokes := 0
var falls := 0
var best_screen := 0
var seen_zones: Array[int] = []
var broken: Array[String] = []     # windows smashed this climb (they stay broken)

# Persistent across runs (the Ball Rack)
var collected: Array[int] = []      # balls in the rack: 1-10 and 17-26 are lost balls, the rest awards
var skin := 0
var wins := 0
var best_time := 0.0
var best_strokes := 0
var hc_wins := 0
var hc_best_time := 0.0
var hc_best_strokes := 0
var records := {}               # level 2+: "mode_level" -> {wins, best_time, best_strokes}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--save-profile="):
			path = "user://test_%s.cfg" % arg.get_slice("=", 1)
	if path == "user://vertical_billiard.cfg":
		adopt_old_save(OS.get_user_data_dir().get_base_dir().path_join("Billiard King/billiard_king.cfg"))
	_setup_input()
	load_data()
	apply_settings()


## The game used to be called Billiard King, and Godot keeps saves in a folder
## named after the game. Copy the old save over once; the original is left alone.
func adopt_old_save(old_path: String) -> bool:
	if FileAccess.file_exists(path) or not FileAccess.file_exists(old_path):
		return false
	return DirAccess.copy_absolute(old_path, ProjectSettings.globalize_path(path)) == OK


func _setup_input() -> void:
	var binds := {
		"charge": [KEY_SPACE, KEY_Z, KEY_J, JOY_BUTTON_A],
		"aim_left": [KEY_A, KEY_LEFT, JOY_BUTTON_DPAD_LEFT],
		"aim_right": [KEY_D, KEY_RIGHT, JOY_BUTTON_DPAD_RIGHT],
		"spin_up": [KEY_W, JOY_BUTTON_DPAD_UP],
		"spin_down": [KEY_S, JOY_BUTTON_DPAD_DOWN],
		"look_up": [KEY_UP],
		"look_down": [KEY_DOWN],
		"pause": [KEY_ESCAPE, KEY_P, JOY_BUTTON_START],
	}
	for action in binds:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.35)
		for code in binds[action]:
			var ev: InputEvent
			if code >= KEY_SPACE: # joypad button indices are all below 32
				var k := InputEventKey.new()
				k.physical_keycode = code
				ev = k
			else:
				var j := InputEventJoypadButton.new()
				j.button_index = code
				ev = j
			InputMap.action_add_event(action, ev)
	var axes := { "aim_left": [JOY_AXIS_LEFT_X, -1.0], "aim_right": [JOY_AXIS_LEFT_X, 1.0], "spin_up": [JOY_AXIS_LEFT_Y, -1.0], "spin_down": [JOY_AXIS_LEFT_Y, 1.0], "look_up": [JOY_AXIS_RIGHT_Y, -1.0], "look_down": [JOY_AXIS_RIGHT_Y, 1.0] }
	for action in axes:
		var m := InputEventJoypadMotion.new()
		m.axis = axes[action][0]
		m.axis_value = axes[action][1]
		InputMap.action_add_event(action, m)


func run_section(for_mode: String = "", for_level: int = 0) -> String:
	var m := mode if for_mode == "" else for_mode
	var l := level if for_level == 0 else for_level
	var base := "run" if m == CLASSIC else "run_" + m
	return base if l == 1 else "%s_l%d" % [base, l]


## Switches to a mode and level. Every mode + level keeps its own run.
func set_run(new_mode: String, new_level: int) -> void:
	if new_mode == mode and new_level == level:
		return
	save()
	mode = new_mode
	level = new_level
	_load_run(_read())


func set_mode(new_mode: String) -> void:
	set_run(new_mode, level)


## Is there a run in progress for a mode and level (without switching to it)?
func has_run_for(for_mode: String, for_level: int = 1) -> bool:
	if for_mode == mode and for_level == level:
		return has_run
	return _read().get_value(run_section(for_mode, for_level), "active", false)


## Level 2 opens once level 1 is finished in either mode. A level 2 run
## already under way stays playable.
func level_unlocked(for_level: int) -> bool:
	if for_level <= 1 or wins > 0 or hc_wins > 0:
		return true
	return has_run_for(CLASSIC, for_level) or has_run_for(HARDCORE, for_level)


## Wins and best results for a mode and level.
func record(for_mode: String, for_level: int) -> Dictionary:
	if for_level == 1:
		if for_mode == HARDCORE:
			return { "wins": hc_wins, "best_time": hc_best_time, "best_strokes": hc_best_strokes }
		return { "wins": wins, "best_time": best_time, "best_strokes": best_strokes }
	return records.get("%s_%d" % [for_mode, for_level], { "wins": 0, "best_time": 0.0, "best_strokes": 0 })


func _read() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(path)
	return cfg


func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	master_volume = cfg.get_value("settings", "master", master_volume)
	sfx_volume = cfg.get_value("settings", "sfx", sfx_volume)
	ambience_volume = cfg.get_value("settings", "ambience", ambience_volume)
	music_volume = cfg.get_value("settings", "music", music_volume)
	fullscreen = cfg.get_value("settings", "fullscreen", fullscreen)
	screen_shake = cfg.get_value("settings", "shake", screen_shake)
	_load_run(cfg)
	collected.assign(cfg.get_value("rack", "collected", []))
	skin = cfg.get_value("rack", "skin", 0)
	wins = cfg.get_value("rack", "wins", 0)
	best_time = cfg.get_value("rack", "best_time", 0.0)
	best_strokes = cfg.get_value("rack", "best_strokes", 0)
	hc_wins = cfg.get_value("rack", "hc_wins", 0)
	hc_best_time = cfg.get_value("rack", "hc_best_time", 0.0)
	hc_best_strokes = cfg.get_value("rack", "hc_best_strokes", 0)
	records = cfg.get_value("rack", "records", {})
	if skin != 0 and not collected.has(skin):
		skin = 0


func _load_run(cfg: ConfigFile) -> void:
	var s := run_section()
	has_run = cfg.get_value(s, "active", false)
	ball_pos = cfg.get_value(s, "pos", Vector2.ZERO)
	white_pos = cfg.get_value(s, "white_pos", Vector2.ZERO)
	world_time = cfg.get_value(s, "world_time", 0.0)
	aim_deg = cfg.get_value(s, "aim", 0.0)
	spin_level = cfg.get_value(s, "spin", 0)
	run_time = cfg.get_value(s, "time", 0.0)
	strokes = cfg.get_value(s, "strokes", 0)
	falls = cfg.get_value(s, "falls", 0)
	best_screen = cfg.get_value(s, "best_screen", 0)
	seen_zones.assign(cfg.get_value(s, "seen_zones", []))
	broken.assign(cfg.get_value(s, "broken", []))


## Writes settings, the Ball Rack and the current mode's run. The other
## mode's run is read back from disk first so it is never lost.
func save() -> void:
	var cfg := _read()
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("settings", "master", master_volume)
	cfg.set_value("settings", "sfx", sfx_volume)
	cfg.set_value("settings", "ambience", ambience_volume)
	cfg.set_value("settings", "music", music_volume)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.set_value("settings", "shake", screen_shake)
	var s := run_section()
	cfg.set_value(s, "active", has_run)
	cfg.set_value(s, "pos", ball_pos)
	cfg.set_value(s, "white_pos", white_pos)
	cfg.set_value(s, "world_time", world_time)
	cfg.set_value(s, "aim", aim_deg)
	cfg.set_value(s, "spin", spin_level)
	cfg.set_value(s, "time", run_time)
	cfg.set_value(s, "strokes", strokes)
	cfg.set_value(s, "falls", falls)
	cfg.set_value(s, "best_screen", best_screen)
	cfg.set_value(s, "seen_zones", seen_zones)
	cfg.set_value(s, "broken", broken)
	cfg.set_value("rack", "collected", collected)
	cfg.set_value("rack", "skin", skin)
	cfg.set_value("rack", "wins", wins)
	cfg.set_value("rack", "best_time", best_time)
	cfg.set_value("rack", "best_strokes", best_strokes)
	cfg.set_value("rack", "hc_wins", hc_wins)
	cfg.set_value("rack", "hc_best_time", hc_best_time)
	cfg.set_value("rack", "hc_best_strokes", hc_best_strokes)
	cfg.set_value("rack", "records", records)
	cfg.save(path)


func start_new_run() -> void:
	has_run = true
	ball_pos = Vector2.ZERO
	white_pos = Vector2.ZERO
	world_time = 0.0
	aim_deg = 0.0
	spin_level = 0
	run_time = 0.0
	strokes = 0
	falls = 0
	best_screen = 0
	seen_zones.clear()
	broken.clear()
	save()


func finish_run() -> void:
	if level > 1:
		var r := record(mode, level)
		r.wins += 1
		if r.best_time == 0.0 or run_time < r.best_time:
			r.best_time = run_time
		if r.best_strokes == 0 or strokes < r.best_strokes:
			r.best_strokes = strokes
		records["%s_%d" % [mode, level]] = r
	elif mode == HARDCORE:
		hc_wins += 1
		if hc_best_time == 0.0 or run_time < hc_best_time:
			hc_best_time = run_time
		if hc_best_strokes == 0 or strokes < hc_best_strokes:
			hc_best_strokes = strokes
	else:
		wins += 1
		if best_time == 0.0 or run_time < best_time:
			best_time = run_time
		if best_strokes == 0 or strokes < best_strokes:
			best_strokes = strokes
	has_run = false
	save()


func mark_broken(prop_name: String) -> void:
	if not broken.has(prop_name):
		broken.append(prop_name)


func collect_ball(number: int) -> void:
	if not collected.has(number):
		collected.append(number)
		collected.sort()
		save()


func apply_settings() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	settings_changed.emit()


static func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
