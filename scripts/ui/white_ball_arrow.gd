class_name WhiteBallArrow
extends Control
## Hardcore: when the white ball is on another screen, a pixel arrow at the
## top or bottom edge points to it, with how many screens away it is.

var target_x := 256.0
var screens_away := 0     # positive = above, negative = below
var _t := 0.0
var _label: Label


func _ready() -> void:
	theme = UIKit.theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(512, 288)
	_label = Label.new()
	_label.add_theme_color_override("font_color", Color("f4eedc"))
	add_child(_label)


func _process(delta: float) -> void:
	_t += delta
	visible = screens_away != 0
	if not visible:
		return
	var x := clampf(target_x, 14.0, 498.0)
	var up := screens_away > 0
	_label.text = str(absi(screens_away))
	_label.position = Vector2(roundf(x) + 9.0, 1.0 if up else 278.0)
	queue_redraw()


func _draw() -> void:
	if screens_away == 0:
		return
	var x := roundf(clampf(target_x, 14.0, 498.0))
	var bob := roundf(sin(_t * 5.0) * 1.5)
	var up := screens_away > 0
	var tip_y: float = (3.0 - bob) if up else (285.0 + bob)
	var dir := 1.0 if up else -1.0
	# Outline then fill: a 9px-wide arrowhead.
	for row in 7:
		var half := row + 1
		var y: float = tip_y + dir * row
		draw_rect(Rect2(x - half - 1, y - 1, half * 2 + 2, 3), Color("11090c"))
	for row in 6:
		var half := row
		var y: float = tip_y + dir * (row + 1)
		draw_rect(Rect2(x - half, y, half * 2 + 1, 1), Color("f4eedc") if row < 5 else Color("c8c4bc"))
