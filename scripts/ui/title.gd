extends Control
## Title screen: the back room under a billiard lamp, the logo, and a cue
## ball idly rolling along the felt.

const FELT_Y := 236

var _menu: VBoxContainer
var _ball: BallVisual
var _ball_x := 120.0
var _ball_v := 38.0
var _first: Button
var _logo: Array[Control] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	if SaveData.url_flag("probe"):
		add_child(WebProbe.new())   # the iPhone rendering test pattern instead
		return
	SaveData.set_run(SaveData.CLASSIC, 1)
	Sfx.set_ambience(0)
	Sfx.play_music(Sfx.MUSIC[0])
	var bg := TextureRect.new()
	bg.texture = load("res://assets/textures/bg_backroom.png")
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.01, 0.02, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	# Hanging lamp and its pool of light.
	var chain := TextureRect.new()
	chain.texture = load("res://assets/textures/chain.png")
	chain.stretch_mode = TextureRect.STRETCH_TILE
	chain.position = Vector2(254, 0)
	chain.size = Vector2(4, 30)
	add_child(chain)
	var lamp := TextureRect.new()
	lamp.texture = load("res://assets/textures/lamp.png")
	lamp.position = Vector2(232, 28)
	add_child(lamp)
	var cone := TextureRect.new()
	cone.texture = load("res://assets/textures/light_cone.png")
	cone.position = Vector2(200, 40)
	cone.size = Vector2(112, 200)
	cone.stretch_mode = TextureRect.STRETCH_SCALE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	cone.material = add
	add_child(cone)
	var rack := TextureRect.new()
	rack.texture = load("res://assets/textures/cue_rack.png")
	rack.position = Vector2(40, 150)
	add_child(rack)
	var beads := TextureRect.new()
	beads.texture = load("res://assets/textures/score_beads.png")
	beads.position = Vector2(380, 120)
	add_child(beads)
	# The felt: a strip of table tiles along the bottom.
	var tiles: Texture2D = load("res://assets/textures/tiles.png")
	for i in 32:
		for row in 4:
			var t := TextureRect.new()
			var at := AtlasTexture.new()
			at.atlas = tiles
			at.region = Rect2((1 if row == 0 else 0) * 16, 0, 16, 16)
			t.texture = at
			t.position = Vector2(i * 16, FELT_Y + row * 16)
			add_child(t)
	if not SaveData.url_flag("noball"):   # iPhone experiment: the title without its shader ball
		_ball = BallVisual.new()
		_ball.number = SaveData.skin
		_ball.diameter = 16
		add_child(_ball)

	# Logo.
	var logo := Label.new()
	logo.text = "VERTICAL BILLIARD"
	logo.add_theme_font_size_override("font_size", 32)
	logo.add_theme_color_override("font_color", Color("f2d27a"))
	logo.add_theme_color_override("font_shadow_color", Color("3a1a0c"))
	logo.add_theme_constant_override("shadow_offset_x", 2)
	logo.add_theme_constant_override("shadow_offset_y", 2)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.position = Vector2(0, 70)
	logo.size = Vector2(512, 36)
	add_child(logo)
	_logo.append(logo)
	var sub := Label.new()
	sub.text = "One ball. One tower. No checkpoints."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 106)
	sub.size = Vector2(512, 10)
	sub.add_theme_color_override("font_color", Color("b0a088"))
	add_child(sub)
	_logo.append(sub)

	_menu = VBoxContainer.new()
	_menu.position = Vector2(196, 120)
	_menu.size = Vector2(120, 100)
	_menu.add_theme_constant_override("separation", 1)
	add_child(_menu)
	_build_menu()


func _build_menu() -> void:
	for c in _menu.get_children():
		c.queue_free()
	var buttons: Array = []
	buttons.append(UIKit.button(_menu, "Normal mode", _open_levels.bind(SaveData.CLASSIC)))
	buttons.append(UIKit.button(_menu, "Hardcore mode", _open_levels.bind(SaveData.HARDCORE)))
	buttons.append(UIKit.button(_menu, "Training", _open_levels.bind(SaveData.TRAINING)))
	buttons.append(UIKit.button(_menu, "Ball Rack", _open.bind(BallRack)))
	buttons.append(UIKit.button(_menu, "Options", _open.bind(OptionsMenu)))
	buttons.append(UIKit.button(_menu, "Quit", func(): get_tree().quit()))
	for b in buttons:
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.chain_focus(buttons)
	_first = buttons[0]
	_first.grab_focus.call_deferred()
	if SaveData.wins > 0 or SaveData.hc_wins > 0:
		var best := Label.new()
		best.text = "Climbs %d   Hardcore wins %d" % [SaveData.wins, SaveData.hc_wins]
		best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		best.add_theme_color_override("font_color", Color("8a8070"))
		_menu.add_child(best)


func _open_levels(mode: String) -> void:
	var m := LevelSelect.new()
	m.mode = mode
	add_child(m)
	_menu.visible = false
	for c in _logo:
		c.visible = false
	m.closed.connect(func():
		_menu.visible = true
		for c in _logo:
			c.visible = true
		_build_menu())


func _open(kind: Variant) -> void:
	var m: Control = kind.new()
	add_child(m)
	_menu.visible = false
	m.closed.connect(func():
		_menu.visible = true
		if _ball:
			_ball.number = SaveData.skin
		_build_menu())


func _process(delta: float) -> void:
	if _ball == null:
		return   # the probe pattern, or ?noball
	_ball_x += _ball_v * delta
	if _ball_x < 24.0 or _ball_x > 488.0:
		_ball_v = -_ball_v
		Sfx.play("rail", -20.0)
	_ball.position = Vector2(round(_ball_x), FELT_Y - 7)
	_ball.roll(_ball_v / 7.0, 0.0, delta)
