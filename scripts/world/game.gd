extends Node2D
## The climb. Fixed one-screen camera that cuts as the ball crosses screen
## edges (Jump King), area title cards, stats, saving where the ball rests,
## and the ending at the gold pocket.

const TOWERS := { 1: "res://scenes/world/tower.tscn", 2: "res://scenes/world/tower2.tscn" }
const PAUSE_MENU := preload("res://scripts/ui/pause_menu.gd")
const ENDING := preload("res://scripts/ui/ending.gd")
const FONT_SIZE_TITLE := 16

## Bonus skins for finished climbs (balls 1-10 are hidden in the tower).
const AWARDS := [
	[11, "Finish the climb"],
	[12, "Finish in under 400 strokes"],
	[13, "Finish in under 30 minutes"],
	[14, "Finish with 10 falls or fewer"],
	[15, "Finish holding lost balls 1-10"],
]

var tower: Tower
var player: PlayerBall
var camera: Camera2D
var hud: CanvasLayer
var pause_menu: Control
var screen := -1
var finished := false
var white: WhiteBall          # Hardcore only
var white_start := Vector2.ZERO
var _arrow: WhiteBallArrow
var intro: GoalIntro          # goal pop-up, while it is open
var show_intro := true        # tests that aren't about the pop-up switch it off

var _title_label: Label
var _toast: Label
var _shake := 0.0
var look := 0.0          # camera peek offset in px (negative = up)

const LOOK_RANGE := 56.0
const LOOK_SPEED := 160.0   # px/s while held
const LOOK_RETURN := 260.0  # px/s easing back when released
var _rng := RandomNumberGenerator.new()
var _props_by_screen := {}   # screen index -> Array of Prop
var _hint: RichTextLabel
var _hint_wait := 0.0
var _using_pad := false

const HINT_KEYS := "[center][color=#f2d27a]A D[/color] aim   [color=#f2d27a]W S[/color] spin   [color=#f2d27a]UP DOWN[/color] look   hold [color=#f2d27a]SPACE[/color] to strike   [color=#f2d27a]ESC[/color] pause[/center]"
const HINT_PAD := "[center][color=#f2d27a]D-PAD[/color] aim and spin   [color=#f2d27a]R-STICK[/color] look   hold [color=#f2d27a]A[/color] to strike   [color=#f2d27a]START[/color] pause[/center]"


func _ready() -> void:
	tower = load(TOWERS.get(SaveData.level, TOWERS[1])).instantiate()
	add_child(tower)
	tower.build_world(SaveData.collected)
	tower.resume_movers(SaveData.world_time)
	_setup_props()

	player = PlayerBall.new()
	player.z_index = 5
	player.world = tower.world
	add_child(player)
	var start: Vector2 = SaveData.ball_pos if SaveData.has_run and SaveData.ball_pos != Vector2.ZERO else tower.spawn
	if not SaveData.has_run:
		SaveData.start_new_run()
	player.place(start)
	player.aim_deg = SaveData.aim_deg
	player.spin_level = SaveData.spin_level

	camera = Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(camera)
	camera.make_current()

	_build_hud()
	player.shot_taken.connect(_on_shot)
	player.fell.connect(_on_fell)
	player.landed.connect(_on_landed)
	player.wall_hit.connect(_on_wall_hit)
	player.bumped.connect(_on_bumped)
	player.settled.connect(_on_settled)
	player.won.connect(_on_won)
	player.lost_ball_found.connect(_on_lost_ball)
	player.trapped.connect(_on_trapped)
	if hardcore():
		_setup_white()
	# A fresh climb (nothing struck yet) states the goal first.
	if show_intro and SaveData.strokes == 0 and SaveData.run_time < 1.0:
		var warning := "\nRed traps fling you. Brass carriages carry you." if SaveData.level > 1 else ""
		if hardcore():
			intro = GoalIntro.new().setup("Hardcore", "Push the white ball up the tower\ninto the gold pocket at the top." + warning, 16)
		else:
			intro = GoalIntro.new().setup("The climb", "Reach the gold pocket\nat the top of the tower." + warning, SaveData.skin)
		hud.add_child(intro)
	_update_screen(true)


