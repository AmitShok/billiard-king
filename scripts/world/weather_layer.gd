class_name WeatherLayer
extends Node2D
## Screen-space weather. In wind, pale streaks race the way the gust blows, so
## you can read it in any direction. In low gravity, slow specks of chalk dust
## hang and drift. Cosmetic only.

const COUNT := 44
const SCREEN := Vector2(512, 288)

var wind := Vector2.ZERO
var low_gravity := false

var _points: Array[Vector2] = []
var _depth: Array[float] = []
var _rng := RandomNumberGenerator.new()
var _t := 0.0


func _ready() -> void:
	_rng.seed = 38
	for i in COUNT:
		_points.append(Vector2(_rng.randf() * SCREEN.x, _rng.randf() * SCREEN.y))
		_depth.append(_rng.randf_range(0.5, 1.0))


func _process(delta: float) -> void:
	_t += delta
	var drift := wind * 1.6
	if low_gravity:
		drift = Vector2(sin(_t * 0.2) * 5.0, -5.0)
	elif wind.length() < 6.0:
		if visible:
			queue_redraw()
		return
	for i in COUNT:
		_points[i] = Vector2(fposmod(_points[i].x + drift.x * _depth[i] * delta, SCREEN.x), fposmod(_points[i].y + drift.y * _depth[i] * delta, SCREEN.y))
	queue_redraw()


func _draw() -> void:
	if low_gravity:
		for i in COUNT:
			var twinkle := 0.3 + 0.3 * sin(_t * 1.3 + i)
			draw_rect(Rect2(_points[i].round(), Vector2.ONE), Color(0.86, 0.88, 1.0, twinkle * _depth[i]))
		return
	var strength := clampf(wind.length() / 280.0, 0.0, 1.0)
	if strength < 0.03:
		return
	var dir := wind.normalized()
	var length := 3.0 + strength * 12.0
	for i in COUNT:
		var alpha := 0.15 + strength * 0.4 * _depth[i]
		var col := Color(0.82, 0.92, 0.95, alpha)
		for s in int(length * _depth[i]):
			draw_rect(Rect2((_points[i] - dir * s).round(), Vector2.ONE), col)
