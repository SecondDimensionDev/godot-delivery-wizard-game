@icon("uid://dxy745jtos7dd")
class_name TopDownSteeringController
extends Node
## Calculates a movement vector using Context-Based Steering.
##
## Sits between a [TopDownMoveTargeter] and a [TopDownMovement] component.
## It evaluates multiple directions, scoring them based on how close they
## are to the target (Interest) and whether there are obstacles (Danger).
## It then passes the safest, most direct vector to the movement component.

# EXPORT VARIABLES
@export_group("References")
@export var parent: Node2D ## The parent entity
@export var targeter_component: TopDownMoveTargeter ## The component providing the target coordinates.
@export var movement_component: TopDownMovement ## The component to send the calculated vector to.

@export_group("Settings")
@export var active: bool = true ## If false, stops calculating and sends a zero vector.
@export var ray_count: int = 8 ## Number of directions to check (8, 16, or 24 recommended).
@export var steering_smoothness: float = 10.0 ## How quickly the AI turns. Lower = smoother/sluggish, Higher = snappy.

@export_group("Obstacle Avoidance")
@export var look_ahead_distance: float = 50.0 ## How far ahead to check for obstacles.
@export_flags_2d_physics var obstacle_mask: int = 1 ## Physics layers that count as obstacles.
@export var avoid_weight: float = 1.0 ## How strongly to avoid walls.

@export_group("Flocking (Swarm Behavior)")
@export var enable_flocking: bool = true ## Toggles separation and cohesion.
@export var flocking_radius: float = 60.0 ## The scanner range for finding neighbors.
@export_flags_2d_physics var flocking_mask: int = 2 ## The physics layer your enemies are on.
@export var separation_weight: float = 1.5 ## Pushes units apart so they don't overlap.
@export var cohesion_weight: float = 0.5 ## Pulls units slightly together to form packs.



# PRIVATE VARIABLES
var _ray_directions: Array[Vector2] = []
var _interest: Array[float] = []
var _danger: Array[float] = []
var _current_steering: Vector2 = Vector2.ZERO # Tracks the smoothed vector
var _debug_scores: Array[float] = []
var _debug_best_dir: Vector2 = Vector2.ZERO


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	_setup_rays()


func _physics_process(delta: float) -> void:
	_calculate_steering(delta)


# PRIVATE FUNCTIONS
func _setup_rays() -> void:
	# Pre-calculates the directional vectors and sizes the arrays.
	_ray_directions.resize(ray_count)
	_interest.resize(ray_count)
	_danger.resize(ray_count)
	_debug_scores.resize(ray_count)
	
	var angle_step := (2 * PI) / ray_count
	for i in range(ray_count):
		var angle := i * angle_step
		_ray_directions[i] = Vector2(cos(angle), sin(angle))


func _calculate_steering(delta: float) -> void:
	if not movement_component or not targeter_component:
		return
		
	if not active or not targeter_component.targeting_enabled:
		movement_component.set_movement_direction(Vector2.ZERO)
		return
		
	if not parent:
		return
		
	var space_state := parent.get_world_2d().direct_space_state
	var current_pos := parent.global_position
	var target_dir := current_pos.direction_to(targeter_component.target_position)
	var owner_rid :RID = parent.get_rid()
	
	# 1. Reset Arrays for the new frame
	_interest.fill(0.0)
	_danger.fill(0.0)
	
	# 2. Apply Behaviors (The Helper Functions)
	_apply_target_interest(target_dir)
	_apply_obstacle_danger(space_state, current_pos, owner_rid)
	
	if enable_flocking:
		_apply_flocking(space_state, current_pos, owner_rid)

	# 3. Choose the best direction
	var best_dir := _choose_best_direction()

	# 4. Apply Smoothing & Hysteresis
	if best_dir != Vector2.ZERO:
		_current_steering = _current_steering.slerp(best_dir, steering_smoothness * delta)
	else:
		_current_steering = _current_steering.move_toward(Vector2.ZERO, steering_smoothness * delta)

	movement_component.set_movement_direction(_current_steering)


func _apply_target_interest(target_dir: Vector2) -> void:
	# Base desire to move toward the target
	for i in range(ray_count):
		var alignment = _ray_directions[i].dot(target_dir)
		
		# Remap from [-1.0, 1.0] to [0.0, 1.0]
		var mapped_interest = (alignment + 1.0) / 2.0 
		
		_interest[i] += mapped_interest


#func _apply_target_interest(target_dir: Vector2) -> void:
	## Base desire to move toward the target
	#for i in range(ray_count):
		#var alignment = _ray_directions[i].dot(target_dir)
		#_interest[i] += max(0.0, alignment)


func _apply_obstacle_danger(space_state: PhysicsDirectSpaceState2D, current_pos: Vector2, owner_rid: RID) -> void:
	# Non-Binary Danger: Scales based on distance to the wall
	for i in range(ray_count):
		var dir := _ray_directions[i]
		var query := PhysicsRayQueryParameters2D.create(current_pos, current_pos + dir * look_ahead_distance, obstacle_mask)
		query.exclude = [owner_rid]
		
		var result := space_state.intersect_ray(query)
		if result:
			var dist := current_pos.distance_to(result.position)
			# Closer = closer to 1.0 danger. Further = closer to 0.0 danger.
			var danger_ratio := 1.0 - (dist / look_ahead_distance) 
			_danger[i] += (danger_ratio * avoid_weight)


