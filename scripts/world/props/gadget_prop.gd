class_name GadgetProp
extends Prop
## Machinery decor for the observatory, station and bell tower: a telescope
## that slowly scans the sky, an orrery with orbiting planets, a console with
## blinking lights, and a turning gear. Each reacts when the ball clips it.
## Purely cosmetic, like every Prop.

enum Style { TELESCOPE, ORRERY, CONSOLE, GEAR }

const TELESCOPE := preload("res://assets/textures/telescope.png")
const ORRERY := preload("res://assets/textures/orrery.png")
const CONSOLE := preload("res://assets/textures/console.png")
const GEAR := preload("res://assets/textures/gear.png")
const SPARK := preload("res://assets/textures/spark_blue.png")
const PLANETS := [[7.0, Color("6ae8a8"), 1.6], [11.0, Color("6af0ff"), 1.0], [14.0, Color("f4eedc"), 0.6]]

@export var style := Style.TELESCOPE

var _spin := 0.0       # gear / orrery speed, telescope swing
var _angle := 0.0
var _t := 0.0
var _tube: Sprite2D
var _body: Sprite2D


func _ready() -> void:
	_t = fposmod(global_position.x * 0.11, 6.0)
	_body = Sprite2D.new()
	add_child(_body)
	match style:
		Style.TELESCOPE:
			_body.texture = TELESCOPE
			_body.hframes = 2
			_tube = Sprite2D.new()
			_tube.texture = TELESCOPE
			_tube.hframes = 2
			_tube.frame = 1
			add_child(_tube)
			hit_size = Vector2(34, 30)
			_angle = -0.6
		Style.ORRERY:
			_body.texture = ORRERY
			hit_size = Vector2(32, 30)
			_spin = 1.0
		Style.CONSOLE:
			_body.texture = CONSOLE
			_body.hframes = 2
			hit_size = Vector2(32, 20)
		Style.GEAR:
			_body.texture = GEAR
			hit_size = Vector2(24, 24)
			_spin = 0.6


func react(_ball_pos: Vector2, ball_vel: Vector2) -> void:
	var push := signf(ball_vel.x if ball_vel.x != 0.0 else 1.0)
	match style:
		Style.TELESCOPE:
			_spin += push * clampf(ball_vel.length() / 120.0, 1.0, 4.0)
			Sfx.play("rail", -16.0, 1.4)
		Style.ORRERY:
			_spin += push * clampf(ball_vel.length() / 60.0, 2.0, 9.0)
			Sfx.play("chime", -16.0, 1.6)
		Style.CONSOLE:
			burst(self, Vector2(0, -2), SPARK, 3, 10, -ball_vel.normalized(), 110.0, true, 0.5)
			Sfx.play("aim_tick", -8.0, 1.8)
			_spin = 1.0
		Style.GEAR:
			_spin += push * clampf(ball_vel.length() / 50.0, 2.0, 10.0)
			Sfx.play("clatter", -14.0, 0.8)


func rumble(_from: Vector2, strength: float) -> void:
	_spin += randf_range(-1.0, 1.0) * strength * 2.0


func update(delta: float) -> void:
	_t += delta
	var dt := minf(delta, 1.0 / 30.0)
	match style:
		Style.TELESCOPE:
			# Slowly scans back and forth; a knock sets it swinging.
			var scan := -0.6 + sin(_t * 0.25) * 0.35
			_spin += (scan - _angle) * 4.0 * dt - _spin * 2.0 * dt
			_angle += _spin * dt
			_tube.rotation = _angle
		Style.ORRERY:
			_spin = move_toward(_spin, 1.0, dt * 0.8)
			_angle += _spin * dt
			queue_redraw()
		Style.CONSOLE:
			_spin = move_toward(_spin, 0.0, dt)
			var rate := 2.0 + _spin * 18.0
			_body.frame = int(_t * rate) % 2
		Style.GEAR:
			_spin = move_toward(_spin, 0.6, dt * 1.2)
			_body.rotation += _spin * dt


func _draw() -> void:
	if style != Style.ORRERY:
		return
	for p: Array in PLANETS:
		var r: float = p[0]
		var ang: float = _angle * p[2] + r
		var pos: Vector2 = Vector2(cos(ang), sin(ang) * 0.45) * r + Vector2(0, -2)
		for a in 12:
			var t: float = a * TAU / 12.0
			var orbit: Vector2 = (Vector2(cos(t), sin(t) * 0.45) * r + Vector2(0, -2)).round()
			draw_rect(Rect2(orbit, Vector2.ONE), Color(0.6, 0.5, 0.25, 0.5))
		draw_rect(Rect2(pos.round() - Vector2.ONE, Vector2(3, 3)), Color("11090c"))
		draw_rect(Rect2(pos.round(), Vector2(2, 2)), p[1])
