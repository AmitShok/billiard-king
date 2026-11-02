class_name BeadsProp
extends Prop
## A pool-hall score wire. Each bead slides on its own: the ball shoves the
## ones it touches, they clack into their neighbours and bounce off the posts.

const BEAD := preload("res://assets/textures/bead.png")
const LEFT := -44.0     # bead centres travel between the posts
const RIGHT := 44.0
const WIDTH := 6.0
const FRICTION := 220.0
const START := [-42.0, -36.0, -30.0, -24.0, -12.0, 18.0, 24.0, 30.0, 36.0]

var xs: Array[float] = []
var vs: Array[float] = []
var _sprites: Array[Sprite2D] = []


func _ready() -> void:
	hit_size = Vector2(96, 12)
	for i in START.size():
		xs.append(START[i])
		vs.append(0.0)
		var s := Sprite2D.new()
		s.texture = BEAD
		s.hframes = 2
		s.frame = 0 if i < 5 else 1
		add_child(s)
		_sprites.append(s)
	_sync()


func react(ball_pos: Vector2, ball_vel: Vector2) -> void:
	var local_x := ball_pos.x - global_position.x
	var shoved := false
	for i in xs.size():
		if absf(xs[i] - local_x) < 14.0:
			vs[i] = clampf(vs[i] + ball_vel.x * 0.7, -320.0, 320.0)
			shoved = true
	if shoved:
		Sfx.play("clack", -12.0, 1.35)


func rumble(_from: Vector2, strength: float) -> void:
	for i in vs.size():
		vs[i] += randf_range(-40.0, 40.0) * strength


func update(delta: float) -> void:
	var dt := minf(delta, 1.0 / 30.0)
	for i in xs.size():
		vs[i] = move_toward(vs[i], 0.0, FRICTION * dt)
		xs[i] += vs[i] * dt
		if xs[i] < LEFT:
			xs[i] = LEFT
			vs[i] = absf(vs[i]) * 0.4
		elif xs[i] > RIGHT:
			xs[i] = RIGHT
			vs[i] = -absf(vs[i]) * 0.4
	# Beads keep their order on the wire: neighbours trade momentum on contact.
	for i in xs.size() - 1:
		var gap := xs[i + 1] - xs[i]
		if gap < WIDTH:
			var push := (WIDTH - gap) / 2.0
			xs[i] -= push
			xs[i + 1] += push
			if vs[i] > vs[i + 1]:
				if absf(vs[i] - vs[i + 1]) > 30.0:
					Sfx.play("clack", -20.0, 1.5)
				var t := vs[i]
				vs[i] = vs[i + 1] * 0.85
				vs[i + 1] = t * 0.85
	_sync()


func _sync() -> void:
	for i in _sprites.size():
		_sprites[i].position = Vector2(round(xs[i]), 0)