func _apply_flocking(space_state: PhysicsDirectSpaceState2D, current_pos: Vector2, owner_rid: RID) -> void:
	# Uses a highly performant circle shape cast to find neighbors in one single query
	var shape := CircleShape2D.new()
	shape.radius = flocking_radius
	
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, current_pos)
	query.collision_mask = flocking_mask
	query.exclude = [owner_rid]
	
	var neighbors := space_state.intersect_shape(query)
	if neighbors.is_empty(): return
	
	var center_of_mass := Vector2.ZERO
	var valid_neighbors := 0
	
	for n in neighbors:
		var neighbor_node = n.collider as Node2D
		if not neighbor_node: continue
			
		var neighbor_pos :Vector2 = neighbor_node.global_position
		var dist := current_pos.distance_to(neighbor_pos)
		
		# SEPARATION: Add danger to rays pointing AT the neighbor
		if dist > 0.0:
			var dir_to_neighbor := current_pos.direction_to(neighbor_pos)
			var crowding_ratio := 1.0 - (dist / flocking_radius) # Closer = more danger
			
			for i in range(ray_count):
				var alignment := _ray_directions[i].dot(dir_to_neighbor)
				if alignment > 0.0:
					_danger[i] += (alignment * crowding_ratio * separation_weight)
		
		center_of_mass += neighbor_pos
		valid_neighbors += 1
		
	# COHESION: Add interest to rays pointing AT the center of the group
	if valid_neighbors > 0:
		center_of_mass /= valid_neighbors
		var dir_to_center := current_pos.direction_to(center_of_mass)
		
		for i in range(ray_count):
			var alignment := _ray_directions[i].dot(dir_to_center)
			if alignment > 0.0:
				_interest[i] += (alignment * cohesion_weight)


func _choose_best_direction() -> Vector2:
	var best_dir := Vector2.ZERO
	var max_score := -INF 
	
	for i in range(ray_count):
		var score := _interest[i] - _danger[i]
		
		# Hysteresis
		var alignment = _ray_directions[i].dot(_current_steering.normalized())
		if alignment > 0.7: 
			score += 0.15 
			
		_debug_scores[i] = score 
		
		if score > max_score:
			max_score = score
			best_dir = _ray_directions[i]
	
	_debug_best_dir = best_dir 
	return best_dir


#func _calculate_steering(delta: float) -> void:
	## Scores all directions and picks the safest direct route.
	#if not movement_component or not targeter_component:
		#return
		#
	#if not active or not targeter_component.targeting_enabled:
		#movement_component.set_movement_direction(Vector2.ZERO)
		#return
		#
	#if not parent:
		#return
		#
	#var space_state := parent.get_world_2d().direct_space_state
	#var current_pos := parent.global_position
	#var target_dir := current_pos.direction_to(targeter_component.target_position)
	#
	## 1. Populate Interest & Danger arrays
	#for i in range(ray_count):
		#var dir := _ray_directions[i]
		#
		## Interest: 1.0 if pointing exactly at target, 0.0 if perpendicular or away
		#_interest[i] = max(0.0, dir.dot(target_dir))
		#
		## Danger: Raycast to check for obstacles
		#var query := PhysicsRayQueryParameters2D.create(current_pos, current_pos + dir * look_ahead_distance, obstacle_mask)
		#query.exclude = [parent.get_rid()] # Ignore ourselves
		#
		#var result := space_state.intersect_ray(query)
		#if result:
			## If we hit an obstacle, max out the danger for this direction
			#_danger[i] = 1.0
		#else:
			#_danger[i] = 0.0
#
	## 2. Choose the best direction based on the scores
	#var best_dir := Vector2.ZERO
	#var max_score := -INF # Using -INF is safer than -1.0 to ensure a direction is always picked
	#
	#for i in range(ray_count):
		#var score := _interest[i] - _danger[i]
		#
		## HYSTERESIS (STUBBORNNESS)
		## Check how closely this ray aligns with our current physical movement
		## Using dot product: 1.0 means exact same direction, < 0 means opposite
		#var alignment = _ray_directions[i].dot(_current_steering.normalized())
		#
		## If this ray is pointing roughly the same way we are already going, give it a bonus!
		#if alignment > 0.7: 
			#score += 0.15 # This small bias stops the 50/50 tie-breaker flipping
			#
		#_debug_scores[i] = score
		#
		#if score > max_score:
			#max_score = score
			#best_dir = _ray_directions[i]
	#
	#_debug_best_dir = best_dir
	#
	## 3. Lerp the current steering toward the new best direction to prevent violent snapping
	#if best_dir != Vector2.ZERO:
		#_current_steering = _current_steering.slerp(best_dir, steering_smoothness * delta)
	#else:
		#_current_steering = _current_steering.move_toward(Vector2.ZERO, steering_smoothness * delta)
	#
	## 4. Send the smoothed command to the legs
	#movement_component.set_movement_direction(_current_steering)
