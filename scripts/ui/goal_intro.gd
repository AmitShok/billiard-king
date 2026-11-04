class_name GoalIntro
extends Control
## Short pop-up shown when a new climb starts, stating the goal. Holds the
## game paused until dismissed, and closes on *release* so the press that
## dismisses it can't also start a charge.

signal dismissed

var _ready_for_input := false
var _ball: BallVisual


## title: heading; lines: one or two short lines; ball: skin number to show.
func setup(title: String, lines: String, ball: int) -> GoalIntro:
	set_meta("title", title)
	set_meta("lines", lines)
	set_meta("ball", ball)
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.02, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := UIKit.panel(self, Vector2(220, 0))
	UIKit.heading(box, get_meta("title", "Goal"))
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 22)
	box.add_child(holder)
	_ball = BallVisual.new()
	_ball.number = get_meta("ball", 0)
	_ball.diameter = 18
	holder.add_child(_ball)
	# Keep the ball centred however wide the panel ends up.
	holder.resized.connect(func(): _ball.position = Vector2(roundf(holder.size.x / 2.0), 11))
	UIKit.label(box, get_meta("lines", ""), Color("f2d27a"))
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
