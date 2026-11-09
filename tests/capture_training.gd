extends Node
## Rendered captures of Training mode: flags planted on the felt, the title menu.
##   godot --path . res://tests/capture_training.tscn -- --save-profile=capture


func _ready() -> void:
	SaveData.all_unlocked = true
	SaveData.set_run(SaveData.TRAINING, 4)
	SaveData.start_new_run()
	var game: Node2D = load("res://scenes/world/game.tscn").instantiate()
	game.show_intro = false
	add_child(game)
	await _physics(10)
	# Two flags on the fire escape: an older one on the floor, the newest on a ledge.
	await _rest(game, game.tower.spawn + Vector2(120, 0))
	game.plant_flag()
	await _rest(game, Vector2(208, -88))
	game.plant_flag()
	await _rest(game, Vector2(172, -88))
	await get_tree().create_timer(1.2).timeout
	_save("training.png")
	# Rooftop with a rightward gust: a flag streaming in the wind.
	game.player.place(Vector2(200, -6 * 288 - 40))
	await _physics(240)
	if game.plant_flag():
		await get_tree().create_timer(1.5).timeout
		_save("training_wind.png")
	game.queue_free()
	await _frames(2)
	SaveData.all_unlocked = false
	SaveData.set_run(SaveData.CLASSIC, 1)
	var title: Control = load("res://scenes/ui/title.tscn").instantiate()
	add_child(title)
	await _frames(20)
	_save("title.png")
	get_tree().quit()


func _rest(game: Node2D, at: Vector2) -> void:
	game.player.place(at)
	for i in 300:
		await get_tree().physics_frame
		if game.player.sim.resting:
			break


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://docs/screenshots/" + name))
	print("captured ", name)
