extends SceneTree
## Bakes every level's ASCII map into its scene (+ resources/tiles.tres):
##   levels/tower.txt -> scenes/world/tower.tscn, levels/tower2.txt -> scenes/world/tower2.tscn
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
##
## Moving things are listed under a screen header, in that screen's tile
## coordinates (x 0..31, y 0..17):
##   @ platform x y tiles dx dy period phase   carriage with its top-left at (x, y),
##                                             travelling (dx, dy) tiles and back
##   @ spinner x y arms length speed angle     spinning arm trap centred on tile (x, y)
##   @ spike x0 y0 x1 y1 period phase          spiked ball between two tile centres
##   @ lost x y number                         a lost ball numbered above 15 (no map char for those)
##   @ gravity scale                           low gravity for this whole screen
##   @ wind dir strength on off phase         one-way gusts (dir R, L, U or D): blows for `on` s,
##                                             calm for `off` s; strength in px/s^2
## Zones: 0 Back Room, 1 Neon Bar, 2 Royal Club, 3 summit, 4 Moon, 5 Storm, 6 Space,
##        7 Observatory, 8 Station, 9 Fire Escape, 10 Bell Tower.
## More decor: A asteroid  G satellite  N moon flag  V wind sock  U bunting  Y weather vane
##   I lantern  h bell  M star chart  X porthole  g flower pot  D telescope  J orrery  Z console  j gear

const TILE := 16
const W := 32
const H := 18
const SCREEN_H := H * TILE
const ZONE_BG := ["bg_backroom", "bg_neonbar", "bg_royal", "bg_summit", "bg_moon", "bg_storm", "bg_space", "bg_observatory", "bg_station", "bg_fire_escape", "bg_bell_tower"]
const TILE_ZONE := [0, 1, 2, 2, 3, 4, 3, 5, 6, 7, 8]   # tile palette for each zone

var tex := {}
var _bad := false
var _gravity := {}
var _winds := {}


func _initialize() -> void:
	var ok := _bake("res://levels/tower.txt", "res://scenes/world/tower.tscn", ["The Back Room", "Lucky's Neon Bar", "The Royal Club", "The King's Table", "", "", "", "", "", "", ""])
	ok = _bake("res://levels/tower2.txt", "res://scenes/world/tower2.tscn", ["The Cellar", "The Jukebox Floor", "The Grand Salon", "The Rooftop Final", "", "", "", "", "", "", ""]) and ok
	ok = _bake("res://levels/tower3.txt", "res://scenes/world/tower3.tscn", ["", "", "", "", "The Sea of Felt", "", "Open Space", "The Observatory", "The Launch Deck", "", ""]) and ok
	ok = _bake("res://levels/tower4.txt", "res://scenes/world/tower4.tscn", ["", "", "", "", "", "The Rooftops", "", "", "", "The Fire Escape", "The Bell Tower"]) and ok
	quit(0 if ok else 1)


