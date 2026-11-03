class_name OptionsMenu
extends Control
## Volume, window and camera settings. Used from the title and pause menus.

signal closed

var _first: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := UIKit.panel(self, Vector2(200, 0))
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
	controls.append(UIKit.button(box, "Back", close))
	UIKit.chain_focus(controls)
	_first = controls[0]
	_first.grab_focus.call_deferred()


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
