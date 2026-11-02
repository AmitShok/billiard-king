extends RigidBody2D
class_name ObjectBall
## A colored object ball (solids/stripes/8-ball) that blocks the player's
## path. Striking it into a Pocket awards points and removes it, opening
## the route forward.

signal ball_pocketed(points: int)

@export var ball_number: int = 9
@export var points: int = 100
@export_range(0.0, 1.0) var pop_scale_duration: float = 0.25
@export var friction_material: PhysicsMaterial

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _pocketed: bool = false

func _ready() -> void:
	add_to_group("object_balls")
	if friction_material:
		physics_material_override = friction_material

## Connect this to a Pocket's `body_entered` signal in the editor,
## or call directly from Pocket.gd: object_ball._on_entered_pocket(pocket)
func _on_entered_pocket(pocket: Node) -> void:
	if _pocketed:
		return
	_pocketed = true
	set_deferred("freeze", true)
	collision_shape.set_deferred("disabled", true)
	ball_pocketed.emit(points)
	_play_pop_effect()

func _play_pop_effect() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2.ZERO, pop_scale_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "modulate:a", 0.0, pop_scale_duration)
	tween.chain().tween_callback(queue_free)

	# Optional: spawn a GPUParticles2D burst if a scene is assigned.
	var particles_scene: PackedScene = get_meta("pop_particles", null)
	if particles_scene:
		var fx: Node2D = particles_scene.instantiate()
		get_tree().current_scene.add_child(fx)
		fx.global_position = global_position