func _bake(source: String, target: String, zone_names: PackedStringArray) -> bool:
	_bad = false
	_gravity = {}
	_winds = {}
	var screens := _parse(source)
	if screens.is_empty() or _bad:
		push_error("no screens parsed from %s" % source)
		return false
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
				cell_zone[cell] = TILE_ZONE[s.zone]

	var tileset := _make_tileset()
	ResourceSaver.save(tileset, "res://resources/tiles.tres")
	tileset = load("res://resources/tiles.tres")

	var root := Node2D.new()
	root.name = "Tower"
	root.set_script(load("res://scripts/world/tower.gd"))
	root.set("screen_zones", zones)
	root.set("zone_names", zone_names)

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

	var movers := Node2D.new()
	movers.name = "Movers"
	_add(root, movers)
	for s in screens:
		_add_movers(movers, objects, s)
	root.set("screen_gravity", _gravity)
	root.set("screen_winds", _winds)

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
				# Hanging light: a pendulum rooted at the ceiling hook.
				var top := _ceiling_y(grid, cell)
				var lamp_pos := _center(cell)
				var length := lamp_pos.y - top
				var swing := _prop(decor, "swing", ch, cell, Vector2(lamp_pos.x, top))
				swing.set("length", length)
				swing.set("crystal", ch == "H")
				var chain := Sprite2D.new()
				chain.name = "Chain"
				chain.texture = _tex("chain")
				chain.region_enabled = true
				chain.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
				chain.region_rect = Rect2(0, 0, 4, maxf(length - 8.0, 2.0))
				chain.centered = false
				chain.position = Vector2(-2, 0)
				_add(swing, chain)
				_motes(lights, lamp_pos + Vector2(0, 50))
				if ch == "L":
					_sprite(swing, "lamp", Vector2(0, length)).name = "Body"
					var cone := _sprite(swing, "light_cone", Vector2(0, length + 82))
					cone.name = "Light"
					cone.material = _additive()
					cone.z_index = 1
				else:
					_sprite(swing, "chandelier", Vector2(0, length + 6)).name = "Body"
					var g := _glow(swing, Vector2(0, length + 12), Color(1.0, 0.86, 0.6, 0.9), 2.2)
					g.name = "Light"
					g.z_index = 1
			"R":
				var rack := _prop(decor, "rattle", ch, cell, _center(cell))
				rack.set("hit_size", Vector2(28, 62))
				_sprite(rack, "cue_rack", Vector2.ZERO).name = "Body"
			"Q":
				var wire := _prop(decor, "beads", ch, cell, _center(cell))
				_sprite(wire, "score_wire", Vector2.ZERO).name = "Wire"
			"P", "E":
				var neon := _prop(decor, "neon", ch, cell, _center(cell))
				neon.set("hit_size", Vector2(56, 20) if ch == "P" else Vector2(28, 28))
				var sign := _sprite(neon, "neon_pool" if ch == "P" else "neon_eight", Vector2.ZERO, 2)
				sign.name = "Sign"
				var ng := _glow(neon, Vector2.ZERO, Color(1.0, 0.4, 0.75, 0.7) if ch == "P" else Color(0.4, 0.95, 1.0, 0.7), 1.6)
				ng.name = "Glow"
				ng.z_index = 1
			"I", "h":
				# Lantern or bell: hangs from the ceiling and swings, like the lamps.
				var top2 := _ceiling_y(grid, cell)
				var hang := _center(cell)
				var length2 := hang.y - top2
				var swing2 := _prop(decor, "swing", ch, cell, Vector2(hang.x, top2))
				swing2.set("length", length2)
				swing2.set("crystal", false)
				swing2.set("bell", ch == "h")
				var rope := Sprite2D.new()
				rope.name = "Chain"
				rope.texture = _tex("chain")
				rope.region_enabled = true
				rope.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
				rope.region_rect = Rect2(0, 0, 4, maxf(length2 - 10.0, 2.0))
				rope.centered = false
				rope.position = Vector2(-2, 0)
				_add(swing2, rope)
				_sprite(swing2, "lantern" if ch == "I" else "bell", Vector2(0, length2)).name = "Body"
				if ch == "I":
					var lg := _glow(swing2, Vector2(0, length2 + 2), Color(1.0, 0.8, 0.45, 0.7), 1.3)
					lg.name = "Light"
					lg.z_index = 1
			"M", "X":
				var plaque := _prop(decor, "tilt", ch, cell, _center(cell) - Vector2(0, 14))
				plaque.set("hit_size", Vector2(28, 30))
				plaque.set("hit_offset", Vector2(0, 14))
				plaque.set("crooked", ch == "M")
				_sprite(plaque, "star_chart" if ch == "M" else "porthole", Vector2(0, 14)).name = "Body"
			"g":
				var pot := _prop(decor, "knock", ch, cell, _center(cell) + Vector2(0, 2))
				pot.set("half_size", Vector2(4, 6))
				pot.set("hit_size", Vector2(10, 12))
				pot.set("heavy", false)
				pot.set("min_speed", 40.0)
				_sprite(pot, "flower_pot", Vector2.ZERO).name = "Body"
			"D", "J", "Z", "j":
				var gadget := _prop(decor, "gadget", ch, cell, _center(cell))
				gadget.set("style", {"D": 0, "J": 1, "Z": 2, "j": 3}[ch])
			"V", "U", "Y":
				var wp := _prop(decor, "wind", ch, cell, _center(cell))
				wp.set("style", {"V": 0, "U": 1, "Y": 2}[ch])
				if ch == "V":
					wp.position = _center(cell) + Vector2(0, -20)
			"A", "G", "N":
				var sp := _prop(decor, "space", ch, cell, _center(cell))
				sp.set("style", {"A": 0, "G": 1, "N": 2}[ch])
				if ch == "N":
					sp.position = _center(cell) + Vector2(0, -7)
			"F", "T":
				# Hung on a nail at the top edge, so it swings about the nail.
				var h := 34.0 if ch == "F" else 20.0
				var nail := _center(cell) - Vector2(0, h / 2.0)
				var hung := _prop(decor, "tilt", ch, cell, nail)
				hung.set("hit_size", Vector2(28, 34) if ch == "F" else Vector2(20, 20))
				hung.set("hit_offset", Vector2(0, h / 2.0))
				hung.set("crooked", ch == "F")
				hung.set("chime", ch == "T")
				_sprite(hung, "portrait" if ch == "F" else "clock", Vector2(0, h / 2.0)).name = "Body"
			"W":
				var win := _prop(decor, "window", ch, cell, _center(cell))
				_sprite(win, "window", Vector2.ZERO, 2).name = "Glass"
			"k", "r":
				var chalk := ch == "k"
				var loose := _prop(decor, "knock", ch, cell, _center(cell) + (Vector2(0, 5) if chalk else Vector2(0, -2)))
				loose.set("half_size", Vector2(3, 3) if chalk else Vector2(11, 10))
				loose.set("hit_size", Vector2(8, 8) if chalk else Vector2(22, 18))
				loose.set("heavy", not chalk)
				loose.set("min_speed", 40.0)
				_sprite(loose, "chalk" if chalk else "rack", Vector2.ZERO).name = "Body"
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
		return false
	ResourceSaver.save(packed, target)
	print("%s baked: %d screens, %d tiles, %d objects, %d movers." % [target.get_file(), count, terrain.get_used_cells().size(), objects.get_child_count(), movers.get_child_count()])
	root.free()
	return true


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
			cur = { "index": int(parts[2]), "zone": int(parts[4]), "rows": [], "movers": [] }
			screens.append(cur)
		elif line.begins_with("@"):
			cur.movers.append(line.split(" ", false))
		elif not cur.is_empty() and line.length() > 0 and not line.begins_with(";"):
			if line.length() != W:
				push_error("%s line %d: expected %d chars, got %d" % [path, line_no, W, line.length()])
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
	for y in 27:
		for x in 16:
			if y % 3 == 2 and x >= 4:
				continue
			src.create_tile(Vector2i(x, y))
	ts.add_source(src, 0)
	return ts


