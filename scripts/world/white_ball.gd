class_name WhiteBall
extends Node2D
## Hardcore mode's floating white ball. It has no gravity: felt drag slows it
## in every direction and it stops wherever it runs out of speed, even in
## mid-air. The player's ball knocks it along (PlayerBall steps and collides
## both sims); this node only draws it.

const GLOW := preload("res://assets/textures/glow.png")

var sim := BallSim.new()
var _visual: BallVisual
var _glow: Sprite2D
var _t := 0.0


func _init() -> void:
	sim.floating = true


func _ready() -> void:
	_glow = Sprite2D.new()
	_glow.texture = GLOW
	_glow.scale = Vector2(0.5, 0.5)
	_glow.modulate = Color(0.8, 0.9, 1.0, 0.25)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	add_child(_glow)
	_visual = BallVisual.new()
	_visual.number = 16
	_visual.diameter = 16
	add_child(_visual)


func place(at: Vector2) -> void:
	sim.reset(at)
	position = at
	reset_physics_interpolation()
	_visual.scale = Vector2.ONE
	_visual.set_alpha(1.0)


func sink(at: Vector2) -> void:
	sim.pos = at
	position = at
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_visual, "scale", Vector2(0.4, 0.4), 0.35).set_ease(Tween.EASE_IN)
	tw.tween_method(_visual.set_alpha, 1.0, 0.0, 0.35)


func knock(impact: float) -> void:
	_visual.flash = clampf(impact / 600.0, 0.15, 0.6)


func _physics_process(_delta: float) -> void:
	if not sim.in_pocket:
		position = sim.pos


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	_t += dt
	_visual.roll(sim.spin_rate, sim.tumble_rate, dt)
	_visual.flash = move_toward(_visual.flash, 0.0, dt * 3.0)
	# A soft pulse so it reads as the objective even when it's sitting still.
	_glow.modulate.a = 0.18 + 0.1 * sin(_t * 2.5)