func _build_hud() -> void:
	var mood := CanvasLayer.new()
	mood.layer = 1
	add_child(mood)
	var vignette := ColorRect.new()
	vignette.size = Vector2(512, 288)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = preload("res://shaders/vignette.gdshader")
	vignette.material = vm
	mood.add_child(vignette)
	hud = CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	_title_label = Label.new()
	_title_label.theme = UIKit.theme()
	_title_label.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.position = Vector2(0, 56)
	_title_label.size = Vector2(512, 24)
	_title_label.modulate.a = 0.0
	hud.add_child(_title_label)
	_toast = Label.new()
	_toast.theme = UIKit.theme()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.position = Vector2(0, 12)
	_toast.size = Vector2(512, 12)
	_toast.modulate = Color(1.0, 0.86, 0.45, 0.0)
	hud.add_child(_toast)
	# Controls hint: engraved on the rail of the bottom table, only while the ball sits there.
	_hint = RichTextLabel.new()
	_hint.theme = UIKit.theme()
	_hint.bbcode_enabled = true
	_hint.scroll_active = false
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.position = Vector2(0, 277)
	_hint.size = Vector2(512, 10)
	_hint.add_theme_color_override("default_color", Color("d8d0bc"))
	_hint.add_theme_color_override("font_shadow_color", Color("0a0604"))
	_hint.add_theme_constant_override("shadow_offset_x", 1)
	_hint.add_theme_constant_override("shadow_offset_y", 1)
	_hint.text = HINT_KEYS
	_hint.modulate.a = 0.0
	hud.add_child(_hint)
	pause_menu = PAUSE_MENU.new()
	pause_menu.game = self
	hud.add_child(pause_menu)


func _process(delta: float) -> void:
	if not finished:
		SaveData.run_time += delta
	_update_screen(false)
	_update_hint(delta)
	_update_look(delta)
	_update_arrow()
	var shake := Vector2.ZERO
	if _shake > 0.0 and SaveData.screen_shake:
		_shake = maxf(0.0, _shake - delta * 8.0)
		shake = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).round() * minf(_shake, 2.0)
	camera.offset = Vector2(0, round(look)) + shake


## Peeking a little above or below the current screen. View only: the screen
## cut, the ball and its physics are untouched.
func _update_look(delta: float) -> void:
	var dir := 0.0
	if not finished and not get_tree().paused:
		dir = Input.get_action_strength("look_down") - Input.get_action_strength("look_up")
	# Nothing is drawn below the bottom floor or above the summit.
	if screen <= 0:
		dir = minf(dir, 0.0)
	if screen >= tower.screen_count() - 1:
		dir = maxf(dir, 0.0)
	var target := dir * LOOK_RANGE
	look = move_toward(look, target, delta * (LOOK_SPEED if absf(target) > absf(look) else LOOK_RETURN))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not finished and not is_instance_valid(intro):
		pause_menu.open()
		get_viewport().set_input_as_handled()


func _update_screen(force: bool) -> void:
	var k := Tower.screen_of(player.sim.pos.y)
	if k == screen and not force:
		return
	var old_zone := tower.zone_of_screen(screen) if screen >= 0 else -1
	screen = k
	camera.position = Tower.screen_center(clampi(k, 0, tower.screen_count() - 1))
	camera.reset_physics_interpolation()
	camera.force_update_scroll()
	var zone := tower.zone_of_screen(k)
	Sfx.set_ambience(zone)
	Sfx.set_music_zone(zone)
	if k > SaveData.best_screen:
		SaveData.best_screen = k
	if zone != old_zone and not SaveData.seen_zones.has(zone):
		SaveData.seen_zones.append(zone)
		show_area_title(tower.zone_names[zone])


func show_area_title(text: String) -> void:
	_title_label.text = text
	var tw := create_tween()
	tw.tween_property(_title_label, "modulate:a", 1.0, 0.8)
	tw.tween_interval(2.2)
	tw.tween_property(_title_label, "modulate:a", 0.0, 1.2)


func toast(text: String) -> void:
	_toast.text = text
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.5)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)


func _add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _on_shot() -> void:
	SaveData.strokes += 1


func _on_fell(_drop: float) -> void:
	SaveData.falls += 1
	rumble(player.sim.pos, 1.0)
	_add_shake(2.0)


func _on_bumped(id: int) -> void:
	var b := tower.object_by_id(id)
	if b is Bumper:
		b.hit(player.sim.vel.normalized())
		rumble(b.position, 0.6)
	_add_shake(1.0)


