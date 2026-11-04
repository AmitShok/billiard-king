class_name HardcoreIntro
extends Control
## Pop-up shown when a Hardcore climb starts: explains the goal and holds
## the game paused until dismissed. It closes on *release* so the press that
## dismisses it can't also start a charge.

signal dismissed

var _ready_for_input := false
var _ball: BallVisual


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.02, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := UIKit.panel(self, Vector2(260, 0))
	UIKit.heading(box, "Hardcore")
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 22)
	box.add_child(holder)
	_ball = BallVisual.new()
	_ball.number = 16
	_ball.diameter = 18
	holder.add_child(_ball)
	# Keep the ball centred however wide the panel ends up.
	holder.resized.connect(func(): _ball.position = Vector2(roundf(holder.size.x / 2.0), 11))
	UIKit.label(box, "A white ball floats above you.\nIt has no gravity: it stops wherever it slows down.")
	UIKit.label(box, "Push it with your ball, all the way up the tower,\nand sink it in the gold pocket at the very top.", Color("f2d27a"))
	UIKit.label(box, "If it drops into a pocket, the ball return sends it down.\nLost it? Pause and re-rack it.", Color("a89e8a"))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 2)
	box.add_child(gap)
	var hint := UIKit.label(box, "Press to begin", Color("8a8070"))
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.25)
	tw.tween_interval(0.35)
	tw.tween_callback(func(): _ready_for_input = true)
	var blink := create_tween().set_loops()
	blink.tween_property(hint, "modulate:a", 0.35, 0.7)
	blink.tween_property(hint, "modulate:a", 1.0, 0.7)
	get_tree().paused = true
	Sfx.play("ui_accept", -6.0, 0.9, 0.0)


func _process(delta: float) -> void:
	_ball.roll(1.4, 0.8, delta)


func _input(event: InputEvent) -> void:
	if not _ready_for_input:
		return
	for action in ["charge", "ui_accept", "pause"]:
		if event.is_action_released(action):
			get_viewport().set_input_as_handled()
			dismiss()
			return


func dismiss() -> void:
	if not is_inside_tree():
		return
	_ready_for_input = false
	get_tree().paused = false
	Sfx.play("ui_accept", -4.0, 1.0, 0.0)
	dismissed.emit()
	queue_free()
