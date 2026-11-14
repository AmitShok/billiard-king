class_name PlayerBall
extends Node2D
## The cue ball you play. Wraps BallSim with input, the cue, sounds and juice.
## Controls (Jump King rules): aim any time, hold to charge while
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
## Hardcore: events from the floating white ball, and ball-on-ball knocks.
signal partner_event(event: Dictionary)
signal ball_hit(impact: float)
signal trapped(event: Dictionary)

const DUST := preload("res://assets/textures/dust.png")

const AIM_REPEAT_DELAY := 0.2
const AIM_REPEAT := 0.055
const SPLAT_LOCK := 0.4
const POCKET_TIME := 0.9

var sim := BallSim.new()
var world: CollisionWorld
var aim_deg := 0.0
var charging := false
var charge_ticks := 0
var input_enabled := true
## Hardcore: the floating white ball, stepped and collided together with ours.
var partner: BallSim

var _lock := 0.0
var _aim_hold := 0.0
var _aim_dir := 0
var _visual: BallVisual
var _cue: CueStick
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
		world.advance(dt)
		if partner:
			partner.step(world, dt)
			for e in partner.events:
				partner_event.emit(e)
		return
	_lock = maxf(0.0, _lock - dt)
	if input_enabled:
		_read_aim_input(dt)
		_read_charge_input()
	_step(dt)
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


func _nudge_aim(dir: int) -> void:
	var next := clampf(aim_deg + dir * BallSim.AIM_STEP_DEG, -BallSim.AIM_LIMIT_DEG, BallSim.AIM_LIMIT_DEG)
	if next != aim_deg:
		aim_deg = next
		Sfx.play("aim_tick", -14.0, 1.0 + aim_deg / 400.0, 0.0)


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


## Fires the shot with the current aim and charge.
func strike() -> void:
	sim.shoot(aim_deg, maxi(charge_ticks, 1))
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
				Sfx.impact("platform_clank" if sim.riding >= 0 else "land", e.impact, 520.0)
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
			BallSim.Event.TRAP:
				Sfx.play("trap_hit", -1.0)
				_visual.flash = 0.8
				_squash = Vector2(0.75, 1.25)
				charging = false
				charge_ticks = 0
				trapped.emit(e)
			BallSim.Event.BALL_HIT:
				Sfx.impact("clack", e.impact, 450.0)
				ball_hit.emit(e.impact)
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


## One physics tick. With a partner ball (Hardcore) both balls advance in two
## half-steps and collide with each other after each, so fast knocks can't
## pass through. Without one this is exactly the Classic step.
func _step(dt: float) -> void:
	if partner == null:
		world.advance(dt)
		sim.step(world, dt)
		return
	var ours: Array[Dictionary] = []
	for half in 2:
		world.advance(dt * 0.5)
		sim.step(world, dt * 0.5)
		ours.append_array(sim.events)
		partner.step(world, dt * 0.5)
		for e in partner.events:
			partner_event.emit(e)
		var hit := BallSim.collide_pair(sim, partner)
		if hit > 20.0:
			ours.append({ "type": BallSim.Event.BALL_HIT, "impact": hit })
	sim.events = ours
