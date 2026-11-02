@tool
class_name LostBall
extends Node2D
## One of the fifteen numbered balls lost in the tower (Ballgame's collection,
## billiard-style). Finding it unlocks that ball as a skin in the Ball Rack.

const GLOW := preload("res://assets/textures/glow.png")

@export_range(1, 15) var number: int = 1:
	set(v):
		number = v
		if _ball:
			_ball.number = v

var taken := false
var _ball: BallVisual
var _glow: Sprite2D
var _t := 0.0


func _ready() -> void:
	_glow = Sprite2D.new()
	_glow.texture = GLOW
	_glow.scale = Vector2(0.55, 0.55)
	_glow.modulate = Color(1.0, 0.9, 0.6, 0.6)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	add_child(_glow)
	_ball = BallVisual.new()
	_ball.diameter = 12
	_ball.number = number
	add_child(_ball)
	_t = number * 0.7


func collect() -> void:
	if taken:
		return
	taken = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_ball, "position", Vector2(0, -26), 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tw.chain().tween_callback(hide)


func _process(delta: float) -> void:
	if _ball == null or taken:
		return
	_t += delta
	_ball.position.y = round(sin(_t * 2.2) * 2.0)
	_ball.roll(1.6, 0.0, delta)
	_glow.modulate.a = 0.45 + 0.15 * sin(_t * 3.0)
