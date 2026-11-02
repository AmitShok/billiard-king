extends Node
## Gameplay checks: physics feel, seams, english, pockets, lost balls,
## input through the real game scene, camera cuts and save/load.
##   godot --headless --path . res://tests/gameplay_test.tscn -- --save-profile=test

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
	print("Physics")
	_physics_tests()
	print("Game scene")
	await _game_tests()
	print("Save data")
	_save_tests()
	print("%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


# A flat floor from x=-20..60 tiles at row 0, walls at x=-21 and 61 (rows -12..-1).
func _flat_world(mat := CollisionWorld.Mat.TABLE, zone := 0) -> CollisionWorld:
	var w := CollisionWorld.new()
	for x in range(-21, 62):
		w.cells[Vector2i(x, 0)] = [CollisionWorld.Shape.SOLID, mat, zone]
	for y in range(-12, 0):
		w.cells[Vector2i(-21, y)] = [CollisionWorld.Shape.SOLID, mat, zone]
		w.cells[Vector2i(61, y)] = [CollisionWorld.Shape.SOLID, mat, zone]
	return w


func _settled_sim(w: CollisionWorld, at: Vector2) -> BallSim:
	var s := BallSim.new()
	s.reset(at)
	for i in 600:
		s.step(w)
		if s.resting:
			break
	return s


func _run(s: BallSim, w: CollisionWorld, max_steps := 1200) -> Array:
	var events: Array = []
	for i in max_steps:
		s.step(w)
		events.append_array(s.events)
		if s.resting and i > 2:
			break
	return events


func _physics_tests() -> void:
	var w := _flat_world()
	var s := _settled_sim(w, Vector2(8, -40))
	check("ball settles on flat felt", s.resting and absf(s.pos.y - (-7.0)) < 0.6, str(s.pos))
	check("settled ball can be struck", s.can_shoot())

	# Straight-up full shot reaches the designed height.
	s.shoot(0, BallSim.CHARGE_TICKS, 0)
	var top := s.pos.y
	for i in 400:
		s.step(w)
		top = minf(top, s.pos.y)
	var expect := BallSim.MAX_SPEED * BallSim.MAX_SPEED / (2.0 * BallSim.GRAVITY)
	check("full-power jump height ~%.0f px" % expect, absf((-7.0 - top) - expect) < 6.0, "got %.1f" % (-7.0 - top))

	# Charge maps linearly onto speed.
	check("minimum charge gives minimum speed", is_equal_approx(BallSim.shot_speed(0), BallSim.MIN_SPEED))
	check("half charge is between", absf(BallSim.shot_speed(BallSim.CHARGE_TICKS / 2) - (BallSim.MIN_SPEED + BallSim.MAX_SPEED) / 2.0) < 1.0)

	# Rolling across many tile seams: no snagging, no hops.
	s = _settled_sim(w, Vector2(-200, -20))
	s.vel = Vector2(400, 0)
	s.resting = false
	var min_y := s.pos.y
	var max_y := s.pos.y
	var steps := 0
	while not s.resting and steps < 1000:
		s.step(w)
		min_y = minf(min_y, s.pos.y)
		max_y = maxf(max_y, s.pos.y)
		steps += 1
	check("rolls over tile seams without hopping", max_y - min_y < 0.6, "y range %.2f" % (max_y - min_y))
	var dist := s.pos.x + 200.0
	var expect_roll := 400.0 * 400.0 / (2.0 * BallSim.ROLL_DECEL[0])
	check("felt stops a 400px/s roll in ~%.0f px" % expect_roll, absf(dist - expect_roll) < 20.0, "rolled %.1f" % dist)

	# Wood rail bounce keeps about half the speed; rubber keeps most.
	for case in [[CollisionWorld.Mat.TABLE, BallSim.WALL_BOUNCE, "wood rail"], [CollisionWorld.Mat.CUSHION, BallSim.CUSHION_BOUNCE, "rubber cushion"]]:
		var ww := CollisionWorld.new()
		for y in range(-30, 30):
			ww.cells[Vector2i(10, y)] = [CollisionWorld.Shape.SOLID, case[0], 0]
		var b := BallSim.new()
		b.reset(Vector2(100, 0))
		b.vel = Vector2(300, 0)
		var got := 0.0
		for i in 200:
			b.vel.y = 0.0
			b.step(ww)
			b.vel.y = 0.0
			if b.vel.x < 0.0:
				got = -b.vel.x
				break
		check("%s rebounds at ~%d%%" % [case[2], case[1] * 100], absf(got / 300.0 - case[1]) < 0.08, "ratio %.2f" % (got / 300.0))

	# Slopes: a ball dropped on a 45 degree slope rolls downhill and cannot be struck there.
	var sw := CollisionWorld.new()
	for x in range(-10, 20):
		sw.cells[Vector2i(x, 1)] = [CollisionWorld.Shape.SOLID, CollisionWorld.Mat.TABLE, 0]
	sw.cells[Vector2i(2, 0)] = [CollisionWorld.Shape.SLOPE_UP_RIGHT, CollisionWorld.Mat.TABLE, 0]
	sw.cells[Vector2i(3, 0)] = [CollisionWorld.Shape.SOLID, CollisionWorld.Mat.TABLE, 0]
	var sb := BallSim.new()
	sb.reset(Vector2(41, -20))
	var on_slope_shootable := false
	for i in 60:
		sb.step(sw)
		if sb.grounded and sb.ground_normal.y > -0.8 and sb.can_shoot():
			on_slope_shootable = true
	check("ball rolls down a slope", sb.vel.x < -20.0, str(sb.vel))
	check("cannot strike from a steep slope", not on_slope_shootable)

	# English: follow carries further than plain, draw stops shorter.
	var lands := []
	for spin in [-2, 0, 2]:
		var e := _settled_sim(w, Vector2(0, -20))
		e.shoot(40, 50, spin)
		_run(e, w)
		lands.append(e.pos.x)
	check("follow > plain > draw on landing", lands[2] > lands[1] + 8.0 and lands[1] > lands[0] + 8.0, str(lands))

	# A big drop is a splat (the Jump King fall).
	var fw := _flat_world()
	var f := BallSim.new()
	f.reset(Vector2(0, -300))
	var evs := _run(f, fw)
	check("long drop lands as a splat", evs.any(func(ev): return ev.type == BallSim.Event.SPLAT))
	var small := BallSim.new()
	small.reset(Vector2(0, -40))
	evs = _run(small, fw)
	check("short drop is a normal landing", not evs.any(func(ev): return ev.type == BallSim.Event.SPLAT))

	# Bumper kicks the ball out at least BUMPER_KICK.
	var bw := _flat_world()
	bw.bumpers.append({ "pos": Vector2(100, -60), "radius": 12.0, "id": 7 })
	var bb := BallSim.new()
	bb.reset(Vector2(100, -120))
	var kicked := 0.0
	var bump_id := -1
	for i in 200:
		bb.step(bw)
		for ev in bb.events:
			if ev.type == BallSim.Event.BUMPER:
				kicked = bb.vel.length()
				bump_id = ev.id
		if bump_id >= 0:
			break
	check("bumper kicks with at least %d px/s" % BallSim.BUMPER_KICK, kicked >= BallSim.BUMPER_KICK - 1.0 and bump_id == 7, "%.0f" % kicked)

	# Pocket swallows the ball, then the return drops it at the exit.
	var pw := _flat_world()
	pw.pockets.append({ "pos": Vector2(120, -8), "radius": 6.0, "exit": Vector2(-200, -100), "goal": false, "id": 3 })
	var pb := _settled_sim(pw, Vector2(40, -20))
	pb.vel = Vector2(320, 0)
	pb.resting = false
	var pocketed: Dictionary = {}
	for i in 300:
		pb.step(pw)
		for ev in pb.events:
			if ev.type == BallSim.Event.POCKET:
				pocketed = ev
		if not pocketed.is_empty():
			break
	check("rolling over a pocket sinks the ball", pb.in_pocket and pocketed.get("exit") == Vector2(-200, -100))
	pb.release_from_pocket(pocketed.get("exit", Vector2.ZERO))
	check("ball-return drops it at the exit", pb.pos == Vector2(-200, -100) and not pb.in_pocket)

	# Lost balls are collected once.
	var lw := _flat_world()
	lw.lost_balls.append({ "pos": Vector2(60, -8), "number": 4, "taken": false })
	var lb := _settled_sim(lw, Vector2(0, -20))
	lb.vel = Vector2(320, 0)
	lb.resting = false
	var found := 0
	for i in 300:
		lb.step(lw)
		for ev in lb.events:
			if ev.type == BallSim.Event.LOST_BALL:
				found += 1
	check("lost ball collected exactly once", found == 1, str(found))

	# Determinism: the same shot gives the same result.
	var r1 := _settled_sim(w, Vector2(0, -20))
	r1.shoot(-35, 61, 1)
	_run(r1, w)
	var r2 := _settled_sim(w, Vector2(0, -20))
	r2.shoot(-35, 61, 1)
	_run(r2, w)
	check("identical shots give identical results", r1.pos == r2.pos)


func _game_tests() -> void:
	SaveData.start_new_run()
	var game: Node2D = load("res://scenes/world/game.tscn").instantiate()
	add_child(game)
	await _physics_frames(240)
	var p: PlayerBall = game.player
	check("player spawns resting at the spawn", p.sim.resting and p.sim.pos.distance_to(game.tower.spawn) < 4.0, str(p.sim.pos))
	check("camera starts on screen 0", game.screen == 0)

	# Aim with input notches, then a held charge auto-fires at full power.
	p.aim_deg = 0.0
	Input.action_press("aim_right")
	await _physics_frames(2)
	Input.action_release("aim_right")
	await _physics_frames(2)
	check("one tap nudges aim one notch", is_equal_approx(p.aim_deg, BallSim.AIM_STEP_DEG), str(p.aim_deg))
	Input.action_press("spin_up")
	await _physics_frames(2)
	Input.action_release("spin_up")
	check("spin up sets follow", p.spin_level == 1)
	p.aim_deg = 0.0
	p.spin_level = 0
	var strokes := SaveData.strokes
	Input.action_press("charge")
	await _physics_frames(20)
	check("holding charges the cue", p.charging and p.charge_ticks > 10)
	await _physics_frames(BallSim.CHARGE_TICKS)
	check("full charge auto-fires", SaveData.strokes == strokes + 1 and not p.sim.grounded)
	Input.action_release("charge")
	await _physics_frames(300)
	check("ball lands and rests again", p.sim.resting)

	# A tap fires a short shot on release.
	Input.action_press("charge")
	await _physics_frames(6)
	Input.action_release("charge")
	await _physics_frames(2)
	check("release fires the shot", SaveData.strokes == strokes + 2)
	await _physics_frames(300)

	# No air control: aim input in the air does nothing to the flight.
	p.place(Vector2(256, -200))
	p.sim.vel = Vector2(0, -100)
	p.sim.grounded = false
	var vx := p.sim.vel.x
	Input.action_press("aim_left")
	await _physics_frames(10)
	Input.action_release("aim_left")
	check("no air control", is_equal_approx(p.sim.vel.x, vx))
	await _physics_frames(300)

	# Camera cuts when the ball crosses into the next screen.
	p.place(Vector2(200, -300))
	await _physics_frames(3)
	check("camera cuts to screen 1", game.screen == 1 and game.camera.position == Tower.screen_center(1))
	p.place(game.tower.spawn)
	await _physics_frames(3)
	check("camera cuts back to screen 0", game.screen == 0)

	# Resting saves the spot.
	await _physics_frames(200)
	SaveData.ball_pos = Vector2.ZERO
	p.place(game.tower.spawn + Vector2(40, -10))
	await _physics_frames(200)
	check("resting saves the ball position", SaveData.ball_pos.distance_to(p.sim.pos) < 0.5 and SaveData.ball_pos != Vector2.ZERO)

	# Pause freezes the climb.
	game.pause_menu.open()
	check("pause stops the tree", get_tree().paused)
	game.pause_menu.close()
	check("resume restarts it", not get_tree().paused)
	game.queue_free()
	await get_tree().process_frame


func _save_tests() -> void:
	SaveData.start_new_run()
	SaveData.strokes = 42
	SaveData.ball_pos = Vector2(123, -456)
	SaveData.collect_ball(3)
	SaveData.skin = 3
	SaveData.save()
	SaveData.strokes = 0
	SaveData.ball_pos = Vector2.ZERO
	SaveData.skin = 0
	SaveData.load_data()
	check("run survives save/load", SaveData.strokes == 42 and SaveData.ball_pos == Vector2(123, -456))
	check("rack and skin survive save/load", SaveData.collected.has(3) and SaveData.skin == 3)
	SaveData.collected.clear()
	SaveData.save()
	SaveData.load_data()
	check("locked skin falls back to the cue ball", SaveData.skin == 0)
	SaveData.finish_run()
	check("finishing clears the run and records it", not SaveData.has_run and SaveData.wins >= 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.path))


func _physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
