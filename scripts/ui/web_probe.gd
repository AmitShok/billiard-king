class_name WebProbe
extends Control
## A test pattern for the iPhone rendering bug (opened with ?probe in the web
## address). Every piece sits at a known place in the 512x288 view, so a
## screenshot shows exactly how a browser misplaces or drops 2D items:
##   row A  8 plain colour blocks (no texture)
##   row B  8 tiles cut from one texture (one batch)
##   row C  8 different textures (a new batch each)
##   row D  8 single letters
## A white border runs round the view with a red mark in each corner.

const COLS := 8
const STEP := 60.0
const LEFT := 22.0
const COLOURS := ["e04848", "f2a03c", "f2d27a", "52c878", "3cb4e0", "4c6ce0", "a05ce0", "e05ca8"]
const TEXTURES := ["chalk", "lamp", "clock", "glow", "flower_pot", "bell", "gear", "crown"]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	_rect(Vector2.ZERO, Vector2(512, 288), Color("101418"))
	# Border and corner marks.
	_rect(Vector2(0, 0), Vector2(512, 2), Color.WHITE)
	_rect(Vector2(0, 286), Vector2(512, 2), Color.WHITE)
	_rect(Vector2(0, 0), Vector2(2, 288), Color.WHITE)
	_rect(Vector2(510, 0), Vector2(2, 288), Color.WHITE)
	for c in [Vector2(2, 2), Vector2(500, 2), Vector2(2, 276), Vector2(500, 276)]:
		_rect(c, Vector2(10, 10), Color("ff2020"))
	var tiles: Texture2D = load("res://assets/textures/tiles.png")
	for i in COLS:
		var x := LEFT + i * STEP
		_label(Vector2(x, 8), "%d" % (i + 1))
		# A: colour blocks.
		_rect(Vector2(x, 22), Vector2(40, 40), Color(COLOURS[i]))
		_label(Vector2(x + 2, 24), "A%d" % (i + 1))
		# B: tiles from one texture.
		var at := AtlasTexture.new()
		at.atlas = tiles
		at.region = Rect2((i % 4) * 16, 0, 16, 16)
		_tex(Vector2(x, 76), Vector2(40, 40), at)
		_label(Vector2(x + 2, 78), "B%d" % (i + 1))
		# C: different textures.
		var path := "res://assets/textures/%s.png" % TEXTURES[i]
		if ResourceLoader.exists(path):
			_tex(Vector2(x, 130), Vector2(40, 40), load(path))
		_label(Vector2(x + 2, 132), "C%d" % (i + 1))
		# D: letters.
		_label(Vector2(x + 14, 190), "DEFGHJKL"[i], 16)
	if SaveData.url_flag("ball"):
		# One rolling ball (the custom spherical shader) in the bottom-right box.
		_rect(Vector2(440, 200), Vector2(48, 48), Color("1d4a32"))
		var ball := BallVisual.new()
		ball.number = 1
		ball.diameter = 24
		ball.position = Vector2(464, 224)
		add_child(ball)
	_label(Vector2(22, 230), "probe: %s" % SaveData.url_flags_text(), 8)
	_label(Vector2(22, 246), "view %s  window %s" % [get_viewport_rect().size, DisplayServer.window_get_size()], 8)


func _rect(at: Vector2, size: Vector2, col: Color) -> void:
	var r := ColorRect.new()
	r.position = at
	r.size = size
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)


func _tex(at: Vector2, size: Vector2, tex: Texture2D) -> void:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # before the size, or it grows to the texture
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture = tex
	t.position = at
	t.size = size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)


func _label(at: Vector2, text: String, font_size := 0) -> void:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_shadow_color", Color.BLACK)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
