extends SceneTree
## Bakes levels/tower.txt into scenes/world/tower.tscn (+ resources/tiles.tres).
##   godot --headless --path <project> --script tools/build_tower.gd
##
## Map legend (one char = one 16px tile, 32x18 per screen):
##   #  table block        C  rubber cushion block
##   /  slope rising right \  slope rising left     { }  cushion slopes
##   S  spawn              B  bumper (8-ball unless a digit follows in ##objects)
##   O  pocket -> drops to the nearest 'o' below it
##   o  pocket exit        K  gold goal pocket (+ crown)
##   1-9 a-f  lost ball 1..15
##   decor: L lamp  H chandelier  R cue rack  Q score beads  P neon POOL
##          E neon 8-ball  F portrait  W window  T clock  k chalk  r rack
## Solid tiles are autotiled from their neighbours; zone comes from the
## screen header ("== screen 3 zone 1").

const TILE := 16
const W := 32
const H := 18
const SCREEN_H := H * TILE
const ZONE_BG := ["bg_backroom", "bg_neonbar", "bg_royal", "bg_summit"]

var tex := {}
var _bad := false


func _initialize() -> void:
	var screens := _parse("res://levels/tower.txt")
	if screens.is_empty() or _bad:
		push_error("no screens parsed")
		quit(1)
		return
	var count := 0
	for s in screens:
		count = maxi(count, s.index + 1)
	var zones := PackedInt32Array()
	zones.resize(count)
	var grid := {}       # Vector2i -> char
	var cell_zone := {}  # Vector2i -> tile zone
	for s in screens:
		zones[s.index] = s.zone
		for r in H:
			var row: String = s.rows[r]
			for c in W:
				var cell := Vector2i(c, -(s.index + 1) * H + r)
				grid[cell] = row[c]
				cell_zone[cell] = mini(s.zone, 2)

	var tileset := _make_tileset()
	ResourceSaver.save(tileset, "res://resources/tiles.tres")
	tileset = load("res://resources/tiles.tres")

	var root := Node2D.new()
	root.name = "Tower"
	root.set_script(load("res://scripts/world/tower.gd"))
	root.set("screen_zones", zones)

	var backdrop := Node2D.new()
	backdrop.name = "Backdrop"
	backdrop.z_index = -20
	_add(root, backdrop)
	for k in count:
		var bg := Sprite2D.new()
		bg.name = "Screen%d" % k
		bg.texture = _tex(ZONE_BG[zones[k]])
		bg.centered = false
		bg.position = Vector2(0, -(k + 1) * SCREEN_H)
		_add(backdrop, bg)

	var decor := Node2D.new()
	decor.name = "Decor"
	decor.z_index = -5
	_add(root, decor)
	var lights := Node2D.new()
	lights.name = "Lights"
	lights.z_index = -4
	_add(root, lights)

	var terrain := TileMapLayer.new()
	terrain.name = "Terrain"
	terrain.tile_set = tileset
	_add(root, terrain)

	var objects := Node2D.new()
	objects.name = "Objects"
	objects.z_index = 1
	_add(root, objects)

	var exits: Array[Vector2] = []
	for cell in grid:
		if grid[cell] == "o":
			exits.append(_center(cell))

	for cell in grid:
		var ch: String = grid[cell]
		var zone: int = cell_zone[cell]
		match ch:
			"#", "C":
				var mask := 0
				if not _solid(grid, cell + Vector2i.UP): mask |= 1
				if not _solid(grid, cell + Vector2i.RIGHT): mask |= 2
				if not _solid(grid, cell + Vector2i.DOWN): mask |= 4
				if not _solid(grid, cell + Vector2i.LEFT): mask |= 8
				terrain.set_cell(cell, 0, Vector2i(mask, zone * 3 + (1 if ch == "C" else 0)))
			"/":
				terrain.set_cell(cell, 0, Vector2i(0, zone * 3 + 2))
			"\\":
				terrain.set_cell(cell, 0, Vector2i(1, zone * 3 + 2))
			"{":
				terrain.set_cell(cell, 0, Vector2i(2, zone * 3 + 2))
			"}":
				terrain.set_cell(cell, 0, Vector2i(3, zone * 3 + 2))
			"S":
				root.set("spawn", _center(cell) + Vector2(0, 1))
			"B":
				var b := Node2D.new()
				b.set_script(load("res://scripts/world/bumper.gd"))
				b.name = "Bumper"
				b.position = _center(cell)
				b.set("number", [8, 3, 11, 6, 14, 1, 9][absi(cell.x * 7 + cell.y * 3) % 7])
				_add(objects, b)
			"O", "K":
				var p := Node2D.new()
				p.set_script(load("res://scripts/world/pocket.gd"))
				p.name = "GoalPocket" if ch == "K" else "Pocket"
				p.position = _center(cell)
				p.set("goal", ch == "K")
				if ch == "O":
					p.set("exit", _nearest_exit(p.position, exits))
				_add(objects, p)
				if ch == "K":
					var crown := _sprite(decor, "crown", p.position + Vector2(0, -22), 4)
					crown.name = "Crown"
					_glow(lights, p.position + Vector2(0, -18), Color(1.0, 0.85, 0.4, 0.8), 1.4)
			"L", "H":
				var top := _ceiling_y(grid, cell)
				var lamp_pos := _center(cell)
				var chain := Sprite2D.new()
				chain.texture = _tex("chain")
				chain.region_enabled = true
				chain.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
				var length := lamp_pos.y - 8 - top
				chain.region_rect = Rect2(0, 0, 4, maxf(length, 2))
				chain.centered = false
				chain.position = Vector2(lamp_pos.x - 2, top)
				_add(decor, chain)
				_motes(lights, lamp_pos + Vector2(0, 50))
				if ch == "L":
					_sprite(decor, "lamp", lamp_pos)
					var cone := _sprite(lights, "light_cone", lamp_pos + Vector2(0, 82))
					cone.material = _additive()
				else:
					_sprite(decor, "chandelier", lamp_pos + Vector2(0, 6))
					_glow(lights, lamp_pos + Vector2(0, 12), Color(1.0, 0.86, 0.6, 0.9), 2.2)
			"R":
				_sprite(decor, "cue_rack", _center(cell))
			"Q":
				_sprite(decor, "score_beads", _center(cell))
			"P", "E":
				var sign := Sprite2D.new()
				sign.texture = _tex("neon_pool" if ch == "P" else "neon_eight")
				sign.hframes = 2
				sign.position = _center(cell)
				sign.set_script(load("res://scripts/world/flicker.gd"))
				_add(decor, sign)
				var g := _glow(lights, sign.position, Color(1.0, 0.4, 0.75, 0.7) if ch == "P" else Color(0.4, 0.95, 1.0, 0.7), 1.6)
				sign.set("glow_path", sign.get_path_to(g) if sign.is_inside_tree() else NodePath("../../Lights/" + String(g.name)))
			"F":
				_sprite(decor, "portrait", _center(cell))
			"W":
				_sprite(decor, "window", _center(cell))
			"T":
				_sprite(decor, "clock", _center(cell))
			"k":
				_sprite(decor, "chalk", _center(cell) + Vector2(0, 5))
			"r":
				_sprite(decor, "rack", _center(cell) + Vector2(0, -2))
			_:
				var n := "123456789abcdef".find(ch)
				if n >= 0:
					var lb := Node2D.new()
					lb.set_script(load("res://scripts/world/lost_ball.gd"))
					lb.name = "LostBall%d" % (n + 1)
					lb.position = _center(cell)
					lb.set("number", n + 1)
					_add(objects, lb)

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack failed %d" % err)
		quit(1)
		return
	ResourceSaver.save(packed, "res://scenes/world/tower.tscn")
	print("Tower baked: %d screens, %d tiles, %d objects." % [count, terrain.get_used_cells().size(), objects.get_child_count()])
	root.free()
	quit(0)


