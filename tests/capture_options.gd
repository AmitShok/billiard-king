extends Node
## Rendered capture of the Options menu.
##   godot --path . res://tests/capture_options.tscn -- --save-profile=capture


func _ready() -> void:
	var title: Control = load("res://scenes/ui/title.tscn").instantiate()
	add_child(title)
	await _frames(10)
	title._open(OptionsMenu)
	await _frames(20)
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://docs/screenshots/options.png"))
	print("captured options.png")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
