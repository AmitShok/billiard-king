class_name PlayerBall
extends Node2D
## The cue ball you play. Wraps BallSim with input, the cue, sounds and juice.
## Controls (Jump King rules): aim and set spin any time, hold to charge while
## the ball sits on flat felt, release to strike. Nothing can be changed in
## the air.

signal shot_taken
signal fell(drop: float)
signal landed(impact: float)
signal bumped(id: int)
signal wall_hit(impact: float)
signal pocketed
signal won
signal lost_ball_found(number: int)
signal settled

const DUST := preload("res://assets/textures/dust.png")
const SPIN_ICON := preload("res://assets/textures/spin_icon.png")

const AIM_REPEAT_DELAY := 0.2
const AIM_REPEAT := 0.055
const SPLAT_LOCK := 0.4
const POCKET_TIME := 0.9

var sim := BallSim.new()
var world: CollisionWorld
var aim_deg := 0.0
var spin_level := 0
var charging := false
var charge_ticks := 0
var input_enabled := true

var _lock := 0.0
var _aim_hold := 0.0
var _aim_dir := 0
var _visual: BallVisual
var _cue: CueStick
var _spin_icon: Sprite2D
var _squash := Vector2.ONE
var _pocket_timer := 0.0
var _pocket_exit := Vector2.ZERO
var _was_resting := false


func _ready() -> void:
	_cue = CueStick.new()
	_cue.visible = false
	add_child(_cue)
	_visual = BallVisual.new()
	_visual.diameter = 16
	add_child(_visual)
	_spin_icon = Sprite2D.new()
	_spin_icon.texture = SPIN_ICON
	_spin_icon.hframes = 5
	_spin_icon.position = Vector2(0, -20)
	_spin_icon.modulate.a = 0.0
	add_child(_spin_icon)
	set_skin(SaveData.skin)


func set_skin(number: int) -> void:
	_visual.number = number


func place(at: Vector2) -> void:
	sim.reset(at)
	position = at
	reset_physics_interpolation()
	charging = false
	charge_ticks = 0
	_visual.scale = Vector2.ONE
	_visual.set_alpha(1.0)


func _physics_process(_delta: float) -> void:
	if world == null:
		return
	var dt := BallSim.DT
	if _pocket_timer > 0.0:
		_pocket_timer -= dt
		if _pocket_timer <= 0.0:
			sim.release_from_pocket(_pocket_exit)
			position = sim.pos
			reset_physics_interpolation()
			_visual.set_alpha(1.0)
			_visual.scale = Vector2.ONE
		return
	_lock = maxf(0.0, _lock - dt)
	if input_enabled:
		_read_aim_input(dt)
		_read_charge_input()
	sim.step(world, dt)
	_handle_events()
	position = sim.pos
	if sim.resting and not _was_resting:
		settled.emit()
	_was_resting = sim.resting
	Sfx.set_roll(sim.vel.length(), sim.grounded)


func _read_aim_input(dt: float) -> void:
	var dir := int(Input.is_action_pressed("aim_right")) - int(Input.is_action_pressed("aim_left"))
	if dir == 0:
		_aim_dir = 0
		_aim_hold = 0.0
	elif dir != _aim_dir:
		_aim_dir = dir
		_aim_hold = 0.0
		_nudge_aim(dir)
	else:
		_aim_hold += dt
		if _aim_hold > AIM_REPEAT_DELAY:
			_aim_hold -= AIM_REPEAT
			_nudge_aim(dir)
	if Input.is_action_just_pressed("spin_up"):
		_set_spin(spin_level + 1)
	if Input.is_action_just_pressed("spin_down"):
		_set_spin(spin_level - 1)


func _nudge_aim(dir: int) -> void:
	var next := clampf(aim_deg + dir * BallSim.AIM_STEP_DEG, -BallSim.AIM_LIMIT_DEG, BallSim.AIM_LIMIT_DEG)
	if next != aim_deg:
		aim_deg = next
		Sfx.play("aim_tick", -14.0, 1.0 + aim_deg / 400.0, 0.0)


func _set_spin(level: int) -> void:
	var next := clampi(level, -BallSim.SPIN_LEVELS, BallSim.SPIN_LEVELS)
	if next != spin_level:
		spin_level = next
		Sfx.play("aim_tick", -10.0, 0.8 + 0.1 * spin_level, 0.0)
	_spin_icon.modulate.a = 1.0


func _read_charge_input() -> void:
	var held := Input.is_action_pressed("charge")
	if not charging:
		# Holding the button while landing starts the charge, like Jump King.
		if held and sim.can_shoot() and _lock <= 0.0:
			charging = true
			charge_ticks = 0
			Sfx.play("chalk", -12.0)
		return
	if not sim.can_shoot():
		charging = false
		charge_ticks = 0
		return
	charge_ticks += 1
	sim.brake(BallSim.DT)
	if not held or charge_ticks >= BallSim.CHARGE_TICKS:
		strike()


