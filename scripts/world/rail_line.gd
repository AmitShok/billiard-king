extends Node2D
## A dotted rail showing where a moving platform or spike ball travels.

var from := Vector2.ZERO
var to := Vector2.ZERO
var color := Color.WHITE


func _draw() -> void:
	var length := from.distance_to(to)
	if length < 1.0:
		return
	var dir := (to - from) / length
	var d := 0.0
	while d <= length:
		var p := (from + dir * d).round()
		draw_rect(Rect2(p - Vector2.ONE, Vector2(3, 3)), Color(0.05, 0.03, 0.03, 0.8))
		draw_rect(Rect2(p, Vector2(1, 1)), color)
		draw_rect(Rect2(p + Vector2(0, 1), Vector2(1, 1)), color.darkened(0.3))
		d += 6.0
	for end in [from, to]:
		var e: Vector2 = end.round()
		draw_rect(Rect2(e - Vector2(2, 2), Vector2(5, 5)), Color(0.05, 0.03, 0.03, 0.9))
		draw_rect(Rect2(e - Vector2(1, 1), Vector2(3, 3)), color)
