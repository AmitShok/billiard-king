class_name TiltProp
extends Prop
## Something hung on a nail (a portrait, a wall clock). The node sits at the
## nail; a knock swings it like a damped spring. Portraits can end up
## hanging crooked; clocks chime.

const STIFFNESS := 60.0
const DAMPING := 5.0

@export var crooked := true
@export var chime := false

var rest := 0.0
var _ang := 0.0
var _vel := 0.0


func react(ball_pos: Vector2, ball_vel: Vector2) -> void:
	# Hitting below the nail swings it toward the ball's direction of travel.
	var lever := clampf((ball_pos.y - global_position.y) / maxf(hit_size.y, 1.0), 0.2, 1.0)
	_vel += ball_vel.x * 0.012 * lever + randf_range(-0.6, 0.6)
	if crooked:
		rest = clampf(rest + randf_range(-0.12, 0.12) + signf(ball_vel.x) * 0.04, -0.22, 0.22)
	if chime:
		Sfx.play("chime", -10.0)
	else:
		Sfx.play("rail", -18.0, 1.3)


func rumble(_from: Vector2, strength: float) -> void:
	_vel += randf_range(-1.0, 1.0) * strength * 2.0
	if crooked and strength > 0.6:
		rest = clampf(rest + randf_range(-0.05, 0.05), -0.22, 0.22)


func feel_wind(wind: Vector2) -> void:
	_vel += wind.x * 0.0008


func update(delta: float) -> void:
	var dt := minf(delta, 1.0 / 30.0)
	_vel += (-STIFFNESS * (_ang - rest) - DAMPING * _vel) * dt
	_ang += _vel * dt
	rotation = _ang
