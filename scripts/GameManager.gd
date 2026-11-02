extends Node
## AUTOLOAD SINGLETON. Register this in Project Settings > Autoload as
## "GameManager" so every script can call it directly (as used above).

signal level_completed(result: Dictionary)
signal ball_pocketed_scored(points: int, total: int)
signal scratch_occurred(scratch_count: int)
signal checkpoint_reached(checkpoint_id: int)

# --- Table configuration (set per-level, e.g. in level's _ready) ---------
var table_gravity_dir: Vector2 = Vector2(0.15, 1.0).normalized() ## tilt direction
var table_gravity_strength: float = 900.0

# --- Run state -------------------------------------------------------------
var run_time: float = 0.0
var is_running: bool = false
var balls_pocketed: int = 0
var total_points: int = 0
var scratch_count: int = 0
var last_checkpoint_id: int = -1
var total_ball_count_in_level: int = 0 ## set by level on load, for grading

func _ready() -> void:
	set_process(false)

func get_table_gravity_dir() -> Vector2:
	return table_gravity_dir

# --- Run lifecycle -----------------------------------------------------------
func start_run() -> void:
	run_time = 0.0
	balls_pocketed = 0
	total_points = 0
	scratch_count = 0
	last_checkpoint_id = -1
	is_running = true
	set_process(true)

func _process(delta: float) -> void:
	if is_running:
		run_time += delta

func register_ball_pocketed(points: int) -> void:
	balls_pocketed += 1
	total_points += points
	ball_pocketed_scored.emit(points, total_points)

func register_scratch() -> void:
	scratch_count += 1
	scratch_occurred.emit(scratch_count)

func register_checkpoint(checkpoint_id: int) -> void:
	if checkpoint_id > last_checkpoint_id:
		last_checkpoint_id = checkpoint_id
		checkpoint_reached.emit(checkpoint_id)

func complete_level() -> void:
	is_running = false
	set_process(false)
	var result: Dictionary = _calculate_grade()
	level_completed.emit(result)

## Grading blends three axes: speed, accuracy (balls pocketed vs total
## available), and cleanliness (fewer scratches = better). Tune the
## thresholds per level length; these are reasonable starting defaults.
func _calculate_grade() -> Dictionary:
	var pocket_ratio: float = 0.0
	if total_ball_count_in_level > 0:
		pocket_ratio = float(balls_pocketed) / float(total_ball_count_in_level)

	# Time score: 100 at par_time or better, decaying past that.
	var par_time: float = 180.0 # seconds — set per level
	var time_score: float = clamp(100.0 * (par_time / max(run_time, 1.0)), 0.0, 100.0)

	# Accuracy score.
	var accuracy_score: float = pocket_ratio * 100.0

	# Scratch penalty: each scratch costs points, floors at 0.
	var scratch_penalty: float = min(scratch_count * 8.0, 60.0)

	var composite: float = (time_score * 0.5 + accuracy_score * 0.5) - scratch_penalty
	composite = clamp(composite, 0.0, 100.0)

	var letter: String = "F"
	if composite >= 95.0: letter = "S"
	elif composite >= 85.0: letter = "A"
	elif composite >= 70.0: letter = "B"
	elif composite >= 50.0: letter = "C"
	elif composite >= 30.0: letter = "D"

	return {
		"time": run_time,
		"balls_pocketed": balls_pocketed,
		"total_balls": total_ball_count_in_level,
		"scratches": scratch_count,
		"score": composite,
		"grade": letter,
	}

func format_time(seconds: float) -> String:
	var minutes: int = int(seconds) / 60
	var secs: int = int(seconds) % 60
	var ms: int = int((seconds - int(seconds)) * 100)
	return "%02d:%02d.%02d" % [minutes, secs, ms]
