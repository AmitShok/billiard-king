extends Control
## Title screen: the back room under a billiard lamp, the logo, and a cue
## ball idly rolling along the felt. Everything on screen is laid out as nodes
## in scenes/ui/title.tscn; this script only adds the behaviour.

const FELT_Y := 236

var _ball_x := 120.0
var _ball_v := 38.0
var _first: Button

@onready var _menu: VBoxContainer = $Menu
@onready var _ball: BallVisual = $Ball
@onready var _best: Label = $Menu/Best
@onready var _logo: Array[Control] = [$Logo, $Subtitle]


func _ready() -> void:
	SaveData.set_run(SaveData.CLASSIC, 1)
	Sfx.set_ambience(0)
	Sfx.play_music(Sfx.MUSIC[0])
	_ball.number = SaveData.skin
	UIKit.wire_button($Menu/Normal, _open_levels.bind(SaveData.CLASSIC))
	UIKit.wire_button($Menu/Hardcore, _open_levels.bind(SaveData.HARDCORE))
	UIKit.wire_button($Menu/Training, _open_levels.bind(SaveData.TRAINING))
	UIKit.wire_button($Menu/BallRack, _open.bind(BallRack))
	UIKit.wire_button($Menu/Options, _open.bind(OptionsMenu))
	UIKit.wire_button($Menu/Quit, func(): get_tree().quit())
	_first = $Menu/Normal
	UIKit.chain_focus([$Menu/Normal, $Menu/Hardcore, $Menu/Training, $Menu/BallRack, $Menu/Options, $Menu/Quit])
	_show_menu()


## Shows the menu again (also after a panel closes): records line, focus.
func _show_menu() -> void:
	_menu.visible = true
	for c in _logo:
		c.visible = true
	_best.visible = SaveData.wins > 0 or SaveData.hc_wins > 0
	_best.text = "Climbs %d   Hardcore wins %d" % [SaveData.wins, SaveData.hc_wins]
	_ball.number = SaveData.skin
	_first.grab_focus.call_deferred()


func _open_levels(mode: String) -> void:
	var m := LevelSelect.new()
	m.mode = mode
	add_child(m)
	_menu.visible = false
	for c in _logo:
		c.visible = false
	m.closed.connect(_show_menu)


func _open(kind: Variant) -> void:
	var m: Control = kind.new()
	add_child(m)
	_menu.visible = false
	m.closed.connect(_show_menu)


func _process(delta: float) -> void:
	_ball_x += _ball_v * delta
	if _ball_x < 24.0 or _ball_x > 488.0:
		_ball_v = -_ball_v
		Sfx.play("rail", -20.0)
	_ball.position = Vector2(round(_ball_x), FELT_Y - 7)
	_ball.roll(_ball_v / 7.0, 0.0, delta)
