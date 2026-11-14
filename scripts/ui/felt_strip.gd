@tool
class_name FeltStrip
extends Control
## The strip of table tiles along the bottom of the title screen: a felt edge
## on top, wood below. Drawn from the tile sheet, and shown in the editor too.

const TILE := 16

@export var tiles: Texture2D:
	set(v):
		tiles = v
		queue_redraw()
## Sheet column of the felt edge (top row) and of the wood (rows below).
@export var edge_column := 1
@export var wood_column := 0


func _draw() -> void:
	if tiles == null:
		return
	var cols := ceili(size.x / TILE)
	var rows := ceili(size.y / TILE)
	for row in rows:
		var column := edge_column if row == 0 else wood_column
		for i in cols:
			draw_texture_rect_region(tiles, Rect2(i * TILE, row * TILE, TILE, TILE), Rect2(column * TILE, 0, TILE, TILE))
