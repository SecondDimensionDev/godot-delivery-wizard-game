class_name WeaponBobComponent
extends Node3D
## Applies a procedural figure-8 walking bob based on a character's velocity.
##
## Dynamically scales both the frequency (speed) and amplitude (height) 
## of the bob based on the character's actual physical movement speed.

# EXPORT VARIABLES
@export var character: CharacterBody3D ## The physics body to monitor for velocity.
@export var bob_frequency: float = 0.34 ## Base multiplier for how fast the wave oscillates relative to speed.
@export var bob_amount: float = 0.0015 ## Multiplier for how high the weapon bounces relative to speed.
@export var bob_speed: float = 9.0 ## How fast it interpolates to the target position.
@export var is_enabled: bool = true ## Toggles the bob effect.

# PRIVATE VARIABLES
var _bob_time: float = 0.0 # Our custom clock that only ticks when moving

# BUILT-IN VIRTUAL METHODS
func _process(delta: float) -> void:
	if not is_enabled or not is_instance_valid(character):
		return
		
	var target_position := Vector3.ZERO
	
	# Calculate actual 2D horizontal speed (ignoring vertical jumping/falling)
	var horizontal_velocity := Vector2(character.velocity.x, character.velocity.z)
	var current_speed := horizontal_velocity.length()
	
	# Only bob if moving and grounded
	if character.is_on_floor() and current_speed > 0.5:
		
		# 1. Advance the wave phase based on actual speed instead of real-world time
		_bob_time += delta * current_speed * bob_frequency
		
		# 2. Scale the bounce height so running creates a larger physical bounce
		var dynamic_amount := current_speed * bob_amount
		
		# Figure-8 pattern: X oscillates at half the frequency of Y
		target_position.y = sin(_bob_time * PI) * dynamic_amount
		target_position.x = cos(_bob_time * PI / 2.0) * dynamic_amount
		
	# Smoothly move to the calculated position (or back to center if stopped)
	position = position.lerp(target_position, bob_speed * delta)
