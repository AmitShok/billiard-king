extends Node
## Menus and the end of the climb: title, Ball Rack locks, options
## persistence, the gold pocket, awards and the ending card.
##   godot --headless --path . res://tests/menu_test.tscn -- --save-profile=menu

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
	SaveData.collected.clear()
	SaveData.skin = 0
	SaveData.has_run = false
	SaveData.wins = 0
	SaveData.save()

	print("Title")
	var title: Control = load("res://scenes/ui/title.tscn").instantiate()
	add_child(title)
	await _frames(3)
	var labels := _button_texts(title)
	check("no Continue without a run", not labels.has("Continue") and labels.has("New climb"), str(labels))
	check("menu has rack, options, quit", labels.has("Ball Rack") and labels.has("Options") and labels.has("Quit"))
	check("first button has focus", get_viewport().gui_get_focus_owner() is Button)

	print("Ball Rack")
	var rack := BallRack.new()
	title.add_child(rack)
	await _frames(2)
	rack._on_pick(5)
	check("locked ball cannot be picked", SaveData.skin == 0)
	SaveData.collect_ball(5)
	rack._on_pick(5)
	check("found ball can be picked", SaveData.skin == 5)
	rack.close()
	await _frames(2)
	SaveData.load_data()
	check("skin choice is saved", SaveData.skin == 5)

	print("Options")
	var opts := OptionsMenu.new()
	title.add_child(opts)
	await _frames(2)
	var before := SaveData.screen_shake
	for b in _buttons(opts):
		if b.text.begins_with("Screen shake"):
			b.pressed.emit()
	check("screen shake toggles", SaveData.screen_shake != before)
	SaveData.sfx_volume = 0.3
	opts.close()
	await _frames(2)
	SaveData.load_data()
	check("options persist", SaveData.screen_shake != before and is_equal_approx(SaveData.sfx_volume, 0.3))
	SaveData.screen_shake = true
	title.queue_free()
	await _frames(2)

	print("Winning")
	SaveData.start_new_run()
	for n in range(1, 11):
		SaveData.collect_ball(n)
	var game: Node2D = load("res://scenes/world/game.tscn").instantiate()
	game.show_intro = false
	add_child(game)
	await _physics(10)
	var goal: Dictionary = {}
	for p in game.tower.world.pockets:
		if p.goal:
			goal = p
	check("tower has a gold pocket", not goal.is_empty())
	SaveData.strokes = 120
	SaveData.falls = 3
	SaveData.run_time = 900.0
	game.player.place(goal.pos + Vector2(-24, -1))
	game.player.sim.vel = Vector2(160, 0)
	game.player.sim.grounded = true
	game.player.sim.resting = false
	await _physics(120)
	check("rolling into the gold pocket wins", game.finished)
	check("all five awards granted", [11, 12, 13, 14, 15].all(func(n): return SaveData.collected.has(n)), str(SaveData.collected))
	check("run is closed and recorded", not SaveData.has_run and SaveData.wins == 1 and absf(SaveData.best_time - 900.0) < 5.0, "time %.1f wins %d" % [SaveData.best_time, SaveData.wins])
	await _frames(5)
	var ending_found := false
	for c in game.hud.get_children():
		if c.get_script() == load("res://scripts/ui/ending.gd"):
			ending_found = true
	check("ending card shown", ending_found)
	check("controls locked after the win", not game.player.input_enabled)
	game.queue_free()
	await _frames(2)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.path))
	print("%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _buttons(root: Node) -> Array:
	var out: Array = []
	for n in root.find_children("*", "Button", true, false):
		out.append(n)
	return out


func _button_texts(root: Node) -> Array:
	return _buttons(root).map(func(b): return b.text)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
