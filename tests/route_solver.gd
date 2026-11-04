extends SceneTree
## Proves a level can be climbed with the real ball physics, and measures how
## forgiving the climb is. Moving platforms and traps run on the real clock.
## 1. Explores every resting spot reachable from the start (a spot on a moving
##    platform counts as one spot, wherever the platform is), firing a sweep of
##    aim notches x charge levels from each. Near moving things the sweep is
##    repeated at several moments, because a player can wait for the right one.
## 2. Scores each move u -> v by how many swept shots from u end at least as
##    high as v, taking the best moment ("working shots").
## 3. Finds the most forgiving route: the path whose hardest stroke has the
##    most working shots (widest path).
##   godot --headless --path . --script tests/route_solver.gd -- [--level=2]
##     [--aim-step=10 --charge-step=6 --min-work=5]
##     [--from-screen=k --to-screen=j]   only this stretch: success = resting on screen j
##     [--verbose]                       print the whole route

const MAX_STEPS := 900
const MAX_NODES := 4000
const STATIC_MOMENTS := 3     # moments tried from still ground near moving things
const RIDING_MOMENTS := 4     # moments tried from a moving platform, across its period
const DROP_ALLOWED := 48.0    # px below a spot that is still worth exploring from
const FALL_ABANDON := 300.0   # a shot that has dropped this far below its start is written off

