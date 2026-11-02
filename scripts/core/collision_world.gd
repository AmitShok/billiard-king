class_name CollisionWorld
extends RefCounted
## Everything the ball can touch, in plain data: terrain cells, bumpers,
## pockets and lost balls. Built from the tower's TileMapLayer, so the live
## game and the headless route solver collide against exactly the same world.
##
## Tile atlas layout (see tools/art_tiles.lua): row 3z+0 table blocks,
## 3z+1 cushion blocks, 3z+2 slopes (cols 0/1 table, 2/3 cushion), z = zone.

enum Shape { NONE, SOLID, SLOPE_UP_RIGHT, SLOPE_UP_LEFT }
enum Mat { TABLE, CUSHION }
enum Kind { TILE, BUMPER }

const TILE := 16.0

## Vector2i -> [shape, material, zone]
var cells: Dictionary = {}
var bumpers: Array[Dictionary] = []   # {pos, radius, id}
var pockets: Array[Dictionary] = []   # {pos, radius, exit, goal, id}
var lost_balls: Array[Dictionary] = [] # {pos, number}


static func from_tilemap(layer: TileMapLayer) -> CollisionWorld:
	var world := CollisionWorld.new()
	for cell in layer.get_used_cells():
		var atlas := layer.get_cell_atlas_coords(cell)
		world.cells[cell] = decode_atlas(atlas)
	return world


static func decode_atlas(atlas: Vector2i) -> Array:
	var zone := atlas.y / 3
	match atlas.y % 3:
		0:
			return [Shape.SOLID, Mat.TABLE, zone]
		1:
			return [Shape.SOLID, Mat.CUSHION, zone]
		_:
			var shape := Shape.SLOPE_UP_RIGHT if atlas.x % 2 == 0 else Shape.SLOPE_UP_LEFT
			return [shape, Mat.CUSHION if atlas.x >= 2 else Mat.TABLE, zone]


func shape_at(cell: Vector2i) -> int:
	var c: Variant = cells.get(cell)
	return Shape.NONE if c == null else c[0]


func is_solid_point(p: Vector2) -> bool:
	var cell := Vector2i(floori(p.x / TILE), floori(p.y / TILE))
	var s := shape_at(cell)
	if s == Shape.SOLID:
		return true
	var lx := p.x - cell.x * TILE
	var ly := p.y - cell.y * TILE
	if s == Shape.SLOPE_UP_RIGHT:
		return lx + ly >= TILE
	if s == Shape.SLOPE_UP_LEFT:
		return ly >= lx
	return false


# Does the neighbour fully cover the face of `cell` that points along `dir`?
# Covered faces are internal seams: the ball must never catch on them.
func _face_covered(cell: Vector2i, dir: Vector2i) -> bool:
	var n := shape_at(cell + dir)
	if n == Shape.SOLID:
		return true
	if dir == Vector2i.UP:
		return n == Shape.SLOPE_UP_RIGHT or n == Shape.SLOPE_UP_LEFT
	if dir == Vector2i.RIGHT:
		return n == Shape.SLOPE_UP_LEFT
	if dir == Vector2i.LEFT:
		return n == Shape.SLOPE_UP_RIGHT
	return false


## Returns contacts {normal, depth, mat, zone, kind, id} for a circle,
## including touching contacts within `skin` (depth may be slightly negative).
func collide_circle(p: Vector2, r: float, skin: float = 0.5) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var reach := r + skin
	var x0 := floori((p.x - reach) / TILE)
	var x1 := floori((p.x + reach) / TILE)
	var y0 := floori((p.y - reach) / TILE)
	var y1 := floori((p.y + reach) / TILE)
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var cell := Vector2i(cx, cy)
			var c: Variant = cells.get(cell)
			if c == null:
				continue
			var hit := _tile_contact(cell, c[0], p, r)
			if hit.is_empty() or hit.depth < -skin:
				continue
			hit.mat = c[1]
			hit.zone = c[2]
			hit.kind = Kind.TILE
			hit.id = -1
			out.append(hit)
	for b in bumpers:
		var d: Vector2 = p - b.pos
		var dist := d.length()
		var depth: float = b.radius + r - dist
		if depth >= -skin and dist > 0.001:
			out.append({ "normal": d / dist, "depth": depth, "mat": Mat.CUSHION, "zone": 0, "kind": Kind.BUMPER, "id": b.id })
	return out


