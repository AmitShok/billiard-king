extends Node
## Reactive decor and the controls hint.
## The key guarantee: props are cosmetic. A ball flying through them follows
## exactly the same path as a ball in a world with no props at all.
##   godot --headless --path . res://tests/props_test.tscn -- --save-profile=props

var passed := 0
var failed := 0
var game: Node2D


func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		passed += 1
		print("  ok   ", name)
	else:
		failed += 1
		print("  FAIL ", name, "  ", detail)


func _ready() -> void:
	SaveData.start_new_run()
	game = load("res://scenes/world/game.tscn").instantiate()
	game.show_intro = false
	add_child(game)
	await _physics(30)
	var decor: Node = game.tower.get_node("Decor")
	var kinds := {}
	for n in decor.get_children():
		if n is Prop:
			kinds[n.get_script().get_global_name()] = kinds.get(n.get_script().get_global_name(), 0) + 1
	check("tower has every prop kind", ["SwingProp", "WindowProp", "NeonProp", "TiltProp", "RattleProp", "BeadsProp", "KnockProp"].all(func(k): return kinds.has(k)), str(kinds))

	print("Props never touch the ball")
	await _trajectory_unchanged(_first(WindowProp), "through a window")
	await _trajectory_unchanged(_first(SwingProp, true), "through a hanging lamp")
	await _trajectory_unchanged(_first(BeadsProp), "through a score wire")

	print("Props react")
	var win: WindowProp = _first(WindowProp)
	win.broken = false
	win.get_node("Glass").frame = 0
	win.poke(win.global_position, Vector2(80, 0))
	check("slow brush doesn't break a window", not win.broken)
	await _physics(40)
	win.poke(win.global_position, Vector2(320, -100))
	check("fast ball smashes a window", win.broken and win.get_node("Glass").frame == 1)
	check("broken window is remembered", SaveData.broken.has(String(win.name)))

	var lamp: SwingProp = _first(SwingProp)
	lamp.poke(lamp.global_position + Vector2(0, lamp.length), Vector2(300, 0))
	await _physics(20)
	check("lamp swings when clipped", absf(lamp.rotation) > 0.05, str(lamp.rotation))
	await _physics(1200)
	check("lamp settles back", absf(lamp.rotation) < 0.03, str(lamp.rotation))

	var neon: NeonProp = _first(NeonProp)
	neon.poke(neon.global_position, Vector2(250, 0))
	check("neon shorts out", neon.get_node("Sign").frame == 1 and not neon.get_node("Glow").visible)

	var tilt: TiltProp = _first(TiltProp)
	tilt.poke(tilt.global_position + tilt.hit_offset, Vector2(260, 0))
	await _physics(10)
	check("hung picture swings", absf(tilt.rotation) > 0.02, str(tilt.rotation))

	var beads: BeadsProp = _first(BeadsProp)
	var before := beads.xs.duplicate()
	beads.poke(beads.global_position + Vector2(beads.xs[0], 0), Vector2(300, 0))
	await _physics(30)
	check("beads slide along the wire", beads.xs != before)
	var ordered := true
	for i in beads.xs.size() - 1:
		if beads.xs[i] > beads.xs[i + 1] + 0.01:
			ordered = false
	check("beads keep their order", ordered, str(beads.xs))

	var chalk: KnockProp = null
	for n in decor.get_children():
		if n is KnockProp and not n.heavy:
			chalk = n
	var y0 := chalk.position.y
	chalk.poke(chalk.global_position, Vector2(200, -50))
	check("chalk is knocked flying", chalk.airborne)
	for i in 600:
		await get_tree().physics_frame
		if not chalk.airborne:
			break
	check("chalk lands somewhere and stops", not chalk.airborne and chalk.visible, "y %.0f -> %.0f" % [y0, chalk.position.y])
	check("landed chalk sits on solid ground", game.tower.world.is_solid_point(chalk.position + Vector2(0, chalk.half_size.y + 1.0)))

	print("Persistence")
	var win_name := String(win.name)
	SaveData.save()
	game.queue_free()
	await _frames(2)
	SaveData.load_data()
	game = load("res://scenes/world/game.tscn").instantiate()
	game.show_intro = false
	add_child(game)
	await _physics(5)
	var again: WindowProp = game.tower.get_node("Decor").get_node(win_name)
	check("window stays broken after reload", again.broken and again.get_node("Glass").frame == 1)
	SaveData.start_new_run()
	game.queue_free()
	await _frames(2)
	game = load("res://scenes/world/game.tscn").instantiate()
	game.show_intro = false
	add_child(game)
	await _physics(5)
	again = game.tower.get_node("Decor").get_node(win_name)
	check("new climb has whole windows", not again.broken)

	print("Controls hint")
	game.player.place(game.tower.spawn)
	await _physics(150)
	check("hint shows on the bottom floor", game._hint.modulate.a > 0.95, str(game._hint.modulate.a))
	game.player.place(Vector2(200, -232))
	await _physics(150)
	check("hint hides once the ball climbs", game._hint.modulate.a < 0.05 and not game.on_bottom_floor(), str(game._hint.modulate.a))
	game.player.place(Vector2(game.tower.spawn.x + 200, -120))
	await _physics(10)
	check("hint stays hidden while falling", game._hint.modulate.a < 0.05)
	await _physics(200)
	check("hint returns after falling back down", game._hint.modulate.a > 0.95 and game.on_bottom_floor())
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = false
	game._input(pad)
	check("hint switches to gamepad prompts", game._hint.text.contains("D-PAD"))
	var key := InputEventKey.new()
	key.physical_keycode = KEY_A
	game._input(key)
	check("and back to keyboard prompts", game._hint.text.contains("SPACE"))

	game.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.path))
	print("%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


## Fires the player's ball through a prop and replays the same flight in a
## bare BallSim (same world, no props): both must match exactly, every tick.
func _trajectory_unchanged(prop: Prop, label: String) -> void:
	var target: Vector2 = prop.global_position + prop.hit_offset
	if prop is SwingProp:
		target = prop.global_position + Vector2(0, prop.length)
	var start := target + Vector2(-36, 4)
	var vel := Vector2(320, -60)
	var p: PlayerBall = game.player
	p.place(start)
	p.input_enabled = false
	p.sim.vel = vel
	var ghost := BallSim.new()
	ghost.reset(start)
	ghost.vel = vel
	var touched := false
	var same := true
	for i in 90:
		await get_tree().physics_frame
		ghost.step(game.tower.world)
		if prop.touches(p.sim.pos, BallSim.RADIUS):
			touched = true
		if p.sim.pos != ghost.pos or p.sim.vel != ghost.vel:
			same = false
	p.input_enabled = true
	check("ball passed through a prop (%s)" % label, touched)
	check("trajectory identical with and without props (%s)" % label, same, "%s vs %s" % [p.sim.pos, ghost.pos])


func _first(kind: Variant, chandelier_ok := true) -> Prop:
	for n in game.tower.get_node("Decor").get_children():
		if is_instance_of(n, kind):
			return n
	return null


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
