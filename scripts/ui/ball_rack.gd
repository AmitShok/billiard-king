class_name BallRack
extends Control
## Choose which ball you climb as. Balls 1-10 are lost in The Tower and 17-26
## in The Long Rack; the rest are awarded for finished climbs.

signal closed

const HINTS := {
	11: "Finish the climb",
	12: "Finish in under 400 strokes",
	13: "Finish in under 30 minutes",
	14: "Finish with 10 falls or fewer",
	15: "Finish holding lost balls 1-10",
	16: "Finish Hardcore mode",
	27: "Finish The Long Rack on Hardcore",
}
const NAMES := {
	16: "The white ball", 17: "Chalk", 18: "Neon", 19: "Checker", 20: "Tournament", 21: "Marble",
	22: "Ember", 23: "Ocean", 24: "Night", 25: "Gold", 26: "Moon", 27: "The rainbow ball",
}
const TOTAL := 27


## "Ball #3", "Chalk", ...
static func display_name(n: int) -> String:
	return NAMES.get(n, "Ball #%d" % n)

var _info: Label
var _buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := UIKit.panel(self, Vector2(300, 0))
	UIKit.heading(box, "Ball Rack")
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	for n in TOTAL + 1:
		var b := Button.new()
		b.custom_minimum_size = Vector2(26, 26)
		b.focus_mode = Control.FOCUS_ALL
		var unlocked := n == 0 or SaveData.collected.has(n)
		var ball := BallVisual.new()
		ball.number = n
		ball.diameter = 18
		ball.position = Vector2(13, 13)
		if not unlocked:
			ball.modulate = Color(0.08, 0.06, 0.08, 1)
		b.add_child(ball)
		b.mouse_entered.connect(b.grab_focus)
		b.focus_entered.connect(_on_focus.bind(n, ball))
		b.pressed.connect(_on_pick.bind(n))
		grid.add_child(b)
		_buttons.append(b)
	_info = UIKit.label(box, "")
	_info.custom_minimum_size = Vector2(0, 20)
	UIKit.label(box, "Found %d of %d" % [SaveData.collected.size(), TOTAL], Color("8a8070"))
	var back := UIKit.button(box, "Back", close)
	for b in _buttons:
		b.focus_neighbor_bottom = b.get_path_to(back) if _buttons.find(b) >= 20 else NodePath()
	back.focus_neighbor_top = back.get_path_to(_buttons[20])
	_buttons[SaveData.skin].grab_focus.call_deferred()


func _on_focus(n: int, ball: BallVisual) -> void:
	Sfx.play("ui_move", -6.0, 1.0, 0.0)
	var unlocked := n == 0 or SaveData.collected.has(n)
	if n == 0:
		_info.text = "The cue ball\nThe original climber"
	elif unlocked:
		_info.text = "%s%s" % [display_name(n), "\nIn play" if SaveData.skin == n else "\nPress to climb with it"]
	elif n <= 10:
		_info.text = "Ball #%d is lost\nsomewhere in The Tower" % n
	elif n >= 17 and n <= 26:
		_info.text = "%s is lost\nsomewhere in The Long Rack" % display_name(n)
	else:
		_info.text = "%s\n%s" % [display_name(n), HINTS[n]]
	var tw := create_tween()
	tw.tween_property(ball, "scale", Vector2(1.2, 1.2), 0.06)
	tw.tween_property(ball, "scale", Vector2.ONE, 0.12)


func _on_pick(n: int) -> void:
	if n != 0 and not SaveData.collected.has(n):
		Sfx.play("ui_back", -6.0, 0.8, 0.0)
		return
	SaveData.skin = n
	SaveData.save()
	Sfx.play("clack", -4.0)
	_on_focus(n, _buttons[n].get_child(0))


func _process(delta: float) -> void:
	for b in _buttons:
		var ball: BallVisual = b.get_child(0)
		var on := b.has_focus()
		ball.roll(2.4 if on else 0.4, 1.2 if on else 0.0, delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	Sfx.play("ui_back", -4.0, 1.0, 0.0)
	closed.emit()
	queue_free()
