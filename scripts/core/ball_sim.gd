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

const ROLL_DECEL := [420.0, 380.0, 150.0, 340.0, 380.0, 360.0, 300.0, 400.0, 420.0]  # felt drag per tile zone (Royal Club felt is fast)
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
const FLOAT_DRAG := 260.0          # Hardcore white ball: felt drag in every direction (no gravity)
const TRAP_KNOCK := 430.0          # traps fling the ball away at this speed
const TRAP_MAX := 620.0
const TRAP_COOLDOWN := 0.25
const BALL_BOUNCE := 0.92           # ball-on-ball restitution (phenolic balls are lively)

enum Event { SHOT, LAND, SPLAT, WALL, CUSHION, BUMPER, POCKET, GOAL, LOST_BALL, BALL_HIT, TRAP }

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
var floating := false            # Hardcore white ball: no gravity, drag everywhere
var ignore_goal := false         # Hardcore player: only the white ball may sink the gold pocket
var takeoff_y := 0.0
var apex_y := 0.0
var events: Array[Dictionary] = []

## The moving platform we are standing on (-1 for none). While riding, `vel` is
## relative to the platform; the carry is applied to `pos` each step.
var riding := -1
var ride_vel := Vector2.ZERO
var _trap_cd := 0.0
var _was_grounded := false
var _queued: Array[Dictionary] = []


func reset(at: Vector2) -> void:
	pos = at
	vel = Vector2.ZERO
	riding = -1
	ride_vel = Vector2.ZERO
	_trap_cd = 0.0
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
	# Shots keep the platform's momentum.
	vel = dir * speed + (ride_vel if riding >= 0 else Vector2.ZERO)
	riding = -1
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
	_trap_cd = maxf(0.0, _trap_cd - dt)
	if riding >= 0:
		ride_vel = world.platforms[riding].vel
		pos += ride_vel * dt
	# Wind only catches your ball in the air, like Jump King. The white ball
	# in Hardcore is never blown.
	if not floating and not grounded:
		vel += world.wind_at(pos.y) * dt
	if floating:
		vel = vel.move_toward(Vector2.ZERO, FLOAT_DRAG * dt)
	elif grounded and not resting:
		# Rolling resistance along the surface.
		var t := Vector2(-ground_normal.y, ground_normal.x)
		var vt := vel.dot(t)
		var vn := vel.dot(ground_normal)
		vt = move_toward(vt, 0.0, ROLL_DECEL[clampi(ground_zone, 0, 8)] * dt)
		vel = t * vt + ground_normal * vn
	if not resting and not floating:
		var g := world.gravity_scale_at(pos.y)
		vel.y = minf(vel.y + GRAVITY * g * dt, MAX_FALL * sqrt(g))

	var touched_floor := false
	var floor_normal := Vector2.ZERO
	var floor_zone := 0
	var floor_platform := -1
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
				var is_plat: bool = c.kind == CollisionWorld.Kind.PLATFORM
				if n.y <= FLOOR_NORMAL_Y and (is_plat or c.kind == CollisionWorld.Kind.TILE) and not floating:
					touched_floor = true
					if n.y < floor_normal.y or floor_normal == Vector2.ZERO:
						floor_normal = n
						floor_zone = c.zone
						floor_platform = c.id if is_plat else -1
				if c.depth > 0.0:
					pos += n * c.depth
					any_push = true
				# Bounce in the frame of a moving platform we aren't already riding.
				var frame := Vector2.ZERO
				if is_plat and c.id != riding:
					frame = world.platforms[c.id].vel
				vel -= frame
				var vn := vel.dot(n)
				if vn < 0.0:
					_respond(c, n, vn)
				vel += frame
				if vn < 0.0:
					motion = vel * dt
			if not any_push:
				break
		if _check_traps(world):
			motion = vel * dt
			floor_platform = -1
			touched_floor = false
		if in_pocket:
			return
		_check_pockets(world)
		if in_pocket:
			return

	grounded = touched_floor
	_update_ride(world, floor_platform)
	if floating:
		resting = vel.length() < REST_SPEED
		if resting:
			vel = Vector2.ZERO
		spin_rate = vel.x / RADIUS
		tumble_rate = -vel.y / RADIUS
		_check_lost_balls(world)
		return
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
	var is_floor := n.y <= FLOOR_NORMAL_Y and not floating
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
		if p.goal and ignore_goal:
			continue
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
	vel = Vector2.ZERO if floating else Vector2(0, 60)


## Equal-mass billiard collision between two balls (Hardcore: your ball and
## the floating white ball). Separates them and trades momentum along the
## line of centres. Returns the closing speed (0 if they didn't meet).
static func collide_pair(a: BallSim, b: BallSim) -> float:
	if a.in_pocket or b.in_pocket:
		return 0.0
	var d := b.pos - a.pos
	var dist := d.length()
	if dist >= RADIUS * 2.0 or dist < 0.0001:
		return 0.0
	var n := d / dist
	var overlap := RADIUS * 2.0 - dist
	a.pos -= n * overlap * 0.5
	b.pos += n * overlap * 0.5
	var closing := (a.world_vel() - b.world_vel()).dot(n)
	if closing <= 0.0:
		return 0.0
	var j := (1.0 + BALL_BOUNCE) * 0.5 * closing
	a.vel -= n * j
	b.vel += n * j
	a.resting = false
	b.resting = false
	return closing


## Switches `vel` between world frame and a platform's frame as we board and leave.
func _update_ride(world: CollisionWorld, floor_platform: int) -> void:
	if floating or floor_platform == riding:
		return
	if riding >= 0:
		vel += ride_vel
	if floor_platform >= 0:
		ride_vel = world.platforms[floor_platform].vel
		vel -= ride_vel
	riding = floor_platform


## Traps fling the ball away from the point of contact.
func _check_traps(world: CollisionWorld) -> bool:
	if world.traps.is_empty():
		return false
	var hit := world.trap_contact(pos, RADIUS)
	if hit.is_empty():
		return false
	pos += hit.normal * hit.depth
	if _trap_cd > 0.0:
		return false
	_trap_cd = TRAP_COOLDOWN
	vel = (hit.normal * TRAP_KNOCK + hit.vel * 0.5).limit_length(TRAP_MAX)
	riding = -1
	resting = false
	grounded = false
	takeoff_y = pos.y
	apex_y = pos.y
	events.append({ "type": Event.TRAP, "id": hit.id, "normal": hit.normal, "pos": pos })
	return true


## Velocity in the world frame, whichever frame `vel` is in.
func world_vel() -> Vector2:
	return vel + ride_vel if riding >= 0 else vel
