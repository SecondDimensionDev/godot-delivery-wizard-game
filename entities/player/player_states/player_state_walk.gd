## Player State - Walk
extends State
## Handles the player moving along the ground.
##
## Calculates input direction and passes it to the MovementController.
## Transitions to IdleState if movement stops.

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
		return state_machine.states.get("Air")
	if event.is_action_pressed("crouch") and player.is_on_floor():
		return state_machine.states.get("Crouch")
	return null


func update(delta: float) -> State:
	controller.apply_gravity(delta)
	
	if not player.is_on_floor():
		return state_machine.states.get("Air")
		
	input_dir = Input.get_vector("strafe_left", "strafe_right", "walk_forwards", "walk_backwards")
	if input_dir == Vector2.ZERO:
		return state_machine.states.get("Idle")
		
	if Input.is_action_pressed("run"):
		return state_machine.states.get("Run")
	
	state_machine.blend_animation_value("IsCrouching", delta, 0.0)
	state_machine.blend_animation_direction("Move", delta, input_dir)
	
	# Transform the 2D input into 3D world direction relative to the player's rotation
	var direction := (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	controller.move(direction, delta)
	
	return null


#func _blend_animations(delta: float) -> void:
	## 1. Get the current position from the tree
	#var current_blend: Vector2 = player.anim_tree.get("parameters/GroundMovement/blend_position")
	#
	## 2. Lerp towards the target input. (Adjust 10.0 to make the blend faster/slower)
	#var new_blend: Vector2 = current_blend.lerp(input_dir, 10.0 * delta)
	#
	## 3. Set the new smoothed position
	#player.anim_tree.set("parameters/GroundMovement/blend_position", new_blend)
