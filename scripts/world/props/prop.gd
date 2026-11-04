class_name Prop
extends Node2D
## Decor the ball can disturb, purely for feel. Props only *read* the ball's
## position and velocity (Game calls poke() while they overlap and rumble()
## after heavy impacts nearby). They never write to the ball, never enter
## the CollisionWorld, and never affect a trajectory.

@export var hit_size := Vector2(16, 16)
@export var hit_offset := Vector2.ZERO
@export var min_speed := 50.0

## Read-only terrain, for props that can fall and land.
var world: CollisionWorld

var _cooldown := 0.0


func touches(ball_pos: Vector2, radius: float) -> bool:
	var r := Rect2(global_position + hit_offset - hit_size / 2.0, hit_size).grow(radius)
	return r.has_point(ball_pos)


## The ball is overlapping this prop.
func poke(ball_pos: Vector2, ball_vel: Vector2) -> void:
	if _cooldown > 0.0 or ball_vel.length() < min_speed:
		return
	_cooldown = 0.25
	react(ball_pos, ball_vel)


## Override: the ball struck this prop.
func react(_ball_pos: Vector2, _ball_vel: Vector2) -> void:
	pass


## Override: something landed hard nearby (strength 0..1).
func rumble(_from: Vector2, _strength: float) -> void:
	pass


## Override: the wind blowing on this screen right now.
func feel_wind(_wind: Vector2) -> void:
	pass


## Override instead of _process.
func update(_delta: float) -> void:
	pass


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	update(delta)


static func burst(parent: Node, at: Vector2, tex: Texture2D, frames: int, count: int, dir: Vector2, speed: float, additive: bool, life: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = count
	p.lifetime = life
	p.texture = tex
	p.direction = dir
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 520)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	var m := CanvasItemMaterial.new()
	m.particles_animation = true
	m.particles_anim_h_frames = frames
	m.particles_anim_v_frames = 1
	if additive:
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	p.anim_offset_max = 1.0
	p.z_index = 3
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p
