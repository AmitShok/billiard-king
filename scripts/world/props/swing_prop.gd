class_name SwingProp
extends Prop
## A billiard lamp or chandelier hanging from the ceiling. The node sits at
## the hook; chain, body and light are children, so the whole thing swings
## as a damped pendulum when the ball clips it.

const GRAVITY := 900.0
const DAMPING := 0.8
const MAX_SPIN := 3.2

@export var length := 60.0
@export var crystal := false   # chandeliers tinkle, lamps clink

var angle := 0.0
var spin := 0.0
var _wind_x := 0.0


func touches(ball_pos: Vector2, radius: float) -> bool:
	var dir := Vector2.DOWN.rotated(angle)
	var body := global_position + dir * length
	if ball_pos.distance_to(body) < radius + (16.0 if crystal else 14.0):
		return true
	var on_chain := Geometry2D.get_closest_point_to_segment(ball_pos, global_position, body)
	return ball_pos.distance_to(on_chain) < radius + 2.0


func react(ball_pos: Vector2, ball_vel: Vector2) -> void:
	# Push along the swing's tangent, more the further down the ball strikes.
	var dir := Vector2.DOWN.rotated(angle)
	var tangent := Vector2(-dir.y, dir.x)
	var reach := clampf((ball_pos - global_position).dot(dir) / length, 0.3, 1.0)
	spin = clampf(spin + ball_vel.dot(tangent) * reach * 0.9 / length, -MAX_SPIN, MAX_SPIN)
	var loud := clampf(ball_vel.length() / 500.0, 0.0, 1.0)
	if crystal:
		Sfx.play("tinkle", lerpf(-16.0, -4.0, loud))
	else:
		Sfx.play("clack", lerpf(-22.0, -10.0, loud), 0.7)


func rumble(_from: Vector2, strength: float) -> void:
	spin = clampf(spin + randf_range(-1.0, 1.0) * strength * 1.4 * sqrt(60.0 / length), -MAX_SPIN, MAX_SPIN)
	if crystal and strength > 0.4:
		Sfx.play("tinkle", -20.0 + strength * 6.0)


func feel_wind(wind: Vector2) -> void:
	_wind_x = wind.x


func update(delta: float) -> void:
	var dt := minf(delta, 1.0 / 30.0)
	var accel := -(GRAVITY / length) * sin(angle) - DAMPING * spin + _wind_x / length * cos(angle)
	spin += accel * dt
	angle += spin * dt
	if absf(angle) < 0.0005 and absf(spin) < 0.0005:
		angle = 0.0
		spin = 0.0
	rotation = angle
