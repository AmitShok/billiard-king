extends Node
## Touchscreen controls: hidden on computers, shown on touch devices, and every
## button drives the same action as its key.
##   godot --headless --path . res://tests/touch_test.tscn -- --save-profile=touch

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
	SaveData.reset_progress()
	print("Hidden on computers")
	await _computer_tests()
	print("Buttons")
	await _button_tests()
	print("Auto mode")
	await _auto_tests()
	print("Training and menus")
	await _training_tests()
	await _menu_tests()
	print("Button size")
	await _size_tests()
	SaveData.touch_controls = "auto"
	SaveData.touch_size = TouchControls.DEFAULT_SIZE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.path))
	print("%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _load(mode: String, intro := false) -> Node2D:
	SaveData.set_run(mode, 1)
	SaveData.start_new_run()
	var g: Node2D = load("res://scenes/world/game.tscn").instantiate()
	g.show_intro = intro
	add_child(g)
	await _frames(3)
	return g


func _close(g: Node2D) -> void:
	get_tree().paused = false
	g.queue_free()
	await _frames(2)


## A finger on the 512x288 view (the root viewport's own coordinates).
func _touch(at: Vector2, pressed: bool, finger := 0) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = finger
	ev.position = at
	ev.pressed = pressed
	get_tree().root.push_input(ev, true)


func _centre(b: TouchScreenButton) -> Vector2:
	return b.position + b.texture_normal.get_size() * b.scale / 2.0


func _rest(game: Node2D, at: Vector2) -> void:
	game.player.place(at)
	for i in 240:
		await get_tree().physics_frame
		if game.player.sim.resting:
			break


func _computer_tests() -> void:
	SaveData.touch_controls = "auto"
	check("a computer is not a touch device", not TouchControls.touch_device())
	var g := await _load(SaveData.CLASSIC)
	check("the game has the touch layer", g.touch != null)
	check("no touch buttons on a computer", not g.touch_on() and g.touch.buttons.all(func(b): return not b.visible))
	check("the keyboard hint stays", g._hint.text == g.HINT_KEYS)
	# Even a click on where a button would be does nothing.
	var at := _centre(g.touch.button("aim_right"))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = at
	click.pressed = true
	get_tree().root.push_input(click, true)
	await _frames(1)
	check("a mouse click never presses a touch button", not Input.is_action_pressed("aim_right"))
	click.pressed = false
	get_tree().root.push_input(click, true)
	await _close(g)


func _button_tests() -> void:
	SaveData.touch_controls = "on"
	var g := await _load(SaveData.CLASSIC)
	var t: TouchControls = g.touch
	check("turned on, the buttons show", g.touch_on() and t.buttons.all(func(b): return b.visible))
	var actions: Array = t.buttons.map(func(b): return String(b.action))
	for a in ["aim_left", "aim_right", "spin_up", "spin_down", "look_up", "look_down", "pause", "charge"]:
		check("there is a button for " + a, actions.has(a))
	check("no flag buttons outside training", not actions.has("flag_place"))
	check("the hint talks about the buttons", g._hint.text == g.HINT_TOUCH)
	check("idle buttons are see-through", t.buttons.all(func(b): return b.modulate.a < 0.6))

	# Layout: on screen, and no two touch areas overlap.
	var inside := true
	var apart := true
	for i in t.buttons.size():
		var a: TouchScreenButton = t.buttons[i]
		var ra: float = (a.shape as CircleShape2D).radius * a.scale.x
		var ca := _centre(a)
		if ca.x - ra < -4 or ca.y - ra < -4 or ca.x + ra > 516 or ca.y + ra > 292:
			inside = false
		for j in range(i + 1, t.buttons.size()):
			var b: TouchScreenButton = t.buttons[j]
			if ca.distance_to(_centre(b)) < ra + (b.shape as CircleShape2D).radius * b.scale.x:
				apart = false
	var aim_size: Vector2 = t.button("aim_left").texture_normal.get_size() * t.button("aim_left").scale
	var cue_size: Vector2 = t.button("charge").texture_normal.get_size() * t.button("charge").scale
	check("the buttons are thumb-sized (42 px, cue 66 px in the view)", aim_size.x >= 42.0 and cue_size.x >= 66.0, "%s %s" % [aim_size, cue_size])
	check("every button sits on screen", inside)
	check("no two buttons' touch areas overlap", apart)

	# Aim: holding the right arrow turns the cue.
	await _rest(g, g.tower.spawn)
	var aim0: float = g.player.aim_deg
	var right := t.button("aim_right")
	_touch(_centre(right), true)
	await _physics(30)
	check("holding the right arrow presses aim_right", Input.is_action_pressed("aim_right"))
	check("the pressed button lights up", right.modulate.a > 0.9)
	check("and turns the aim", g.player.aim_deg > aim0, "%s -> %s" % [aim0, g.player.aim_deg])
	_touch(_centre(right), false)
	await _physics(2)
	check("letting go releases it", not Input.is_action_pressed("aim_right"))
	# Spin.
	var spin0: int = g.player.spin_level
	_touch(_centre(t.button("spin_up")), true)
	await _physics(2)
	_touch(_centre(t.button("spin_up")), false)
	await _physics(2)
	check("a tap on the spin button adds one spin", g.player.spin_level == spin0 + 1, str(g.player.spin_level))
	# Look.
	_touch(_centre(t.button("look_up")), true)
	await _frames(20)
	check("the look button peeks up", g.look < -5.0, str(g.look))
	_touch(_centre(t.button("look_up")), false)
	await _frames(2)

	# Strike: hold the cue button, let go, the ball flies.
	g.player.aim_deg = 0.0
	var strokes := SaveData.strokes
	var strike := t.button("charge")
	_touch(_centre(strike), true, 1)
	await _physics(30)
	check("holding the cue button charges the shot", g.player.charging)
	_touch(_centre(strike), false, 1)
	await _physics(4)
	check("letting go strikes", SaveData.strokes == strokes + 1 and not g.player.sim.resting, str(SaveData.strokes))

	# Two fingers at once: hold aim and strike together.
	await _rest(g, g.tower.spawn)
	_touch(_centre(t.button("aim_left")), true, 0)
	_touch(_centre(strike), true, 1)
	await _physics(3)
	check("two fingers press two buttons", Input.is_action_pressed("aim_left") and Input.is_action_pressed("charge"))
	_touch(_centre(t.button("aim_left")), false, 0)
	_touch(_centre(strike), false, 1)
	await _physics(4)

	# The ball behind a button: the button all but disappears.
	await _rest(g, Vector2(478, -40))
	await _frames(2)
	check("a button fades while the ball is behind it", strike.modulate.a < 0.2 and t.button("aim_left").modulate.a > 0.4, "%s at %s" % [strike.modulate.a, t.ball_at])
	await _rest(g, g.tower.spawn)
	await _frames(2)
	check("and comes back when the ball moves on", strike.modulate.a > 0.4)

	# Pause.
	await _rest(g, g.tower.spawn)
	_touch(_centre(t.button("pause")), true)
	await _frames(2)
	_touch(_centre(t.button("pause")), false)
	await _frames(2)
	check("the pause button opens the pause menu", get_tree().paused and g.pause_menu.visible)
	check("the buttons hide under the pause menu", t.buttons.all(func(b): return not b.visible))
	check("nothing stays held under the menu", not Input.is_action_pressed("pause"))
	g.pause_menu.close()
	await _frames(3)
	check("they come back after", not get_tree().paused and t.buttons.all(func(b): return b.visible))
	g.finished = true
	await _frames(2)
	check("they hide while the ending is up", t.buttons.all(func(b): return not b.visible))
	await _close(g)


func _auto_tests() -> void:
	SaveData.touch_controls = "auto"
	var g := await _load(SaveData.CLASSIC)
	var t: TouchControls = g.touch
	check("auto starts hidden on a computer", not t.active)
	_touch(Vector2(256, 140), true)
	_touch(Vector2(256, 140), false)
	await _frames(2)
	check("a touch brings the buttons up", t.active and t.buttons.all(func(b): return b.visible))
	check("and switches the hint", g._hint.text == g.HINT_TOUCH)
	# Holding a button, then a key: they go away and let go of what was held.
	_touch(_centre(t.button("look_down")), true)
	await _frames(2)
	var key := InputEventKey.new()
	key.keycode = KEY_D
	key.physical_keycode = KEY_D
	key.pressed = true
	get_tree().root.push_input(key, true)
	await _frames(2)
	check("a key press hides them again", not t.active and t.buttons.all(func(b): return not b.visible))
	check("and releases anything they held", not Input.is_action_pressed("look_down"))
	check("the keyboard hint returns", g._hint.text == g.HINT_KEYS)
	key.pressed = false
	get_tree().root.push_input(key, true)
	_touch(_centre(t.button("look_down")), false)
	await _frames(2)
	# Off: a touch does nothing.
	SaveData.touch_controls = "off"
	SaveData.apply_settings()
	_touch(Vector2(256, 140), true)
	_touch(Vector2(256, 140), false)
	await _frames(2)
	check("turned off, a touch doesn't show them", not t.active)
	SaveData.touch_controls = "on"
	SaveData.apply_settings()
	await _frames(1)
	check("turning them on in Options shows them straight away", t.active)
	SaveData.touch_controls = "auto"
	SaveData.apply_settings()
	await _close(g)


func _training_tests() -> void:
	SaveData.touch_controls = "on"
	var g := await _load(SaveData.TRAINING, true)
	check("a fresh climb opens with the goal pop-up", is_instance_valid(g.intro))
	await get_tree().create_timer(0.8, true, false, true).timeout
	_touch(Vector2(256, 140), true)
	_touch(Vector2(256, 140), false)
	await _frames(3)
	check("a tap dismisses the pop-up", not is_instance_valid(g.intro) and not get_tree().paused)
	var t: TouchControls = g.touch
	for a in ["flag_place", "flag_return", "flag_remove"]:
		check("training has a %s button" % a, t.button(a) != null and t.button(a).visible)
	check("the training line points at the flag buttons", g._training_hud.text.contains("plant") and g._training_hud.text.contains("top right"), g._training_hud.text)
	await _rest(g, g.tower.spawn)
	var plant := t.button("flag_place")
	_touch(_centre(plant), true)
	await _frames(2)
	_touch(_centre(plant), false)
	await _frames(2)
	check("the flag button plants a flag", g.flags.size() == 1)
	var spot: Vector2 = g.player.sim.pos
	g.player.place(Vector2(200, -400))
	await _physics(5)
	var back := t.button("flag_return")
	_touch(_centre(back), true)
	await _frames(2)
	_touch(_centre(back), false)
	await _frames(2)
	check("the back button returns to the flag", g.player.sim.pos.distance_to(spot) < 0.5, str(g.player.sim.pos))
	var remove := t.button("flag_remove")
	_touch(_centre(remove), true)
	await _frames(2)
	_touch(_centre(remove), false)
	await _frames(2)
	check("the remove button takes the flag away", g.flags.is_empty())
	SaveData.touch_controls = "auto"
	await _close(g)


func _menu_tests() -> void:
	SaveData.touch_controls = "auto"
	var menu := OptionsMenu.new()
	add_child(menu)
	await _frames(2)
	var btn: Button = null
	for b in menu.find_children("*", "Button", true, false):
		if b.text.begins_with("Touch controls"):
			btn = b
	check("Options has a touch controls setting", btn != null and btn.text == "Touch controls: Auto", btn.text if btn else "")
	btn.pressed.emit()
	check("it turns them on", SaveData.touch_controls == "on" and btn.text == "Touch controls: On")
	btn.pressed.emit()
	check("then off", SaveData.touch_controls == "off" and btn.text == "Touch controls: Off")
	btn.pressed.emit()
	check("then back to auto", SaveData.touch_controls == "auto")
	menu.close()
	await _frames(2)
	SaveData.touch_controls = "on"
	SaveData.save()
	SaveData.touch_controls = "auto"
	SaveData.load_data()
	check("the setting is saved", SaveData.touch_controls == "on")


func _size_tests() -> void:
	# Every size: all twelve buttons (flags included) on screen, none overlapping.
	for s in TouchControls.SIZES:
		var at := TouchControls.layout(s)
		var radius := func(action: String) -> float:
			return ((TouchControls.BIG if action == "charge" else TouchControls.SMALL) / 2.0 + TouchControls.MARGIN) * s
		var inside := true
		var apart := true
		var actions: Array = at.keys()
		for i in actions.size():
			var a: String = actions[i]
			var ca: Vector2 = at[a]
			var ra: float = radius.call(a)
			if ca.x - ra < -0.01 or ca.y - ra < -0.01 or ca.x + ra > 512.01 or ca.y + ra > 288.01:
				inside = false
			for j in range(i + 1, actions.size()):
				var b: String = actions[j]
				if ca.distance_to(at[b]) < ra + radius.call(b) - 0.01:
					apart = false
		check("at %sx every button is on screen" % s, inside)
		check("at %sx no two touch areas overlap" % s, apart)

	# The Options button walks 1x .. 2x and saves.
	SaveData.touch_size = TouchControls.DEFAULT_SIZE
	var menu := OptionsMenu.new()
	add_child(menu)
	await _frames(2)
	var btn: Button = null
	for b in menu.find_children("*", "Button", true, false):
		if b.text.begins_with("Button size"):
			btn = b
	check("Options has a Button size setting at 1.5x", btn != null and btn.text == "Button size: 1.5x", btn.text if btn else "")
	var seen: Array = []
	for i in TouchControls.SIZES.size():
		btn.pressed.emit()
		seen.append(SaveData.touch_size)
	check("it cycles 1.75x, 2x, 1x, 1.25x and back to 1.5x", seen == [1.75, 2.0, 1.0, 1.25, 1.5], str(seen))
	btn.pressed.emit()   # 1.75x
	check("the label shows the size", btn.text == "Button size: 1.75x", btn.text)
	menu.close()
	await _frames(2)
	SaveData.load_data()
	check("the size is saved", is_equal_approx(SaveData.touch_size, 1.75), str(SaveData.touch_size))

	# Live in a climb: the buttons resize at once, and the hints shorten when big.
	SaveData.touch_controls = "on"
	SaveData.touch_size = 1.0
	var g := await _load(SaveData.TRAINING)
	var t: TouchControls = g.touch
	var small_cue: float = t.button("charge").scale.x
	check("1x draws the buttons at their art size", is_equal_approx(small_cue, 1.0))
	check("the full hints show at 1x", g._hint.text == g.HINT_TOUCH and g._training_hud.text.contains("plant"))
	SaveData.touch_size = 2.0
	SaveData.apply_settings()
	await _frames(2)
	check("2x resizes the buttons straight away", is_equal_approx(t.button("charge").scale.x, 2.0) and is_equal_approx(t.button("flag_remove").scale.x, 2.0))
	check("and moves them to the 2x layout", _centre(t.button("charge")).distance_to(TouchControls.layout(2.0)["charge"]) < 0.5)
	check("big buttons get the short hints", g._hint.text == g.HINT_TOUCH_SHORT and g._training_hud.text.contains("top right") and not g._training_hud.text.contains("plant"), g._training_hud.text)
	SaveData.touch_size = TouchControls.DEFAULT_SIZE
	SaveData.touch_controls = "auto"
	SaveData.apply_settings()
	await _close(g)


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
