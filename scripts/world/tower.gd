@tool
class_name Tower
extends Node2D
## The whole climb: one TileMapLayer, the gameplay objects and the decor.
## Baked from levels/tower.txt by tools/build_tower.gd. Screen 0 is the
## bottom; screen k spans y in [-(k+1)*288, -k*288).

const SCREEN := Vector2(512, 288)
const ZONE_NAMES := ["The Back Room", "Lucky's Neon Bar", "The Royal Club", "The King's Table"]

@export var screen_zones: PackedInt32Array
@export var spawn := Vector2.ZERO

var world: CollisionWorld


static func screen_of(y: float) -> int:
	return floori(-y / SCREEN.y)


static func screen_center(k: int) -> Vector2:
	return Vector2(SCREEN.x / 2.0, -k * SCREEN.y - SCREEN.y / 2.0)


func screen_count() -> int:
	return screen_zones.size()


func zone_of_screen(k: int) -> int:
	return screen_zones[clampi(k, 0, screen_zones.size() - 1)]


## Builds the collision data. Lost balls already in the Ball Rack are skipped.
func build_world(collected: Array = []) -> CollisionWorld:
	world = CollisionWorld.from_tilemap($Terrain)
	# Invisible lid over the summit so a wild shot can't leave the tower.
	var lid := -screen_count() * 18 - 1
	for x in range(-1, 33):
		world.cells[Vector2i(x, lid)] = [CollisionWorld.Shape.SOLID, CollisionWorld.Mat.TABLE, 2]
	var id := 0
	for child in $Objects.get_children():
		if child is Bumper:
			world.bumpers.append({ "pos": child.position, "radius": Bumper.RADIUS, "id": id })
		elif child is Pocket:
			world.pockets.append({ "pos": child.position, "radius": Pocket.RADIUS, "exit": child.exit, "goal": child.goal, "id": id })
		elif child is LostBall:
			if collected.has(child.number):
				child.hide()
			else:
				world.lost_balls.append({ "pos": child.position, "number": child.number, "taken": false })
		child.set_meta("world_id", id)
		id += 1
	return world


func object_by_id(id: int) -> Node:
	for child in $Objects.get_children():
		if child.get_meta("world_id", -1) == id:
			return child
	return null


func lost_ball_node(number: int) -> LostBall:
	for child in $Objects.get_children():
		if child is LostBall and child.number == number:
			return child
	return null
