class_name UIKit
extends RefCounted
## Small builders shared by every menu so they look and sound the same.


## The UI theme. Assigned to each top-level UI root (not set as the project
## theme, so a fresh import never loads it before its textures exist).
static func theme() -> Theme:
	return load("res://resources/ui_theme.tres")


static func panel(parent: Node, min_size := Vector2(180, 0)) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	center.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	p.add_child(box)
	return box


static func heading(parent: Node, text: String, size := 16) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("f2d27a"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


static func label(parent: Node, text: String, color := Color("d8d0bc")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


static func button(parent: Node, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	wire_button(b, on_press)
	parent.add_child(b)
	return b


## Gives a button (made in code or placed in a scene) the shared menu
## behaviour: hover focuses it, focus and press make their sounds.
static func wire_button(b: Button, on_press: Callable) -> void:
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(b.grab_focus)
	b.focus_entered.connect(func(): Sfx.play("ui_move", -6.0, 1.0, 0.0))
	b.pressed.connect(func():
		Sfx.play("ui_accept", -4.0, 1.0, 0.0)
		on_press.call())


static func slider(parent: Node, text: String, value: float, on_change: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(64, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.1
	s.value = value
	s.custom_minimum_size = Vector2(90, 10)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	s.mouse_entered.connect(s.grab_focus)
	s.focus_entered.connect(func(): Sfx.play("ui_move", -6.0, 1.0, 0.0))
	s.value_changed.connect(func(v: float):
		on_change.call(v)
		Sfx.play("aim_tick", -8.0, 0.8 + v * 0.4, 0.0))
	row.add_child(s)
	return s


## Wires up/down focus in order and wraps around.
static func chain_focus(controls: Array) -> void:
	for i in controls.size():
		var c: Control = controls[i]
		var prev: Control = controls[(i - 1 + controls.size()) % controls.size()]
		var next: Control = controls[(i + 1) % controls.size()]
		c.focus_neighbor_top = c.get_path_to(prev)
		c.focus_neighbor_bottom = c.get_path_to(next)
