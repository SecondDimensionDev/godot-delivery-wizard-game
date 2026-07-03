class_name FPSCameraController
extends Node
## Handles first-person mouse look and camera anti-jitter.
##
## Rotates the main body for yaw, and a specific pitch node for looking up/down.
## Also smoothly syncs a detached head node to an anchor to prevent physics jitter.

# EXPORT VARIABLES
@export_group("Target Nodes")
@export var body: CharacterBody3D ## The main physics body to rotate (Yaw).
@export var pitch_node: Node3D ## The node to rotate up and down (Pitch).
@export var camera_anchor: Marker3D ## The physical attachment point on the body.
@export var dynamic_head: Node3D ## The detached visual head/camera rig.
@export var player_camera: FPSCameraViewfinder

@export_group("Settings")
@export var mouse_sensitivity: float = 0.002 ## Multiplier for mouse movement.
@export var pitch_limit_degrees: float = 89.0 ## Maximum up/down look angle.

# PUBLIC VARIABLES
var is_enabled: bool = true ## Toggles camera movement on or off.

# BUILT-IN VIRTUAL METHODS
func _unhandled_input(event: InputEvent) -> void:
	if not is_enabled or Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
		
	if event is InputEventMouseMotion:
		
		# 1. Calculate the sensitivity modifier based on zoom
		var zoom_modifier := 1.0
		if is_instance_valid(player_camera):
			zoom_modifier = player_camera.fov / player_camera.base_fov
			
		# 2. Apply the modifier to the base sensitivity
		var current_sensitivity = mouse_sensitivity * zoom_modifier

		# 3. Use the new sensitivity for rotation
		body.rotate_y(-event.relative.x * current_sensitivity)
		pitch_node.rotate_x(-event.relative.y * current_sensitivity)
		
		## Rotate the main body left and right (Yaw)
		#body.rotate_y(-event.relative.x * mouse_sensitivity)
		#
		## Rotate the pitch node up and down (Pitch)
		#pitch_node.rotate_x(-event.relative.y * mouse_sensitivity)
		
		# Clamp the pitch to prevent doing backflips
		var limit := deg_to_rad(pitch_limit_degrees)
		pitch_node.rotation.x = clamp(pitch_node.rotation.x, -limit, limit)

func _process(_delta: float) -> void:
	# --- THE ANTI-JITTER SYNC ---
	# Move the detached head to the anchor's exact position every visual frame
	if is_instance_valid(dynamic_head) and is_instance_valid(camera_anchor):
		dynamic_head.global_position = camera_anchor.global_position
		# Sync the Y rotation because the body handles Yaw
		dynamic_head.global_rotation.y = body.global_rotation.y
