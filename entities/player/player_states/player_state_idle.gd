## Player State - Idle
extends State
## Handles the player standing still on the ground.
##
## Transitions to WalkState when directional input is detected.
## Transitions to AirState if the floor is lost or jump is pressed.

# PUBLIC VARIABLES
var player: Player
var controller: FPSMovementController
var fov_component: FPSCameraViewfinder
var input_dir: Vector2

var next_state: State

# VIRTUAL METHODS
func enter() -> void:
	player = state_machine.parent as Player
	if is_instance_valid(player.lean_component):
		player.lean_component.can_lean = true
	controller = player.movement_controller
	fov_component = player.player_camera as FPSCameraViewfinder
	
	fov_component.reset_fov()


func handle_input(event: InputEvent) -> State:
	if event.is_action_pressed("jump") and player.is_on_floor():
		controller.jump()
		player.animation_control.request_animation_one_shot("Jump")
		player.player_view_model.animation_control.request_animation_one_shot("Jump")
		return state_machine.states.get("Air")
	if event.is_action_pressed("crouch") and player.is_on_floor():
		return state_machine.states.get("Crouch")
	return null


func update(delta: float) -> State:
	controller.apply_gravity(delta)
	
	if not player.is_on_floor():
		return state_machine.states.get("Air")
		
	input_dir = Input.get_vector("strafe_left", "strafe_right", "walk_forwards", "walk_backwards")
	if input_dir != Vector2.ZERO:
		return state_machine.states.get("Walk")
	controller.move(Vector3.ZERO, delta)
	
	player.animation_control.blend_animation_value("IsAirborne", delta, 0.0, 2.5)
	player.animation_control.blend_animation_value("IsCrouching", delta, 0.0)
	player.animation_control.blend_animation_direction("Move", delta, input_dir)
	
	player.player_view_model.animation_control.blend_animation_value("IsAirborne", delta, 0.0, 2.5)
	player.player_view_model.animation_control.blend_animation_value("IsCrouching", delta, 0.0)
	player.player_view_model.animation_control.blend_animation_direction("Move", delta, input_dir)
	return null
