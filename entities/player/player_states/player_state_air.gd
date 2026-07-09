## Player State - Air
extends State
## Handles the player when jumping or falling.
##
## Applies gravity and checks for landing. Notice we still pass directional 
## input to the controller; the controller decides whether to allow air-strafing 
## based on its 'air_control' export variable.

# PUBLIC VARIABLES
var player: Player
var controller: FPSMovementController
var run_multiplier: float

var next_state: State

# VIRTUAL METHODS
func enter() -> void:
	player = state_machine.parent as Player
	if is_instance_valid(player.lean_component):
		player.lean_component.can_lean = false
	controller = player.movement_controller
	run_multiplier = controller.run_mulitplier
	player.animation_player.play("animation_library/Jump")
	#player.animation_player_states.travel("Jump")

func update(delta: float) -> State:
	controller.apply_gravity(delta)
	
	var input_dir := Input.get_vector("strafe_left", "strafe_right", "walk_forwards", "walk_backwards")
	var direction := (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var current_multiplier := 1.0
	if Input.is_action_pressed("run"):
		current_multiplier = run_multiplier
	
	# Pass the multiplier so we don't lose our sprint speed mid-air
	controller.move(direction, delta, current_multiplier)
	
	if player.is_on_floor():
		if input_dir == Vector2.ZERO:
			return state_machine.states.get("Idle")
		elif Input.is_action_pressed("run"):
			return state_machine.states.get("Run")
		else:
			return state_machine.states.get("Walk")
			
	return null
