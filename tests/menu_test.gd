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

	print("Rename")
	var old_file := ProjectSettings.globalize_path("user://test_old_name.cfg")
	var old := ConfigFile.new()
	old.set_value("rack", "wins", 7)
	old.save(old_file)
	var keep_path := SaveData.path
	SaveData.path = "user://test_new_name.cfg"
	check("an old save is adopted", SaveData.adopt_old_save(old_file) and FileAccess.file_exists(SaveData.path))
	var copied := ConfigFile.new()
	copied.load(SaveData.path)
	check("with its progress intact", copied.get_value("rack", "wins", 0) == 7)
	check("the original is left in place", FileAccess.file_exists(old_file))
	check("an existing save is never overwritten", not SaveData.adopt_old_save(old_file))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.path))
	check("no old save, nothing happens", not SaveData.adopt_old_save("user://no_such_file.cfg"))
	DirAccess.remove_absolute(old_file)
	SaveData.path = keep_path

	print("Title")
	var title: Control = load("res://scenes/ui/title.tscn").instantiate()
	add_child(title)
	await _frames(3)
	var labels := _button_texts(title)
	check("title offers both modes", labels.has("Normal mode") and labels.has("Hardcore mode"), str(labels))
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

	await _progress_tests()

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
	var ending: Control = null
	for c in game.hud.get_children():
		if c.get_script() == load("res://scripts/ui/ending.gd"):
			ending = c
	check("ending card shown", ending != null)
	check("controls locked after the win", not game.player.input_enabled)
	# Returning: a real button, and a tap anywhere (taps used to be swallowed).
	ending.back_requested.disconnect(game.quit_to_title)
	var backs := [0]
	ending.back_requested.connect(func(): backs[0] += 1)
	var back_btn: Button = null
	for b in ending.find_children("*", "Button", true, false):
		if b.text == "Back to title":
			back_btn = b
	check("the win card has a Back to title button", back_btn != null)
	for i in 400:
		if ending.can_return():
			break
		await get_tree().process_frame
	check("it is focused once the card fades in", back_btn != null and back_btn.has_focus() and not back_btn.disabled)
	var tap := InputEventScreenTouch.new()
	tap.position = Vector2(40, 40)
	tap.pressed = true
	get_tree().root.push_input(tap, true)
	await _frames(1)
	check("a tap anywhere returns to the title", backs[0] == 1, str(backs[0]))
	ending.back()
	check("only once", backs[0] == 1)
	game.queue_free()
	await _frames(2)
	# A fresh card: the button and the Enter key also return.
	var card: Control = load("res://scripts/ui/ending.gd").new()
	add_child(card)
	var presses := [0]
	card.back_requested.connect(func(): presses[0] += 1)
	for i in 400:
		if card.can_return():
			break
		await get_tree().process_frame
	var enter := InputEventAction.new()
	enter.action = "ui_accept"
	enter.pressed = true
	get_tree().root.push_input(enter, true)
	await _frames(1)
	check("Enter on the focused button returns", presses[0] == 1, str(presses[0]))
	card.queue_free()
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


func _progress_tests() -> void:
	print("Unlock and reset")
	# Build up real progress in several places.
	SaveData.master_volume = 0.35
	SaveData.set_run(SaveData.HARDCORE, 3)
	SaveData.start_new_run()
	SaveData.strokes = 9
	SaveData.save()
	SaveData.set_run(SaveData.CLASSIC, 1)
	SaveData.start_new_run()
	SaveData.strokes = 5
	SaveData.collect_ball(2)
	SaveData.skin = 2
	SaveData.wins = 3
	SaveData.records["classic_2"] = { "wins": 1, "best_time": 1.0, "best_strokes": 1 }
	SaveData.save()
	var keep_records: Dictionary = SaveData.records.duplicate()

	var opts := OptionsMenu.new()
	add_child(opts)
	await _frames(2)
	var labels := _button_texts(opts)
	check("Options has Reset all progress", labels.has("Reset all progress"), str(labels))
	check("debug builds show the unlock button", OS.is_debug_build() and labels.has("Test: unlock everything"), str(labels))
	check("the Options panel still fits the screen", _panel_fits(opts))
	for b in _buttons(opts):
		if b.text == "Test: unlock everything":
			b.pressed.emit()
	check("unlock opens every level", range(1, 5).all(func(n): return SaveData.level_unlocked(n)))
	check("unlock fills the Ball Rack, rainbow included", SaveData.collected.size() == BallRack.TOTAL and SaveData.collected.has(BallVisual.RAINBOW) and SaveData.collected.has(31), str(SaveData.collected.size()))
	check("unlock keeps your run and records", SaveData.strokes == 5 and SaveData.wins == 3 and SaveData.records == keep_records)
	SaveData.load_data()
	check("unlock survives a restart", SaveData.all_unlocked and SaveData.collected.size() == BallRack.TOTAL)
	opts.close()
	await _frames(2)

	# The real button: one press only asks. Run it under a throwaway scene so
	# the change back to the title doesn't free this test.
	var host := Node.new()
	get_tree().root.add_child(host)
	get_tree().current_scene = host
	var menu := OptionsMenu.new()
	host.add_child(menu)
	await _frames(2)
	var reset: Button = _buttons(menu).filter(func(b): return b.text == "Reset all progress")[0]
	reset.pressed.emit()
	check("one press only asks for confirmation", reset.text == OptionsMenu.CONFIRM_RESET and SaveData.wins == 3)
	reset.focus_exited.emit()
	check("moving away cancels it", reset.text == "Reset all progress")
	reset.pressed.emit()
	get_tree().paused = true
	reset.pressed.emit()
	await get_tree().create_timer(0.2, true, false, true).timeout
	await _frames(3)
	check("the second press wipes the Ball Rack and skin", SaveData.collected.is_empty() and SaveData.skin == 0)
	check("and every record", SaveData.wins == 0 and SaveData.hc_wins == 0 and SaveData.records.is_empty() and SaveData.best_time == 0.0)
	check("levels lock again", SaveData.level_unlocked(1) and not SaveData.level_unlocked(2) and not SaveData.level_unlocked(4))
	check("no run is left in any mode or level", not SaveData.has_run_for(SaveData.CLASSIC, 1) and not SaveData.has_run_for(SaveData.HARDCORE, 3) and not SaveData.has_run_for(SaveData.CLASSIC, 2))
	check("settings are kept", is_equal_approx(SaveData.master_volume, 0.35))
	check("it unpauses and returns to the title", not get_tree().paused and get_tree().current_scene != null and get_tree().current_scene.name == "Title", str(get_tree().current_scene))
	SaveData.load_data()
	check("the wipe survives a restart", SaveData.collected.is_empty() and SaveData.wins == 0 and not SaveData.all_unlocked and is_equal_approx(SaveData.master_volume, 0.35))
	var back_home := get_tree().current_scene
	get_tree().current_scene = self
	back_home.queue_free()
	await _frames(2)
	SaveData.master_volume = 0.8
	SaveData.save()


## Every control of the menu's panel sits inside the 512x288 view.
func _panel_fits(root: Control) -> bool:
	var view := Rect2(Vector2.ZERO, Vector2(512, 288))
	for c in root.find_children("*", "PanelContainer", true, false):
		if not view.encloses(c.get_global_rect()):
			return false
	return true
