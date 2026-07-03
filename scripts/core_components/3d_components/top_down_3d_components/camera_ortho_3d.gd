@tool
class_name OrthoCamera3D
extends Camera3D
## A 3D Orthogonal Camera component for pseudo-2D top-down and isometric games.
##
## Manages following a target, manual pan-dragging, and editor-driven
## perspective configuration (tilt, yaw, and distance). It enforces orthogonal
## projection and handles smoothing independently of physics.

# EXPORT VARIABLES
@export_group("Targeting")
@export var follow_target: bool = true
@export var target_node: Node3D ## The specific Node3D this camera should follow.
@export var follow_speed: float = 10.0 ## How smoothly the camera lerps to the target.

@export_group("Perspective")
@export var use_orthogonal_camera: bool = true
@export var ortho_zoom_size: float = 10.0: ## Controls the scale/zoom of the orthogonal view.
	set(value):
		ortho_zoom_size = value
		size = ortho_zoom_size
@export var camera_distance: float = 20.0: ## Physical distance backward from the target focus point.
	set(value):
		camera_distance = value
		if is_inside_tree():
			_update_camera_transform()
@export var tilt_angle_degrees: float = 45.0: ## The downward pitch angle of the camera.
	set(value):
		tilt_angle_degrees = value
		if is_inside_tree():
			_update_camera_transform()
@export var yaw_angle_degrees: float = 45.0: ## The rotational angle around the vertical axis.
	set(value):
		yaw_angle_degrees = value
		if is_inside_tree():
			_update_camera_transform()

@export_group("Panning")
@export var pan_drag_enabled: bool = false ## If true, allows manual camera panning.
@export var pan_button: MouseButton = MOUSE_BUTTON_RIGHT ## Mouse button used to trigger panning.
@export var pan_speed: float = 0.05 ## Sensitivity of the pan movement.

# PUBLIC VARIABLES
var current_focus_position: Vector3 = Vector3.ZERO ## The central point the camera is currently looking at.
var target_focus_position: Vector3 = Vector3.ZERO ## The point the camera is trying to look at.

# PRIVATE VARIABLES
var _pan_offset: Vector3 = Vector3.ZERO
var _is_dragging: bool = false

# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	# Enforce orthogonal projection on initialization
	if use_orthogonal_camera:
		projection = Camera3D.PROJECTION_ORTHOGONAL
		size = ortho_zoom_size
	else:
		projection = Camera3D.PROJECTION_PERSPECTIVE
	
	if target_node:
		current_focus_position = target_node.global_position
		
	target_focus_position = current_focus_position
		
	# Unconditionally apply the transform once the node is safely in the tree.
	if is_inside_tree():
		_update_camera_transform()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_process_following(delta)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not pan_drag_enabled:
		return
		
	if event is InputEventMouseButton and event.button_index == pan_button:
		_is_dragging = event.is_pressed()
	
	elif event is InputEventMouseMotion and _is_dragging:
		# Project the camera's local axes onto the horizontal XZ plane
		# This prevents the camera from digging into the ground or flying into the sky
		var right_axis := global_transform.basis.x
		right_axis.y = 0.0
		right_axis = right_axis.normalized()
		
		var forward_axis := -global_transform.basis.z
		forward_axis.y = 0.0
		
		# Fallback just in case the camera is looking perfectly straight down
		if forward_axis.length_squared() < 0.001: 
			forward_axis = global_transform.basis.y
			forward_axis.y = 0.0
			
		forward_axis = forward_axis.normalized()
		
		var drag_movement : Vector3 = (right_axis * -event.relative.x * pan_speed) + (forward_axis * event.relative.y * pan_speed)
		
		if is_instance_valid(target_node):
			# If we have a target, mouse dragging offsets us from that target
			_pan_offset += drag_movement
		else:
			# If we are free-camming, mouse dragging permanently moves our target focus
			target_focus_position += drag_movement


# PUBLIC FUNCTIONS
func reset_pan_offset() -> void:
	## Clears any manual panning done by the player and recenters on the target.
	_pan_offset = Vector3.ZERO


# PRIVATE FUNCTIONS
func _process_following(delta: float) -> void:
	if is_instance_valid(target_node) and follow_target:
		# Constantly update our target focus based on the moving target node + our manual offset
		target_focus_position = target_node.global_position + _pan_offset
	
	# Only do math if we actually need to move
	if current_focus_position.distance_squared_to(target_focus_position) > 0.001:
		current_focus_position = current_focus_position.lerp(target_focus_position, follow_speed * delta)
		_update_camera_transform()


func _update_camera_transform() -> void: # Calculates and applies the rotation and positional offset.
	# 1. Apply Rotations (Tilt = X axis, Yaw = Y axis)
	rotation_degrees = Vector3(-tilt_angle_degrees, yaw_angle_degrees, 0.0)
	
	# 2. Apply Distance Offset
	# We take the backward direction of our new rotation and multiply by our desired distance.
	var offset_vector := global_transform.basis.z * camera_distance
	
	# 3. Apply Final Position
	global_position = current_focus_position + offset_vector
