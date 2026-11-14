class_name TouchLayoutEditor
extends Control
## Options > Arrange touch buttons. Every on-screen button is shown at the
## chosen size; drag them anywhere with a finger (or the mouse). Done saves
## the arrangement, Reset layout puts every button back in its default spot.
## The fixed parts are laid out in scenes/ui/touch_layout_editor.tscn.

signal closed

const SCENE := "res://scenes/ui/touch_layout_editor.tscn"
const GRAB_SLACK := 6.0   # view pixels around a button that still pick it up

var _scale := 1.5
var _centres := {}            # action -> centre being edited (512x288 view)
var _previews := {}           # action -> TextureRect
var _held := ""               # action being dragged
var _held_finger := -2        # touch index, or -1 for the mouse
var _grab_offset := Vector2.ZERO

@onready var _layer: Control = $Previews
@onready var _reset: Button = $Center/Panel/Box/Row/Reset
@onready var _done: Button = $Center/Panel/Box/Row/Done


## Builds the editor from its scene (use this, not new()).
static func create() -> TouchLayoutEditor:
	return load(SCENE).instantiate()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # usable from the pause menu
	_scale = TouchControls.size_scale()
	_centres = TouchControls.centres(_scale)
	for action in TouchControls.all_actions():
		var r := TextureRect.new()
		r.name = "Preview_" + action
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.texture = TouchControls.icon(action)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var side := TouchControls.half_size(action, _scale) * 2.0
		r.size = Vector2(side, side)
		_layer.add_child(r)
		_previews[action] = r
	UIKit.wire_button(_reset, reset_layout)
	UIKit.wire_button(_done, close)
	UIKit.chain_focus([_reset, _done])
	_done.grab_focus.call_deferred()
	_place_all()


## Puts every button back in its default spot (saved when you press Done).
func reset_layout() -> void:
	_centres = TouchControls.layout(_scale)
	_place_all()


## Saves the arrangement and closes. Only buttons away from their default
## spot are stored, so later layout changes still reach the untouched ones.
func close() -> void:
	var defaults := TouchControls.layout(_scale)
	var moved := {}
	for action in _centres:
		if _centres[action].distance_to(defaults[action]) > 0.5:
			moved[action] = _centres[action].round()
	SaveData.touch_layout = moved
	SaveData.apply_settings()
	SaveData.save()
	Sfx.play("ui_back", -4.0, 1.0, 0.0)
	closed.emit()
	queue_free()


## Where a button is in the editor right now (for tests).
func centre_of(action: String) -> Vector2:
	return _centres[action]


func _place_all() -> void:
	for action in _previews:
		var r: TextureRect = _previews[action]
		r.position = _centres[action] - r.size / 2.0
		r.texture = TouchControls.icon(action, action == _held)
		r.modulate.a = 1.0 if action == _held else 0.85


## The button under a point, nearest first (the cue wins ties: it's drawn last).
func _button_at(p: Vector2) -> String:
	var best := ""
	var best_d := INF
	for action in _centres:
		var d: float = p.distance_to(_centres[action])
		if d <= TouchControls.half_size(action, _scale) + GRAB_SLACK and d <= best_d:
			best = action
			best_d = d
	return best


func _input(event: InputEvent) -> void:
	# A touch also arrives as a made-up mouse click; follow only the real one.
	# While a button is being dragged, that copy must not press Reset or Done.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION:
		if _held != "":
			get_viewport().set_input_as_handled()
		return
	var finger := -2
	var pressed := false
	var released := false
	var moved := false
	if event is InputEventScreenTouch:
		finger = event.index
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenDrag:
		finger = event.index
		moved = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		finger = -1
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion:
		finger = -1
		moved = true
	else:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			close()
		return
	var p: Vector2 = make_input_local(event).position
	if pressed and _held == "":
		var action := _button_at(p)
		if action != "":
			_held = action
			_held_finger = finger
			_grab_offset = _centres[action] - p
			Sfx.play("ui_move", -6.0, 1.2, 0.0)
			_place_all()
			get_viewport().set_input_as_handled()
	elif moved and _held != "" and finger == _held_finger:
		_centres[_held] = TouchControls.clamp_centre(_held, p + _grab_offset, _scale)
		_place_all()
		get_viewport().set_input_as_handled()
	elif released and _held != "" and finger == _held_finger:
		_centres[_held] = TouchControls.clamp_centre(_held, p + _grab_offset, _scale)
		_held = ""
		_held_finger = -2
		Sfx.play("aim_tick", -8.0, 1.0, 0.0)
		_place_all()
		get_viewport().set_input_as_handled()
