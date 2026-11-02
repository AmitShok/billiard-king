class_name CueStick
extends Node2D
## The cue drawn behind the ball while aiming, one pixel at a time so it
## stays crisp at any angle. It pulls back as the shot charges (the Jump King
## crouch) and snaps forward when released.

const LENGTH := 76
const BASE_GAP := 10.0
const MAX_PULL := 16.0

var aim_deg := 0.0
var charge := 0.0           # 0..1
var strike := 0.0           # 1 right after a shot, decays to 0
var guide_alpha := 0.0

const TIP := Color("4a8adc")
const FERRULE := Color("f4f0e8")
const SHAFT_HI := Color("f0dcae")
const SHAFT := Color("d8bc84")
const JOINT := Color("e0bc5a")
const BUTT := Color("5a2418")
const BUTT_HI := Color("8a3a26")
const WRAP := Color("1c1a1f")
const CAP := Color("0e0c10")


func _process(delta: float) -> void:
	if strike > 0.0:
		strike = maxf(0.0, strike - delta * 6.0)
		if strike == 0.0 and charge == 0.0:
			visible = false
	queue_redraw()


func _draw() -> void:
	var dir := BallSim.aim_vector(aim_deg)
	var back := -dir
	var perp := Vector2(-dir.y, dir.x)
	var gap := BASE_GAP + charge * MAX_PULL - strike * 6.0
	# Aim guide: four short dots ahead of the ball, same length for every shot.
	if guide_alpha > 0.0:
		for i in 4:
			var p := (dir * (14.0 + i * 7.0)).round()
			draw_rect(Rect2(p, Vector2.ONE), Color(1.0, 0.96, 0.82, guide_alpha * (0.95 - i * 0.18)))
	for i in LENGTH:
		var d := gap + i
		var p := (back * d).round()
		var col: Color
		var thick := false
		if i < 2:
			col = TIP
		elif i < 5:
			col = FERRULE
		elif i < 44:
			col = SHAFT_HI if i < 20 else SHAFT
		elif i < 46:
			col = JOINT
			thick = true
		elif i < LENGTH - 2:
			thick = true
			col = BUTT_HI if (i / 3) % 2 == 0 else BUTT
			if i > 54 and i < 66:
				col = WRAP if i % 2 == 0 else Color("2c2830")
		else:
			col = CAP
			thick = true
		draw_rect(Rect2(p, Vector2.ONE), col)
		if thick:
			draw_rect(Rect2((back * d + perp).round(), Vector2.ONE), col.darkened(0.35))
