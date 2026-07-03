@icon("uid://3mlg8wmxmykk")
class_name TopDownAnimator
extends Node
## Generates and plays directional animation strings.
##
## This component reads the [TopDownMovement] state and constructs animation
## strings (e.g., "walk_up", "idle_right"). It works with both [AnimationPlayer]
## and [AnimatedSprite2D] by utilizing duck typing on the play() method.[br]
## [br]
## Supports an override system for actions like attacking or casting.

# ENUMS
enum DirectionMethod {NONE, DIR_2, DIR_4, DIR_8}

# EXPORT VARIABLES
@export_group("References")
@export var target_animator: Node ## The AnimationPlayer or AnimatedSprite2D.
@export var movement_component: TopDownMovement ## The component supplying movement data.

@export_group("Animation Naming")
@export var append_direction: DirectionMethod = DirectionMethod.NONE ## Which diretion string to append to animations.
@export var use_compass_directions: bool = false ## Convert "right" to "E", useful for 8 directional animations
@export var base_idle_name: String = "idle" ## The prefix for the idle animation.
@export var base_move_name: String = "walk" ## The prefix for the moving animation.

# PUBLIC VARIABLES
var is_override_active: bool = false ## True if a custom animation is overriding default states.

# PRIVATE VARIABLES
var _current_facing: String = "down" # Defaults to facing the camera.
var _current_anim: String = ""
var _override_anim_name: String = ""
var _override_uses_direction: bool = true


# BUILT-IN VIRTUAL METHODS
func _physics_process(_delta: float) -> void:
	_update_animation()


# PUBLIC FUNCTIONS
func play_animation(anim_name: String, use_direction: bool = true) -> void: ## Forces a specific animation to play until cleared.
	_override_anim_name = anim_name
	_override_uses_direction = use_direction
	is_override_active = true
	_current_anim = "" # Force re-evaluation next frame


func reset_animation() -> void: ## Resumes standard idle/walk animation logic.
	_override_anim_name = ""
	is_override_active = false
	_current_anim = "" # Force re-evaluation next frame


# PRIVATE FUNCTIONS
func _update_animation() -> void: # Calculates state and direction to play the correct animation.
	if not target_animator or not movement_component:
		return
		
	var direction := movement_component.current_direction
	var is_moving := direction != Vector2.ZERO
	
	# Update facing direction if moving so we remember where to face when stopping
	if is_moving and append_direction != DirectionMethod.NONE:
		_current_facing = _get_direction_string(direction)
	
	var base_state := ""
	var apply_direction := false
	
	if is_override_active:
		base_state = _override_anim_name
		apply_direction = _override_uses_direction and append_direction != DirectionMethod.NONE
	else:
		base_state = base_move_name if is_moving else base_idle_name
		apply_direction = append_direction != DirectionMethod.NONE
		
	var anim_to_play := base_state
	
	if apply_direction:
		anim_to_play = base_state + "_" + _current_facing
		
	if anim_to_play != _current_anim:
		if target_animator.has_method("play"):
			target_animator.play(anim_to_play)
			_current_anim = anim_to_play


func _get_direction_string(dir: Vector2) -> String: # Converts a vector into a string, using the appropriate helper function
	match append_direction:
		DirectionMethod.DIR_2:
			return _get_2_way_string(dir)
		DirectionMethod.DIR_4:
			return _get_4_way_string(dir)
		DirectionMethod.DIR_8:
			return _get_8_way_string(dir)
		_:
			return ""


func _get_2_way_string(dir: Vector2) -> String: # Converts a vector into a 2-way direction string.
	var return_dir: String
	if dir.x > 0:
		return_dir = "right"
	else:
		return_dir = "left"
	
	if use_compass_directions:
		return _convert_direction_type(return_dir)
	else:
		return return_dir


func _get_4_way_string(dir: Vector2) -> String: # Converts a vector into a 4-way direction string.
	var return_dir: String
	if abs(dir.x) > abs(dir.y):
		return_dir = "right" if dir.x > 0 else "left"
	else:
		return_dir = "down" if dir.y > 0 else "up"
		
	if use_compass_directions:
		return _convert_direction_type(return_dir)
	else:
		return return_dir


func _get_8_way_string(dir: Vector2) -> String: # Converts a vector into a 8-way compass direction string.
	if dir.is_zero_approx():
		return "Idle"
		
	# Array ordered by angle starting from Right/East (0 radians) going clockwise
	var compass = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
	
	# Divide the angle by 45 degrees (PI/4), round it, and use posmod to wrap negatives
	var index = posmod(int(round(dir.angle() / (PI / 4.0))), 8)
	
	return compass[index]


func _convert_direction_type(dir_string: String) -> String: # Converts "right" into "E" and vice versa.
	match dir_string:
		"left":
			return "W"
		"right":
			return "E"
		"up":
			return "N"
		"down":
			return "S"
		"N":
			return "up"
		"S":
			return "down"
		"E":
			return "right"
		"W":
			return "left"
		"NE":
			return "up_right"
		"SE":
			return "down_right"
		"NW":
			return "up_left"
		"SW":
			return "down_left"
		_:
			return dir_string
