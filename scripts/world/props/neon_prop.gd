class_name NeonProp
extends Prop
## Neon sign: normally hums with the odd stutter. A ball strike shorts it
## out: sparks, a zap, a jolt, and a few seconds of sputtering darkness.

const SPARK := preload("res://assets/textures/spark.png")

@export var stutter_chance := 0.18

var _timer := 0.0
var _dark := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = hash(global_position)
	_timer = _rng.randf_range(1.0, 5.0)


func react(_ball_pos: Vector2, ball_vel: Vector2) -> void:
	Sfx.play("zap", -6.0)
	burst(self, Vector2.ZERO, SPARK, 3, 14, -ball_vel.normalized().rotated(_rng.randf_range(-0.5, 0.5)), 140.0, true, 0.5)
	_dark = _rng.randf_range(1.5, 3.0)
	_set_lit(false)
	var tw := create_tween()
	tw.tween_property($Sign, "rotation", signf(ball_vel.x) * 0.12, 0.05)
	tw.tween_property($Sign, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func rumble(_from: Vector2, strength: float) -> void:
	if strength > 0.5:
		_set_lit(false)
		_timer = _rng.randf_range(0.05, 0.2)


func update(delta: float) -> void:
	if _dark > 0.0:
		_dark -= delta
		# Sputters while it recovers.
		if _rng.randf() < 0.04:
			_set_lit($Sign.frame == 1)
		if _dark <= 0.0:
			_set_lit(true)
			_timer = _rng.randf_range(1.5, 4.0)
		return
	_timer -= delta
	if _timer > 0.0:
		return
	if $Sign.frame == 1:
		_set_lit(true)
		_timer = _rng.randf_range(1.5, 6.0)
	elif _rng.randf() < stutter_chance:
		_set_lit(false)
		_timer = _rng.randf_range(0.04, 0.16)
	else:
		_timer = _rng.randf_range(0.5, 2.0)


func _set_lit(lit: bool) -> void:
	$Sign.frame = 0 if lit else 1
	$Glow.visible = lit
