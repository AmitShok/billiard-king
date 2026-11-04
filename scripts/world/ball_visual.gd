@tool
class_name BallVisual
extends Node2D
## Draws one billiard ball with the spherical-UV shader and keeps its 3D
## orientation. Call roll() every frame with angular speeds; the skin texture
## rotates over the sphere so the ball reads as genuinely rolling.

const SKIN := preload("res://assets/textures/balls.png")
const SHADER := preload("res://shaders/ball.gdshader")

const RAINBOW := 27
const GLOW := preload("res://assets/textures/glow.png")

@export_range(0, 27) var number: int = 0:
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
var _rainbow_glow: Sprite2D
var _t := 0.0


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
	_mat.set_shader_parameter("rainbow", 1.0 if number == RAINBOW else 0.0)
	_sync_rainbow_glow()


## The rainbow ball glows, cycling through the colours behind the ball.
func _sync_rainbow_glow() -> void:
	var on := number == RAINBOW
	set_process(on)
	if on and _rainbow_glow == null:
		_rainbow_glow = Sprite2D.new()
		_rainbow_glow.texture = GLOW
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_rainbow_glow.material = add
		_rainbow_glow.show_behind_parent = true
		add_child(_rainbow_glow)
	if _rainbow_glow:
		_rainbow_glow.visible = on
		_rainbow_glow.scale = Vector2.ONE * (diameter * 2.6 / 64.0)


func _process(delta: float) -> void:
	_t += delta
	_rainbow_glow.modulate = Color.from_hsv(fmod(_t * 0.35, 1.0), 0.75, 1.0, 0.65 + 0.2 * sin(_t * 4.0))


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