## Fires the shot with the current aim, charge and spin.
func strike() -> void:
	sim.shoot(aim_deg, maxi(charge_ticks, 1), spin_level)
	charging = false
	charge_ticks = 0
	_cue.strike = 1.0


func _handle_events() -> void:
	for e in sim.events:
		match e.type:
			BallSim.Event.SHOT:
				var t: float = inverse_lerp(BallSim.MIN_SPEED, BallSim.MAX_SPEED, e.speed)
				Sfx.play("cue", lerpf(-9.0, 0.0, t), lerpf(1.1, 0.92, t))
				_squash = Vector2(0.82, 1.18)
				shot_taken.emit()
			BallSim.Event.LAND:
				Sfx.impact("land", e.impact, 520.0)
				if e.impact > 160.0:
					_spawn_dust(e.normal, 0.7)
				_squash = Vector2(1.0 + minf(e.impact / 1600.0, 0.22), 1.0 - minf(e.impact / 1600.0, 0.22))
				landed.emit(e.impact)
			BallSim.Event.SPLAT:
				Sfx.play("splat", 0.0)
				_spawn_dust(e.normal, 1.0)
				_squash = Vector2(1.3, 0.7)
				_lock = SPLAT_LOCK
				charging = false
				fell.emit(e.drop)
				landed.emit(e.impact)
			BallSim.Event.WALL:
				Sfx.impact("rail", e.impact)
				wall_hit.emit(e.impact)
			BallSim.Event.CUSHION:
				Sfx.impact("cushion", e.impact)
				wall_hit.emit(e.impact * 0.5)
			BallSim.Event.BUMPER:
				Sfx.play("clack", -2.0)
				Sfx.play("bumper", -6.0)
				_visual.flash = 0.6
				bumped.emit(e.id)
			BallSim.Event.POCKET:
				_sink(e.pos)
				_pocket_exit = e.exit
				_pocket_timer = POCKET_TIME
				Sfx.play("pocket", 0.0)
				pocketed.emit()
			BallSim.Event.GOAL:
				_sink(e.pos)
				_pocket_timer = 0.0
				Sfx.play("pocket", 0.0, 0.9)
				won.emit()
			BallSim.Event.LOST_BALL:
				Sfx.play("lost_ball", -2.0)
				lost_ball_found.emit(e.number)


func _sink(at: Vector2) -> void:
	sim.pos = at
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_visual, "scale", Vector2(0.4, 0.4), 0.35).set_ease(Tween.EASE_IN)
	tw.tween_method(_visual.set_alpha, 1.0, 0.0, 0.35)


func _spawn_dust(normal: Vector2, strength: float) -> void:
	var s := Sprite2D.new()
	s.texture = DUST
	s.hframes = 4
	s.position = position - normal * BallSim.RADIUS
	s.rotation = normal.angle() + PI / 2.0
	s.scale = Vector2.ONE * (0.8 + strength * 0.5)
	s.z_index = 2
	get_parent().add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "frame", 3, 0.32)
	tw.tween_callback(s.queue_free)


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	_visual.roll(sim.spin_rate, sim.tumble_rate, dt)
	_squash = _squash.lerp(Vector2.ONE, 1.0 - exp(-dt * 14.0))
	if _pocket_timer <= 0.0:
		_visual.scale = _squash
	_visual.flash = move_toward(_visual.flash, 0.0, dt * 3.0)
	# Cue and aim guide only while the ball can actually be struck.
	var show_cue := input_enabled and sim.can_shoot() and _pocket_timer <= 0.0
	if show_cue or _cue.strike > 0.0:
		_cue.visible = true
	elif not charging:
		_cue.visible = false
	_cue.aim_deg = aim_deg
	_cue.charge = float(charge_ticks) / BallSim.CHARGE_TICKS if charging else 0.0
	var guide_target := (0.6 if charging else 1.0) if show_cue else 0.0
	_cue.guide_alpha = move_toward(_cue.guide_alpha, guide_target, dt * 6.0)
	_spin_icon.frame = spin_level + BallSim.SPIN_LEVELS
	var spin_target := 1.0 if (show_cue and spin_level != 0) else 0.0
	_spin_icon.modulate.a = move_toward(_spin_icon.modulate.a, spin_target, dt * (12.0 if spin_target == 0.0 else 6.0))
	_spin_icon.position = Vector2(-16 if aim_deg > 0.0 else 16, -14)
