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
enum Kind { TILE, BUMPER, PLATFORM }
enum Trap { SPINNER, SPIKE }

const TILE := 16.0
const SPINNER_HALF_WIDTH := 2.0
const WIND_SWELL := 0.35   # seconds for a gust to build or die

## Vector2i -> [shape, material, zone]
var cells: Dictionary = {}
var bumpers: Array[Dictionary] = []   # {pos, radius, id}
var pockets: Array[Dictionary] = []   # {pos, radius, exit, goal, id}
var lost_balls: Array[Dictionary] = [] # {pos, number}
## Moving things, as pure functions of `time`, so a shot replays identically.
var platforms: Array[Dictionary] = [] # {a, b, size, period, phase, zone, pos, vel}; pos = top-left
var traps: Array[Dictionary] = []     # spinner {kind, center, arms, length, speed, angle0}, spike {kind, a, b, period, phase, radius, pos, vel}
var time := 0.0
## Per-screen conditions: screen -> gravity multiplier, screen -> {dir, strength, on, off, phase}.
var screen_gravity := {}
var screen_wind := {}
## Set by set_active_window: only these movers tick and collide. Null means all of them.
var _active_platforms: Variant = null
var _active_traps: Variant = null


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
	for i: int in (range(platforms.size()) if _active_platforms == null else _active_platforms):
		var plat := platforms[i]
		# Quick reject: most platforms are nowhere near the ball.
		var pp: Vector2 = plat.pos
		var ps: Vector2 = plat.size
		if p.y < pp.y - reach or p.y > pp.y + ps.y + reach or p.x < pp.x - reach or p.x > pp.x + ps.x + reach:
			continue
		var hit := _rect_contact(pp, ps, p, r)
		if hit.depth >= -skin:
			hit.mat = Mat.TABLE
			hit.zone = plat.zone
			hit.kind = Kind.PLATFORM
			hit.id = i
			out.append(hit)
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


# --- Low gravity and wind -----------------------------------------------------------

func gravity_scale_at(y: float) -> float:
	if screen_gravity.is_empty():
		return 1.0
	return screen_gravity.get(floori(-y / 288.0), 1.0)


## The wind acceleration at this height right now. Each windy section blows
## one way only (like Jump King's bluffs): it gusts for `on` seconds, then
## falls calm for `off` seconds, with a short swell at each end.
func wind_at(y: float) -> Vector2:
	if screen_wind.is_empty():
		return Vector2.ZERO
	var w: Variant = screen_wind.get(floori(-y / 288.0))
	if w == null:
		return Vector2.ZERO
	return w.dir * w.strength * gust_level(w)


## 0 in the lull, rising to 1 through the gust.
func gust_level(w: Dictionary) -> float:
	var cycle: float = w.on + w.off
	var t := fposmod(time / cycle + w.phase, 1.0) * cycle
	if t >= w.on:
		return 0.0
	return minf(1.0, minf(t, w.on - t) / WIND_SWELL)


# --- Moving platforms and traps -----------------------------------------------------

## Back-and-forth along a -> b with eased ends.
static func path_pos(a: Vector2, b: Vector2, period: float, phase: float, t: float) -> Vector2:
	var s := 0.5 - 0.5 * cos(TAU * (t / period + phase))
	return a.lerp(b, s)


## The route solver limits work to movers whose paths come near this y range.
func set_active_window(y_lo: float, y_hi: float) -> void:
	var ps: Array[int] = []
	for i in platforms.size():
		var p := platforms[i]
		if maxf(p.a.y, p.b.y) >= y_lo and minf(p.a.y, p.b.y) <= y_hi:
			ps.append(i)
	var ts: Array[int] = []
	for i in traps.size():
		var tr := traps[i]
		var top: float = tr.center.y if tr.kind == Trap.SPINNER else minf(tr.a.y, tr.b.y)
		var bottom: float = tr.center.y if tr.kind == Trap.SPINNER else maxf(tr.a.y, tr.b.y)
		if bottom >= y_lo and top <= y_hi:
			ts.append(i)
	_active_platforms = ps
	_active_traps = ts


## Moves everything to time t, with correct velocities.
func set_time(t: float) -> void:
	time = t - BallSim.DT
	for p in platforms:
		p.pos = path_pos(p.a, p.b, p.period, p.phase, time)
	for tr in traps:
		if tr.kind == Trap.SPIKE:
			tr.pos = path_pos(tr.a, tr.b, tr.period, tr.phase, time)
	advance(BallSim.DT)


func advance(dt: float) -> void:
	time += dt
	for i: int in (range(platforms.size()) if _active_platforms == null else _active_platforms):
		var p := platforms[i]
		var next := path_pos(p.a, p.b, p.period, p.phase, time)
		p.vel = (next - p.pos) / dt
		p.pos = next
	for i: int in (range(traps.size()) if _active_traps == null else _active_traps):
		var tr := traps[i]
		if tr.kind == Trap.SPIKE:
			var next := path_pos(tr.a, tr.b, tr.period, tr.phase, time)
			tr.vel = (next - tr.pos) / dt
			tr.pos = next


func spinner_angle(tr: Dictionary, arm: int) -> float:
	return tr.angle0 + tr.speed * time + arm * TAU / tr.arms


## A trap overlapping this circle: {normal, depth, vel (trap surface velocity), id}, or {}.
func trap_contact(p: Vector2, r: float) -> Dictionary:
	for i: int in (range(traps.size()) if _active_traps == null else _active_traps):
		var tr := traps[i]
		if tr.kind == Trap.SPIKE:
			var d: Vector2 = p - tr.pos
			if absf(d.y) > 40.0:
				continue
			var dist := d.length()
			if dist < tr.radius + r and dist > 0.001:
				return { "normal": d / dist, "depth": tr.radius + r - dist, "vel": tr.vel, "id": i }
			continue
		var reach: float = tr.length + r + SPINNER_HALF_WIDTH
		if absf(p.y - tr.center.y) > reach or p.distance_squared_to(tr.center) > reach * reach:
			continue
		for arm in tr.arms:
			var tip: Vector2 = tr.center + Vector2.from_angle(spinner_angle(tr, arm)) * tr.length
			var q := Geometry2D.get_closest_point_to_segment(p, tr.center, tip)
			var d := p - q
			var dist := d.length()
			if dist < SPINNER_HALF_WIDTH + r and dist > 0.001:
				var along: Vector2 = q - tr.center
				return { "normal": d / dist, "depth": SPINNER_HALF_WIDTH + r - dist, "vel": Vector2(-along.y, along.x) * tr.speed, "id": i }
	return {}


func _rect_contact(o: Vector2, size: Vector2, p: Vector2, r: float) -> Dictionary:
	var q := Vector2(clampf(p.x, o.x, o.x + size.x), clampf(p.y, o.y, o.y + size.y))
	var d := p - q
	if d != Vector2.ZERO:
		var dist := d.length()
		return { "normal": d / dist, "depth": r - dist }
	# Centre inside: push out through the nearest side.
	var faces := [[Vector2.UP, p.y - o.y], [Vector2.DOWN, o.y + size.y - p.y], [Vector2.LEFT, p.x - o.x], [Vector2.RIGHT, o.x + size.x - p.x]]
	var best: Array = faces[0]
	for f in faces:
		if f[1] < best[1]:
			best = f
	return { "normal": best[0], "depth": r + best[1] }
