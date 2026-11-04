class_name TrapSpinner
extends Node2D
## A spinning arm trap. Touch an arm and you get flung away. Hazard stripes,
## a pulsing red glow and a dotted ring marking its reach keep it from ever
## reading as decoration. Drawn pixel by pixel to stay crisp at any angle.

const HUB := preload("res://assets/textures/spinner_hub.png")
const GLOW := preload("res://assets/textures/glow.png")
const RED := Color("e02028")
const YELLOW := Color("ffc21a")
const INK := Color("11090c")

@export var arms := 2
@export var length := 40.0
@export var speed := 1.5           # rad/s, sign = direction
@export var angle0 := 0.0

var world: CollisionWorld
var data: Dictionary
var _flash := 0.0
var _t := 0.0
var _glow: Sprite2D


func _ready() -> void:
	_glow = Sprite2D.new()
	_glow.texture = GLOW
	_glow.scale = Vector2.ONE * (length / 26.0)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.show_behind_parent = true
	add_child(_glow)


func hit() -> void:
	_flash = 1.0


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 4.0)
	_glow.modulate = Color(1.0, 0.15, 0.1, 0.3 + 0.12 * sin(_t * 5.0) + _flash * 0.4)
	queue_redraw()


func _draw() -> void:
	# Dotted danger ring: exactly how far the arms reach.
	var ring := length + 2.0
	var dots := int(TAU * ring / 7.0)
	for i in dots:
		var p := (Vector2.from_angle(TAU * i / dots + _t * 0.3) * ring).round()
		draw_rect(Rect2(p, Vector2.ONE), Color(1.0, 0.25, 0.2, 0.75))
	for arm in arms:
		var ang: float = world.spinner_angle(data, arm) if world else angle0 + arm * TAU / arms
		var dir := Vector2.from_angle(ang)
		var perp := Vector2(-dir.y, dir.x)
		var steps := int(length)
		# Dark outline first, then the striped arm.
		for i in steps + 1:
			for w in range(-3, 4):
				draw_rect(Rect2((dir * i + perp * w).round(), Vector2.ONE), INK)
		for i in steps:
			var col := RED if (i / 5) % 2 == 0 else YELLOW
			if _flash > 0.0:
				col = col.lerp(Color.WHITE, _flash)
			for w in range(-2, 3):
				draw_rect(Rect2((dir * i + perp * w).round(), Vector2.ONE), col)
		for w in range(-2, 3):
			draw_rect(Rect2((dir * (length - 1.0) + perp * w).round(), Vector2.ONE), Color.WHITE)
	draw_texture(HUB, Vector2(-9, -9))
