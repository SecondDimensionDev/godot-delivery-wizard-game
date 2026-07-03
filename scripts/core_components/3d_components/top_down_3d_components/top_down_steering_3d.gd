@icon("uid://dxy745jtos7dd") 
class_name TopDownSteeringController3D 
extends Node
## Calculates a 3D movement vector using Context-Based Steering on the XZ plane.

# EXPORT VARIABLES
@export_group("References")
@export var parent: Node3D
@export var targeter_component: TopDownMoveTargeter3D 
@export var movement_component: TopDownMovement3D 

@export_group("Settings")
@export var active: bool = true 
@export var ray_count: int = 16 ## Number of directions to check.
@export var steering_smoothness: float = 10.0 ## How quickly the AI turns.

@export_group("Obstacle Avoidance")
@export var look_ahead_distance: float = 5.0 ## How far ahead to check for obstacles.
@export_flags_3d_physics var obstacle_mask: int = 1 ## Physics layers that count as walls.
@export var avoid_weight: float = 1.0 ## How strongly to avoid walls.

# PRIVATE VARIABLES
var _ray_directions: Array[Vector3] = []
var _interest: Array[float] = []
var _danger: Array[float] = []
var _current_steering: Vector3 = Vector3.ZERO

# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	_setup_rays()

func _physics_process(delta: float) -> void:
	_calculate_steering(delta)

# PRIVATE FUNCTIONS
func _setup_rays() -> void:
	_ray_directions.resize(ray_count)
	_interest.resize(ray_count)
	_danger.resize(ray_count)

	var angle_step := (2 * PI) / ray_count
	for i in range(ray_count):
		var angle := i * angle_step
		# Map the circle to the XZ plane
		_ray_directions[i] = Vector3(cos(angle), 0.0, sin(angle))

func _calculate_steering(delta: float) -> void:
	if not movement_component or not targeter_component or not parent:
		return

	if not active or not targeter_component.targeting_enabled:
		movement_component.set_movement_direction(Vector3.ZERO)
		return

	var space_state := parent.get_world_3d().direct_space_state
	var current_pos := parent.global_position
	
	# Flatten the target direction to the XZ plane
	var target_pos := targeter_component.target_position
	target_pos.y = current_pos.y 
	var target_dir := current_pos.direction_to(target_pos)
	
	# Try to get RID safely if it's a physics body
	var owner_rid := RID()
	if parent is CollisionObject3D:
		owner_rid = parent.get_rid()

	_interest.fill(0.0)
	_danger.fill(0.0)

	_apply_target_interest(target_dir)
	_apply_obstacle_danger(space_state, current_pos, owner_rid)

	var best_dir := _choose_best_direction()

	if best_dir != Vector3.ZERO:
		# Use lerp for smooth vector adjustments
		_current_steering = _current_steering.lerp(best_dir, steering_smoothness * delta).normalized()
	else:
		_current_steering = _current_steering.move_toward(Vector3.ZERO, steering_smoothness * delta)

	movement_component.set_movement_direction(_current_steering)

func _apply_target_interest(target_dir: Vector3) -> void:
	for i in range(ray_count):
		var alignment := _ray_directions[i].dot(target_dir)
		var mapped_interest := (alignment + 1.0) / 2.0
		_interest[i] += mapped_interest

func _apply_obstacle_danger(space_state: PhysicsDirectSpaceState3D, current_pos: Vector3, owner_rid: RID) -> void:
	for i in range(ray_count):
		var dir := _ray_directions[i]
		var query := PhysicsRayQueryParameters3D.create(current_pos, current_pos + dir * look_ahead_distance, obstacle_mask)
		if owner_rid.is_valid():
			query.exclude = [owner_rid]

		var result := space_state.intersect_ray(query)
		if result:
			var dist := current_pos.distance_to(result.position)
			var danger_ratio := 1.0 - (dist / look_ahead_distance)
			_danger[i] += (danger_ratio * avoid_weight)

func _choose_best_direction() -> Vector3:
	var best_dir := Vector3.ZERO
	var max_score := -INF

	for i in range(ray_count):
		var score := _interest[i] - _danger[i]

		# Hysteresis: Bias toward our current direction to prevent jitter
		if _current_steering != Vector3.ZERO:
			var alignment := _ray_directions[i].dot(_current_steering.normalized())
			if alignment > 0.7:
				score += 0.15 

		if score > max_score:
			max_score = score
			best_dir = _ray_directions[i]

	return best_dir