var world: CollisionWorld
var aim_step := 10
var charge_step := 6
var min_work := 5
var level := 1
var from_screen := -1
var to_screen := -1
var verbose := false
var mover_screens := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var v := arg.get_slice("=", 1)
		if arg.begins_with("--aim-step="): aim_step = int(v)
		if arg.begins_with("--charge-step="): charge_step = int(v)
		if arg.begins_with("--min-work="): min_work = int(v)
		if arg.begins_with("--level="): level = int(v)
		if arg.begins_with("--from-screen="): from_screen = int(v)
		if arg.begins_with("--to-screen="): to_screen = int(v)
		if arg == "--verbose": verbose = true
	var path := "res://scenes/world/tower.tscn" if level == 1 else "res://scenes/world/tower%d.tscn" % level
	var tower: Tower = load(path).instantiate()
	root.add_child(tower)
	world = tower.build_world()
	_note_mover_screens()
	var t0 := Time.get_ticks_msec()
	var shots_per_moment := (BallSim.AIM_LIMIT_DEG * 2 / aim_step + 1) * (BallSim.CHARGE_TICKS / charge_step)

	var start_at: Vector2 = tower.spawn if from_screen < 0 else _entry_of_screen(from_screen)
	var start := _settle(start_at)
	if start.is_empty():
		print("FAIL: the start does not settle")
		quit(1)
		return
	var start_key := _key(start)
	var nodes := { start_key: _node(start) }
	var queue: Array = [start_key]
	var lost_seen := {}
	while not queue.is_empty() and nodes.size() < MAX_NODES:
		var key: Vector3i = queue.pop_front()
		var node: Dictionary = nodes[key]
		var results: Array = []
		var moments := _moments(node)
		# Only movers around this spot need to tick.
		world.set_active_window(node.y_top - 300.0, node.y_low + FALL_ABANDON + 20.0)
		for m in moments.size():
			for aim in range(-BallSim.AIM_LIMIT_DEG, BallSim.AIM_LIMIT_DEG + 1, aim_step):
				for ticks in range(charge_step, BallSim.CHARGE_TICKS + 1, charge_step):
					var r := _shot(node, moments[m], aim, ticks)
					for n in r.lost:
						lost_seen[n] = true
					if r.goal:
						results.append({ "goal": true, "y": -INF, "key": null, "shot": [aim, ticks], "m": m })
						continue
					if r.end.is_empty():
						continue
					var k := _key(r.end)
					results.append({ "goal": false, "y": r.end.pos.y, "key": k, "shot": [aim, ticks], "m": m })
					if not nodes.has(k) and _in_scope(r.end.pos.y):
						nodes[k] = _node(r.end)
						# Spots well below this one can't be part of a sensible climb.
						var sensible: bool = nodes[k].y_top <= node.y_low + DROP_ALLOWED
						if sensible and (to_screen < 0 or Tower.screen_of(r.end.pos.y) < to_screen):
							queue.append(k)
		node.results = results
		node.moments = moments.size()

	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	var best_screen := -1
	for k in nodes:
		best_screen = maxi(best_screen, Tower.screen_of(nodes[k].y_top))
	print("Explored %d resting spots in %.1fs (%d shots per moment). Highest screen: %d of %d." % [nodes.size(), secs, shots_per_moment, best_screen, tower.screen_count() - 1])
	if not world.lost_balls.is_empty():
		var lost := lost_seen.keys()
		lost.sort()
		print("Lost balls reachable: %s of %d placed" % [str(lost), world.lost_balls.size()])

	# Widest path over climbing moves.
	var width := { start_key: 1 << 30 }
	var prev := {}
	var done := {}
	var goal_width := -1
	var goal_from: Variant = null
	while true:
		var u: Variant = null
		for k in width:
			if not done.has(k) and (u == null or width[k] > width[u]):
				u = k
		if u == null:
			break
		done[u] = true
		var unode: Dictionary = nodes[u]
		var results: Array = unode.get("results", [])
		var success := _goal_count(results)
		# A stretch ends by standing on its target screen.
		if to_screen >= 0 and Tower.screen_of(unode.y_top) >= to_screen and width[u] > goal_width:
			goal_width = width[u]
			goal_from = u
		if success > 0 and mini(width[u], success) > goal_width:
			goal_width = mini(width[u], success)
			goal_from = u
		var targets := {}
		for r in results:
			if r.key != null and r.key != u and nodes.has(r.key):
				targets[r.key] = r
		for v in targets:
			var vnode: Dictionary = nodes[v]
			if vnode.y_top >= unode.y_low - 4.0:
				continue
			var work := _work(results, vnode.y_low)
			var w := mini(width[u], work)
			if w > width.get(v, -1):
				width[v] = w
				prev[v] = [u, work, targets[v].shot]

	if goal_from == null:
		_report_frontier(nodes)
		print("FAIL: target not reachable")
		quit(1)
		return
	var route: Array = []
	var cur: Variant = goal_from
	while prev.has(cur):
		route.push_front({ "from": prev[cur][0], "to": cur, "work": prev[cur][1], "shot": prev[cur][2] })
		cur = prev[cur][0]
	print("Most forgiving route: %d climbing strokes, hardest stroke has %d of %d working shots." % [route.size() + (0 if to_screen >= 0 else 1), goal_width, shots_per_moment])
	var worst := {}
	for step in route:
		var a: Dictionary = nodes[step.from]
		var b: Dictionary = nodes[step.to]
		var sa := Tower.screen_of(a.y_low)
		worst[sa] = mini(worst.get(sa, 1 << 30), step.work)
		if verbose or step.work < min_work:
			print("  s%d %s -> s%d %s  aim %3d charge %2d  %3d working" % [sa, _describe(a), Tower.screen_of(b.y_low), _describe(b), step.shot[0], step.shot[1], step.work])
	var screens := worst.keys()
	screens.sort()
	print("Hardest stroke per screen: %s" % ", ".join(screens.map(func(s): return "s%d=%d" % [s, worst[s]])))
	if goal_width < min_work:
		print("FAIL: a required stroke has fewer than %d working shots" % min_work)
		quit(1)
		return
	print("PASS")
	quit(0)


func _goal_count(results: Array) -> int:
	var best := {}
	for r in results:
		if r.goal:
			best[r.m] = best.get(r.m, 0) + 1
	var out := 0
	for m in best:
		out = maxi(out, best[m])
	return out


## Working shots at the best moment: a player can wait for it.
func _work(results: Array, y_low: float) -> int:
	var per := {}
	for r in results:
		if r.goal or r.y <= y_low + 4.0:
			per[r.m] = per.get(r.m, 0) + 1
	var out := 0
	for m in per:
		out = maxi(out, per[m])
	return out


func _in_scope(y: float) -> bool:
	if from_screen < 0:
		return true
	var s := Tower.screen_of(y)
	return s >= from_screen and s <= to_screen


func _describe(n: Dictionary) -> String:
	if n.riding >= 0:
		return "carriage %d" % n.riding
	return "(%d,%d)" % [n.pos.x, posmod(int(n.pos.y), 288)]


