extends Area2D
class_name Pocket
## Attach to an Area2D placed at each pocket mesh on the table.
## Differentiates between the player (scratch) and object balls (score).
##
## Setup: Area2D with a small CircleShape2D roughly matching the pocket
## mouth, collision layer "pockets", mask set to detect "cue_ball" and
## "object_balls" layers.

@export var is_goal_pocket: bool = false ## the final win pocket at level end

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body is PlayerCueBall:
		if is_goal_pocket:
			GameManager.complete_level()
		else:
			body.scratch()
			GameManager.register_scratch()
	elif body is ObjectBall:
		body._on_entered_pocket(self)
		GameManager.register_ball_pocketed(body.points)
