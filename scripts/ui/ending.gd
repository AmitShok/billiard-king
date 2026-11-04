extends Control
## The gold pocket: fade to night, the crown, the final card.

var stats: Dictionary = {}
var _ready_for_input := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	box.modulate.a = 0.0
	add_child(box)
	var crown := TextureRect.new()
	crown.texture = _crown_frame()
	crown.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	crown.custom_minimum_size = Vector2(0, 20)
	crown.scale = Vector2(2, 2)
	box.add_child(crown)
	UIKit.heading(box, "The table is yours", 16)
	UIKit.label(box, "Vertical Billiard", Color("f2d27a"))
	UIKit.label(box, "")
	UIKit.label(box, "Time  %s" % SaveData.format_time(stats.get("time", 0.0)))
	UIKit.label(box, "Strokes  %d     Falls  %d" % [stats.get("strokes", 0), stats.get("falls", 0)])
	var unlocked: Array = stats.get("unlocked", [])
	if not unlocked.is_empty():
		UIKit.label(box, "New balls in the rack: %s" % ", ".join(unlocked.map(func(n): return BallRack.display_name(n))), Color("9fe0a8"))
	UIKit.label(box, "")
	var hint := UIKit.label(box, "Press to return", Color("8a8070"))
	var tw := create_tween()
	tw.tween_property(dim, "color:a", 0.85, 1.6)
	tw.tween_property(box, "modulate:a", 1.0, 1.0)
	tw.tween_callback(func(): _ready_for_input = true)
	tw.tween_property(hint, "modulate:a", 0.3, 0.8).set_trans(Tween.TRANS_SINE)


func _crown_frame() -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = load("res://assets/textures/crown.png")
	a.region = Rect2(0, 0, 20, 16)
	return a


func _unhandled_input(event: InputEvent) -> void:
	if not _ready_for_input:
		return
	if event.is_action_pressed("charge") or event.is_action_pressed("ui_accept") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_ready_for_input = false
		get_parent().get_parent().quit_to_title()
