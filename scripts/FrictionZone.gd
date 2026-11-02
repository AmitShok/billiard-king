extends Area2D
class_name FrictionZone
## "Magnetic chalk" / rough-felt patch. While the cue ball overlaps this
## zone, its velocity is aggressively damped each physics tick — enough to
## strand a ball mid-table if the player enters at low speed, but a fast
## enough shot can still punch through. This creates risk/reward around
## shot power near these zones.

@export var damping_per_second: float = 6.0   ## higher = stops the ball faster
@export_range(0.0, 1.0) var min_speed_to_escape: float = 0.0 ## 0 = can never fully resist
@export var visual_tint: Color = Color(0.55, 0.4, 0.25, 0.5)

@onready var shape_visual: Node2D = $ZoneVisual

var _balls_inside: Array[RigidBody2D] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if shape_visual:
		shape_visual.modulate = visual_tint

func _on_body_entered(body: Node) -> void:
	if body is RigidBody2D:
		_balls_inside.append(body)

func _on_body_exited(body: Node) -> void:
	_balls_inside.erase(body)

func _physics_process(delta: float) -> void:
	for ball in _balls_inside:
		if not is_instance_valid(ball):
			continue
		# Exponential decay toward zero — framerate independent.
		var decay: float = clamp(1.0 - damping_per_second * delta, 0.0, 1.0)
		ball.linear_velocity *= decay
		ball.angular_velocity *= decay
