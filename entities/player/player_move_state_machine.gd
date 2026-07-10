## Example State Machine
extends StateMachine

#export var debug_label: Label

func blend_animation_value(animation_type: String, delta: float, target_value: float, blend_speed: float = 10.0) -> void:
	var anim_parameter: String = ""
	
	match animation_type:
		"IsCrouching":
			anim_parameter = "parameters/IsCrouching/blend_amount"
		_:
			push_warning("Animation type not found: ", animation_type)
			return
	
	# 1. Get the current float from the tree
	var current_blend: float = parent.anim_tree.get(anim_parameter)
	
	# 2. Use the global lerpf() function instead of a method
	var new_blend: float = lerpf(current_blend, target_value, blend_speed * delta)
	
	# 3. Set the new smoothed position
	parent.anim_tree.set(anim_parameter, new_blend)


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
	var current_blend: Vector2 = parent.anim_tree.get(anim_parameter)
	
	# 2. Lerp towards the target input. (Adjust 10.0 to make the blend faster/slower)
	var new_blend: Vector2 = current_blend.lerp(input_dir, blend_speed * delta)
	
	# 3. Set the new smoothed position
	parent.anim_tree.set(anim_parameter, new_blend)
