@tool
class_name BallVisual
extends Node2D
## Draws one billiard ball with the spherical-UV shader and keeps its 3D
## orientation. Call roll() every frame with angular speeds; the skin texture
## rotates over the sphere so the ball reads as genuinely rolling.

const SKIN := preload("res://assets/textures/balls.png")
const SHADER := preload("res://shaders/ball.gdshader")

@export_range(0, 15) var number: int = 0:
	set(v):
		number = v
		_apply()
@export var diameter: int = 16:
	set(v):
		diameter = v
		_apply()
		queue_redraw()

var orientation := Basis.IDENTITY
var flash := 0.0:
	set(v):
		flash = v
		if _mat:
			_mat.set_shader_parameter("flash", v)

var _mat: ShaderMaterial


func _init() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("skin", SKIN)
	material = _mat
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _ready() -> void:
	# Start each ball turned a little so the number isn't dead centre.
	orientation = Basis(Vector3.UP, 0.6 + number * 0.37) * Basis(Vector3.RIGHT, 0.25)
	_apply()


func _apply() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("cell", Vector2(number % 4, number / 4))
	_mat.set_shader_parameter("diameter_px", float(diameter))
	_mat.set_shader_parameter("orientation", orientation)


## spin: rad/s about the view axis (rolling along the screen);
## tumble: rad/s about the horizontal axis (top toward the viewer).
func roll(spin: float, tumble: float, dt: float) -> void:
	if spin != 0.0:
		orientation = Basis(Vector3.BACK, -spin * dt) * orientation
	if tumble != 0.0:
		orientation = Basis(Vector3.RIGHT, tumble * dt) * orientation
	orientation = orientation.orthonormalized()
	_mat.set_shader_parameter("orientation", orientation)


func set_alpha(a: float) -> void:
	_mat.set_shader_parameter("alpha", a)


func _draw() -> void:
	var h := diameter / 2.0
	draw_texture_rect(SKIN, Rect2(-h, -h, diameter, diameter), false)
