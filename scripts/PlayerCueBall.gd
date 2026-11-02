extends RigidBody2D
class_name PlayerCueBall
## Bird's-eye-view precision cue ball (Miniclip 8-Ball style).
## No directional gravity is applied to the ball — this is a flat overhead
## table, not a tilted one. Godot's own `mass` property (Inspector ->
## RigidBody2D -> Mass) IS the ball's weight: the same shot impulse
## produces less speed on a heavier ball, and mass feeds directly into the
## engine's elastic collisions against object balls — no extra code needed.

signal shot_taken(force: float, direction: Vector2)
signal scratched()
signal came_to_rest()

enum State { AIMING, MOVING, SCRATCHED }

# --- Rolling friction (the felt) --------------------------------------------
@export_range(0.0, 1.0) var rolling_friction: float = 0.25 ## μ — higher = felt grips harder, ball stops sooner
@export var gravity_reference: float = 980.0 ## scalar stand-in for 9.8 m/s²; used ONLY to size friction, not a direction
@export var min_roll_speed: float = 4.0 ## below this, snap to a full stop instead of crawling forever

# --- Cushion (wall) bounce, strength-dependent ------------------------------
@export_range(0.0, 1.0) var min_wall_restitution: float = 0.55 ## soft taps barely bounce
@export_range(0.0, 1.0) var max_wall_restitution: float = 0.92 ## hard hits stay lively
@export var max_expected_impact_speed: float = 1400.0 ## px/s at which restitution maxes out
@export_range(0.0, 1.0) var wall_tangent_friction: float = 0.08 ## scrubs a little sideways speed on each cushion hit

# --- Shot / aiming -----------------------------------------------------------
@export var max_drag_distance: float = 220.0
@export var max_impulse_force: float = 1800.0
@export var min_impulse_force: float = 80.0
@export var velocity_stop_threshold: float = 5.0
@export var angular_stop_threshold: float = 0.15
@export var stop_check_delay: float = 0.12

# --- Trajectory preview ------------------------------------------------------
@export var trajectory_point_count: int = 24
@export var trajectory_length: float = 260.0

@onready var aim_line: Line2D = $AimLine
@onready var power_indicator: Node2D = $PowerIndicator

var current_state: State = State.AIMING
var is_dragging: bool = false
var _stop_timer: float = 0.0
var last_checkpoint_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 6
	gravity_scale = 0.0    # bird's-eye table: nothing pulls the ball in a direction
	continuous_cd = CCD_MODE_CAST_SHAPE   # thin cushions + a fast ball = tunneling risk otherwise
	aim_line.clear_points()
	aim_line.visible = false
	last_checkpoint_position = global_position

# ---------------------------------------------------------------------------
# INPUT / AIMING
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if current_state != State.AIMING:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_aim()
		else:
			_release_aim()
	elif event is InputEventMouseMotion and is_dragging:
		_update_aim()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_start_aim()
		else:
			_release_aim()
	elif event is InputEventScreenDrag and is_dragging:
		_update_aim()

func _start_aim() -> void:
	is_dragging = true
	aim_line.visible = true

func _update_aim() -> void:
	var pull_vector: Vector2 = global_position - get_global_mouse_position()
	var clamped_pull: Vector2 = pull_vector.limit_length(max_drag_distance)
	var shot_dir: Vector2 = clamped_pull.normalized()
	var power_ratio: float = clamped_pull.length() / max_drag_distance
	_draw_trajectory_preview(shot_dir, power_ratio)
	if power_indicator:
		power_indicator.rotation = shot_dir.angle()
		power_indicator.scale = Vector2.ONE * (0.5 + power_ratio * 0.5)

func _release_aim() -> void:
	is_dragging = false
	aim_line.visible = false
	var pull_vector: Vector2 = global_position - get_global_mouse_position()
	var clamped_pull: Vector2 = pull_vector.limit_length(max_drag_distance)
	if clamped_pull.length() < 4.0:
		return
	var power_ratio: float = clamped_pull.length() / max_drag_distance
	var force: float = lerp(min_impulse_force, max_impulse_force, power_ratio)
	_fire_shot(clamped_pull.normalized(), force)

func _fire_shot(direction: Vector2, force: float) -> void:
	current_state = State.MOVING
	_stop_timer = 0.0
	# Same impulse yields a smaller Δv on a heavier ball — Godot divides by
	# `mass` internally, so the Inspector's Mass field already IS the weight.
	apply_central_impulse(direction * force)
	shot_taken.emit(force, direction)

func _draw_trajectory_preview(direction: Vector2, power_ratio: float) -> void:
	aim_line.clear_points()
	var length: float = trajectory_length * power_ratio
	for i in range(trajectory_point_count):
		var t: float = float(i) / float(trajectory_point_count - 1)
		aim_line.add_point(direction * length * t)