func _tile_contact(cell: Vector2i, shape: int, p: Vector2, r: float) -> Dictionary:
	var o := Vector2(cell) * TILE
	if shape == Shape.SOLID:
		return _box_contact(cell, o, p, r)
	return _slope_contact(cell, shape, o, p, r)


func _box_contact(cell: Vector2i, o: Vector2, p: Vector2, r: float) -> Dictionary:
	var q := Vector2(clampf(p.x, o.x, o.x + TILE), clampf(p.y, o.y, o.y + TILE))
	var d := p - q
	if d != Vector2.ZERO:
		# Distances measured across a covered face are seams: drop that axis so
		# a row of tiles behaves like one continuous surface.
		var side := Vector2i(signi(int(signf(d.x))), 0)
		var vert := Vector2i(0, signi(int(signf(d.y))))
		if d.x != 0.0 and d.y != 0.0:
			# Corner region: a surface only continues across a full block,
			# never across a slope (its top is not flush with ours).
			var mask_x := _face_covered(cell, side) and shape_at(cell + side) == Shape.SOLID
			var mask_y := _face_covered(cell, vert) and shape_at(cell + vert) == Shape.SOLID
			if mask_x:
				d.x = 0.0
			if mask_y:
				d.y = 0.0
		elif d.x != 0.0 and _face_covered(cell, side):
			return {}
		elif d.y != 0.0 and _face_covered(cell, vert):
			return {}
		if d == Vector2.ZERO:
			return {}
		var dist := d.length()
		return { "normal": d / dist, "depth": r - dist }
	# Centre inside the tile: push out through the nearest open face.
	var faces := [
		[Vector2i.UP, Vector2.UP, p.y - o.y],
		[Vector2i.DOWN, Vector2.DOWN, o.y + TILE - p.y],
		[Vector2i.LEFT, Vector2.LEFT, p.x - o.x],
		[Vector2i.RIGHT, Vector2.RIGHT, o.x + TILE - p.x],
	]
	var best: Array = []
	for f in faces:
		if _face_covered(cell, f[0]):
			continue
		if best.is_empty() or f[2] < best[2]:
			best = f
	if best.is_empty():
		return {}
	return { "normal": best[1], "depth": r + best[2] }


func _slope_contact(cell: Vector2i, shape: int, o: Vector2, p: Vector2, r: float) -> Dictionary:
	# Triangle: hypotenuse a->b, right-angle corner c, two legs c->a and c->b.
	var a: Vector2
	var b: Vector2
	var c := o + Vector2(TILE if shape == Shape.SLOPE_UP_RIGHT else 0.0, TILE)
	var hyp_normal: Vector2
	var side_dir: Vector2i
	if shape == Shape.SLOPE_UP_RIGHT:
		a = o + Vector2(0, TILE)
		b = o + Vector2(TILE, 0)
		hyp_normal = Vector2(-1, -1).normalized()
		side_dir = Vector2i.RIGHT
	else:
		a = o + Vector2(TILE, TILE)
		b = o
		hyp_normal = Vector2(1, -1).normalized()
		side_dir = Vector2i.LEFT
	var side := (p - a).dot(hyp_normal)
	if side >= 0.0:
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var d := p - q
		var dist := d.length()
		if dist < 0.0001:
			return { "normal": hyp_normal, "depth": r }
		return { "normal": d / dist, "depth": r - dist }
	# Beside the vertical leg (c->b) or under the bottom leg (c->a)?
	var beyond_side := (p.x - c.x) * float(side_dir.x)
	if beyond_side > 0.0:
		if _face_covered(cell, side_dir):
			return {}
		var qs := Geometry2D.get_closest_point_to_segment(p, c, b)
		var ds := p - qs
		return {} if ds.length() < 0.0001 else { "normal": ds.normalized(), "depth": r - ds.length() }
	if p.y > c.y:
		if _face_covered(cell, Vector2i.DOWN):
			return {}
		var qb := Geometry2D.get_closest_point_to_segment(p, c, a)
		var db := p - qb
		return {} if db.length() < 0.0001 else { "normal": db.normalized(), "depth": r - db.length() }
	# Centre inside the triangle: push out along the hypotenuse.
	return { "normal": hyp_normal, "depth": r - side }
