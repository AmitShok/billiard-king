extends Node2D
## The climb. Fixed one-screen camera that cuts as the ball crosses screen
## edges (Jump King), area title cards, stats, saving where the ball rests,
## and the ending at the gold pocket.

const TOWER := preload("res://scenes/world/tower.tscn")
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

var _title_label: Label
var _toast: Label
var _shake := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	tower = TOWER.instantiate()
	add_child(tower)
	tower.build_world(SaveData.collected)

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
	player.landed.connect(func(impact: float): if impact > 300.0: _add_shake(1.5))
	player.wall_hit.connect(func(impact: float): if impact > 380.0: _add_shake(1.0))
	player.bumped.connect(_on_bumped)
	player.settled.connect(_on_settled)
	player.won.connect(_on_won)
	player.lost_ball_found.connect(_on_lost_ball)
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
	pause_menu = PAUSE_MENU.new()
	pause_menu.game = self
	hud.add_child(pause_menu)


func _process(delta: float) -> void:
	if not finished:
		SaveData.run_time += delta
	_update_screen(false)
	if _shake > 0.0 and SaveData.screen_shake:
		_shake = maxf(0.0, _shake - delta * 8.0)
		camera.offset = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).round() * minf(_shake, 2.0)
	else:
		camera.offset = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not finished:
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
	if k > SaveData.best_screen:
		SaveData.best_screen = k
	if zone != old_zone and not SaveData.seen_zones.has(zone):
		SaveData.seen_zones.append(zone)
		show_area_title(Tower.ZONE_NAMES[zone])


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
	_add_shake(2.0)


func _on_bumped(id: int) -> void:
	var b := tower.object_by_id(id)
	if b is Bumper:
		b.hit(player.sim.vel.normalized())
	_add_shake(1.0)


func _on_settled() -> void:
	save_progress()


func save_progress() -> void:
	if finished:
		return
	if player.sim.resting:
		SaveData.ball_pos = player.sim.pos
	SaveData.aim_deg = player.aim_deg
	SaveData.spin_level = player.spin_level
	SaveData.save()


func _on_lost_ball(number: int) -> void:
	var node := tower.lost_ball_node(number)
	if node:
		node.collect()
	SaveData.collect_ball(number)
	toast("Lost ball #%d found - see the Ball Rack" % number)


func _on_won() -> void:
	finished = true
	player.input_enabled = false
	Sfx.stop_roll()
	var unlocked: Array[int] = []
	var all_found := true
	for n in range(1, 11):
		if not SaveData.collected.has(n):
			all_found = false
	var checks := [true, SaveData.strokes < 400, SaveData.run_time < 1800.0, SaveData.falls <= 10, all_found]
	for i in AWARDS.size():
		var n: int = AWARDS[i][0]
		if checks[i] and not SaveData.collected.has(n):
			SaveData.collected.append(n)
			unlocked.append(n)
	var stats := { "time": SaveData.run_time, "strokes": SaveData.strokes, "falls": SaveData.falls, "unlocked": unlocked }
	SaveData.finish_run()
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