# ---------------------------------------------------------------------------
# PHYSICS: rolling friction + strength-dependent cushion bounce
# ---------------------------------------------------------------------------
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	_apply_rolling_friction(state)
	_handle_wall_collisions(state)

## Real billiard-ball friction is close to a CONSTANT deceleration
## (a = μ·g), not an exponential decay — this is what lets a player learn to
## judge rolling distance consistently, the way you can on a real (or
## Miniclip) table. Mass does NOT appear in this formula: heavier and
## lighter balls slow down at the same rate once rolling, same as real
## billiard balls (friction force scales with weight, but so does inertia,
## so they cancel).
func _apply_rolling_friction(state: PhysicsDirectBodyState2D) -> void:
	var vel: Vector2 = state.linear_velocity
	var speed: float = vel.length()
	if speed <= 0.0:
		return

	var decel: float = rolling_friction * gravity_reference * state.step
	if speed <= decel or speed < min_roll_speed:
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
	else:
		state.linear_velocity = vel - vel.normalized() * decel
		state.angular_velocity = lerp(state.angular_velocity, 0.0, clamp(rolling_friction * state.step * 4.0, 0.0, 1.0))

## Custom cushion bounce: restitution SCALES with how hard the ball hits the
## wall, instead of using Godot's flat PhysicsMaterial bounce value.
## IMPORTANT SETUP: set every cushion StaticBody2D's PhysicsMaterial bounce
## to 0 and add it to the "cushions" group, or the engine's own restitution
## will stack on top of this and the bounce will feel wrong/uncontrollable.
func _handle_wall_collisions(state: PhysicsDirectBodyState2D) -> void:
	for i in state.get_contact_count():
		var collider: Object = state.get_contact_collider_object(i)
		if collider == null or not (collider is StaticBody2D):
			continue
		if not collider.is_in_group("cushions"):
			continue

		var normal: Vector2 = state.get_contact_local_normal(i)
		var vel: Vector2 = state.linear_velocity
		var incoming_speed: float = -vel.dot(normal) # positive = moving into the wall

		if incoming_speed <= 0.0:
			continue # already separating this frame — don't double-bounce the same contact

		var restitution: float = _dynamic_restitution(incoming_speed)
		var normal_component: Vector2 = vel.dot(normal) * normal
		var tangent_component: Vector2 = vel - normal_component

		var bounced: Vector2 = (-normal_component * restitution) + (tangent_component * (1.0 - wall_tangent_friction))
		state.linear_velocity = bounced
		_on_wall_bounce(incoming_speed, restitution)

## Harder hits retain proportionally more energy (up to max_wall_restitution);
## soft taps feel "dead" against the cushion. This mirrors real rubber
## cushion behavior at low-to-mid speeds and gives hard shots a lively,
## satisfying carom — the signature Miniclip 8-Ball cushion feel.
func _dynamic_restitution(impact_speed: float) -> float:
	var t: float = clamp(impact_speed / max_expected_impact_speed, 0.0, 1.0)
	t = sqrt(t) # front-loads the ramp so mid-power shots already feel lively
	return lerp(min_wall_restitution, max_wall_restitution, t)

func _on_wall_bounce(impact_speed: float, restitution: float) -> void:
	pass # hook for camera shake / cushion SFX volume / flash, scaled by impact_speed

# ---------------------------------------------------------------------------
# STOP DETECTION / STATE
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if current_state != State.MOVING:
		return
	var is_slow: bool = linear_velocity.length() < velocity_stop_threshold
	var is_settled: bool = abs(angular_velocity) < angular_stop_threshold
	if is_slow and is_settled:
		_stop_timer += delta
		if _stop_timer >= stop_check_delay:
			_settle_to_aiming()
	else:
		_stop_timer = 0.0

func _settle_to_aiming() -> void:
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	current_state = State.AIMING
	came_to_rest.emit()

# ---------------------------------------------------------------------------
# SCRATCH / CHECKPOINT
# ---------------------------------------------------------------------------
func apply_hazard_impulse(impulse: Vector2) -> void:
	current_state = State.MOVING
	apply_central_impulse(impulse)

func scratch() -> void:
	if current_state == State.SCRATCHED:
		return
	current_state = State.SCRATCHED
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	scratched.emit()
	await get_tree().create_timer(0.6).timeout
	_reset_to_checkpoint()

func _reset_to_checkpoint() -> void:
	global_position = last_checkpoint_position
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	current_state = State.AIMING

func set_checkpoint(pos: Vector2) -> void:
	last_checkpoint_position = pos
