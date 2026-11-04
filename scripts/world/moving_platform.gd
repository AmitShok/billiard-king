class_name MovingPlatform
extends Node2D
## A brass carriage that rides back and forth on a visible rail. Sideways,
## up and down, or diagonal. Its motion lives in the CollisionWorld (a pure
## function of time); this node only draws it.

const TEX := preload("res://assets/textures/moving_platform.png")
const RAIL_LINE := preload("res://scripts/world/rail_line.gd")

@export var a := Vector2.ZERO      # top-left at one end of the rail
@export var b := Vector2.ZERO      # top-left at the other end
@export var tiles := 3             # width in tiles (always one tile tall)
@export var period := 6.0          # seconds for a full there-and-back
@export var phase := 0.0
@export var zone := 0

var data: Dictionary               # this platform's entry in CollisionWorld.platforms


func size_px() -> Vector2:
	return Vector2(tiles * 16.0, 16.0)


func _ready() -> void:
	# Runs after the balls have stepped, so the ball and its carriage stay in sync.
	process_physics_priority = 10
	var half := size_px() / 2.0
	var rail: Node2D = RAIL_LINE.new()
	rail.top_level = true
	rail.from = a + half
	rail.to = b + half
	rail.color = Color("c49a40")
	rail.z_index = -1
	add_child(rail)
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if not data.is_empty():
		position = data.pos


func _draw() -> void:
	var row := clampi(zone, 0, 2) * 16
	for i in tiles:
		var part := 1
		if i == 0:
			part = 0
		elif i == tiles - 1:
			part = 2
		draw_texture_rect_region(TEX, Rect2(i * 16, 0, 16, 16), Rect2(part * 16, row, 16, 16))