const PROP_SCRIPTS := {
	"swing": "res://scripts/world/props/swing_prop.gd",
	"rattle": "res://scripts/world/props/rattle_prop.gd",
	"beads": "res://scripts/world/props/beads_prop.gd",
	"neon": "res://scripts/world/props/neon_prop.gd",
	"tilt": "res://scripts/world/props/tilt_prop.gd",
	"window": "res://scripts/world/props/window_prop.gd",
	"knock": "res://scripts/world/props/knock_prop.gd",
	"wind": "res://scripts/world/props/wind_props.gd",
	"space": "res://scripts/world/props/space_props.gd",
	"gadget": "res://scripts/world/props/gadget_prop.gd",
}


## A reactive decor prop, named uniquely by kind and cell (broken windows are saved by name).
func _prop(parent: Node, kind: String, ch: String, cell: Vector2i, pos: Vector2) -> Node2D:
	var p := Node2D.new()
	p.set_script(load(PROP_SCRIPTS[kind]))
	p.name = "%s_%s_%d_%d" % [kind.capitalize(), "abcdefghijklmnopqrstuvwxyz".find(ch.to_lower()), cell.x, absi(cell.y)]
	p.position = pos.round()
	_add(parent, p)
	return p


## Moving platforms and traps listed under this screen's header.
func _add_movers(parent: Node, objects: Node, s: Dictionary) -> void:
	var top: int = -(s.index + 1) * SCREEN_H
	var i := 0
	for m in s.movers:
		var kind: String = m[1]
		if kind == "gravity":
			_gravity[s.index] = float(m[2])
			continue
		if kind == "wind":
			_winds[s.index] = { "dir": m[2], "strength": float(m[3]), "on": float(m[4]), "off": float(m[5]), "phase": float(m[6]) }
			continue
		if kind == "lost":
			var lb := Node2D.new()
			lb.set_script(load("res://scripts/world/lost_ball.gd"))
			lb.name = "LostBall%s" % m[4]
			lb.position = Vector2(float(m[2]) * TILE + TILE / 2.0, float(m[3]) * TILE + TILE / 2.0 + top)
			lb.set("number", int(m[4]))
			_add(objects, lb)
			continue
		var node := Node2D.new()
		node.name = "%s_s%d_%d" % [kind.capitalize(), s.index, i]
		i += 1
		match kind:
			"platform":
				node.set_script(load("res://scripts/world/moving_platform.gd"))
				var a := Vector2(float(m[2]) * TILE, float(m[3]) * TILE + top)
				node.position = a
				node.set("a", a)
				node.set("b", a + Vector2(float(m[5]), float(m[6])) * TILE)
				node.set("tiles", int(m[4]))
				node.set("period", float(m[7]))
				node.set("phase", float(m[8]))
				node.set("zone", TILE_ZONE[s.zone])
			"spinner":
				node.set_script(load("res://scripts/world/trap_spinner.gd"))
				node.position = Vector2(float(m[2]) * TILE + TILE / 2.0, float(m[3]) * TILE + TILE / 2.0 + top)
				node.set("arms", int(m[4]))
				node.set("length", float(m[5]))
				node.set("speed", float(m[6]))
				node.set("angle0", float(m[7]))
				node.z_index = 6
			"spike":
				node.set_script(load("res://scripts/world/trap_spike.gd"))
				var a := Vector2(float(m[2]) * TILE + TILE / 2.0, float(m[3]) * TILE + TILE / 2.0 + top)
				node.position = a
				node.set("a", a)
				node.set("b", Vector2(float(m[4]) * TILE + TILE / 2.0, float(m[5]) * TILE + TILE / 2.0 + top))
				node.set("period", float(m[6]))
				node.set("phase", float(m[7]))
				node.z_index = 6
			_:
				push_error("unknown mover '%s'" % kind)
				_bad = true
		_add(parent, node)
