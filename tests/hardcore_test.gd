extends Node
## Hardcore mode (the floating white ball) and the music.
##   godot --headless --path . res://tests/hardcore_test.tscn -- --save-profile=hardcore

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
	print("White ball physics")
	_physics_tests()
	print("Hardcore game")
	await _game_tests()
	print("Music")
	await _music_tests()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.path))
	print("%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _box_world() -> CollisionWorld:
	var w := CollisionWorld.new()
	for x in range(-30, 31):
		w.cells[Vector2i(x, 0)] = [CollisionWorld.Shape.SOLID, CollisionWorld.Mat.TABLE, 0]
		w.cells[Vector2i(x, -40)] = [CollisionWorld.Shape.SOLID, CollisionWorld.Mat.TABLE, 0]
	for y in range(-40, 1):
		w.cells[Vector2i(-30, y)] = [CollisionWorld.Shape.SOLID, CollisionWorld.Mat.TABLE, 0]
		w.cells[Vector2i(30, y)] = [CollisionWorld.Shape.SOLID, CollisionWorld.Mat.TABLE, 0]
	return w


func _floater(at: Vector2) -> BallSim:
	var b := BallSim.new()
	b.floating = true
	b.reset(at)
	return b


func _physics_tests() -> void:
	var w := _box_world()
	var f := _floater(Vector2(0, -300))
	for i in 300:
		f.step(w)
	check("white ball hangs in mid-air (no gravity)", f.pos == Vector2(0, -300) and f.resting)

	f.vel = Vector2(0, -360)
	f.resting = false
	var start := f.pos
	for i in 600:
		f.step(w)
		if f.resting:
			break
	var expect := 360.0 * 360.0 / (2.0 * BallSim.FLOAT_DRAG)
	check("felt drag stops it after ~%.0f px" % expect, f.resting and absf(start.y - f.pos.y - expect) < 6.0, "travelled %.1f" % (start.y - f.pos.y))

	var wall := _floater(Vector2(400, -200))
	wall.vel = Vector2(300, 0)
	var back := 0.0
	for i in 200:
		wall.step(w)
		if wall.vel.x < 0.0:
			back = -wall.vel.x
			break
	check("it banks off a rail like a wall shot", back > 100.0 and back < 160.0, "%.0f" % back)

	var a := BallSim.new()
	a.reset(Vector2(0, -100))
	a.vel = Vector2(300, 0)
	var b := _floater(Vector2(13, -100))
	var closing := BallSim.collide_pair(a, b)
	check("ball-on-ball knock transfers momentum", closing > 299.0 and absf(b.vel.x - 300.0 * (1.0 + BallSim.BALL_BOUNCE) / 2.0) < 0.5 and absf(a.vel.x + b.vel.x - 300.0) < 0.01, "%s %s" % [a.vel, b.vel])
	check("knock separates overlapping balls", a.pos.distance_to(b.pos) >= BallSim.RADIUS * 2.0 - 0.01)
	check("moving apart is not a second knock", BallSim.collide_pair(a, b) == 0.0)

	# Gold pocket: only the white ball may sink it in Hardcore.
	var pw := _box_world()
	pw.pockets.append({ "pos": Vector2(0, -8), "radius": 6.0, "exit": Vector2.ZERO, "goal": true, "id": 1 })
	var player := BallSim.new()
	player.ignore_goal = true
	player.reset(Vector2(-60, -7))
	player.grounded = true
	player.vel = Vector2(320, 0)
	var won := false
	for i in 120:
		player.step(pw)
		won = won or player.events.any(func(e): return e.type == BallSim.Event.GOAL)
	check("your ball rolls straight over the gold pocket", not won and not player.in_pocket)
	var wb := _floater(Vector2(-60, -8))
	wb.vel = Vector2(200, 0)
	for i in 120:
		wb.step(pw)
		won = won or wb.events.any(func(e): return e.type == BallSim.Event.GOAL)
	check("the white ball sinks it", won)

	var rp := _floater(Vector2.ZERO)
	rp.in_pocket = true
	rp.release_from_pocket(Vector2(50, -60))
	check("white ball leaves the ball return at rest", rp.vel == Vector2.ZERO and rp.pos == Vector2(50, -60))


func _game_tests() -> void:
	# A classic run in progress must survive a hardcore session untouched.
	SaveData.set_mode(SaveData.CLASSIC)
	SaveData.start_new_run()
	SaveData.strokes = 17
	SaveData.ball_pos = Vector2(111, -222)
	SaveData.save()
	SaveData.set_mode(SaveData.HARDCORE)
	SaveData.start_new_run()
	check("hardcore starts a fresh run of its own", SaveData.strokes == 0 and SaveData.has_run)

	var game: Node2D = load("res://scenes/world/game.tscn").instantiate()
	add_child(game)
	await _frames(3)
	check("a fresh Hardcore climb opens the goal pop-up", is_instance_valid(game.intro) and get_tree().paused)
	var words := " ".join(game.intro.find_children("*", "Label", true, false).map(func(l): return l.text)).to_lower()
	check("pop-up explains pushing the white ball into the top pocket", words.contains("white ball") and words.contains("gold pocket") and words.contains("top"), words)
	check("Hardcore pop-up is short and shows the white ball", game.intro.get_meta("lines").length() < 70 and game.intro._ball.number == 16 and words.contains("hardcore"))
	await get_tree().create_timer(0.8, true, false, true).timeout
	var release := InputEventAction.new()
	release.action = "charge"
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(3)
	check("releasing the button closes it and resumes play", not is_instance_valid(game.intro) and not get_tree().paused)
	await _physics(60)
	check("closing the pop-up didn't start a charge", not game.player.charging)
	check("white ball starts just above your ball", game.white != null and game.white.sim.pos.distance_to(game.white_start) < 0.5 and absf(game.white_start.x - game.tower.spawn.x) < 0.5 and game.white_start.y < game.player.sim.pos.y - BallSim.RADIUS * 2.0 and game.player.sim.pos.y - game.white_start.y < 40.0, "%s vs %s" % [game.white_start, game.player.sim.pos])
	check("your ball is the normal ball, partnered to the white one", game.player.partner == game.white.sim and not game.player.sim.floating and game.player.sim.ignore_goal)
	check("white ball stays put without gravity", game.white.sim.resting and absf(game.white.sim.pos.y - game.white_start.y) < 0.01)

	# A soft straight-up shot from the spawn knocks it on its way.
	var p: PlayerBall = game.player
	p.aim_deg = 0.0
	p.charge_ticks = 12
	p.strike()
	var moved := false
	var hits: Array[float] = []
	p.ball_hit.connect(func(i: float): hits.append(i))
	for i in 240:
		await get_tree().physics_frame
		if game.white.sim.vel.length() > 50.0:
			moved = true
	check("a soft shot straight up knocks the white ball", not hits.is_empty() and moved, str(hits))
	check("knocked white ball travels up then stops in place", game.white.sim.resting and game.white.sim.pos.y < game.white_start.y - 20.0, str(game.white.sim.pos))
	game.save_progress()
	game.queue_free()
	await _frames(2)
	game = load("res://scenes/world/game.tscn").instantiate()
	add_child(game)
	await _frames(3)
	check("continuing a started climb skips the pop-up", not is_instance_valid(game.intro) and not get_tree().paused)

	# The edge arrow points to the white ball on another screen.
	game.white.place(Vector2(256, -2 * 288 - 140))
	await _frames(3)
	check("edge arrow points two screens up", game._arrow.screens_away == 2 and game._arrow.visible)
	game.white.place(game.white_start)
	await _frames(3)
	check("no arrow when it's on screen", game._arrow.screens_away == 0)

	# Re-rack.
	var falls := SaveData.falls
	game.white.place(Vector2(300, -1000))
	game.rerack_white()
	check("re-rack returns the white ball and counts a fall", game.white.sim.pos == game.white_start and SaveData.falls == falls + 1)

	# Saved white position survives a reload.
	game.white.place(Vector2(200, -150))
	await _physics(5)
	game.save_progress()
	game.queue_free()
	await _frames(2)
	game = load("res://scenes/world/game.tscn").instantiate()
	add_child(game)
	await _physics(10)
	check("white ball position is saved", game.white.sim.pos.distance_to(Vector2(200, -150)) < 0.5, str(game.white.sim.pos))

	# Sink the white ball in the gold pocket: Hardcore is won.
	var goal: Dictionary = {}
	for pk in game.tower.world.pockets:
		if pk.goal:
			goal = pk
	SaveData.collected.erase(16)
	game.white.place(goal.pos + Vector2(-30, -1))
	game.white.sim.vel = Vector2(220, 0)
	game.white.sim.resting = false
	await _physics(120)
	check("white ball in the gold pocket wins Hardcore", game.finished)
	check("the white ball joins the Ball Rack", SaveData.collected.has(16))
	check("hardcore win recorded separately", SaveData.hc_wins == 1 and not SaveData.has_run)
	game.queue_free()
	await _frames(2)
	SaveData.set_mode(SaveData.CLASSIC)
	check("classic run untouched by hardcore", SaveData.has_run and SaveData.strokes == 17 and SaveData.ball_pos == Vector2(111, -222))

	# Classic games have no white ball.
	game = load("res://scenes/world/game.tscn").instantiate()
	add_child(game)
	await _physics(5)
	check("classic mode has no white ball", game.white == null and game.player.partner == null and not game.player.sim.ignore_goal)
	game.queue_free()
	await _frames(2)


func _music_tests() -> void:
	var title: Control = load("res://scenes/ui/title.tscn").instantiate()
	add_child(title)
	await _frames(3)
	check("title plays the Back Room theme", Sfx.current_music() == Sfx.MUSIC[0])
	var labels: Array = title.find_children("*", "Button", true, false).map(func(b): return b.text)
	check("title offers Hardcore", labels.any(func(t): return t.begins_with("Hardcore")), str(labels))
	title.queue_free()
	await _frames(2)
	for track in Sfx.MUSIC:
		var s: AudioStream = load("res://assets/audio/" + track + ".wav")
		check("%s exists and is 30 s or longer" % track, s != null and s.get_length() >= 30.0)
	SaveData.set_mode(SaveData.CLASSIC)
	SaveData.start_new_run()
	var game: Node2D = load("res://scenes/world/game.tscn").instantiate()
	add_child(game)
	await _frames(3)
	# Each mode has its own goal pop-up: Classic's is about you, not a white ball.
	check("a fresh Classic climb opens its own goal pop-up", is_instance_valid(game.intro) and get_tree().paused)
	var words := " ".join(game.intro.find_children("*", "Label", true, false).map(func(l): return l.text)).to_lower()
	check("Classic pop-up: reach the gold pocket at the top", words.contains("the climb") and words.contains("gold pocket") and words.contains("top") and not words.contains("white ball"), words)
	check("Classic pop-up shows your own ball", game.intro._ball.number == SaveData.skin)
	game.intro.dismiss()
	await _physics(5)
	check("climb starts with the Back Room theme", Sfx.current_music() == Sfx.MUSIC[0])
	game.player.place(Vector2(256, -3 * 288 - 100))
	await _physics(5)
	check("Neon Bar switches the music", Sfx.current_music() == Sfx.MUSIC[1])
	game.player.place(Vector2(256, -9 * 288 - 100))
	await _physics(5)
	check("the summit has its own theme", Sfx.current_music() == Sfx.MUSIC[3])
	game.queue_free()
	await _frames(2)
	var opts := OptionsMenu.new()
	add_child(opts)
	await _frames(2)
	var rows := opts.find_children("*", "Label", true, false).map(func(l): return l.text)
	check("options has a Music volume", rows.has("Music"), str(rows))
	SaveData.music_volume = 0.25
	opts.close()
	await _frames(2)
	SaveData.load_data()
	check("music volume persists", is_equal_approx(SaveData.music_volume, 0.25))


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
