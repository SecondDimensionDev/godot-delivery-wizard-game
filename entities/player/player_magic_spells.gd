class_name PlayerMagicSpells
extends Node3D

@export var player: Player
@export var current_spell: Spell

func _process(_delta: float) -> void:
	if current_spell == null:
		return
	
	# Start casting on click
	if Input.is_action_just_pressed("mouse_left"):
		current_spell.start_cast()
		
	# Stop casting on release
	if Input.is_action_just_released("mouse_left"):
		current_spell.stop_cast()


func _physics_process(delta: float) -> void:
	if current_spell:
		if current_spell.is_casting:
			current_spell.process_cast(delta)
			player.player_view_model.animation_control.blend_animation_value("IsCasting", delta, 1.0, 5.0)
			player.animation_control.blend_animation_value("IsCasting", delta, 1.0)
			player.animation_control.blend_animation_value("AimDirection", delta, player.player_camera_controller.normalized_pitch)
		else:
			player.player_view_model.animation_control.blend_animation_value("IsCasting", delta, 0.0, 1.0)
			player.animation_control.blend_animation_value("IsCasting", delta, 0.0)
			player.animation_control.blend_animation_value("AimDirection", delta, 0.0)
