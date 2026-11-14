extends Control
## The gold pocket: fade to night, the crown, the final card. A real "Back to
## title" button (focused, so Enter, Space and the pad work) and a tap anywhere
## on a touchscreen both return, once the card has faded in.

signal back_requested

var stats: Dictionary = {}
var _ready_for_input := false
var _back: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.modulate.a = 0.0
	add_child(box)
	var crown := TextureRect.new()
	crown.texture = _crown_frame()
	crown.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	crown.custom_minimum_size = Vector2(0, 20)
	crown.scale = Vector2(2, 2)
	box.add_child(crown)
	UIKit.heading(box, stats.get("title", "The table is yours"), 16)
	UIKit.label(box, "Vertical Billiard", Color("f2d27a"))
	UIKit.label(box, "")
	UIKit.label(box, "Time  %s" % SaveData.format_time(stats.get("time", 0.0)))
	UIKit.label(box, "Strokes  %d     Falls  %d" % [stats.get("strokes", 0), stats.get("falls", 0)])
	var unlocked: Array = stats.get("unlocked", [])
	if not unlocked.is_empty():
		UIKit.label(box, "New balls in the rack: %s" % ", ".join(unlocked.map(func(n): return BallRack.display_name(n))), Color("9fe0a8"))
	if stats.has("note"):
		UIKit.label(box, stats.note, Color("9ff0b4"))
	UIKit.label(box, "")
	# A big, real button: easy to hit with a thumb.
	_back = UIKit.button(box, "Back to title", back)
	_back.custom_minimum_size = Vector2(150, 28)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.disabled = true
	var hint := UIKit.label(box, "or tap anywhere", Color("8a8070"))
	for l in box.get_children():
		if l is Label:
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(dim, "color:a", 0.85, 1.6)
	tw.tween_property(box, "modulate:a", 1.0, 1.0)
	tw.tween_callback(func():
		_ready_for_input = true
		_back.disabled = false
		_back.grab_focus())
	tw.tween_property(hint, "modulate:a", 0.3, 0.8).set_trans(Tween.TRANS_SINE)


## True once the card has faded in and a press will return.
func can_return() -> bool:
	return _ready_for_input


## Returns to the title (once).
func back() -> void:
	if not _ready_for_input:
		return
	_ready_for_input = false
	back_requested.emit()


func _crown_frame() -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = load("res://assets/textures/crown.png")
	a.region = Rect2(0, 0, 20, 16)
	return a


## Taps are caught here, before any UI can swallow them, so a tap anywhere returns.
func _input(event: InputEvent) -> void:
	if not _ready_for_input:
		return
	if event is InputEventScreenTouch and event.pressed:
		get_viewport().set_input_as_handled()
		back()


func _unhandled_input(event: InputEvent) -> void:
	if not _ready_for_input:
		return
	if event.is_action_pressed("charge") or event.is_action_pressed("ui_accept") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		back()
