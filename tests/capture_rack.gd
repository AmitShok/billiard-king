extends Node
## Rendered capture of the full Ball Rack and the locked level select.
##   godot --path . res://tests/capture_rack.tscn -- --save-profile=capture


func _ready() -> void:
	SaveData.collected.assign(range(1, 28))
	SaveData.skin = 27
	var title: Control = load("res://scenes/ui/title.tscn").instantiate()
	add_child(title)
	await _frames(10)
	title._open(BallRack)
	await _frames(30)
	_save("ball_rack.png")
	var rack: BallRack = title.find_children("*", "BallRack", true, false)[0]
	rack.close()
	await _frames(3)
	SaveData.wins = 0
	SaveData.hc_wins = 0
	title._open_levels(SaveData.CLASSIC)
	await _frames(20)
	_save("level_select_locked.png")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://docs/screenshots/" + name))
	print("captured ", name)
