extends Node
## Rendered captures of levels 3 and 4: every screen, with props and weather live.
##   godot --path . res://tests/capture_new_levels.tscn -- --save-profile=capture


func _ready() -> void:
	for level in [3, 4]:
		SaveData.set_run(SaveData.CLASSIC, level)
		SaveData.start_new_run()
		SaveData.seen_zones.assign([0, 1, 2, 3, 4, 5, 6])
		var game: Node2D = load("res://scenes/world/game.tscn").instantiate()
		game.show_intro = false
		add_child(game)
		await _physics(10)
		var tower: Tower = game.tower
		for k in tower.screen_count():
			game.player.place(_entry(tower, k))
			game.player.aim_deg = 25.0
			# Long enough for a gust to build, so the wind shows.
			await _physics(300)
			_save("l%d_screen_%d.png" % [level, k])
		game.queue_free()
		await _frames(2)
	SaveData.set_run(SaveData.CLASSIC, 1)
	SaveData.collected.assign(range(1, 32))
	var title: Control = load("res://scenes/ui/title.tscn").instantiate()
	add_child(title)
	await _frames(10)
	title._open_levels(SaveData.CLASSIC)
	await _frames(20)
	_save("level_select.png")
	get_tree().quit()


func _entry(tower: Tower, k: int) -> Vector2:
	var top := -(k + 1) * 18
	var w := tower.world
	for row in range(top + 17, top, -1):
		for col in range(1, 31):
			if w.shape_at(Vector2i(col, row)) == CollisionWorld.Shape.SOLID and w.shape_at(Vector2i(col, row - 1)) == CollisionWorld.Shape.NONE and w.shape_at(Vector2i(col + 1, row)) == CollisionWorld.Shape.SOLID:
				return Vector2((col + 1) * 16.0, row * 16.0 - 8.0)
	return Tower.screen_center(k)


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
