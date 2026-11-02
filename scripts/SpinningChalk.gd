extends Node2D
class_name SpinningChalk
## A rotating hazard (visually: a spinning cube of chalk / triangle rack).
## On contact with the cue ball, it does NOT destroy the ball — it violently
## redirects it, usually costing the player huge amounts of progress.
## This is the primary "Jump King fall" punishment mechanic.

@export var rotation_speed: float = 4.0          # rad/s, visual spin
@export var launch_force: float = 1400.0
@export var launch_upward_bias: float = 0.3      # 0 = pure reflection, 1 = mostly straight up-table
@export var hit_cooldown: float = 0.4            # prevents double-hits in one collision frame

@onready var hitbox: Area2D = $HitArea
@onready var sprite: Node2D = $Sprite2D

var _cooldown_timer: float = 0.0

func _ready() -> void:
	hitbox.body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	sprite.rotation += rotation_speed * delta
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

func _on_body_entered(body: Node) -> void:
	if _cooldown_timer > 0.0:
		return
	if not (body is PlayerCueBall):
		return

	_cooldown_timer = hit_cooldown

	# Launch direction: reflect the ball's incoming velocity away from the
	# hazard center, blended with an "upward" (back toward table start) bias
	# so hits feel punishing rather than merely random.
	var away_dir: Vector2 = (body.global_position - global_position).normalized()
	var back_toward_start: Vector2 = -GameManager.get_table_gravity_dir()
	var launch_dir: Vector2 = (away_dir.lerp(back_toward_start, launch_upward_bias)).normalized()

	body.apply_hazard_impulse(launch_dir * launch_force)
	_play_hit_feedback()

func _play_hit_feedback() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2.ONE * 1.4, 0.08)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.12)
