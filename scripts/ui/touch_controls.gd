class_name TouchControls
extends CanvasLayer
## On-screen buttons for phones and tablets. Each one presses the same input
## action as its key, so the game reads a tap exactly like a key press.
## They only appear on a touch device (or when turned on in Options). In Auto
## mode a key or pad press hides them again and a touch brings them back, so
## they never sit over the game for someone playing with a keyboard.

signal active_changed(on: bool)

const SHEET := preload("res://assets/textures/touch_buttons.png")
const STRIKE := preload("res://assets/textures/touch_strike.png")
const IDLE_ALPHA := 0.5
const HELD_ALPHA := 0.95
const UNDER_ALPHA := 0.15   # while the ball is behind a button, so it never hides it
const SMALL := 28   # art size of the small buttons (touch_buttons.png cells)
const BIG := 44     # art size of the cue button (touch_strike.png frames)
## Buttons are drawn and touched at this multiple of their art, so they're
## comfortable under a thumb: 42 px small, 66 px cue, in the 512x288 view.
const SCALE := 1.5
## Sheet column, action and centre (in the 512x288 view) of each button.
const PLAY_BUTTONS := [
	{ "col": 0, "action": "aim_left", "at": Vector2(26, 262), "slide": true },
	{ "col": 1, "action": "aim_right", "at": Vector2(78, 262), "slide": true },
	{ "col": 2, "action": "spin_up", "at": Vector2(26, 210) },
	{ "col": 3, "action": "spin_down", "at": Vector2(78, 210) },
	{ "col": 4, "action": "look_up", "at": Vector2(410, 210), "slide": true },
	{ "col": 5, "action": "look_down", "at": Vector2(410, 262), "slide": true },
	{ "col": 6, "action": "pause", "at": Vector2(488, 24) },
]
const FLAG_BUTTONS := [
	{ "col": 7, "action": "flag_place", "at": Vector2(436, 24) },
	{ "col": 8, "action": "flag_return", "at": Vector2(384, 24) },
	{ "col": 9, "action": "flag_remove", "at": Vector2(332, 24) },
]
const STRIKE_AT := Vector2(477, 253)

## Training adds the three flag buttons.
var training := false
## Set by the game while nothing should be pressed (the ending is up).
var suspended := false
## Where the ball is on screen (view coordinates); set by the game each frame.
var ball_at := Vector2(-1000, -1000)
var active := false
var buttons: Array[TouchScreenButton] = []
var _turn: Label


## True on phones, tablets and touchscreen computers.
static func touch_device() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") \
		or OS.has_feature("web_android") or OS.has_feature("web_ios")


## Whether the buttons should show when a climb starts.
static func wanted() -> bool:
	match SaveData.touch_controls:
		"on":
			return true
		"off":
			return false
	return touch_device()


func _ready() -> void:
	layer = 4   # under the HUD layer, so the pause menu and intro cover them
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in PLAY_BUTTONS:
		_add(b)
	if training:
		for b in FLAG_BUTTONS:
			_add(b)
	_add_strike()
	_turn = Label.new()
	_turn.theme = UIKit.theme()
	_turn.text = "Turn your device sideways"
	_turn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn.position = Vector2(0, 120)
	_turn.size = Vector2(512, 12)
	_turn.add_theme_color_override("font_color", Color("f2d27a"))
	_turn.add_theme_color_override("font_shadow_color", Color("0a0604"))
	_turn.add_theme_constant_override("shadow_offset_x", 1)
	_turn.add_theme_constant_override("shadow_offset_y", 1)
	_turn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn.visible = false
	add_child(_turn)
	SaveData.settings_changed.connect(_on_settings)
	set_active(wanted())


func _region(col: int, row: int, size: int, tex: Texture2D) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(col * size, row * size, size, size)
	return a


func _make(action: String, normal: Texture2D, pressed: Texture2D, size: int, at: Vector2, slide: bool) -> TouchScreenButton:
	var b := TouchScreenButton.new()
	b.name = "Touch_" + action
	b.action = action
	b.texture_normal = normal
	b.texture_pressed = pressed
	# A touch area a little larger than the drawing, so thumbs don't miss.
	var shape := CircleShape2D.new()
	shape.radius = size / 2.0 + 3.0
	b.shape = shape
	b.shape_centered = true
	b.passby_press = slide
	b.scale = Vector2(SCALE, SCALE)   # scales the drawing and the touch area together
	b.position = at - Vector2(size, size) * SCALE / 2.0
	b.modulate.a = IDLE_ALPHA
	# Buttons stop with the game: nothing is pressed under a menu.
	b.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(b)
	buttons.append(b)
	return b


func _add(info: Dictionary) -> void:
	var col: int = info.col
	_make(info.action, _region(col, 0, SMALL, SHEET), _region(col, 1, SMALL, SHEET), SMALL, info.at, info.get("slide", false))


func _add_strike() -> void:
	_make("charge", _region(0, 0, BIG, STRIKE), _region(1, 0, BIG, STRIKE), BIG, STRIKE_AT, false)


func button(action: String) -> TouchScreenButton:
	for b in buttons:
		if b.action == action:
			return b
	return null


func set_active(on: bool) -> void:
	if on == active and buttons.size() > 0 and buttons[0].visible == on:
		return
	active = on
	if not on:
		_release_all()
	_refresh()
	active_changed.emit(on)


## True when the ball is behind (or right beside) this button.
func covers_ball(b: TouchScreenButton) -> bool:
	var size := b.texture_normal.get_size() * b.scale
	return ball_at.distance_to(b.position + size / 2.0) < size.x / 2.0 + 10.0


func _release_all() -> void:
	for b in buttons:
		if Input.is_action_pressed(b.action):
			Input.action_release(b.action)


func _on_settings() -> void:
	set_active(wanted() if SaveData.touch_controls != "auto" else (active or touch_device()))


func _input(event: InputEvent) -> void:
	if SaveData.touch_controls != "auto":
		return
	if event is InputEventScreenTouch and event.pressed and not active:
		set_active(true)
	elif active and ((event is InputEventKey and event.pressed and not event.echo) or event is InputEventJoypadButton):
		set_active(false)


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	var show := active and not suspended and not get_tree().paused
	for b in buttons:
		if b.visible != show:
			b.visible = show
		b.modulate.a = HELD_ALPHA if b.is_pressed() else (UNDER_ALPHA if covers_ball(b) else IDLE_ALPHA)
	if _turn:
		var win := DisplayServer.window_get_size()
		_turn.visible = active and win.y > win.x
