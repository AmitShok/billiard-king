class_name KnockProp
extends Prop
## A loose thing on a ledge (a chalk cube, a triangle rack). The ball knocks
## it flying; it tumbles, lands on whatever terrain is below and stays there.
## It reads the terrain to land, but the ball never feels it.

const GRAVITY := 800.0

@export var half_size := Vector2(3, 3)   # visual half extents for landing
@export var heavy := false               # racks clatter, chalk ticks

var vel := Vector2.ZERO
var airborne := false
var _spin := 0.0
var _fallen := 0.0


func react(_ball_pos: Vector2, ball_vel: Vector2) -> void:
	vel = ball_vel * (0.35 if heavy else 0.6) + Vector2(0, -90.0 if heavy else -130.0)
	_spin = ball_vel.x * (0.02 if heavy else 0.06)
	airborne = true
	_noise(ball_vel.length())


func rumble(_from: Vector2, strength: float) -> void:
	if not airborne and strength > 0.45:
		vel = Vector2(randf_range(-30.0, 30.0), -70.0 * strength)
		_spin = randf_range(-4.0, 4.0) * strength
		airborne = true


func update(delta: float) -> void:
	if not airborne or world == null:
		return
	var dt := minf(delta, 1.0 / 30.0)
	vel.y = minf(vel.y + GRAVITY * dt, 500.0)
	var next := position + vel * dt
	_fallen += maxf(vel.y * dt, 0.0)
	# Sides first, then the floor under the prop.
	var side := Vector2(signf(vel.x) * half_size.x, 0)
	if vel.x != 0.0 and world.is_solid_point(next + side):
		vel.x = -vel.x * 0.3
		next.x = position.x
	var foot := next + Vector2(0, half_size.y)
	if vel.y > 0.0 and world.is_solid_point(foot):
		# Settle on top of the solid cell.
		while world.is_solid_point(next + Vector2(0, half_size.y)) and next.y > position.y - 16.0:
			next.y -= 1.0
		if vel.y > 120.0:
			_noise(vel.y)
		vel.y = -vel.y * 0.25
		vel.x *= 0.55
		_spin *= 0.5
		if absf(vel.y) < 40.0:
			vel = Vector2.ZERO
			airborne = false
			rotation = 0.0
	position = next
	if airborne:
		rotation += _spin * dt
	# A shot off the side of the tower: give up after a long drop.
	if _fallen > 1200.0:
		airborne = false
		hide()


func _noise(speed: float) -> void:
	var loud := clampf(speed / 400.0, 0.0, 1.0)
	if heavy:
		Sfx.play("clatter", lerpf(-18.0, -8.0, loud))
	else:
		Sfx.play("aim_tick", lerpf(-16.0, -6.0, loud), 0.8)
