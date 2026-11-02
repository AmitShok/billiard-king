extends Area2D
class_name Checkpoint
## Passive checkpoint: the cue ball only "locks in" a checkpoint when it
## comes to REST inside the zone, not just on touch. This prevents cheap
## checkpoints from a ball merely grazing the area mid-flight, keeping the
## Jump-King-style tension (a bad shot can still carry you back past one).

@export var checkpoint_id: int = 0
@onready var marker: Marker2D = $Marker2D  # exact respawn position/orientation

var _ball_inside: PlayerCueBall = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body is PlayerCueBall:
		_ball_inside = body
		body.came_to_rest.connect(_try_lock_checkpoint, CONNECT_ONE_SHOT)

func _on_body_exited(body: Node) -> void:
	if body == _ball_inside:
		_ball_inside = null

func _try_lock_checkpoint() -> void:
	if _ball_inside == null:
		return
	_ball_inside.set_checkpoint(marker.global_position)
	GameManager.register_checkpoint(checkpoint_id)
	_flash_confirmation()

func _flash_confirmation() -> void:
	var sprite: Node = get_node_or_null("Sprite2D")
	if sprite:
		var tween: Tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(0.4, 1.0, 0.6), 0.15)
		tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.3)
