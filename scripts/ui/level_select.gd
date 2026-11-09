class_name LevelSelect
extends Control
## A small felt panel for choosing a level, one row per numbered ball. Both
## modes share the levels; each mode + level keeps its own run and records.

signal closed

const LEVELS := [
	{ "name": "The Tower", "about": "10 screens" },
	{ "name": "The Long Rack", "about": "20 screens, traps, moving carriages" },
	{ "name": "The Moon Shot", "about": "15 screens, low gravity in space" },
	{ "name": "The Gale", "about": "15 screens, one-way gusts of wind" },
]

var mode := SaveData.CLASSIC
var _info: Label
var _balls: Array[BallVisual] = []
var _focused := 0
var _first: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := UIKit.panel(self, Vector2(340, 0))
	UIKit.heading(box, { SaveData.HARDCORE: "Hardcore mode", SaveData.TRAINING: "Training" }.get(mode, "Normal mode"))
	for i in LEVELS.size():
		_add_row(box, i)
	_info = UIKit.label(box, "", Color("a89e8a"))
	_info.custom_minimum_size = Vector2(0, 10)
	var back := UIKit.button(box, "Back", close)
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.focus_entered.connect(func(): _info.text = "")
	_first.grab_focus.call_deferred()


func _add_row(box: Control, i: int) -> void:
	var lvl: int = i + 1
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(22, 22)
	row.add_child(holder)
	var ball := BallVisual.new()
	ball.number = lvl
	ball.diameter = 18
	ball.position = Vector2(11, 11)
	holder.add_child(ball)
	_balls.append(ball)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var title := Label.new()
	title.text = LEVELS[i].name
	title.add_theme_color_override("font_color", Color("f2d27a"))
	text.add_child(title)
	var about := Label.new()
	about.text = LEVELS[i].about
	about.add_theme_color_override("font_color", Color("a89e8a"))
	text.add_child(about)
	if not SaveData.level_unlocked(lvl):
		ball.modulate = Color(0.08, 0.06, 0.08, 1)
		title.add_theme_color_override("font_color", Color("6a6458"))
		about.text = "Finish %s to unlock" % LEVELS[i - 1].name
		var locked := UIKit.button(row, "Locked", func(): pass)
		locked.disabled = true
		locked.focus_mode = Control.FOCUS_NONE
		return
	if mode == SaveData.TRAINING:
		# Practice only: always a fresh run, nothing to continue.
		_track(UIKit.button(row, "Practise", _start.bind(lvl, true)), i)
		return
	var running := SaveData.has_run_for(mode, lvl)
	if running:
		var cont := UIKit.button(row, "Continue", _start.bind(lvl, false))
		_track(cont, i)
		var fresh := UIKit.button(row, "New", func(): pass)
		fresh.pressed.connect(func():
			if fresh.text == "Sure?":
				_start(lvl, true)
			else:
				fresh.text = "Sure?")
		fresh.focus_exited.connect(func(): fresh.text = "New")
		_track(fresh, i)
	else:
		_track(UIKit.button(row, "Start", _start.bind(lvl, true)), i)


func _track(b: Button, i: int) -> void:
	if _first == null:
		_first = b
	b.focus_entered.connect(_on_level_focus.bind(i))


func _on_level_focus(i: int) -> void:
	_focused = i
	if mode == SaveData.TRAINING:
		_info.text = "Flags, no lost balls. Nothing here counts or unlocks."
		return
	var r := SaveData.record(mode, i + 1)

	if r.wins > 0:
		_info.text = "Finished %d   Best %s   Fewest strokes %d" % [r.wins, SaveData.format_time(r.best_time), r.best_strokes]
	else:
		_info.text = "Not finished yet"


func _prepare(lvl: int, fresh: bool) -> void:
	SaveData.set_run(mode, lvl)
	if fresh:
		SaveData.start_new_run()


func _start(lvl: int, fresh: bool) -> void:
	_prepare(lvl, fresh)
	Sfx.play("cue", -2.0)
	get_tree().change_scene_to_file("res://scenes/world/game.tscn")


func _process(delta: float) -> void:
	for i in _balls.size():
		var on := i == _focused and not _info.text.is_empty()
		_balls[i].roll(2.4 if on else 0.3, 1.2 if on else 0.0, delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	Sfx.play("ui_back", -4.0, 1.0, 0.0)
	closed.emit()
	queue_free()
