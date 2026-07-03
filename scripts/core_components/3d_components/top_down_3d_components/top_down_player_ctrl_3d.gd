class_name TopDownPlayerController3D
extends Node
## Reads player input and sends 3D movement commands.
##
## Translates 2D screen input into 3D world vectors, supporting both
## absolute world-axis movement and camera-relative movement.

# EXPORT VARIABLES
@export_group("References")
@export var movement_component: TopDownMovement3D ## The component to send input directions to.
@export var reference_camera: Camera3D ## The camera to use for relative movement. Leave empty to auto-find.

@export_group("Settings")
@export var input_enabled: bool = true ## If false, ignores input.
@export var camera_relative_movement: bool = true ## If true, 'up' moves away from the camera.
@export var jump_action_name: String = "jump" ## The Input Map action name for jumping.

# PUBLIC VARIABLES
var input_dir: Vector2 = Vector2.ZERO
var movement_dir: Vector3 = Vector3.ZERO

# BUILT-IN VIRTUAL METHODS
func _physics_process(_delta: float) -> void:
	_handle_movement_input()

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or not movement_component:
		return
		
	# Listen for the jump action and pass the command to the movement component
	if event.is_action_pressed(jump_action_name):
		movement_component.jump()

# PRIVATE FUNCTIONS
func _handle_movement_input() -> void:
	if not movement_component:
		return

	if not input_enabled:
		movement_component.set_movement_direction(Vector3.ZERO)
		return

	# Assuming your InputMap uses these standard action names
	input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir == Vector2.ZERO:
		movement_dir = Vector3.ZERO
		movement_component.set_movement_direction(movement_dir)
		return

	if camera_relative_movement:
		var cam := reference_camera
		if not cam:
			cam = get_viewport().get_camera_3d()

		if cam:
			var cam_forward := -cam.global_transform.basis.z
			cam_forward.y = 0.0
			cam_forward = cam_forward.normalized()

			var cam_right := cam.global_transform.basis.x
			cam_right.y = 0.0
			cam_right = cam_right.normalized()

			movement_dir = (cam_right * input_dir.x + cam_forward * -input_dir.y).normalized()
		else:
			movement_dir = Vector3(input_dir.x, 0.0, input_dir.y).normalized()
	else:
		movement_dir = Vector3(input_dir.x, 0.0, input_dir.y).normalized()

	movement_component.set_movement_direction(movement_dir)
