extends Control
## Pause: the run's stats (Jump King style: time, strokes, falls) and options.

var game: Node
var _box: VBoxContainer
var _stats: Label
var _resume: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.02, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_box = UIKit.panel(self, Vector2(190, 0))
	UIKit.heading(_box, "Paused")
	_stats = UIKit.label(_box, "")
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	_box.add_child(gap)
	_resume = UIKit.button(_box, "Resume", close)
	var opts := UIKit.button(_box, "Options", _open_options)
	var buttons: Array = [_resume, opts]
	if game.hardcore():
		buttons.append(UIKit.button(_box, "Re-rack white ball", func():
			game.rerack_white()
			close()))
	var restart := UIKit.button(_box, "Restart climb", func(): pass)
	restart.pressed.connect(func():
		if restart.text == "Press again to restart":
			game.restart_climb()
		else:
			restart.text = "Press again to restart")
	restart.focus_exited.connect(func(): restart.text = "Restart climb")
	buttons.append(restart)
	buttons.append(UIKit.button(_box, "Quit" if game.training() else "Save and quit", func(): game.quit_to_title()))
	UIKit.chain_focus(buttons)


func open() -> void:
	if visible:
		return
	game.save_progress()
	if game.training():
		_stats.text = "Training, level %d\nTime  %s\nStrokes  %d\nFalls  %d\nFlags  %d" % [SaveData.level, SaveData.format_time(SaveData.run_time), SaveData.strokes, SaveData.falls, game.flags.size()]
	else:
		_stats.text = ("Level %d\n" % SaveData.level) + "Time  %s\nStrokes  %d\nFalls  %d\nLost balls  %d / %d" % [
		SaveData.format_time(SaveData.run_time), SaveData.strokes, SaveData.falls,
		game.tower.lost_numbers().filter(func(n): return SaveData.collected.has(n)).size(), game.tower.lost_numbers().size()]
	visible = true
	get_tree().paused = true
	Sfx.stop_roll()
	Sfx.play("ui_accept", -6.0, 0.9, 0.0)
	_resume.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false


func _open_options() -> void:
	var o := OptionsMenu.new()
	add_child(o)
	_box.get_parent().visible = false
	o.closed.connect(func():
		_box.get_parent().visible = true
		_resume.grab_focus())


func _unhandled_input(event: InputEvent) -> void:
	if not visible or get_child_count() > 2 and get_child(get_child_count() - 1) is OptionsMenu:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
