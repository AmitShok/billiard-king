extends Node
## Training mode: checkpoint flags, no lost balls, nothing saved or unlocked,
## and the camera glide between screens.
##   godot --headless --path . res://tests/training_test.tscn -- --save-profile=training

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
	# A fresh profile: only level 1 is open.
	SaveData.reset_progress()
	print("Menus")
	await _menu_tests()
	print("Flags")
	await _flag_tests()
	print("Nothing counts")
	await _no_progress_tests()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.path))
	print("%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _buttons(root: Node) -> Array:
	return root.find_children("*", "Button", true, false)


func _menu_tests() -> void:
	var title: Control = load("res://scenes/ui/title.tscn").instantiate()
	add_child(title)
	await _frames(3)
	var names: Array = _buttons(title).map(func(b): return b.text)
	check("the title has a Training button", names.has("Training"), str(names))
	title._open_levels(SaveData.TRAINING)
	await _frames(3)
	var select: LevelSelect = title.find_children("*", "LevelSelect", true, false)[0]
	var texts: Array = _buttons(select).map(func(b): return b.text)
	check("training lists level 1 to practise", texts.count("Practise") == 1, str(texts))
	check("levels not yet opened stay locked in training", texts.count("Locked") == 3, str(texts))
	check("no Continue or New in training", not texts.has("Continue") and not texts.has("New"))
	title.queue_free()
	await _frames(2)


func _load_training(level: int) -> Node2D:
	SaveData.set_run(SaveData.TRAINING, level)
	SaveData.start_new_run()
	var g: Node2D = load("res://scenes/world/game.tscn").instantiate()
	add_child(g)
	await _frames(2)
	if is_instance_valid(g.intro):
		var words := " ".join(g.intro.find_children("*", "Label", true, false).map(func(l): return l.text)).to_lower()
		check("the training pop-up explains the flags", words.contains("flag") and words.contains("nothing here counts"), words)
		g.intro.dismiss()
	await _physics(10)
	return g


func _rest(game: Node2D, at: Vector2) -> void:
	game.player.place(at)
	for i in 240:
		await get_tree().physics_frame
		if game.player.sim.resting:
			break


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	ev = InputEventAction.new()
	ev.action = action
	ev.pressed = false
	Input.parse_input_event(ev)
	await _frames(1)


func _flag_tests() -> void:
	var game := await _load_training(1)
	check("training is its own mode", game.training() and not game.hardcore())
	var visible_lost: Array = game.tower.get_node("Objects").get_children().filter(func(n): return n is LostBall and n.visible)
	check("training has no lost balls", game.tower.world.lost_balls.is_empty() and visible_lost.is_empty(), str(visible_lost.size()))
	var top: String = game._training_hud.text
	check("the training keys are always on screen", top.contains("plant flag") and top.contains("back to flag") and top.contains("remove flag") and game._training_hud.visible, top)
	check("they name the keys", top.contains("]C[") and top.contains("]R[") and top.contains("]X["), top)

	# Can't plant mid-flight.
	game.player.place(game.tower.spawn + Vector2(0, -60))
	await _physics(2)
	check("no flag while the ball is in the air", not game.plant_flag() and game.flags.is_empty())

	var a: Vector2 = game.tower.spawn
	await _rest(game, a)
	await _press("flag_place")
	check("C plants a flag where the ball rests", game.flags.size() == 1 and game.flags[0].spot.distance_to(game.player.sim.pos) < 0.5)
	var first: CheckpointFlag = game.flags[0]
	check("the flag stands in the tower's decor", first.get_parent() == game.tower.get_node("Decor") and first.active)
	var bumpers: int = game.tower.world.bumpers.size()
	var cells: int = game.tower.world.cells.size()
	check("a flag never enters the physics", game.tower.world.bumpers.size() == bumpers and game.tower.world.cells.size() == cells)
	await get_tree().create_timer(0.5).timeout
	check("a planted flag pops up to full height", is_equal_approx(first._rise, 1.0), str(first._rise))
	check("the planted flag shows in the count", game._training_hud.text.contains("flags [color=#9ff0b4]1"), game._training_hud.text)
	check("training shows the controls on any resting spot", game.player.sim.resting)

	await _rest(game, a + Vector2(90, 0))
	check("the ball rested somewhere new", game.player.sim.resting and game.player.sim.pos.distance_to(a) > 40.0, str(game.player.sim.pos))
	var b: Vector2 = game.player.sim.pos
	check("a second flag goes down", game.plant_flag() and game.flags.size() == 2)
	check("only the newest flag is lit", game.flags[1].active and not game.flags[0].active)
	check("planting on a flag doesn't stack another", not game.plant_flag() and game.flags.size() == 2)

	# The pennant streams with the wind and flutters when the ball passes.
	var second: CheckpointFlag = game.flags[1]
	second.feel_wind(Vector2(-280, 0))
	for i in 30:
		second.update(1.0 / 60.0)
	check("a gust turns the pennant downwind", second._side < 0.0, str(second._side))
	second.feel_wind(Vector2.ZERO)
	var calm_flutter: float = second._flutter
	second.poke(second.global_position + Vector2(4, -10), Vector2(200, 0))
	check("a passing ball makes it flutter", second._flutter > calm_flutter)

	# Fall away, then R goes back to the newest flag.
	game.player.place(Vector2(200, -400))
	await _physics(5)
	await _press("flag_return")
	check("R sends the ball back to the newest flag", game.player.sim.pos.distance_to(b) < 0.5, str(game.player.sim.pos))
	check("the camera follows it back", game.camera_target == Tower.screen_center(Tower.screen_of(b.y)))

	await _press("flag_remove")
	check("X pulls up the newest flag", game.flags.size() == 1 and game.flags[0] == first and first.active)
	await _physics(40)
	check("the removed flag folds away", not is_instance_valid(second))
	game.return_to_flag()
	check("then R goes back to the flag before it", game.player.sim.pos.distance_to(a) < 1.0, str(game.player.sim.pos))
	game.remove_flag()
	check("no flags left", game.flags.is_empty() and not game.remove_flag())
	game.player.place(Vector2(200, -400))
	await _physics(3)
	game.return_to_flag()
	check("with no flags R goes back to the start", game.player.sim.pos == game.tower.spawn)

	# Pause shows the flags; quitting says Quit, not Save.
	game.pause_menu.open()
	await _frames(2)
	var words: String = game.pause_menu._stats.text
	check("the pause screen counts flags", words.contains("Training") and words.contains("Flags"), words)
	var labels: Array = _buttons(game.pause_menu).map(func(b): return b.text)
	check("training's pause offers Quit", labels.has("Quit") and not labels.has("Save and quit"), str(labels))
	game.pause_menu.close()
	game.queue_free()
	await _frames(2)


func _no_progress_tests() -> void:
	var before_collected := SaveData.collected.duplicate()
	var game := await _load_training(1)
	game.plant_flag()
	game.save_progress()
	var cfg := ConfigFile.new()
	cfg.load(SaveData.path)
	var training_sections: Array = Array(cfg.get_sections()).filter(func(s): return s.contains("training"))
	check("a training run is never written to the save", training_sections.is_empty(), str(training_sections))
	game._on_won()
	await _frames(3)
	var ending: Control = game.hud.get_child(game.hud.get_child_count() - 1)
	var text := " ".join(ending.find_children("*", "Label", true, false).map(func(l): return l.text))
	check("winning in training says it's practice", text.contains("Training run complete") and text.contains("no records"), text)
	check("training wins open no levels", not SaveData.level_unlocked(2))
	check("training wins record nothing", SaveData.wins == 0 and SaveData.record(SaveData.CLASSIC, 1).wins == 0)
	check("training wins give no balls", SaveData.collected == before_collected, str(SaveData.collected))
	check("and the normal run is untouched", not SaveData.has_run_for(SaveData.CLASSIC, 1))
	game.queue_free()
	await _frames(2)
	SaveData.set_run(SaveData.CLASSIC, 1)


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