func _on_settled() -> void:
	save_progress()


func save_progress() -> void:
	if finished:
		return
	if player.sim.resting:
		SaveData.ball_pos = player.sim.pos
	if white and white.sim.resting and not white.sim.in_pocket:
		SaveData.white_pos = white.sim.pos
	SaveData.aim_deg = player.aim_deg
	SaveData.spin_level = player.spin_level
	SaveData.world_time = tower.world.time
	SaveData.save()


func _on_lost_ball(number: int) -> void:
	var node := tower.lost_ball_node(number)
	if node:
		node.collect()
	SaveData.collect_ball(number)
	toast("%s found - see the Ball Rack" % BallRack.display_name(number))


func _on_won() -> void:
	finished = true
	player.input_enabled = false
	Sfx.stop_roll()
	var unlocked: Array[int] = []
	if hardcore():
		# Hardcore's prize is the white ball itself, for the Ball Rack.
		if not SaveData.collected.has(16):
			SaveData.collected.append(16)
			unlocked.append(16)
		# And level 2 on Hardcore earns the rainbow ball.
		if SaveData.level == 2 and not SaveData.collected.has(BallVisual.RAINBOW):
			SaveData.collected.append(BallVisual.RAINBOW)
			unlocked.append(BallVisual.RAINBOW)
	var all_found := true
	for n in range(1, 11):
		if not SaveData.collected.has(n):
			all_found = false
	var checks := [true, SaveData.strokes < 400, SaveData.run_time < 1800.0, SaveData.falls <= 10, all_found]
	for i in (0 if hardcore() or SaveData.level > 1 else AWARDS.size()):
		var n: int = AWARDS[i][0]
		if checks[i] and not SaveData.collected.has(n):
			SaveData.collected.append(n)
			unlocked.append(n)
	var stats := { "time": SaveData.run_time, "strokes": SaveData.strokes, "falls": SaveData.falls, "unlocked": unlocked }
	SaveData.finish_run()
	Sfx.set_music_zone(-1)
	Sfx.play("win", 0.0, 1.0, 0.0)
	var ending: Control = ENDING.new()
	ending.stats = stats
	hud.add_child(ending)


func quit_to_title() -> void:
	save_progress()
	Sfx.stop_roll()
	Sfx.set_ambience(-1)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")


# --- Controls hint ------------------------------------------------------------------

## True while the ball sits on the very bottom floor of the tower.
func on_bottom_floor() -> bool:
	return player.sim.grounded and player.sim.pos.y > -2.0 * CollisionWorld.TILE - 1.0


func _update_hint(delta: float) -> void:
	var show := on_bottom_floor() and not finished
	if show:
		_hint_wait += delta
	else:
		_hint_wait = 0.0
	var target := 1.0 if show and _hint_wait > 0.35 else 0.0
	_hint.modulate.a = move_toward(_hint.modulate.a, target, delta * (2.5 if target > 0.0 else 6.0))


func _input(event: InputEvent) -> void:
	var pad := _using_pad
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false
	if pad != _using_pad:
		_using_pad = pad
		_hint.text = HINT_PAD if pad else HINT_KEYS


# --- Reactive decor -----------------------------------------------------------------
# Props only read the ball's position and velocity. They are never part of the
# CollisionWorld, so swinging lamps or smashed windows can't change a shot.

func _setup_props() -> void:
	for node in tower.get_node("Decor").get_children():
		if node is Prop:
			node.world = tower.world
			var k := Tower.screen_of(node.global_position.y)
			if not _props_by_screen.has(k):
				_props_by_screen[k] = []
			_props_by_screen[k].append(node)
			if node is WindowProp and SaveData.broken.has(String(node.name)):
				node.smash(Vector2.ZERO, true)


func _props_near_screen() -> Array:
	var out: Array = []
	for k in [screen - 1, screen, screen + 1]:
		out.append_array(_props_by_screen.get(k, []))
	return out


func _physics_process(_delta: float) -> void:
	if player == null or finished:
		return
	var p := player.sim.pos
	for prop in _props_near_screen():
		if prop.visible and prop.touches(p, BallSim.RADIUS):
			prop.poke(p, player.sim.vel)
		# The white ball disturbs decor too (on any screen).
		if white and not white.sim.in_pocket and prop.visible and prop.touches(white.sim.pos, BallSim.RADIUS):
			prop.poke(white.sim.pos, white.sim.vel)


