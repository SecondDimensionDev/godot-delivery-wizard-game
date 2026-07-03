@icon("uid://bqj6hyfpjh5qd")
class_name TopDownPlayerController
extends Node
## Reads player input and sends commands to the appropriate components.
##
## This component acts as the "brain" for the player character, listening
## to the standard input map and translating those inputs into movement
## requests for the [TopDownMovement] component.
## It also listens for specific action buttons and broadcasts them via signals.

# SIGNALS
signal action_pressed(action_name: String) ## Emitted when an action from the action_buttons list is just pressed.
signal action_released(action_name: String) ## Emitted when an action from the action_buttons list is just released.

# EXPORT VARIABLES
@export_group("References")
@export var movement_component: TopDownMovement ## The movement component to send input directions to

@export_group("General Settings")
@export var input_enabled: bool = true ## If false, ignores player input and sends zero movement
@export var action_buttons: Array[String] = [] ## A list of Input Map action names to listen for and broadcast.(Set to 0 to disable).
@export var angle_snap_degrees: float = 4.0 ## Snaps analog input to nearest X degrees (Set to 0 to disable)

@export_group("Aim Settings")
@export var capture_aim: bool = false ## If true, will capture the aim vector from right stick

# PUBLIC VARIABLES
var input_dir:= Vector2.ZERO ## The current vector of the movement keys or left analog stick
var aim_direction:= Vector2.ZERO ## The current vector of the right analog stick (or mouse aim)

# BUILT-IN VIRTUAL METHODS	
func _ready() -> void:
	if not movement_component:
		push_warning("TopDownPlayerController is missing a reference to a TopDownMovement component.")


func _physics_process(_delta: float) -> void:
	_handle_directional_input()


func _unhandled_input(event: InputEvent) -> void:
	_handle_action_input(event)


# PRIVATE FUNCTIONS
func _handle_directional_input() -> void: # Reads the input vector and passes it to the movement component.
	if not movement_component:
		return
		
	if not input_enabled:
		movement_component.set_movement_direction(Vector2.ZERO)
		return
		
	input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if capture_aim:
		aim_direction = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	
	# Apply Angle Snapping
	if angle_snap_degrees > 0.0 and input_dir != Vector2.ZERO:
		var current_angle := input_dir.angle()
		var step := deg_to_rad(angle_snap_degrees)
		var snapped_angle := snappedf(current_angle, step)
		input_dir = Vector2.from_angle(snapped_angle) * input_dir.length()
	
	if capture_aim and angle_snap_degrees > 0.0 and aim_direction != Vector2.ZERO:
		var aim_current_angle := input_dir.angle()
		var aim_step := deg_to_rad(angle_snap_degrees)
		var aim_snapped_angle := snappedf(aim_current_angle, aim_step)
		aim_direction = Vector2.from_angle(aim_snapped_angle) * aim_direction.length()
	
	movement_component.set_movement_direction(input_dir)


func _handle_action_input(event: InputEvent) -> void: # Broadcasts custom action buttons.
	if not input_enabled or action_buttons.is_empty():
		return
		
	for action in action_buttons:
		if event.is_action_pressed(action):
			action_pressed.emit(action)
		elif event.is_action_released(action):
			action_released.emit(action)