func _parse(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var screens: Array = []
	var cur: Dictionary = {}
	var line_no := 0
	while not f.eof_reached():
		var line := f.get_line().strip_edges(false, true)
		line_no += 1
		if line.begins_with("=="):
			var parts := line.split(" ", false)
			cur = { "index": int(parts[2]), "zone": int(parts[4]), "rows": [] }
			screens.append(cur)
		elif not cur.is_empty() and line.length() > 0 and not line.begins_with(";"):
			if line.length() != W:
				push_error("tower.txt line %d: expected %d chars, got %d" % [line_no, W, line.length()])
				_bad = true
			cur.rows.append(line.rpad(W, "."))
	for s in screens:
		if s.rows.size() != H:
			push_error("screen %d has %d rows" % [s.index, s.rows.size()])
			_bad = true
	return screens


func _solid(grid: Dictionary, cell: Vector2i) -> bool:
	return grid.has(cell) and "#C/\\{}".contains(grid[cell])


func _center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE + Vector2(TILE, TILE) / 2.0


func _ceiling_y(grid: Dictionary, cell: Vector2i) -> float:
	var c := cell + Vector2i.UP
	var screen_top := floori(float(cell.y) / H) * H
	while c.y >= screen_top:
		if _solid(grid, c):
			return float(c.y + 1) * TILE
		c += Vector2i.UP
	return float(screen_top) * TILE


func _nearest_exit(from: Vector2, exits: Array[Vector2]) -> Vector2:
	var best := from + Vector2(0, 64)
	var best_d := INF
	for e in exits:
		if e.y > from.y and from.distance_to(e) < best_d:
			best_d = from.distance_to(e)
			best = e
	return best


func _tex(name: String) -> Texture2D:
	if not tex.has(name):
		tex[name] = load("res://assets/textures/%s.png" % name)
	return tex[name]


func _sprite(parent: Node, name: String, pos: Vector2, hframes: int = 1) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(name)
	s.hframes = hframes
	s.position = pos.round()
	_add(parent, s)
	return s


func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


func _glow(parent: Node, pos: Vector2, color: Color, size: float) -> Sprite2D:
	var g := _sprite(parent, "glow", pos)
	g.name = "Glow%d" % parent.get_child_count()
	g.modulate = color
	g.scale = Vector2(size, size)
	g.material = _additive()
	return g


## Chalk dust drifting through a lamp's light: 1px warm specks.
func _motes(parent: Node, pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = 9
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(26, 46)
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 0.6)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.5
	p.color = Color(1.0, 0.88, 0.6, 0.55)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.3, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	p.material = _additive()
	_add(parent, p)


func _add(parent: Node, child: Node) -> void:
	parent.add_child(child, true)
	var root := parent
	while root.get_parent() != null:
		root = root.get_parent()
	child.owner = root


func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = _tex("tiles")
	src.texture_region_size = Vector2i(TILE, TILE)
	for y in 9:
		for x in 16:
			if y % 3 == 2 and x >= 4:
				continue
			src.create_tile(Vector2i(x, y))
	ts.add_source(src, 0)
	return ts
