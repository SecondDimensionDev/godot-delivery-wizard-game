## Player State - Run
extends State
## Handles the player sprinting on the ground.
##
## Applies a positive speed modifier to the movement controller.
## Transitions back to WalkState if the sprint action is released,
## or IdleState if movement stops completely.

# PUBLIC VARIABLES
var player: Player
var controller: FPSMovementController
var run_multiplier: float = 1.5 ## How much faster the player runs compared to walking.
var fov_component: FPSCameraViewfinder

var next_state: State

# VIRTUAL METHODS
func enter() -> void:
	player = state_machine.parent as Player
	if is_instance_valid(player.lean_component):
		player.lean_component.can_lean = true
	controller = player.movement_controller
	fov_component = player.player_camera as FPSCameraViewfinder
	
	run_multiplier = controller.run_mulitplier
	fov_component.set_target_fov(86.0)
	player.animation_player.play("animation_library/Walk")

func handle_input(event: InputEvent) -> State:
	if event.is_action_pressed("jump") and player.is_on_floor():
		controller.jump()
		return state_machine.states.get("Air")
		
	if event.is_action_pressed("crouch") and player.is_on_floor():
		return state_machine.states.get("Crouch")
		
	return null

func update(delta: float) -> State:
	controller.apply_gravity(delta)
	
	if not player.is_on_floor():
		return state_machine.states.get("Air")
		
	var input_dir := Input.get_vector("strafe_left", "strafe_right", "walk_forwards", "walk_backwards")
	if input_dir == Vector2.ZERO:
		return state_machine.states.get("Idle")
		
	if not Input.is_action_pressed("run"):
		return state_machine.states.get("Walk")
		
	var direction := (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Pass the multiplier to increase the speed
	controller.move(direction, delta, run_multiplier)
	
	return null
