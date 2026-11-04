extends Node
## Moving platforms, traps, the second level and the level select.
##   godot --headless --path . res://tests/level2_test.tscn -- --save-profile=level2

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
	print("Moving platforms")
	_platform_tests()
	print("Traps")
	_trap_tests()
	print("The second level")
	await _level_tests()
	print("Level select")
	await _menu_tests()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.path))
	print("%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _world(a: Vector2, b: Vector2, period := 4.0) -> CollisionWorld:
	var w := CollisionWorld.new()
	w.platforms.append({ "a": a, "b": b, "size": Vector2(64, 16), "period": period, "phase": 0.0, "zone": 0, "pos": a, "vel": Vector2.ZERO })
	w.set_time(0.0)
	return w


func _rider(w: CollisionWorld) -> BallSim:
	var s := BallSim.new()
	var p := w.platforms[0]
	s.reset(p.pos + Vector2(32, -7.5))
	for i in 60:
		w.advance(BallSim.DT)
		s.step(w)
	return s


func _platform_tests() -> void:
	var w := _world(Vector2(0, 0), Vector2(200, 0))
	var s := _rider(w)
	check("ball lands and rides a platform", s.riding == 0 and s.grounded, str(s.riding))
	var offset: float = s.pos.x - w.platforms[0].pos.x
	var stayed := true
	var moved := 0.0
	var start_x := s.pos.x
	for i in 480:
		w.advance(BallSim.DT)
		s.step(w)
		moved = maxf(moved, absf(s.pos.x - start_x))
		if s.riding != 0 or absf(s.pos.y + 7.0) > 1.0:
			stayed = false
	check("sideways platform carries the ball along", stayed and moved > 100.0, "moved %.0f" % moved)
	check("ball keeps its spot on the deck", absf(s.pos.x - w.platforms[0].pos.x - offset) < 2.0)
	check("riding ball can be struck", s.can_shoot())

	var up := _world(Vector2(0, 0), Vector2(0, -160))
	var u := _rider(up)
	var low := u.pos.y
	var high := u.pos.y
	var rode := true
	for i in 480:
		up.advance(BallSim.DT)
		u.step(up)
		low = maxf(low, u.pos.y)
		high = minf(high, u.pos.y)
		if u.riding != 0 or absf(u.pos.y - (up.platforms[0].pos.y - BallSim.RADIUS)) > 1.5:
			rode = false
	check("elevator carries the ball up and down without dropping it", rode and low - high > 100.0, "%.0f..%.0f" % [high, low])

	# A shot from a moving platform keeps its momentum.
	var m := _world(Vector2(0, 0), Vector2(300, 0), 2.0)
	var r := _rider(m)
	for i in 120:
		m.advance(BallSim.DT)
		r.step(m)
	var pv: Vector2 = m.platforms[0].vel
	r.shoot(0.0, 40, 0)
	check("shots inherit the platform's velocity", absf(r.vel.x - pv.x) < 1.0 and r.riding == -1 and absf(pv.x) > 20.0, "%s vs %s" % [r.vel, pv])
	m.advance(BallSim.DT)
	r.step(m)
	check("struck ball leaves the deck", not r.grounded)

	# Solid from every side.
	var side := _world(Vector2(100, 0), Vector2(100, 0))
	var hit := BallSim.new()
	hit.reset(Vector2(40, 8))
	hit.vel = Vector2(300, 0)
	var bounced := false
	for i in 60:
		hit.vel.y = 0.0
		side.advance(BallSim.DT)
		hit.step(side)
		if hit.vel.x < 0.0:
			bounced = true
	check("platforms are solid from the side", bounced and hit.pos.x < 100.0)
	var over := BallSim.new()
	over.reset(Vector2(132, 60))
	over.vel = Vector2(0, -300)
	var knocked := false
	for i in 40:
		side.advance(BallSim.DT)
		over.step(side)
		if over.vel.y > 0.0 and over.pos.y > 16.0:
			knocked = true
	check("and from below", knocked and over.pos.y > 16.0, str(over.pos))

	# Replays are exact, so the solver's verdicts hold.
	var results := []
	for run in 2:
		var d := _world(Vector2(0, 0), Vector2(200, -60), 3.0)
		var b := _rider(d)
		b.shoot(30.0, 50, 1)
		for i in 300:
			d.advance(BallSim.DT)
			b.step(d)
		results.append(b.pos)
	check("moving worlds replay identically", results[0] == results[1])


func _trap_world(kind: int) -> CollisionWorld:
	var w := CollisionWorld.new()
	if kind == CollisionWorld.Trap.SPINNER:
		w.traps.append({ "kind": kind, "center": Vector2.ZERO, "arms": 2, "length": 40.0, "speed": 0.0, "angle0": 0.0 })
	else:
		w.traps.append({ "kind": kind, "a": Vector2.ZERO, "b": Vector2(100, 0), "period": 4.0, "phase": 0.0, "radius": 8.0, "pos": Vector2.ZERO, "vel": Vector2.ZERO })
	w.set_time(0.0)
	return w


func _trap_tests() -> void:
	var w := _trap_world(CollisionWorld.Trap.SPINNER)
	var s := BallSim.new()
	s.floating = true
	s.reset(Vector2(30, 40))
	s.vel = Vector2(0, -220)
	var trapped := false
	for i in 120:
		w.advance(BallSim.DT)
		s.step(w)
		for e in s.events:
			if e.type == BallSim.Event.TRAP:
				trapped = true
		if trapped:
			break
	check("spinner arm catches the ball", trapped)
	check("and flings it away", s.vel.length() >= BallSim.TRAP_KNOCK - 1.0 and s.vel.y > 0.0, str(s.vel))

	var clear := BallSim.new()
	clear.floating = true
	clear.reset(Vector2(30, 60))
	w.advance(BallSim.DT)
	clear.step(w)
	check("outside its reach nothing happens", clear.vel == Vector2.ZERO)

	var spin := _trap_world(CollisionWorld.Trap.SPINNER)
	spin.traps[0].speed = PI
	spin.set_time(0.5)
	var ang := spin.spinner_angle(spin.traps[0], 0)
	check("arms sweep with time", absf(ang - PI / 2.0) < 0.05, str(ang))

	var sp := _trap_world(CollisionWorld.Trap.SPIKE)
	var b := BallSim.new()
	b.floating = true
	b.reset(Vector2(12, 0))
	var count := 0
	for i in 20:
		sp.advance(BallSim.DT)
		b.step(sp)
		for e in b.events:
			if e.type == BallSim.Event.TRAP:
				count += 1
	check("spike ball flings the ball, once", count == 1 and b.vel.length() > 300.0, "%d %s" % [count, b.vel])

	# A trap knocks you off a carriage.
	var both := _world(Vector2(0, 0), Vector2(0, 0))
	var r := _rider(both)
	both.traps.append({ "kind": CollisionWorld.Trap.SPIKE, "a": r.pos + Vector2(12, 0), "b": r.pos + Vector2(12, 0), "period": 1.0, "phase": 0.0, "radius": 8.0, "pos": r.pos + Vector2(12, 0), "vel": Vector2.ZERO })
	both.advance(BallSim.DT)
	r.step(both)
	check("a trap knocks you off a carriage", r.riding == -1 and not r.resting)


func _load_game() -> Node2D:
	var game: Node2D = load("res://scenes/world/game.tscn").instantiate()
	game.show_intro = false
	add_child(game)
	return game


func _level_tests() -> void:
	var one: Tower = load("res://scenes/world/tower.tscn").instantiate()
	var two: Tower = load("res://scenes/world/tower2.tscn").instantiate()
	check("level 2 is at least twice as long as level 1", two.screen_zones.size() >= one.screen_zones.size() * 2, "%d vs %d" % [two.screen_zones.size(), one.screen_zones.size()])
	add_child(two)
	two.build_world()
	var w := two.world
	var sideways := w.platforms.filter(func(p): return absf(p.b.x - p.a.x) > 16.0 and absf(p.b.y - p.a.y) < 1.0)
	var vertical := w.platforms.filter(func(p): return absf(p.b.y - p.a.y) > 16.0 and absf(p.b.x - p.a.x) < 1.0)
	check("level 2 has sideways platforms", sideways.size() >= 3, str(sideways.size()))
	check("level 2 has up-and-down platforms", vertical.size() >= 3, str(vertical.size()))
	check("level 2 has spinning traps", w.traps.filter(func(t): return t.kind == CollisionWorld.Trap.SPINNER).size() >= 4)
	check("level 2 has spike rails", w.traps.filter(func(t): return t.kind == CollisionWorld.Trap.SPIKE).size() >= 3)
	check("level 2 has one gold pocket", w.pockets.filter(func(p): return p.goal).size() == 1)
	check("level 1 is unchanged: nothing moves", load("res://scenes/world/tower.tscn").instantiate().get_node("Movers").get_child_count() == 0)
	one.free()
	two.queue_free()
	await _frames(2)

	# Every mode + level keeps its own run.
	SaveData.set_run(SaveData.CLASSIC, 1)
	SaveData.start_new_run()
	SaveData.strokes = 11
	SaveData.save()
	SaveData.set_run(SaveData.CLASSIC, 2)
	check("level 2 starts with no run", not SaveData.has_run)
	SaveData.start_new_run()
	SaveData.strokes = 22
	SaveData.save()
	SaveData.set_run(SaveData.HARDCORE, 2)
	SaveData.start_new_run()
	SaveData.strokes = 33
	SaveData.save()
	check("each mode and level is tracked separately", SaveData.has_run_for(SaveData.CLASSIC, 1) and SaveData.has_run_for(SaveData.CLASSIC, 2) and not SaveData.has_run_for(SaveData.HARDCORE, 1))
	SaveData.set_run(SaveData.CLASSIC, 1)
	check("level 1 run untouched", SaveData.strokes == 11)
	SaveData.set_run(SaveData.CLASSIC, 2)
	check("level 2 run restored", SaveData.strokes == 22)

	# Playing level 2.
	var game := _load_game()
	await _physics(30)
	check("level 2 loads its own tower", game.tower.screen_count() == 20 and game.tower.world.platforms.size() > 0)
	check("area names come from the level", game.tower.zone_names[0] == "The Cellar")
	check("bottom-floor hint still works on level 2", game.on_bottom_floor())
	var plat: Dictionary = game.tower.world.platforms[0]
	var before: Vector2 = plat.pos
	await _physics(60)
	check("platforms move during play", plat.pos != before)
	var node: Node2D = game.tower.get_node("Movers").get_child(0)
	check("platform node follows its data", node.position.distance_to(plat.pos) < 6.0, "%s %s" % [node.position, plat.pos])

	# Touching a real trap flings the ball and flashes the trap.
	var tr: Dictionary = game.tower.world.traps[0]
	var trap_node: Node2D = game.tower.trap_nodes[0]
	var at: Vector2 = tr.center if tr.kind == CollisionWorld.Trap.SPINNER else tr.pos
	game.player.place(at + Vector2(0, -3))
	var falls := SaveData.falls
	await _physics(8)
	check("a real trap flings the ball", game.player.sim.vel.length() > 200.0, str(game.player.sim.vel))
	check("the trap flashes", trap_node._flash > 0.0)
	check("being flung isn't a fall by itself", SaveData.falls == falls)

	# The clock survives a save: moving things resume where they were.
	await _physics(30)
	game.save_progress()
	var saved: float = game.tower.world.time
	game.queue_free()
	await _frames(2)
	SaveData.load_data()
	check("world clock saved", absf(SaveData.world_time - saved) < 0.001)
	game = _load_game()
	await _frames(1)
	check("moving things resume from the saved moment", absf(game.tower.world.time - saved) < 0.2, "%f %f" % [game.tower.world.time, saved])

	# Winning level 2: recorded apart from level 1, and no level 1 awards.
	var goal: Dictionary = game.tower.world.pockets.filter(func(p): return p.goal)[0]
	var wins_l1 := SaveData.wins
	SaveData.collected.clear()
	game.player.place(goal.pos + Vector2(-24, -1))
	game.player.sim.vel = Vector2(160, 0)
	game.player.sim.grounded = true
	game.player.sim.resting = false
	await _physics(120)
	check("gold pocket wins level 2", game.finished)
	check("recorded for level 2 only", SaveData.record(SaveData.CLASSIC, 2).wins == 1 and SaveData.wins == wins_l1)
	check("level 1 awards aren't handed out here", not SaveData.collected.has(11))
	game.queue_free()
	await _frames(2)

	# Hardcore shares the level: the white ball rides through it too.
	SaveData.set_run(SaveData.HARDCORE, 2)
	SaveData.start_new_run()
	game = _load_game()
	await _physics(20)
	check("Hardcore plays level 2 with its white ball", game.white != null and game.tower.screen_count() == 20)
	var w_goal: Dictionary = game.tower.world.pockets.filter(func(p): return p.goal)[0]
	game.white.place(w_goal.pos + Vector2(-30, -1))
	game.white.sim.vel = Vector2(220, 0)
	game.white.sim.resting = false
	await _physics(120)
	check("white ball in level 2's gold pocket wins", game.finished and SaveData.record(SaveData.HARDCORE, 2).wins == 1)
	game.queue_free()
	await _frames(2)
	SaveData.set_run(SaveData.CLASSIC, 1)


func _menu_tests() -> void:
	var title: Control = load("res://scenes/ui/title.tscn").instantiate()
	add_child(title)
	await _frames(3)
	var labels: Array = title.find_children("*", "Button", true, false).map(func(b): return b.text)
	check("title offers both modes", labels.has("Normal mode") and labels.has("Hardcore mode"), str(labels))
	for mode in [SaveData.CLASSIC, SaveData.HARDCORE]:
		title._open_levels(mode)
		await _frames(3)
		var pick: LevelSelect = title.find_children("*", "LevelSelect", true, false)[0]
		var names: Array = pick.find_children("*", "Label", true, false).map(func(l): return l.text)
		check("%s level select lists both levels" % mode, names.has("The Tower") and names.has("The Long Rack"), str(names))
		check("%s level select shows a numbered ball per level" % mode, pick._balls.size() == 2 and pick._balls[1].number == 2)
		pick.close()
		await _frames(2)
	# Starting a level from the menu.
	SaveData.set_run(SaveData.CLASSIC, 2)
	SaveData.has_run = false
	SaveData.save()
	SaveData.set_run(SaveData.CLASSIC, 1)
	title._open_levels(SaveData.CLASSIC)
	await _frames(3)
	var select: LevelSelect = title.find_children("*", "LevelSelect", true, false)[0]
	var buttons: Array = select.find_children("*", "Button", true, false).map(func(b): return b.text)
	check("a level with no run offers Start", buttons.has("Start"), str(buttons))
	select.mode = SaveData.HARDCORE
	select._prepare(2, true)
	check("starting sets the mode and level", SaveData.mode == SaveData.HARDCORE and SaveData.level == 2 and SaveData.has_run)
	select.close()
	title.queue_free()
	await _frames(2)
	SaveData.set_run(SaveData.CLASSIC, 1)


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
