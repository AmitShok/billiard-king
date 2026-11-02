class_name WindowProp
extends Prop
## A night window. A fast ball smashes it (glass bursts out along the ball's
## path and tinkles down); it stays broken for the rest of the climb.
## Slower brushes only tick the glass.

const SHARD := preload("res://assets/textures/glass_shard.png")
const BREAK_SPEED := 170.0

var broken := false


func _ready() -> void:
	hit_size = Vector2(36, 46)


func react(ball_pos: Vector2, ball_vel: Vector2) -> void:
	if broken:
		return
	if ball_vel.length() < BREAK_SPEED:
		Sfx.play("tinkle", -22.0, 1.4)
		_wobble(0.5)
		return
	smash(ball_vel)


func smash(ball_vel: Vector2 = Vector2(0, 200), quiet := false) -> void:
	if broken:
		return
	broken = true
	$Glass.frame = 1
	if quiet:
		return
	SaveData.mark_broken(String(name))
	Sfx.play("glass_break", -2.0)
	var dir := ball_vel.normalized() if ball_vel.length() > 1.0 else Vector2.DOWN
	burst(self, Vector2.ZERO, SHARD, 4, 26, dir, 160.0 + ball_vel.length() * 0.3, false, 1.4)
	burst(self, Vector2(0, 10), SHARD, 4, 10, Vector2.DOWN, 40.0, false, 1.2)
	_wobble(1.0)


func _wobble(amount: float) -> void:
	var tw := create_tween()
	tw.tween_property($Glass, "position", Vector2(amount, 0), 0.04)
	tw.tween_property($Glass, "position", Vector2(-amount, 0), 0.06)
	tw.tween_property($Glass, "position", Vector2.ZERO, 0.08)
