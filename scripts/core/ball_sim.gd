class_name BallSim
extends RefCounted
## Deterministic cue-ball physics, stepped at a fixed 1/120 s.
## Pure data: the player node drives it with input, the route solver drives
## it with brute-force shots, and both get identical results.
##
## Feel targets (Jump King + billiards):
## - no air control: once struck, the ball is committed
## - felt grips: landings bleed speed, rolling stops in a short, learnable distance
## - wood rails bounce at half speed, rubber cushions and bumpers stay lively
## - english (spin) set before the shot shapes the first landing:
##   follow keeps running forward, draw checks up or pulls back

const DT := 1.0 / 120.0
const RADIUS := 7.0
const GRAVITY := 900.0
const MAX_FALL := 640.0

const CHARGE_TICKS := 84            # 0.7 s from tap to full power
const MIN_SPEED := 150.0
const MAX_SPEED := 580.0
const AIM_STEP_DEG := 5
const AIM_LIMIT_DEG := 80
const SPIN_LEVELS := 2              # -2 draw .. +2 follow
const SPIN_SPEED := 75.0            # px/s added along the shot per spin level on first landing

const ROLL_DECEL := [420.0, 380.0, 150.0]  # felt drag per zone (Royal Club felt is fast)
const CHARGE_BRAKE := 1400.0
const REST_SPEED := 5.0
const SHOOTABLE_NORMAL_Y := -0.86   # flatter than ~30 degrees
const FLOOR_NORMAL_Y := -0.6

const FLOOR_BOUNCE := 0.3
const FLOOR_BOUNCE_MIN := 140.0     # slower impacts land dead, no hop
const WALL_BOUNCE := 0.5
const CUSHION_BOUNCE := 0.9
const BUMPER_KICK := 340.0
const LANDING_GRIP_HARD := 0.4     # tangential speed kept on a hard landing
const LANDING_GRIP_SOFT := 0.75
const HARD_LANDING := 260.0
const SPLAT_FALL := 200.0           # px of drop that counts as a fall / splat landing

enum Event { SHOT, LAND, SPLAT, WALL, CUSHION, BUMPER, POCKET, GOAL, LOST_BALL }

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var grounded := false
var ground_normal := Vector2.UP
var ground_zone := 0
var resting := false
var in_pocket := false
var pending_spin := 0.0             # px/s along the shot, applied on first floor contact
var shot_dir_x := 0.0
var spin_rate := 0.0                # visual angular speed about the view axis (rad/s)
var tumble_rate := 0.0              # visual angular speed about the horizontal axis
var takeoff_y := 0.0
var apex_y := 0.0
var events: Array[Dictionary] = []

var _was_grounded := false
var _queued: Array[Dictionary] = []


func reset(at: Vector2) -> void:
	pos = at
	vel = Vector2.ZERO
	grounded = false
	resting = false
	in_pocket = false
	pending_spin = 0.0
	spin_rate = 0.0
	tumble_rate = 0.0
	takeoff_y = at.y
	apex_y = at.y


func can_shoot() -> bool:
	return grounded and not in_pocket and ground_normal.y <= SHOOTABLE_NORMAL_Y


static func aim_vector(aim_deg: float) -> Vector2:
	var a := deg_to_rad(aim_deg)
	return Vector2(sin(a), -cos(a))


static func shot_speed(charge_ticks: int) -> float:
	var t := clampf(float(charge_ticks) / CHARGE_TICKS, 0.0, 1.0)
	return lerpf(MIN_SPEED, MAX_SPEED, t)


func shoot(aim_deg: float, charge_ticks: int, spin_level: int) -> void:
	var dir := aim_vector(aim_deg)
	var speed := shot_speed(charge_ticks)
	vel = dir * speed
	grounded = false
	resting = false
	shot_dir_x = signf(dir.x) if absf(dir.x) > 0.05 else 0.0
	pending_spin = spin_level * SPIN_SPEED
	takeoff_y = pos.y
	apex_y = pos.y
	# Cue strike puts a little roll on the ball, plus the chosen english.
	spin_rate = shot_dir_x * speed / RADIUS * 0.35
	tumble_rate = (0.6 + 0.4 * absf(spin_level)) * signf(spin_level if spin_level != 0 else 1) * speed / RADIUS * 0.3
	# Reported with the next step so consumers see it alongside the flight.
	_queued.append({ "type": Event.SHOT, "speed": speed, "spin": spin_level })


## Holding a charge on the felt plants the ball.
func brake(dt: float) -> void:
	if grounded:
		vel = vel.move_toward(Vector2.ZERO, CHARGE_BRAKE * dt)


