class_name CheckpointFlag
extends Prop
## Training mode checkpoint: a brass pole with a felt pennant, planted where
## the ball rests. The pennant waves column by column, streams out with the
## wind (and lifts in an updraft), flutters when a ball goes by, and glows
## while it is the flag you'd return to. Purely cosmetic, like every Prop.

const POLE := preload("res://assets/textures/flag_pole.png")
const CLOTH := preload("res://assets/textures/flag_cloth.png")
const SPARK := preload("res://assets/textures/spark_green.png")
const CLOTH_W := 16
const CLOTH_H := 10
const POLE_H := 30
const GLOW := Color(0.35, 1.0, 0.55)

## The ball's resting centre this flag sends you back to.
var spot := Vector2.ZERO
var active := true:
	set(v):
		active = v
		queue_redraw()

var _t := 0.0
var _wind := Vector2.ZERO
var _flutter := 0.0     # extra wave from knocks, decays
var _side := 1.0        # which way the pennant flies: +1 right, -1 left
var _lift := 0.0        # updraft (+) or downdraft (-), smoothed
var _rise := 0.0        # 0..1 while planting / folding
var _leaving := false


## The ball rests with its centre 8 px above the felt; the pole stands just behind it.
func setup(ball_spot: Vector2) -> CheckpointFlag:
	spot = ball_spot
	position = (ball_spot + Vector2(-5, BallSim.RADIUS)).round()
	hit_size = Vector2(20, 30)
	hit_offset = Vector2(6, -15)
	min_speed = 20.0
	return self


func _ready() -> void:
	_t = fposmod(spot.x * 0.13, 6.0)
	var tw := create_tween()
	tw.tween_property(self, "_rise", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	burst(self, Vector2(2, -POLE_H + 4), SPARK, 3, 12, Vector2.UP, 120.0, true, 0.6)
	_flutter = 1.0


## Folds the flag down and frees it.
func remove() -> void:
	if _leaving:
		return
	_leaving = true
	burst(get_parent(), position + Vector2(2, -POLE_H + 4), SPARK, 3, 6, Vector2.UP, 60.0, true, 0.4)
	var tw := create_tween()
	tw.tween_property(self, "_rise", 0.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


## The ball was sent back here: a proud wave and a ring of sparks.
func welcome() -> void:
	_flutter = 1.6
	burst(self, Vector2(2, -POLE_H + 4), SPARK, 3, 10, Vector2.UP, 90.0, true, 0.5)


func react(_ball_pos: Vector2, ball_vel: Vector2) -> void:
	_flutter = minf(2.0, _flutter + clampf(ball_vel.length() / 300.0, 0.3, 1.2))
	if absf(ball_vel.x) > 30.0 and _wind.length() < 60.0:
		_side = signf(ball_vel.x)


func rumble(_from: Vector2, strength: float) -> void:
	_flutter = minf(2.0, _flutter + strength)


func feel_wind(wind: Vector2) -> void:
	_wind = wind


func update(delta: float) -> void:
	_t += delta
	var dt := minf(delta, 1.0 / 30.0)
	_flutter = move_toward(_flutter, 0.0, dt * 0.8)
	if absf(_wind.x) > 40.0:
		_side = move_toward(_side, signf(_wind.x), dt * 4.0)
	_lift = lerpf(_lift, clampf(-_wind.y / 300.0, -1.0, 1.0), dt * 3.0)
	queue_redraw()


func _draw() -> void:
	if _rise <= 0.01:
		return
	var h := roundf(POLE_H * _rise)
	draw_texture_rect_region(POLE, Rect2(0, -h, 7, h), Rect2(0, POLE_H - h, 7, h))
	var top := -h + 5.0
	var strength := clampf(_wind.length() / 280.0, 0.0, 1.0)
	var amp := 0.6 + strength * 1.6 + _flutter * 1.4
	var speed := 4.0 + strength * 8.0 + _flutter * 3.0
	# Hangs a little in still air, streams flat in a gust, lifts in an updraft.
	var droop := 0.32 * (1.0 - strength) - _lift * 0.35
	var w := absf(_side)
	var frame := 0 if active else 1
	var pulse := 0.0
	if active:
		pulse = 0.5 + 0.5 * sin(_t * 3.0)
		draw_circle(Vector2(3, top + 4), 9.0 + pulse * 2.0, Color(GLOW, 0.08 + pulse * 0.06))
	for x in CLOTH_W:
		var reach := float(x) / CLOTH_W
		var wave := sin(_t * speed - x * 0.7) * amp * reach
		var y := roundf(top + wave + x * droop)
		var px := roundf(3.0 + _side_sign() * (1.0 + x * w))
		var src := Rect2(frame * CLOTH_W + x, 0, 1, CLOTH_H)
		var tint := Color.WHITE if not active else Color(1.0 + pulse * 0.15, 1.0 + pulse * 0.15, 1.0 + pulse * 0.15)
		draw_texture_rect_region(CLOTH, Rect2(px, y, 1, CLOTH_H), src, tint)


func _side_sign() -> float:
	return 1.0 if _side >= 0.0 else -1.0
