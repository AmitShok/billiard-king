@tool
class_name Bumper
extends Node2D
## A giant numbered ball pinned in a brass collar: Fallosophy's pinball
## bumper, billiard-style. Kicks the cue ball away and spins when struck.

const RING := preload("res://assets/textures/bumper_ring.png")
const RADIUS := 12.0

@export_range(1, 15) var number: int = 8:
	set(v):
		number = v
		if _ball:
			_ball.number = v

var _ball: BallVisual
var _spin := 0.0
var _tumble := 0.0


func _ready() -> void:
	var ring := Sprite2D.new()
	ring.texture = RING
	ring.z_index = -1
	add_child(ring)
	_ball = BallVisual.new()
	_ball.diameter = 24
	_ball.number = number
	add_child(_ball)


func hit(normal: Vector2) -> void:
	_spin += -normal.x * 14.0
	_tumble += normal.y * 10.0
	_ball.flash = 0.8
	var tw := create_tween()
	tw.tween_property(_ball, "scale", Vector2(1.18, 1.18), 0.05)
	tw.tween_property(_ball, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)


func _process(delta: float) -> void:
	if _ball == null:
		return
	_ball.roll(_spin + 0.25, _tumble, delta)
	_spin = move_toward(_spin, 0.0, delta * 6.0)
	_tumble = move_toward(_tumble, 0.0, delta * 6.0)
	_ball.flash = move_toward(_ball.flash, 0.0, delta * 3.0)
