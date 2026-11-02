@tool
class_name Pocket
extends Node2D
## A pocket in the tower. Normal pockets swallow the ball and the ball-return
## drops it out at `exit` (usually far below: the big Jump King fall).
## The gold pocket at the summit ends the climb.

const RADIUS := 6.0

@export var exit := Vector2.ZERO
@export var goal := false:
	set(v):
		goal = v
		_refresh()

var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	# The pocket node sits at the tile centre; its mouth art lines up with the felt below.
	_sprite.position = Vector2(0, 12)
	add_child(_sprite)
	_refresh()


func _refresh() -> void:
	if _sprite:
		_sprite.texture = load("res://assets/textures/pocket_gold.png" if goal else "res://assets/textures/pocket.png")
