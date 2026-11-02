extends SceneTree
## Proves the tower can be climbed with the real ball physics, and measures
## how forgiving the climb is.
## 1. Explores every resting spot reachable from the spawn, firing a sweep of
##    aim notches x charge levels (english off) from each, following every
##    shot until the ball rests, pockets or wins.
## 2. Scores each move u -> v by how many of the swept shots from u end at
##    least as high as v ("working shots").
## 3. Finds the most forgiving route to the gold pocket: the path whose
##    hardest stroke has the most working shots (widest path).
##   godot --headless --path . --script tests/route_solver.gd [-- --aim-step=10 --charge-step=6 --min-work=3]

const MAX_STEPS := 900
const MAX_NODES := 800

var world: CollisionWorld
var aim_step := 10
var charge_step := 6
var min_work := 5


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--aim-step="):
			aim_step = int(arg.get_slice("=", 1))
		if arg.begins_with("--charge-step="):
			charge_step = int(arg.get_slice("=", 1))
		if arg.begins_with("--min-work="):
			min_work = int(arg.get_slice("=", 1))
	var tower: Tower = load("res://scenes/world/tower.tscn").instantiate()
	root.add_child(tower)
	world = tower.build_world()
	var t0 := Time.get_ticks_msec()
	var shots_per_spot := 0

	var start := _settle(tower.spawn)
	if start.is_empty():
		print("FAIL: spawn does not settle")
		quit(1)
		return
	var start_key := _key(start.pos)
	var nodes := { start_key: { "pos": start.pos, "results": [] } }
	var queue: Array = [start_key]
	var lost_seen := {}
	while not queue.is_empty() and nodes.size() < MAX_NODES:
		var key: Vector2i = queue.pop_front()
		var node: Dictionary = nodes[key]
		var results: Array = []
		for aim in range(-BallSim.AIM_LIMIT_DEG, BallSim.AIM_LIMIT_DEG + 1, aim_step):
			for ticks in range(charge_step, BallSim.CHARGE_TICKS + 1, charge_step):
				var r := _shot(node.pos, aim, ticks)
				for n in r.lost:
					lost_seen[n] = true
				if r.goal:
					results.append({ "goal": true, "y": -INF, "key": null, "shot": [aim, ticks] })
					continue
				if r.pos == null:
					continue
				var k := _key(r.pos)
				results.append({ "goal": false, "y": r.pos.y, "key": k, "shot": [aim, ticks] })
				if not nodes.has(k):
					nodes[k] = { "pos": r.pos, "results": [] }
					queue.append(k)
		shots_per_spot = (BallSim.AIM_LIMIT_DEG * 2 / aim_step + 1) * (BallSim.CHARGE_TICKS / charge_step)
		node.results = results

	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	var best_screen := 0
	for k in nodes:
		best_screen = maxi(best_screen, Tower.screen_of(nodes[k].pos.y))
	print("Explored %d resting spots in %.1fs (%d shots each). Highest screen: %d of %d." % [nodes.size(), secs, shots_per_spot, best_screen, tower.screen_count() - 1])
	var lost := lost_seen.keys()
	lost.sort()
	print("Lost balls reachable: %s of %d placed" % [str(lost), world.lost_balls.size()])

	# Widest path: maximise the minimum working-shot count along the route.
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
		var results: Array = nodes[u].results
		var goal_count := 0
		for r in results:
			if r.goal:
				goal_count += 1
		if goal_count > 0 and mini(width[u], goal_count) > goal_width:
			goal_width = mini(width[u], goal_count)
			goal_from = u
		var targets := {}
		for r in results:
			if r.key != null and r.key != u:
				targets[r.key] = r
		for v in targets:
			var vy: float = nodes[v].pos.y
			if vy >= nodes[u].pos.y - 4.0:
				continue  # only count moves that climb
			var work := 0
			for r in results:
				if r.goal or r.y <= vy + 4.0:
					work += 1
			var w := mini(width[u], work)
			if w > width.get(v, -1):
				width[v] = w
				prev[v] = [u, work, targets[v].shot]

	if goal_from == null:
		_report_frontier(nodes)
		print("FAIL: gold pocket not reachable")
		quit(1)
		return
	var route: Array = []
	var cur: Variant = goal_from
	while prev.has(cur):
		route.push_front({ "from": prev[cur][0], "to": cur, "work": prev[cur][1], "shot": prev[cur][2] })
		cur = prev[cur][0]
	print("Most forgiving route: %d climbing strokes, hardest stroke has %d of %d working shots." % [route.size() + 1, goal_width, shots_per_spot])
	var worst_per_screen := {}
	for step in route:
		var a: Vector2 = nodes[step.from].pos
		var b: Vector2 = nodes[step.to].pos
		var sa := Tower.screen_of(a.y)
		worst_per_screen[sa] = mini(worst_per_screen.get(sa, 1 << 30), step.work)
		print("  s%d (%3d,%5d) -> s%d (%3d,%5d)  aim %3d charge %2d  %3d working" % [sa, a.x, a.y, Tower.screen_of(b.y), b.x, b.y, step.shot[0], step.shot[1], step.work])
	print("  -> GOAL from s%d" % Tower.screen_of(nodes[goal_from].pos.y))
	var screens := worst_per_screen.keys()
	screens.sort()
	print("Hardest stroke per screen: %s" % ", ".join(screens.map(func(s): return "s%d=%d" % [s, worst_per_screen[s]])))
	if goal_width < min_work:
		print("FAIL: a required stroke has fewer than %d working shots" % min_work)
		quit(1)
		return
	print("PASS")
	quit(0)


func _report_frontier(nodes: Dictionary) -> void:
	var top: Array = nodes.values()
	top.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	print("Highest resting spots:")
	for i in mini(6, top.size()):
		var p: Vector2 = top[i].pos
		print("  screen %d tile (%d,%d)" % [Tower.screen_of(p.y), floori(p.x / 16), posmod(floori(p.y / 16), 18)])


func _key(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x / 12.0), roundi(p.y / 8.0))


func _settle(at: Vector2) -> Dictionary:
	var sim := BallSim.new()
	sim.reset(at)
	for i in MAX_STEPS:
		sim.step(world)
		if sim.resting:
			return { "pos": sim.pos }
	return {}


func _shot(from: Vector2, aim: int, ticks: int) -> Dictionary:
	var sim := BallSim.new()
	sim.reset(from)
	sim.grounded = true
	sim.shoot(aim, ticks, 0)
	var lost: Array = []
	var result := { "goal": false, "pos": null, "lost": lost }
	for i in MAX_STEPS:
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
		if sim.resting and i > 2:
			result.pos = sim.pos
			break
	for b in world.lost_balls:
		b.taken = false
	return result