## Heavy impacts nudge nearby props (lamps sway, beads jiggle, chalk hops).
func rumble(at: Vector2, strength: float) -> void:
	for prop in _props_near_screen():
		var d: float = prop.global_position.distance_to(at)
		if d < 170.0:
			prop.rumble(at, clampf(strength * (1.0 - d / 170.0), 0.0, 1.0))


func _on_landed(impact: float) -> void:
	if impact > 300.0:
		_add_shake(1.5)
	if impact > 180.0:
		rumble(player.sim.pos, impact / 600.0)


func _on_wall_hit(impact: float) -> void:
	if impact > 380.0:
		_add_shake(1.0)
	if impact > 220.0:
		rumble(player.sim.pos, impact / 800.0)


# --- Hardcore: the floating white ball ---------------------------------------------

func hardcore() -> bool:
	return SaveData.mode == SaveData.HARDCORE


func _setup_white() -> void:
	# Floating just above your ball at the start: a soft straight-up shot knocks it.
	white_start = tower.spawn + Vector2(0, -28)
	white = WhiteBall.new()
	white.z_index = 4
	add_child(white)
	white.place(SaveData.white_pos if SaveData.white_pos != Vector2.ZERO else white_start)
	player.partner = white.sim
	player.sim.ignore_goal = true
	player.partner_event.connect(_on_partner_event)
	player.ball_hit.connect(func(impact: float):
		white.knock(impact)
		if impact > 300.0:
			_add_shake(1.0))
	_arrow = WhiteBallArrow.new()
	hud.add_child(_arrow)
	hud.move_child(_arrow, 0)


func _update_arrow() -> void:
	if _arrow == null:
		return
	if white.sim.in_pocket:
		_arrow.screens_away = 0
		return
	_arrow.screens_away = Tower.screen_of(white.sim.pos.y) - screen
	_arrow.target_x = white.sim.pos.x


func _on_partner_event(e: Dictionary) -> void:
	match e.type:
		BallSim.Event.WALL:
			Sfx.impact("rail", e.impact)
		BallSim.Event.CUSHION:
			Sfx.impact("cushion", e.impact)
		BallSim.Event.BUMPER:
			Sfx.play("clack", -2.0)
			Sfx.play("bumper", -6.0)
			var b := tower.object_by_id(e.id)
			if b is Bumper:
				b.hit(white.sim.vel.normalized())
			rumble(white.sim.pos, 0.6)
		BallSim.Event.POCKET:
			# The white ball drops down the ball return: a fall for the run.
			white.sink(e.pos)
			Sfx.play("pocket", 0.0)
			SaveData.falls += 1
			toast("The white ball dropped down the ball return")
			var exit: Vector2 = e.exit
			get_tree().create_timer(0.9, false).timeout.connect(func():
				white.sim.release_from_pocket(exit)
				white.place(exit)
				save_progress())
		BallSim.Event.GOAL:
			white.sink(e.pos)
			Sfx.play("pocket", 0.0, 0.9)
			_on_won()
		BallSim.Event.LOST_BALL:
			Sfx.play("lost_ball", -2.0)
			_on_lost_ball(e.number)
		BallSim.Event.TRAP:
			Sfx.play("trap_hit", -3.0)
			white.knock(500.0)
			_flash_trap(e.id)


## Pause-menu escape hatch: put the white ball back by the start (counts as a fall).
func rerack_white() -> void:
	if white == null:
		return
	white.place(white_start)
	SaveData.falls += 1
	SaveData.white_pos = white_start
	SaveData.save()


## Abandon this mode's run and start it again from the bottom.
func restart_climb() -> void:
	SaveData.start_new_run()
	get_tree().paused = false
	Sfx.stop_roll()
	get_tree().reload_current_scene()


# --- Traps ----------------------------------------------------------------------------

func _on_trapped(e: Dictionary) -> void:
	_flash_trap(e.id)
	_add_shake(2.0)
	rumble(player.sim.pos, 0.5)


func _flash_trap(id: int) -> void:
	if id < tower.trap_nodes.size():
		tower.trap_nodes[id].hit()
