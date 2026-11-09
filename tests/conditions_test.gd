extends Node
## Low gravity, wind, levels 3 and 4, chained locks and the lost-ball spread.
##   godot --headless --path . res://tests/conditions_test.tscn -- --save-profile=conditions

var passed := 0
var failed := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		passed += 1
		print("  ok   ", name)
	else:
		failed += 1
		print("  FAIL ", name, "  ", detail)


func _ready() -> void:
	print("Low gravity")
	_gravity_tests()
	print("Wind")
	_wind_tests()
	print("Levels and lost balls")
	_level_tests()
	print("Locks")
	_lock_tests()
	print("In the game")
	await _game_tests()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.path))
	print("%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _flat(screen_y_cells := 0) -> CollisionWorld:
	var w := CollisionWorld.new()
	for x in range(-40, 41):
		w.cells[Vector2i(x, screen_y_cells)] = [CollisionWorld.Shape.SOLID, CollisionWorld.Mat.TABLE, 0]
	return w


func _peak_of_shot(w: CollisionWorld) -> float:
	var s := BallSim.new()
	s.reset(Vector2(0, -8))
	for i in 60:
		w.advance(BallSim.DT)
		s.step(w)
	var start := s.pos.y
	s.shoot(0.0, BallSim.CHARGE_TICKS, 0)
	var top := s.pos.y
	for i in 900:
		w.advance(BallSim.DT)
		s.step(w)
		top = minf(top, s.pos.y)
	return start - top


func _gravity_tests() -> void:
	var normal := _peak_of_shot(_flat())
	var low := _flat()
	# Screen 0 and the screens above it, so the whole flight is in low gravity.
	for k in 4:
		low.screen_gravity[k] = 0.45
	var floaty := _peak_of_shot(low)
	check("full shot reaches about 2.2x as high at 0.45 gravity", absf(floaty / normal - 1.0 / 0.45) < 0.15, "%.0f vs %.0f" % [floaty, normal])
	check("gravity is per screen", low.gravity_scale_at(-100.0) == 0.45 and low.gravity_scale_at(-288.0 * 6.0) == 1.0)
	check("no low gravity data means normal gravity", CollisionWorld.new().gravity_scale_at(-500.0) == 1.0)
	var sim := BallSim.new()
	sim.reset(Vector2(0, -200))
	var slow_world := _flat()
	slow_world.screen_gravity[0] = 0.45
	for i in 60:
		slow_world.advance(BallSim.DT)
		sim.step(slow_world)
	check("falls slowly in low gravity", absf(sim.vel.y - 900.0 * 0.45 * 0.5) < 10.0, str(sim.vel))


func _windy(strength := 240.0, dir := Vector2.RIGHT, on := 3.0, off := 3.0) -> CollisionWorld:
	var w := _flat()
	for k in 3:
		w.screen_wind[k] = { "dir": dir, "strength": strength, "on": on, "off": off, "phase": 0.0 }
	return w


func _wind_tests() -> void:
	var w := _windy(240.0, Vector2.LEFT)
	var dirs := {}
	var peak := 0.0
	var lull := INF
	var gusting := 0
	for i in 1440:  # two full cycles
		w.advance(BallSim.DT)
		var v := w.wind_at(-100.0)
		peak = maxf(peak, v.length())
		lull = minf(lull, v.length())
		if v.length() > 0.0:
			gusting += 1
			dirs[v.normalized().round()] = true
	check("a stretch's wind only ever blows one way", dirs.size() == 1 and dirs.has(Vector2.LEFT), str(dirs.keys()))
	check("gusts peak at the set strength", absf(peak - 240.0) < 2.0, str(peak))
	check("the wind drops to dead calm between gusts", lull == 0.0, str(lull))
	check("it blows for the 'on' time each cycle", absf(gusting * BallSim.DT - 6.0) < 0.1, str(gusting * BallSim.DT))
	check("only windy screens have wind", w.wind_at(-288.0 * 8.0) == Vector2.ZERO and CollisionWorld.new().wind_at(-100.0) == Vector2.ZERO)

	# The same shot in calm air, mid-gust and in the lull.
	var results := []
	for setup in [[_flat(), 0.0], [_windy(280.0, Vector2.RIGHT), 1.5], [_windy(280.0, Vector2.RIGHT), 4.5]]:
		var world: CollisionWorld = setup[0]
		var s := BallSim.new()
		s.reset(Vector2(0, -8))
		world.set_time(0.0)
		for i in 30:
			s.step(world)
		world.set_time(setup[1])
		s.shoot(0.0, 60, 0)
		for i in 60:
			world.advance(BallSim.DT)
			s.step(world)
		results.append(s.pos.x)
	check("a gust pushes a ball in the air", results[1] > results[0] + 20.0, str(results))
	check("in the lull the same shot flies true", absf(results[2] - results[0]) < 0.5, str(results))
	var up := []
	for setup in [_flat(), _windy(300.0, Vector2.UP)]:
		var s := BallSim.new()
		s.reset(Vector2(0, -8))
		for i in 30:
			s.step(setup)
		setup.set_time(1.0)
		s.shoot(0.0, 40, 0)
		var top := 0.0
		for i in 120:
			setup.advance(BallSim.DT)
			s.step(setup)
			top = minf(top, s.pos.y)
		up.append(top)
	check("an updraft carries a jump higher", up[1] < up[0] - 10.0, str(up))

	var rest := _windy(400.0)
	rest.set_time(1.0)
	var grounded := BallSim.new()
	grounded.reset(Vector2(0, -8))
	for i in 30:
		rest.advance(BallSim.DT)
		grounded.step(rest)
	var settled_x := grounded.pos.x
	for i in 240:
		rest.advance(BallSim.DT)
		grounded.step(rest)
	check("a ball resting on the felt ignores the wind", grounded.grounded and grounded.pos.x == settled_x, str(grounded.pos))

	var calm := true
	for dir in [Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN]:
		var gale := _windy(600.0, dir, 5.0, 0.5)
		var white := BallSim.new()
		white.floating = true
		white.reset(Vector2(0, -100))
		for i in 360:
			gale.advance(BallSim.DT)
			white.step(gale)
		if white.pos != Vector2(0, -100):
			calm = false
	check("Hardcore's white ball never feels the wind", calm)

	var runs := []
	for run in 2:
		var d := _windy(260.0, Vector2.DOWN)
		d.set_time(2.3)
		var b := BallSim.new()
		b.reset(Vector2(0, -8))
		b.grounded = true
		b.shoot(25.0, 60, 0)
		for i in 300:
			d.advance(BallSim.DT)
			b.step(d)
		runs.append(b.pos)
	check("windy shots replay identically", runs[0] == runs[1])


func _tower(level: int) -> Tower:
	var path := "res://scenes/world/tower.tscn" if level == 1 else "res://scenes/world/tower%d.tscn" % level
	var t: Tower = load(path).instantiate()
	add_child(t)
	t.build_world()
	return t


func _level_tests() -> void:
	var all: Array[int] = []
	var names := BallRack.LOST_IN.keys()
	for level in range(1, 5):
		var t := _tower(level)
		var lost := t.lost_numbers()
		check("level %d hides exactly 6 lost balls" % level, lost.size() == 6, str(lost))
		var expect: Array = BallRack.LOST_IN[names[level - 1]].duplicate()
		var got: Array = lost.duplicate()
		got.sort()
		expect.sort()
		check("level %d's balls match the rack's list" % level, got == expect, "%s vs %s" % [got, expect])
		all.append_array(lost)
		# Spread through the whole level, not bunched together.
		var screens: Array = lost.map(func(n): return Tower.screen_of(t.get_node("Objects/LostBall%d" % n).position.y))
		screens.sort()
		check("level %d's balls are spread out" % level, screens[-1] - screens[0] >= t.screen_count() / 2 and screens.size() == 6, str(screens))
		var clear := true
		for b in t.world.lost_balls:
			if t.world.is_solid_point(b.pos):
				clear = false
		check("level %d's balls aren't buried" % level, clear)
		check("level %d has a gold pocket" % level, t.world.pockets.filter(func(p): return p.goal).size() == 1)
		if level == 3:
			var low := t.screen_zones.size()
			check("level 3 has 15 screens", low == 15)
			var zones: Array = range(low).map(func(k): return t.zone_of_screen(k))
			check("level 3 climbs from the observatory via the station", zones.slice(0, 3) == [7, 7, 7] and zones.slice(8, 10) == [8, 8], str(zones))
			var moon_ok := true
			for k in low:
				var is_space: bool = t.zone_of_screen(k) == 4 or t.zone_of_screen(k) == 6
				if is_space != t.world.screen_gravity.has(k):
					moon_ok = false
			check("low gravity exactly on the moon and space screens", moon_ok and t.world.screen_gravity.size() >= 8, str(t.world.screen_gravity))
		if level == 4:
			check("level 4 has 15 screens", t.screen_zones.size() == 15)
			var zones4: Array = range(15).map(func(k): return t.zone_of_screen(k))
			check("level 4 starts on the fire escape and rests in the bell tower", zones4.slice(0, 3) == [9, 9, 9] and zones4.slice(9, 11) == [10, 10], str(zones4))
			check("wind on most of level 4", t.world.screen_wind.size() >= 10, str(t.world.screen_wind.size()))
			var ways := {}
			var clean := true
			for k in t.world.screen_wind:
				var gust: Dictionary = t.world.screen_wind[k]
				ways[gust.dir] = true
				if gust.dir.length() != 1.0 or gust.on <= 0.0 or gust.off <= 0.0:
					clean = false
			check("each windy stretch blows one way, on and off", clean)
			check("level 4's stretches use all four directions", ways.size() == 4, str(ways.keys()))
		if level >= 3:
			# None of levels 1 and 2's bar and club decor comes back.
			var old_decor := ""
			for line in FileAccess.get_file_as_string("res://levels/tower%d.txt" % level).split("\n"):
				if line.begins_with(";") or line.begins_with("=") or line.begins_with("@"):
					continue
				for ch in "HFWTPELRk":
					if line.contains(ch):
						old_decor += ch
			check("level %d uses its own decor, not the bar's" % level, old_decor == "", old_decor)
		t.free()
	var unique := {}
	for n in all:
		unique[n] = true
	check("24 different lost balls in all, more than the old 20", all.size() == 24 and unique.size() == 24, str(all))
	check("every lost ball has a name or number", BallRack.display_name(28) == "Comet" and BallRack.display_name(31) == "Copper")


func _lock_tests() -> void:
	SaveData.set_run(SaveData.CLASSIC, 1)
	var keep := [SaveData.wins, SaveData.hc_wins, SaveData.records.duplicate()]
	SaveData.wins = 0
	SaveData.hc_wins = 0
	SaveData.records = {}
	for level in [2, 3, 4]:
		for m in [SaveData.CLASSIC, SaveData.HARDCORE]:
			SaveData.set_run(m, level)
			SaveData.has_run = false
			SaveData.save()
	SaveData.set_run(SaveData.CLASSIC, 1)
	check("fresh game: only level 1 is open", SaveData.level_unlocked(1) and not SaveData.level_unlocked(2) and not SaveData.level_unlocked(3) and not SaveData.level_unlocked(4))
	SaveData.wins = 1
	check("finishing level 1 opens level 2 only", SaveData.level_unlocked(2) and not SaveData.level_unlocked(3))
	SaveData.records["hardcore_2"] = { "wins": 1, "best_time": 1.0, "best_strokes": 1 }
	check("finishing level 2 (either mode) opens level 3 only", SaveData.level_unlocked(3) and not SaveData.level_unlocked(4))
	SaveData.records["classic_3"] = { "wins": 1, "best_time": 1.0, "best_strokes": 1 }
	check("finishing level 3 opens level 4", SaveData.level_unlocked(4))
	SaveData.wins = keep[0]
	SaveData.hc_wins = keep[1]
	SaveData.records = keep[2]


func _load(level: int, mode: String = SaveData.CLASSIC) -> Node2D:
	SaveData.set_run(mode, level)
	SaveData.start_new_run()
	var g: Node2D = load("res://scenes/world/game.tscn").instantiate()
	add_child(g)
	return g


func _dismiss(game: Node2D) -> String:
	await _frames(2)
	var words := ""
	if is_instance_valid(game.intro):
		words = " ".join(game.intro.find_children("*", "Label", true, false).map(func(l): return l.text)).to_lower()
		game.intro.dismiss()
	return words


func _props(game: Node2D, script_class: Variant) -> Array:
	return game.tower.get_node("Decor").get_children().filter(func(n): return is_instance_of(n, script_class))


func _game_tests() -> void:
	# Level 3: the moon.
	var game := _load(3)
	var words: String = await _dismiss(game)
	check("level 3's pop-up warns about low gravity", words.contains("gravity"), words)
	await _physics(5)
	check("the observatory has normal gravity and its own name", not game.weather.low_gravity and game.tower.zone_names[7] == "The Observatory")
	game.player.place(Vector2(256, -3 * 288 - 40))
	await _physics(4)
	await _frames(1)
	check("the moon has low gravity", game.weather.low_gravity and game.screen == 3)
	check("the moon has its own music", Sfx.current_music() == Sfx.MUSIC[4], Sfx.current_music())
	var rocks: Array = _props(game, SpaceProp).filter(func(p): return p.style == SpaceProp.Style.ASTEROID)
	check("moon screens have asteroids", rocks.size() >= 4, str(rocks.size()))
	var rock: SpaceProp = rocks[0]
	var home := rock.position
	rock.poke(rock.global_position, Vector2(300, 0))
	await _frames(12)
	await get_tree().create_timer(0.3).timeout
	check("a bumped asteroid drifts away", rock.position.distance_to(home) > 4.0, str(rock.position - home))
	var sat: SpaceProp = _props(game, SpaceProp).filter(func(p): return p.style == SpaceProp.Style.SATELLITE)[0]
	var slow: float = absf(sat._spin)
	sat.poke(sat.global_position, Vector2(300, 0))
	check("a struck satellite spins up", absf(sat._spin) > slow + 2.0)
	game.queue_free()
	await _frames(2)

	# Level 4: the gale.
	game = _load(4)
	words = await _dismiss(game)
	check("level 4's pop-up warns about the gusts", words.contains("gust"), words)
	game.player.place(Vector2(100, -3 * 288 - 40))
	await _physics(3)
	check("the rooftops have their own music", Sfx.current_music() == Sfx.MUSIC[5], Sfx.current_music())
	# Jump to mid-gust and let the decor catch up.
	var w: CollisionWorld = game.tower.world
	var gust: Dictionary = w.screen_wind[3]
	game.tower.resume_movers(gust.on * 0.5 - gust.phase * (gust.on + gust.off))
	await _physics(6)
	check("the weather layer sees the gust", game.weather.wind.length() > 100.0, str(game.weather.wind))
	check("the rooftop gust is an updraft", game.weather.wind.y < -100.0 and absf(game.weather.wind.x) < 1.0, str(game.weather.wind))
	# Rain falls on the rooftops (it used to be painted into the backdrop).
	var rain: RainLayer = game.rain
	check("it's raining on the rooftops", rain != null and rain._rain_in_view())
	var before_drops: Array[Vector2] = rain._pos.duplicate()
	await _frames(10)
	check("the rain is falling, not painted on", rain._pos != before_drops)
	check("the updraft slows the rain", rain.drop_velocity(1.0).y < RainLayer.FALL - 100.0, str(rain.drop_velocity(1.0)))
	var keep_wind: Vector2 = rain.wind
	rain.wind = Vector2(280, 0)
	check("a crosswind slants it hard", rain.drop_velocity(1.0).x > RainLayer.FALL / 3.0 + 200.0)
	rain.wind = Vector2(0, 320)
	check("a downdraft drives it down", rain.drop_velocity(1.0).y > RainLayer.FALL + 200.0)
	rain.wind = keep_wind
	var socks: Array = _props(game, WindProp).filter(func(p): return Tower.screen_of(p.global_position.y) == 3 and p.style == WindProp.Style.SOCK)
	var sock: WindProp = socks[0]
	check("wind socks feel the wind", sock._wind.length() > 100.0)
	var vanes: Array = _props(game, WindProp).filter(func(p): return Tower.screen_of(p.global_position.y) == 3 and p.style == WindProp.Style.VANE)
	var vane: WindProp = vanes[0]
	var before: float = vane._arrow.rotation
	await get_tree().create_timer(0.5).timeout
	check("the vane turns with it", absf(vane._arrow.rotation - before) > 0.01 or absf(angle_difference(vane._arrow.rotation, game.weather.wind.angle())) < 1.0, "%f" % vane._arrow.rotation)
	var bunting: Array = _props(game, WindProp).filter(func(p): return p.style == WindProp.Style.BUNTING)
	check("rooftops have bunting", bunting.size() >= 3)
	var flung: WindProp = bunting[0]
	flung.poke(flung.global_position, Vector2(300, 0))
	check("bunting reacts to a knock", flung._kick > 0.0)
	game.player.place(Vector2(200, -9 * 288 - 40))
	await _physics(90)
	check("no rain indoors in the bell tower", game.screen == 9 and not game.rain._rain_in_view(), str(game.screen))
	game.player.place(game.tower.spawn)
	await _physics(90)
	check("rain on the fire escape", game.screen == 0 and game.rain._rain_in_view())
	game.queue_free()
	await _frames(2)

	# Hardcore rides the same levels: the white ball exists and winning records it.
	game = _load(4, SaveData.HARDCORE)
	await _dismiss(game)
	await _physics(5)
	check("Hardcore plays the new levels too", game.white != null and game.tower.screen_count() == 15)
	game.queue_free()
	await _frames(2)
	SaveData.set_run(SaveData.CLASSIC, 1)


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
