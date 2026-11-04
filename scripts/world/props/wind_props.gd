class_name WindProp
extends Prop
## Decor that reads the wind: a sock on a pole, a string of bunting, or a
## weather vane. They show which way the gust is blowing and how hard, and
## the ball can knock them about. Purely cosmetic, like every Prop.

enum Style { SOCK, BUNTING, VANE }

const VANE_TEX := preload("res://assets/textures/vane.png")
const SOCK_A := Color("f4eedc")
const SOCK_B := Color("1f7a48")
const POLE := Color("8c6a28")
const INK := Color("11090c")
const PENNANTS := [Color("f0b92c"), Color("2f56c4"), Color("1f7a48"), Color("f4eedc")]
const GUST_FULL := 280.0

@export var style := Style.SOCK

var _wind := Vector2.ZERO        # smoothed
var _angle := PI / 2.0           # sock and vane heading
var _kick := 0.0                 # extra flutter after a knock
var _t := 0.0
var _arrow: Sprite2D


func _ready() -> void:
	_t = fposmod(global_position.x * 0.13, 7.0)
	match style:
		Style.SOCK:
			hit_size = Vector2(36, 28)
			hit_offset = Vector2(0, 12)
		Style.BUNTING:
			hit_size = Vector2(100, 24)
		Style.VANE:
			hit_size = Vector2(32, 34)
			var post := Sprite2D.new()
			post.texture = VANE_TEX
			post.hframes = 2
			add_child(post)
			_arrow = Sprite2D.new()
			_arrow.texture = VANE_TEX
			_arrow.hframes = 2
			_arrow.frame = 1
			add_child(_arrow)


func react(_ball_pos: Vector2, ball_vel: Vector2) -> void:
	_kick = clampf(_kick + ball_vel.length() / 300.0, 0.0, 2.0)
	_angle += signf(ball_vel.x if ball_vel.x != 0.0 else 1.0) * 0.8
	Sfx.play("aim_tick", -14.0, 0.7)


func rumble(_from: Vector2, strength: float) -> void:
	_kick = maxf(_kick, strength * 0.7)


func feel_wind(wind: Vector2) -> void:
	_wind = wind


func update(delta: float) -> void:
	_t += delta
	_kick = move_toward(_kick, 0.0, delta * 1.5)
	var strength := clampf(_wind.length() / GUST_FULL, 0.0, 1.0)
	if style == Style.VANE:
		# Weather vanes turn into the wind and keep their last heading in a calm.
		if strength > 0.05:
			_angle = lerp_angle(_angle, _wind.angle(), 1.0 - exp(-delta * (1.0 + strength * 5.0)))
		_arrow.rotation = _angle + sin(_t * 14.0) * 0.12 * _kick
		return
	if style == Style.SOCK:
		# Droops straight down in a calm, streams out along the wind in a gust.
		var target := PI / 2.0
		if strength > 0.05:
			target = lerp_angle(PI / 2.0, _wind.angle(), minf(strength * 2.0, 1.0))
		_angle = lerp_angle(_angle, target, 1.0 - exp(-delta * 4.0))
	queue_redraw()


func _draw() -> void:
	match style:
		Style.SOCK:
			_draw_sock()
		Style.BUNTING:
			_draw_bunting()


func _draw_sock() -> void:
	draw_rect(Rect2(-1, -2, 2, 30), INK)
	draw_rect(Rect2(0, -1, 1, 28), POLE)
	var strength := clampf(_wind.length() / GUST_FULL, 0.0, 1.0)
	var flutter := sin(_t * (6.0 + strength * 14.0)) * (0.05 + strength * 0.14 + _kick * 0.25)
	var dir := Vector2.from_angle(_angle)
	var perp := Vector2(-dir.y, dir.x)
	var length := int(12.0 + strength * 10.0)
	for i in length:
		var bend := sin(_t * 9.0 + i * 0.5) * flutter * i
		var half := roundi(lerpf(3.5, 1.5, float(i) / length))
		var col := SOCK_A if (i / 4) % 2 == 0 else SOCK_B
		for w in range(-half - 1, half + 2):
			var c := INK if absi(w) > half else col
			draw_rect(Rect2((dir * i + perp * (bend + w)).round(), Vector2.ONE), c)


func _draw_bunting() -> void:
	var count := 8
	var strength := clampf(_wind.length() / GUST_FULL, 0.0, 1.0)
	var swing := _wind.normalized() * strength * 7.0 if _wind.length() > 1.0 else Vector2.ZERO
	var points: Array[Vector2] = []
	for i in count + 1:
		var u := float(i) / count
		var sag := sin(u * PI) * (10.0 - strength * 4.0)
		var ripple := sin(_t * (3.0 + strength * 9.0) + i * 0.9) * (0.5 + strength * 2.0 + _kick * 3.0)
		points.append(Vector2(lerpf(-48.0, 48.0, u), sag + ripple * sin(u * PI)) + swing * sin(u * PI))
	for i in count:
		var a := points[i]
		var b := points[i + 1]
		for s in 13:
			draw_rect(Rect2(a.lerp(b, s / 12.0).round(), Vector2.ONE), INK)
		var mid := a.lerp(b, 0.5)
		var tip_x := swing.x * 0.8 + sin(_t * (4.0 + strength * 12.0) + i) * (1.0 + strength * 2.0 + _kick * 2.0)
		var tip := mid + Vector2(tip_x, 9.0 + swing.y * 0.5)
		var col: Color = PENNANTS[i % PENNANTS.size()]
		for r in 9:
			var v := r / 8.0
			var l := a.lerp(b, 0.1).lerp(tip, v)
			var q := a.lerp(b, 0.9).lerp(tip, v)
			var steps := int(l.distance_to(q)) + 1
			for s in steps + 1:
				draw_rect(Rect2(l.lerp(q, float(s) / steps).round(), Vector2.ONE), col)
		draw_rect(Rect2(tip.round(), Vector2.ONE), INK)