func _report_frontier(nodes: Dictionary) -> void:
	var top: Array = nodes.values()
	top.sort_custom(func(a, b): return a.y_top < b.y_top)
	print("Highest resting spots:")
	for i in mini(6, top.size()):
		var p: Vector2 = top[i].pos
		print("  screen %d tile (%d,%d)%s" % [Tower.screen_of(p.y), floori(p.x / 16), posmod(floori(p.y / 16), 18), " riding" if top[i].riding >= 0 else ""])


func _note_mover_screens() -> void:
	for p in world.platforms:
		for y in [p.a.y, p.b.y]:
			_mark(y)
	for tr in world.traps:
		if tr.kind == CollisionWorld.Trap.SPIKE:
			_mark(tr.a.y)
			_mark(tr.b.y)
		else:
			_mark(tr.center.y)


func _mark(y: float) -> void:
	var s := Tower.screen_of(y)
	for k in [s - 1, s, s + 1]:
		mover_screens[k] = true


func _moments(node: Dictionary) -> Array:
	if node.riding >= 0:
		var p := world.platforms[node.riding]
		var out: Array = []
		for i in RIDING_MOMENTS:
			out.append(p.period * i / RIDING_MOMENTS)
		return out
	if mover_screens.has(Tower.screen_of(node.pos.y)):
		return [0.0, 1.37, 2.81, 4.19].slice(0, STATIC_MOMENTS)
	return [0.0]


## Where a ball dropped on this screen's lowest ledge comes to rest.
func _entry_of_screen(k: int) -> Vector2:
	var top := -(k + 1) * 18
	for row in range(top + 17, top - 1, -1):
		for col in range(1, 31):
			if world.shape_at(Vector2i(col, row)) == CollisionWorld.Shape.SOLID and world.shape_at(Vector2i(col, row - 1)) == CollisionWorld.Shape.NONE and world.shape_at(Vector2i(col + 1, row)) == CollisionWorld.Shape.SOLID:
				return Vector2((col + 1) * 16.0, row * 16.0 - 8.0)
	return Vector2(256, top * 16.0 + 100.0)


func _key(end: Dictionary) -> Vector3i:
	if end.riding >= 0:
		return Vector3i(roundi(end.offset / 12.0), 0, end.riding)
	return Vector3i(roundi(end.pos.x / 12.0), roundi(end.pos.y / 8.0), -1)


func _node(end: Dictionary) -> Dictionary:
	var n := end.duplicate()
	n.y_low = end.pos.y
	n.y_top = end.pos.y
	if end.riding >= 0:
		var p := world.platforms[end.riding]
		n.y_low = maxf(p.a.y, p.b.y) - BallSim.RADIUS
		n.y_top = minf(p.a.y, p.b.y) - BallSim.RADIUS
	return n


func _settle(at: Vector2) -> Dictionary:
	world.set_time(0.0)
	var sim := BallSim.new()
	sim.reset(at)
	for i in MAX_STEPS:
		world.advance(BallSim.DT)
		sim.step(world)
		if sim.resting:
			return _end_of(sim)
	return {}


func _end_of(sim: BallSim) -> Dictionary:
	var offset := 0.0
	if sim.riding >= 0:
		offset = sim.pos.x - world.platforms[sim.riding].pos.x
	return { "pos": sim.pos, "riding": sim.riding, "offset": offset }


func _shot(node: Dictionary, moment: float, aim: int, ticks: int) -> Dictionary:
	world.set_time(moment)
	var sim := BallSim.new()
	if node.riding >= 0:
		var p := world.platforms[node.riding]
		sim.reset(Vector2(p.pos.x + node.offset, p.pos.y - BallSim.RADIUS))
		sim.riding = node.riding
		sim.ride_vel = p.vel
	else:
		sim.reset(node.pos)
	sim.grounded = true
	sim.shoot(aim, ticks, 0)
	var lost: Array = []
	var result := { "goal": false, "end": {}, "lost": lost }
	for i in MAX_STEPS:
		world.advance(BallSim.DT)
		sim.step(world)
		var done := false
		for e in sim.events:
			if e.type == BallSim.Event.GOAL:
				result.goal = true
				done = true
			elif e.type == BallSim.Event.POCKET:
				sim.release_from_pocket(e.exit)
			elif e.type == BallSim.Event.LOST_BALL:
				lost.append(e.number)
		if done:
			break
		if sim.pos.y > node.y_low + FALL_ABANDON:
			break
		if sim.resting and i > 2:
			result.end = _end_of(sim)
			break
	for b in world.lost_balls:
		b.taken = false
	return result
