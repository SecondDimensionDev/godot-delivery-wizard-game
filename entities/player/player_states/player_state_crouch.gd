## Player State - Crouch
extends State
## Handles the player crouching on the ground.
##
## Applies a negative speed modifier to the movement controller.
## Blocks jumping while crouched. Transitions to Idle or Walk when released.

# PUBLIC VARIABLES
var player: Player
var controller: FPSMovementController
var crouch_multiplier: float = 0.5 ## How much slower the player moves while crouching.
var fov_component: FPSCameraViewfinder
var crouch_component: PlayerCrouchComponent

var next_state: State


# VIRTUAL METHODS
func enter() -> void:
	player = state_machine.parent as Player
	if is_instance_valid(player.lean_component):
		player.lean_component.can_lean = true
	controller = player.movement_controller
	fov_component = player.player_camera as FPSCameraViewfinder
	crouch_component = player.crouch_component
	
	crouch_multiplier = controller.crouch_mulitplier
	fov_component.reset_fov()
	crouch_component.crouch()
	player.animation_player.play("animation_library/Crouch_Fwd")


func exit() -> void:
	crouch_component.uncrouch()


func handle_input(event: InputEvent) -> State:
	if event.is_action_released("crouch"):
		# Ceiling Check
		if crouch_component.can_stand():
			var input_dir := Input.get_vector("strafe_left", "strafe_right", "walk_forwards", "walk_backwards")
			if input_dir == Vector2.ZERO:
				return state_machine.states.get("Idle")
			else:
				return state_machine.states.get("Walk")
		# If we can't stand, we stay in the CrouchState even though the key is released!
		
	return null


func update(delta: float) -> State:
	controller.apply_gravity(delta)
	
	if not player.is_on_floor():
		return state_machine.states.get("Air")
		
	var input_dir := Input.get_vector("strafe_left", "strafe_right", "walk_forwards", "walk_backwards")
	
	# Continuous check: If the user released the key previously but was stuck under a ceiling, 
	# automatically stand them up the moment they walk out into the open.
	if not Input.is_action_pressed("crouch") and crouch_component.can_stand():
		if input_dir == Vector2.ZERO:
			return state_machine.states.get("Idle")
		else:
			return state_machine.states.get("Walk")
	
	var direction := (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	controller.move(direction, delta, crouch_multiplier)
	
	return null