func step(world: CollisionWorld, dt: float = DT) -> void:
	events.clear()
	if not _queued.is_empty():
		events.append_array(_queued)
		_queued.clear()
	if in_pocket:
		return
	_was_grounded = grounded
	if grounded and not resting:
		# Rolling resistance along the surface.
		var t := Vector2(-ground_normal.y, ground_normal.x)
		var vt := vel.dot(t)
		var vn := vel.dot(ground_normal)
		vt = move_toward(vt, 0.0, ROLL_DECEL[clampi(ground_zone, 0, 2)] * dt)
		vel = t * vt + ground_normal * vn
	if not resting:
		vel.y = minf(vel.y + GRAVITY * dt, MAX_FALL)

	var touched_floor := false
	var floor_normal := Vector2.ZERO
	var floor_zone := 0
	var motion := vel * dt
	var substeps := maxi(1, ceili(motion.length() / 3.0))
	for _s in substeps:
		pos += motion / substeps
		for _iter in 3:
			var contacts := world.collide_circle(pos, RADIUS, 0.6)
			if contacts.is_empty():
				break
			var any_push := false
			for c in contacts:
				var n: Vector2 = c.normal
				if n.y <= FLOOR_NORMAL_Y and c.kind == CollisionWorld.Kind.TILE:
					touched_floor = true
					if n.y < floor_normal.y or floor_normal == Vector2.ZERO:
						floor_normal = n
						floor_zone = c.zone
				if c.depth > 0.0:
					pos += n * c.depth
					any_push = true
				var vn := vel.dot(n)
				if vn < 0.0:
					_respond(c, n, vn)
					motion = vel * dt
			if not any_push:
				break
		if in_pocket:
			return
		_check_pockets(world)
		if in_pocket:
			return

	grounded = touched_floor
	if grounded:
		ground_normal = floor_normal
		ground_zone = floor_zone
		var t := Vector2(-ground_normal.y, ground_normal.x)
		spin_rate = vel.dot(t) / RADIUS
		tumble_rate = move_toward(tumble_rate, 0.0, 30.0 * dt)
		resting = ground_normal.y <= SHOOTABLE_NORMAL_Y and vel.length() < REST_SPEED
		if resting:
			vel = Vector2.ZERO
	else:
		resting = false
		apex_y = minf(apex_y, pos.y)
		spin_rate *= 1.0 - 0.15 * dt
	if _was_grounded and not grounded:
		takeoff_y = pos.y
		apex_y = pos.y
	_check_lost_balls(world)


func _respond(c: Dictionary, n: Vector2, vn: float) -> void:
	var t := Vector2(-n.y, n.x)
	var vt := vel.dot(t)
	var impact := -vn
	if c.kind == CollisionWorld.Kind.BUMPER:
		var out := vel - 2.0 * vn * n
		var along := out.dot(n)
		if along < BUMPER_KICK:
			out += n * (BUMPER_KICK - along)
		vel = out
		spin_rate = -spin_rate * 0.5 + vt / RADIUS
		events.append({ "type": Event.BUMPER, "id": c.id, "impact": impact, "normal": n })
		return
	var is_floor := n.y <= FLOOR_NORMAL_Y
	var e := WALL_BOUNCE
	var grip := 0.92
	if c.mat == CollisionWorld.Mat.CUSHION:
		e = CUSHION_BOUNCE
		grip = 0.97 if impact > 40.0 else 1.0
		if impact > 40.0:
			events.append({ "type": Event.CUSHION, "impact": impact, "normal": n })
	elif is_floor:
		e = FLOOR_BOUNCE if impact > FLOOR_BOUNCE_MIN else 0.0
		# Landing grip bites once, on touchdown; rolling uses ROLL_DECEL instead.
		grip = 1.0
		if not _was_grounded:
			grip = LANDING_GRIP_HARD if impact > HARD_LANDING else LANDING_GRIP_SOFT
		if not _was_grounded and impact > 25.0:
			var drop := pos.y - apex_y
			var splat := pos.y - takeoff_y > SPLAT_FALL and drop > SPLAT_FALL
			events.append({ "type": Event.SPLAT if splat else Event.LAND, "impact": impact, "drop": drop, "fall": pos.y - takeoff_y, "normal": n })
	elif impact > 40.0:
		events.append({ "type": Event.WALL, "impact": impact, "normal": n })
	if not is_floor:
		spin_rate = -spin_rate * 0.6
	vt *= grip
	if is_floor and pending_spin != 0.0:
		# English bites on the first floor contact after the shot.
		var along_x := signf(t.x) if absf(t.x) > 0.01 else 1.0
		vt += pending_spin * shot_dir_x * along_x
		pending_spin = 0.0
		tumble_rate = 0.0
	vel = t * vt - n * vn * e


func _check_pockets(world: CollisionWorld) -> void:
	for p in world.pockets:
		if pos.distance_to(p.pos) < p.radius:
			in_pocket = true
			vel = Vector2.ZERO
			events.append({ "type": Event.GOAL if p.goal else Event.POCKET, "id": p.id, "exit": p.exit, "pos": p.pos })
			return


func _check_lost_balls(world: CollisionWorld) -> void:
	for b in world.lost_balls:
		if not b.get("taken", false) and pos.distance_to(b.pos) < 12.0:
			b.taken = true
			events.append({ "type": Event.LOST_BALL, "number": b.number, "pos": b.pos })


## After a pocket swallows the ball, the ball-return drops it at the exit.
func release_from_pocket(exit: Vector2) -> void:
	reset(exit)
	vel = Vector2(0, 60)
