class_name GridNav
extends RefCounted

## Walkability A* grid over a level GridMap. A dungeon cell is FLOOR iff it has a y=0
## item; a nav point is walkable iff a clearance cylinder in the wall-height band above
## the floor hits NO static geometry there -- the level is hand-decorated, so the real
## collision world is the truth: props without collision stay walkable, anything the
## enemy's body couldn't pass through blocks the point. Build is server-side, one-time,
## and physics-dependent: the GridMap registers its colliders a few physics frames after
## entering the tree, so try_build returns RETRY until the floor probe hits geometry (or
## it times out into FAILED and the caller falls back to straight-line movement).

# ENUMS
enum Build { RETRY, FAILED, READY } ## try_build outcome; FAILED = no usable GridMap/floor.

# CONSTANTS
const NAV_SUBDIV := 2 # nav subcells per GridMap cell side (2 m cells -> 1 m nav grid)
const NAV_BAND_LOW := 0.9 # walkability probe band above the floor surface
const NAV_BAND_HIGH := 2.0
const NAV_TIGHT_WEIGHT := 4.0 # A* cost multiplier for passable-but-tight points
const MAX_BUILD_WAIT_TICKS := 120 # ~2 s of physics ticks waiting for colliders

# PRIVATE VARIABLES
var _astar: AStarGrid2D
var _grid_map: GridMap
var _sub_size := 1.0
var _wait_ticks := 0


# PUBLIC FUNCTIONS
func is_ready() -> bool:
	return _astar != null


func try_build(probe_origin: Node3D, grid_map: GridMap, clearance: float, comfort: float,
		exclude: Array[RID]) -> Build:
	# Points cost 1 when a comfort-radius cylinder fits, NAV_TIGHT_WEIGHT when only the
	# hard clearance fits, and are solid when not even that does.
	if grid_map == null:
		return Build.FAILED
	var floor_y := _probe_floor_y(probe_origin, exclude)
	if is_inf(floor_y):
		_wait_ticks += 1
		return Build.RETRY if _wait_ticks < MAX_BUILD_WAIT_TICKS else Build.FAILED
	_grid_map = grid_map
	_sub_size = grid_map.cell_size.x / float(NAV_SUBDIV)
	var floor_cells := {}
	var min_cell := Vector2i(2147483647, 2147483647)
	var max_cell := Vector2i(-2147483648, -2147483648)
	for cell: Vector3i in grid_map.get_used_cells():
		if cell.y != 0:
			continue
		var flat := Vector2i(cell.x, cell.z)
		floor_cells[flat] = true
		min_cell = Vector2i(mini(min_cell.x, flat.x), mini(min_cell.y, flat.y))
		max_cell = Vector2i(maxi(max_cell.x, flat.x), maxi(max_cell.y, flat.y))
	if floor_cells.is_empty():
		_grid_map = null
		return Build.FAILED
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(min_cell * NAV_SUBDIV,
			(max_cell - min_cell + Vector2i.ONE) * NAV_SUBDIV)
	grid.cell_size = Vector2(_sub_size, _sub_size)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	# Cylinders, not boxes -- round like the enemies' capsules, so diagonals aren't
	# over-blocked by box corners.
	var comfort_shape := CylinderShape3D.new()
	comfort_shape.radius = comfort
	comfort_shape.height = NAV_BAND_HIGH - NAV_BAND_LOW
	var minimum_shape := CylinderShape3D.new()
	minimum_shape.radius = clearance
	minimum_shape.height = NAV_BAND_HIGH - NAV_BAND_LOW
	var probe := PhysicsShapeQueryParameters3D.new()
	probe.exclude = exclude
	var band_y := floor_y + (NAV_BAND_LOW + NAV_BAND_HIGH) / 2.0
	var space := probe_origin.get_world_3d().direct_space_state
	for sx in range(grid.region.position.x, grid.region.end.x):
		for sz in range(grid.region.position.y, grid.region.end.y):
			var id := Vector2i(sx, sz)
			var cell := Vector2i(floori((id.x + 0.5) / float(NAV_SUBDIV)),
					floori((id.y + 0.5) / float(NAV_SUBDIV)))
			if not floor_cells.has(cell):
				grid.set_point_solid(id, true)
				continue
			probe.transform = Transform3D(Basis.IDENTITY, _world_from_id_at(id, band_y))
			probe.shape = comfort_shape
			if space.intersect_shape(probe, 1).is_empty():
				continue
			probe.shape = minimum_shape
			if space.intersect_shape(probe, 1).is_empty():
				grid.set_point_weight_scale(id, NAV_TIGHT_WEIGHT)
			else:
				grid.set_point_solid(id, true)
	_astar = grid
	return Build.READY


func path_points(from: Vector3, to: Vector3) -> PackedVector3Array:
	## World-space waypoints from -> to (skipping the start's own cell, y held at
	## from.y). Empty when either end is off-grid or no route exists.
	var points := PackedVector3Array()
	if _astar == null:
		return points
	var from_id := nearest_walkable_id(from)
	var to_id := nearest_walkable_id(to)
	if from_id.x == 2147483647 or to_id.x == 2147483647:
		return points
	var ids := _astar.get_id_path(from_id, to_id)
	for i in range(1, ids.size()):
		points.append(_world_from_id_at(ids[i], from.y))
	return points


func nearest_walkable_id(world: Vector3) -> Vector2i:
	## Snap a world position to its nav point, spiralling outward a few metres if that
	## exact point is solid (a player standing on a prop cell, cargo shoved to a wall).
	## Returns Vector2i(2147483647, ...) when nothing walkable is nearby.
	var local := _grid_map.to_local(world)
	var home := Vector2i(floori(local.x / _sub_size), floori(local.z / _sub_size))
	for ring in range(0, 5):
		var best := Vector2i(2147483647, 2147483647)
		var best_dist := INF
		for dx in range(-ring, ring + 1):
			for dz in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var id := home + Vector2i(dx, dz)
				if not _astar.region.has_point(id) or _astar.is_point_solid(id):
					continue
				var world_point := _world_from_id_at(id, world.y)
				var dist := Vector2(world.x, world.z).distance_to(
						Vector2(world_point.x, world_point.z))
				if dist < best_dist:
					best_dist = dist
					best = id
		if best.x != 2147483647:
			return best
	return Vector2i(2147483647, 2147483647)


# PRIVATE FUNCTIONS
func _probe_floor_y(probe_origin: Node3D, exclude: Array[RID]) -> float:
	# The walkable floor surface height under the enemy (the whole dungeon is flat).
	# INF while nothing is hit -- physics colliders aren't registered yet (or there
	# genuinely is no floor); the caller retries or falls back.
	var from := probe_origin.global_position + Vector3(0.0, 2.0, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0.0, -10.0, 0.0))
	query.exclude = exclude
	var hit := probe_origin.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return INF
	return (hit["position"] as Vector3).y


func _world_from_id_at(id: Vector2i, world_y: float) -> Vector3:
	var local := Vector3((id.x + 0.5) * _sub_size, 0.0, (id.y + 0.5) * _sub_size)
	var world := _grid_map.to_global(local)
	world.y = world_y
	return world
