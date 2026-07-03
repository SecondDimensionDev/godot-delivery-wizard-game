@icon("uid://bv1ydtultdjrt")
class_name TopDownSpriteFlip
extends Node
## Flips a visual node based on movement direction.
##
## This component monitors a [TopDownMovement] component and automatically
## applies horizontal or vertical flipping to a target [Sprite2D] or
## [AnimatedSprite2D] based on the current velocity.

# ENUMS
enum FacingMode { MOVEMENT_INTENT, ACTUAL_VELOCITY, AIM_DIRECTION, TARGETER }

# EXPORT VARIABLES
@export_group("References")
@export var target_sprite: Node2D ## The sprite to flip (Sprite2D or AnimatedSprite2D).
@export var movement_component: TopDownMovement ## The component supplying the movement vector.
@export var physics_body: CharacterBody2D ## For ACTUAL_VELOCITY.
@export var player_controller: TopDownPlayerController ## For AIM_DIRECTION.
@export var targeter_component: TopDownMoveTargeter ## For TARGETER

@export_group("Settings")
@export var facing_mode: FacingMode = FacingMode.MOVEMENT_INTENT ## What dictates the flip direction?
@export var flip_horizontal: bool = true ## Should the sprite flip left/right?
@export var flip_vertical: bool = false ## Should the sprite flip up/down?
@export var default_facing_right: bool = true ## True if the original art faces right.


# BUILT-IN VIRTUAL METHODS
func _physics_process(_delta: float) -> void:
	_update_flip()


# PRIVATE FUNCTIONS
func _update_flip() -> void:
	if not target_sprite:
		return

	var direction := Vector2.ZERO
	
	match facing_mode:
		FacingMode.MOVEMENT_INTENT:
			if movement_component: direction = movement_component.current_direction
		FacingMode.ACTUAL_VELOCITY:
			if physics_body: direction = physics_body.velocity
		FacingMode.AIM_DIRECTION:
			if player_controller: direction = player_controller.aim_direction
		FacingMode.TARGETER:
			if targeter_component: direction = target_sprite.global_position.direction_to(targeter_component.target_position)
	
	if direction == Vector2.ZERO:
		return
	
	if flip_horizontal and "flip_h" in target_sprite:
		if direction.x > 0:
			target_sprite.flip_h = not default_facing_right
		elif direction.x < 0:
			target_sprite.flip_h = default_facing_right
	
	if flip_vertical and "flip_v" in target_sprite:
		if direction.y > 0:
			target_sprite.flip_v = not default_facing_right
		elif direction.y < 0:
			target_sprite.flip_v = default_facing_right
