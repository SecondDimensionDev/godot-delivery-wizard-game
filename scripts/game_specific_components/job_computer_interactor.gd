class_name JobComputerInteractor
extends Node

## Lets the local player activate a JobComputer ("crystal ball") when close to and
## roughly facing its screen. Distance + facing dot test, no raycast node needed for
## one static prop -- same spirit as Cargo's own aim check. Attach as a child of Player;
## wire `player`/`camera` in the editor.

# CONSTANTS
const INTERACT_RANGE := 3.0
const INTERACT_FACING := 0.85

# EXPORT VARIABLES
@export var player: Player
@export var camera: Camera3D


# BUILT-IN VIRTUAL METHODS
func _unhandled_input(event: InputEvent) -> void:
	if not player.is_multiplayer_authority():
		return
	if event.is_action_pressed("interact"):
		_try_interact()


# PRIVATE FUNCTIONS
func _try_interact() -> void:
	var computer := get_tree().get_first_node_in_group("job_computer") as JobComputer
	if computer == null:
		return # not in the lobby
	var eye := camera.global_position
	var to_screen := computer.screen_position() - eye
	if to_screen.length() > INTERACT_RANGE:
		return
	var look := -camera.global_transform.basis.z
	if look.dot(to_screen.normalized()) < INTERACT_FACING:
		return
	computer.activate(multiplayer.get_unique_id() == 1)
