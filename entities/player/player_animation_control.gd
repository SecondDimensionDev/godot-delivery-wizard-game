class_name PlayerAnimationControl
extends Node

@export var anim_tree: AnimationTree

func set_animation_value(animation_type: String, new_value: float) -> void:
	var anim_parameter: String = "parameters/IsCrouching/blend_amount"
	
	match animation_type:
		"IsCrouching":
			anim_parameter = "parameters/IsCrouching/blend_amount"
		"IsAirborne":
			anim_parameter = "parameters/IsAirborne/blend_amount"
		"IsLanding":
			anim_parameter = "parameters/LandAnimationTimeline/seek_request"
		_:
			push_warning("Animation type not found: ", animation_type)
			return
	
	anim_tree.set(anim_parameter, new_value)
	


func blend_animation_value(animation_type: String, delta: float, target_value: float, blend_speed: float = 10.0) -> void:
	var anim_parameter: String = "parameters/IsCrouching/blend_amount"
	
	match animation_type:
		"IsCrouching":
			anim_parameter = "parameters/IsCrouching/blend_amount"
		"IsAirborne":
			anim_parameter = "parameters/IsAirborne/blend_amount"
		"IsCasting":
			anim_parameter =  "parameters/SingleSpellCast/blend_amount"
		"AimDirection":
			anim_parameter = "parameters/PistolAimDirection/blend_position"
		_:
			push_warning("Animation type not found: ", animation_type)
			return
	
	# 1. Get the current float from the tree
	var current_blend: float = anim_tree.get(anim_parameter)
	
	# 2. Use the global lerpf() function instead of a method
	var new_blend: float = lerpf(current_blend, target_value, blend_speed * delta)
	
	# 3. Set the new smoothed position
	anim_tree.set(anim_parameter, new_blend)


func blend_animation_direction(animation_type: String, delta: float, input_dir: Vector2, blend_speed: float = 10.0) -> void:
	var anim_parameter: String = "parameters/GroundMovement/blend_position"
	
	match animation_type:
		"Move":
			anim_parameter = "parameters/GroundMovement/blend_position"
		"Crouch":
			anim_parameter = "parameters/CrouchMovement/blend_position"
		_:
			push_warning("Animation type not found: ", animation_type)
			return
	
	# 1. Get the current position from the tree
	var current_blend: Vector2 = anim_tree.get(anim_parameter)
	
	# 2. Lerp towards the target input. (Adjust 10.0 to make the blend faster/slower)
	var new_blend: Vector2 = current_blend.lerp(input_dir, blend_speed * delta)
	
	# 3. Set the new smoothed position
	anim_tree.set(anim_parameter, new_blend)


func  switch_animation_transition_state(animation_type: String, new_state: String,) -> void:
	var anim_parameter: String = "parameters/GroundAirState/transition_request"
	
	match animation_type:
		"GroundedState":
			anim_parameter = "parameters/GroundAirState/transition_request"
		_:
			push_warning("Animation type not found: ", animation_type)
			return
	anim_tree.set(anim_parameter, new_state)


func request_animation_one_shot(animation_type: String, fade_out: bool = false, abort: bool = false) -> void:
	var anim_parameter: String = "parameters/JumpOneShot/request"
	
	match animation_type:
		"Jump":
			anim_parameter = "parameters/JumpOneShot/request"
		"Land":
			anim_parameter = "parameters/LandOneShot/request"
		_:
			push_warning("Animation type not found: ", animation_type)
			return
	
	if abort:
		anim_tree.set(anim_parameter, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	elif fade_out:
		anim_tree.set(anim_parameter, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	else:
		anim_tree.set(anim_parameter, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
