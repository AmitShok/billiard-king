extends Node
## Rendered captures for review and the README (not shipped gameplay).
## Saves every tower screen with the ball placed on it, plus the title.
##   godot --path . res://tests/capture.tscn -- --save-profile=capture

const OUT := "res://docs/screenshots/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	SaveData.start_new_run()
	SaveData.seen_zones.assign([0, 1, 2, 3])
	var game: Node2D = load("res://scenes/world/game.tscn").instantiate()
	add_child(game)
	await _frames(10)
	var tower: Tower = game.tower
	var spots := _ledge_spots(tower)
	for k in tower.screen_count():
		var spot: Vector2 = spots.get(k, Tower.screen_center(k))
		game.player.place(spot)
		game.player.aim_deg = -25.0 if spot.x > 256 else 25.0
		await _frames(8)
		_save("screen_%d.png" % k)
	# A real shot through input: charging, flight, landing.
	game.player.place(Vector2(200, -232))
	game.player.aim_deg = 35.0
	game.player.spin_level = 1
	await _physics(30)
	Input.action_press("charge")
	await _physics(50)
	_save("shot_charge.png")
	Input.action_release("charge")
	await _physics(14)
	_save("shot_flight.png")
	await _physics(30)
	_save("shot_flight2.png")
	await _physics(240)
	game.pause_menu.open()
	await _frames(4)
	_save("pause.png")
	game.pause_menu.close()
	game.queue_free()
	await _frames(2)
	var title: Control = load("res://scenes/ui/title.tscn").instantiate()
	add_child(title)
	await _frames(30)
	_save("title.png")
	for n in [1, 3, 4, 8, 9, 11]:
		SaveData.collected.append(n)
	title._open(BallRack)
	await _frames(20)
	_save("ball_rack.png")
	SaveData.collected.clear()
	get_tree().quit()


## One resting spot per screen: the first open tile above solid ground.
func _ledge_spots(tower: Tower) -> Dictionary:
	var out := {}
	var w := tower.world
	for k in tower.screen_count():
		var top := -(k + 1) * 18
		for row in range(top + 17, top, -1):
			for col in [8, 22, 14, 4, 27]:
				var below := Vector2i(col, row + 1)
				if w.shape_at(Vector2i(col, row)) == CollisionWorld.Shape.NONE and w.shape_at(below) == CollisionWorld.Shape.SOLID:
					out[k] = Vector2(col * 16 + 8, (row + 1) * 16 - 7)
					break
			if out.has(k):
				break
	return out


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + name))
	print("captured ", name)
