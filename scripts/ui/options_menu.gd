class_name OptionsMenu
extends Control
## Volume, window and camera settings. Used from the title and pause menus.

signal closed

const CONFIRM_RESET := "Press again to erase everything"

var _first: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := UIKit.panel(self, Vector2(220, 0))
	UIKit.heading(box, "Options")
	var controls: Array = []
	controls.append(UIKit.slider(box, "Master", SaveData.master_volume, func(v): SaveData.master_volume = v; SaveData.apply_settings()))
	controls.append(UIKit.slider(box, "Effects", SaveData.sfx_volume, func(v): SaveData.sfx_volume = v; SaveData.apply_settings()))
	controls.append(UIKit.slider(box, "Music", SaveData.music_volume, func(v): SaveData.music_volume = v; SaveData.apply_settings()))
	controls.append(UIKit.slider(box, "Ambience", SaveData.ambience_volume, func(v): SaveData.ambience_volume = v; SaveData.apply_settings()))
	var full := UIKit.button(box, "", func(): pass)
	full.pressed.connect(func():
		SaveData.fullscreen = not SaveData.fullscreen
		SaveData.apply_settings()
		full.text = _onoff("Fullscreen", SaveData.fullscreen))
	full.text = _onoff("Fullscreen", SaveData.fullscreen)
	controls.append(full)
	var shake := UIKit.button(box, "", func(): pass)
	shake.pressed.connect(func():
		SaveData.screen_shake = not SaveData.screen_shake
		shake.text = _onoff("Screen shake", SaveData.screen_shake))
	shake.text = _onoff("Screen shake", SaveData.screen_shake)
	controls.append(shake)
	var touch := UIKit.button(box, "", func(): pass)
	touch.pressed.connect(func():
		var order := ["auto", "on", "off"]
		SaveData.touch_controls = order[(order.find(SaveData.touch_controls) + 1) % order.size()]
		SaveData.apply_settings()
		touch.text = touch_label())
	touch.text = touch_label()
	controls.append(touch)
	var size := UIKit.button(box, "", func(): pass)
	size.pressed.connect(func():
		var order: Array = TouchControls.SIZES
		var i := order.find(SaveData.touch_size)
		SaveData.touch_size = order[(i + 1) % order.size()] if i >= 0 else TouchControls.DEFAULT_SIZE
		SaveData.apply_settings()
		size.text = size_label())
	size.text = size_label()
	controls.append(size)
	var reset := UIKit.button(box, "Reset all progress", func(): pass)
	reset.pressed.connect(func():
		if reset.text == CONFIRM_RESET:
			_reset_progress()
		else:
			reset.text = CONFIRM_RESET)
	reset.focus_exited.connect(func(): reset.text = "Reset all progress")
	controls.append(reset)
	# Test tool: only in debug builds (running from the editor), never in a release export.
	if OS.is_debug_build():
		var unlock := UIKit.button(box, "Test: unlock everything", func(): pass)
		unlock.pressed.connect(func():
			SaveData.unlock_everything()
			unlock.text = "Everything unlocked")
		controls.append(unlock)
	controls.append(UIKit.button(box, "Back", close))
	UIKit.chain_focus(controls)
	_first = controls[0]
	_first.grab_focus.call_deferred()


## Everything on screen may belong to a run that no longer exists, so start clean.
func _reset_progress() -> void:
	SaveData.reset_progress()
	Sfx.stop_roll()
	Sfx.set_gust(0.0)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")


## Auto shows the on-screen buttons only on touch devices.
static func touch_label() -> String:
	return "Touch controls: %s" % { "on": "On", "off": "Off" }.get(SaveData.touch_controls, "Auto")


## How big the on-screen touch buttons are drawn.
static func size_label() -> String:
	return "Button size: %sx" % String.num(TouchControls.size_scale(), 2)


func _onoff(text: String, on: bool) -> String:
	return "%s: %s" % [text, "On" if on else "Off"]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	SaveData.save()
	Sfx.play("ui_back", -4.0, 1.0, 0.0)
	closed.emit()
	queue_free()
