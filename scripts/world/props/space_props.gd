class_name SpaceProp
extends Prop
## Low-gravity decor: asteroids that drift off when bumped and float home, a
## satellite that spins up when struck, and a flag that ripples. Purely
## cosmetic, like every Prop: the ball passes through and never feels them.

enum Style { ASTEROID, SATELLITE, FLAG }

const ASTEROID := preload("res://assets/textures/asteroid.png")
const SATELLITE := preload("res://assets/textures/satellite.png")
const FLAG := preload("res://assets/textures/moon_flag.png")

@export var style := Style.ASTEROID

var _home := Vector2.ZERO
var _drift := Vector2.ZERO
var _spin := 0.0
var _t := 0.0
var _wave := 0.0
var _sprite: Sprite2D


func _ready() -> void:
	_home = position
	_t = fposmod(global_position.x * 0.17 + global_position.y * 0.05, 9.0)
	_sprite = Sprite2D.new()
	add_child(_sprite)
	match style:
		Style.ASTEROID:
			_sprite.texture = ASTEROID
			_sprite.hframes = 3
			_sprite.frame = absi(int(global_position.x + global_position.y)) % 3
			hit_size = Vector2(26, 22)
			_spin = 0.15 * (1.0 if int(global_position.x) % 2 == 0 else -1.0)
		Style.SATELLITE:
			_sprite.texture = SATELLITE
			hit_size = Vector2(36, 18)
			_spin = 0.3
		Style.FLAG:
			_sprite.texture = FLAG
			_sprite.hframes = 3
			hit_size = Vector2(26, 30)


func react(_ball_pos: Vector2, ball_vel: Vector2) -> void:
	match style:
		Style.ASTEROID:
			_drift += ball_vel * 0.35
			_spin += ball_vel.x * 0.012 + 0.6
			Sfx.play("rail", -18.0, 0.8)
		Style.SATELLITE:
			_spin += signf(ball_vel.x if ball_vel.x != 0.0 else 1.0) * clampf(ball_vel.length() / 40.0, 3.0, 12.0)
			Sfx.play("chime", -14.0, 1.4)
		Style.FLAG:
			_wave = 1.0
			Sfx.play("aim_tick", -14.0, 0.7)


func rumble(_from: Vector2, strength: float) -> void:
	if style == Style.ASTEROID:
		_drift += Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0)) * strength
	elif style == Style.FLAG:
		_wave = maxf(_wave, strength)


func update(delta: float) -> void:
	_t += delta
	var dt := minf(delta, 1.0 / 30.0)
	match style:
		Style.ASTEROID, Style.SATELLITE:
			# A weak spring home; no gravity to speak of, so everything is slow.
			var bob := Vector2(sin(_t * 0.5) * 2.0, sin(_t * 0.8) * 3.0)
			var to_home := _home + bob - position
			_drift += to_home * 0.5 * dt
			_drift = _drift.move_toward(Vector2.ZERO, 14.0 * dt)
			position += _drift * dt
			_sprite.rotation += _spin * dt
			var rest := 0.3 if style == Style.SATELLITE else 0.15
			_spin = move_toward(_spin, signf(_spin) * rest, 2.0 * dt)
		Style.FLAG:
			_wave = move_toward(_wave, 0.0, dt * 0.5)
			_sprite.frame = int(_t * (1.5 + _wave * 10.0)) % 3
