class_name RainLayer
extends Node2D
## Falling rain over the rainy backdrops (the Rooftops storm and the Fire
## Escape). Drawn just above the backdrop and behind the ledges and decor,
## only where a rainy screen is in view, so it stops at the zone's edge even
## while the camera glides. Each stretch's gust bends it: a crosswind slants
## it hard, an updraft slows it, a downdraft drives it down. Cosmetic only.

const RAINY_ZONES := [5, 9]
const COUNT := 170
const VIEW := Vector2(512, 288)
const FALL := 380.0        # px/s for the nearest drops in still air
const FAR := Color("3a4c58")
const NEAR := Color("5a7486")

var tower: Tower
var camera: Camera2D
## The wind on the screen in view (px/s^2, as the physics uses it).
var wind := Vector2.ZERO

var _pos: Array[Vector2] = []
var _depth: Array[float] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = -19   # backdrop is -20, decor -5, terrain 0
	_rng.seed = 905
	for i in COUNT:
		_pos.append(Vector2(_rng.randf() * VIEW.x, _rng.randf() * VIEW.y))
		_depth.append(_rng.randf_range(0.45, 1.0))


## A drop's velocity: the painted slant (one across for three down) plus the gust.
func drop_velocity(depth: float) -> Vector2:
	var v := Vector2(FALL / 3.0 + wind.x * 0.9, FALL + wind.y * 0.9) * depth
	v.y = maxf(v.y, 70.0 * depth)
	return v


func _process(delta: float) -> void:
	if not _rain_in_view():
		return
	for i in COUNT:
		var p := _pos[i] + drop_velocity(_depth[i]) * delta
		_pos[i] = Vector2(fposmod(p.x, VIEW.x), fposmod(p.y, VIEW.y))
	queue_redraw()


func _view_top_left() -> Vector2:
	return camera.get_screen_center_position() - VIEW / 2.0


func _rainy(world_y: float) -> bool:
	var k := Tower.screen_of(world_y)
	if k < 0 or k >= tower.screen_count():
		return false
	return RAINY_ZONES.has(tower.zone_of_screen(k))


func _rain_in_view() -> bool:
	if tower == null or camera == null:
		return false
	var top := _view_top_left().y
	return _rainy(top + 1.0) or _rainy(top + VIEW.y - 1.0)


func _draw() -> void:
	if not _rain_in_view():
		return
	var origin := _view_top_left().round()
	for i in COUNT:
		var p := origin + _pos[i].round()
		if not _rainy(p.y):
			continue
		var v := drop_velocity(_depth[i])
		var dir := v.normalized()
		var length := int(clampf(v.length() * 0.011, 3.0, 8.0))
		var col := FAR.lerp(NEAR, (_depth[i] - 0.45) / 0.55)
		for s in length:
			draw_rect(Rect2((p - dir * s).round(), Vector2.ONE), col)
