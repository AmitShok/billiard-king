class_name TrapSpike
extends Node2D
## A red spiked ball sliding along a dotted red rail. Touch it and you get
## flung away. Motion lives in the CollisionWorld; this node only draws it.

const TEX := preload("res://assets/textures/spike_ball.png")
const GLOW := preload("res://assets/textures/glow.png")
const RAIL_LINE := preload("res://scripts/world/rail_line.gd")

@export var a := Vector2.ZERO
@export var b := Vector2.ZERO
@export var period := 5.0
@export var phase := 0.0
@export var radius := 8.0

var data: Dictionary
var _sprite: Sprite2D
var _glow: Sprite2D
var _flash := 0.0
var _t := 0.0


func _ready() -> void:
	process_physics_priority = 10
	var rail: Node2D = RAIL_LINE.new()
	rail.top_level = true
	rail.from = a
	rail.to = b
	rail.color = Color("e02028")
	rail.z_index = -1
	add_child(rail)
	_glow = Sprite2D.new()
	_glow.texture = GLOW
	_glow.scale = Vector2(0.8, 0.8)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	add_child(_glow)
	_sprite = Sprite2D.new()
	_sprite.texture = TEX
	_sprite.hframes = 2
	add_child(_sprite)


func hit() -> void:
	_flash = 1.0


func _physics_process(_delta: float) -> void:
	if not data.is_empty():
		position = data.pos


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 4.0)
	_sprite.frame = int(_t * 8.0) % 2
	_sprite.modulate = Color.WHITE.lerp(Color(2.0, 2.0, 2.0), _flash)
	_glow.modulate = Color(1.0, 0.15, 0.1, 0.35 + 0.15 * sin(_t * 6.0) + _flash * 0.4)
