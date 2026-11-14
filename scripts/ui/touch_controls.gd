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
const MARGIN := 3.0 # touch area beyond the drawing, in art pixels, so thumbs don't miss
const EDGE := 1.0   # gap to the screen edge (view pixels)
const GAP := 1.0    # gap between neighbouring touch areas (view pixels)
## Button size setting (Options > Button size): multiples of the art, 1x to 2x.
## 1.5x (42 px buttons, 66 px cue in the 512x288 view) is the default.
const SIZES := [1.0, 1.25, 1.5, 1.75, 2.0]
const DEFAULT_SIZE := 1.5
## Above this size the hints shorten so they never sit under a button.
const ROOMY_SIZE := 1.5
## Sheet column of each small button, and the ones a sliding thumb can press.
const COLUMNS := { "aim_left": 0, "aim_right": 1, "spin_up": 2, "spin_down": 3, "look_up": 4, "look_down": 5, "pause": 6 }
const FLAG_COLUMNS := { "flag_place": 7, "flag_return": 8, "flag_remove": 9 }
const SLIDE := ["aim_left", "aim_right", "look_up", "look_down"]

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


## The chosen button size as a multiple of the art.
static func size_scale() -> float:
	return clampf(SaveData.touch_size, SIZES[0], SIZES[-1])


## Centre of every button in the 512x288 view at size multiple s. Each group
## hugs its corner, and neighbours sit exactly a touch area apart, so nothing
## overlaps or leaves the screen at any size.
static func layout(s: float) -> Dictionary:
	var rs := (SMALL / 2.0 + MARGIN) * s   # touch radius of a small button
	var rb := (BIG / 2.0 + MARGIN) * s     # touch radius of the cue button
	var step := 2.0 * rs + GAP
	var low := 288.0 - EDGE - rs
	var at := {}
	at["aim_left"] = Vector2(EDGE + rs, low)
	at["aim_right"] = Vector2(EDGE + rs + step, low)
	at["spin_up"] = Vector2(EDGE + rs, low - step)
	at["spin_down"] = Vector2(EDGE + rs + step, low - step)
	at["charge"] = Vector2(512.0 - EDGE - rb, 288.0 - EDGE - rb)
	var look_x: float = at["charge"].x - rb - GAP - rs
	at["look_down"] = Vector2(look_x, low)
	at["look_up"] = Vector2(look_x, low - step)
	at["pause"] = Vector2(512.0 - EDGE - rs, EDGE + rs)
	at["flag_place"] = at["pause"] - Vector2(step, 0)
	at["flag_return"] = at["pause"] - Vector2(2.0 * step, 0)
	at["flag_remove"] = at["pause"] - Vector2(3.0 * step, 0)
	return at


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
	for action in COLUMNS:
		_add(action, COLUMNS[action])
	if training:
		for action in FLAG_COLUMNS:
			_add(action, FLAG_COLUMNS[action])
	_make("charge", _region(0, 0, BIG, STRIKE), _region(1, 0, BIG, STRIKE), BIG, false)
	apply_size()
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


func _make(action: String, normal: Texture2D, pressed: Texture2D, size: int, slide: bool) -> TouchScreenButton:
	var b := TouchScreenButton.new()
	b.name = "Touch_" + action
	b.action = action
	b.texture_normal = normal
	b.texture_pressed = pressed
	# A touch area a little larger than the drawing, so thumbs don't miss.
	var shape := CircleShape2D.new()
	shape.radius = size / 2.0 + MARGIN
	b.shape = shape
	b.shape_centered = true
	b.passby_press = slide
	b.modulate.a = IDLE_ALPHA
	# Buttons stop with the game: nothing is pressed under a menu.
	b.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(b)
	buttons.append(b)
	return b


func _add(action: String, col: int) -> void:
	_make(action, _region(col, 0, SMALL, SHEET), _region(col, 1, SMALL, SHEET), SMALL, SLIDE.has(action))


## Sizes and places every button for the current Button size setting.
func apply_size() -> void:
	var s := size_scale()
	var at := layout(s)
	for b in buttons:
		var art := b.texture_normal.get_size()
		b.scale = Vector2(s, s)   # scales the drawing and the touch area together
		b.position = at[String(b.action)] - art * s / 2.0


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
	apply_size()
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
