class_name Flicker
extends Sprite2D
## Neon signs and old bulbs: mostly on, with the odd stutter. Frame 0 lit,
## frame 1 dark. An optional glow child follows the state.

@export var glow_path: NodePath
@export var stutter_chance := 0.18

var _timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = hash(global_position)
	_timer = _rng.randf_range(1.0, 5.0)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	if frame == 1:
		_set_lit(true)
		_timer = _rng.randf_range(1.5, 6.0)
	elif _rng.randf() < stutter_chance:
		_set_lit(false)
		_timer = _rng.randf_range(0.04, 0.16)
	else:
		_timer = _rng.randf_range(0.5, 2.0)


func _set_lit(lit: bool) -> void:
	frame = 0 if lit else 1
	var glow := get_node_or_null(glow_path) as CanvasItem
	if glow:
		glow.visible = lit
