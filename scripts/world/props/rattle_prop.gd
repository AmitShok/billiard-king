class_name RattleProp
extends Prop
## A wall-mounted cue rack: the cues knock and shiver when the ball clips it.

var _shake := 0.0
var _t := 0.0


func react(_ball_pos: Vector2, ball_vel: Vector2) -> void:
	_shake = clampf(_shake + ball_vel.length() / 300.0, 0.0, 2.0)
	Sfx.play("clatter", lerpf(-16.0, -4.0, clampf(ball_vel.length() / 500.0, 0.0, 1.0)))


func rumble(_from: Vector2, strength: float) -> void:
	_shake = maxf(_shake, strength)
	if strength > 0.5:
		Sfx.play("clatter", -20.0)


func update(delta: float) -> void:
	_t += delta
	_shake = move_toward(_shake, 0.0, delta * 2.5)
	$Body.position = Vector2(round(sin(_t * 70.0) * _shake), 0)
	$Body.rotation = sin(_t * 53.0) * _shake * 0.02
