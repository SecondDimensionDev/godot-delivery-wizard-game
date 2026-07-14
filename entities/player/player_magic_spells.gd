class_name PlayerMagicSpells
extends Node3D

@export var player: Player
@export var current_spell: Spell

func _process(_delta: float) -> void:
	if current_spell == null:
		return
	
	# ONLY the local player detects their own mouse clicks
	if player.is_multiplayer_authority():
		if Input.is_action_just_pressed("mouse_left"):
			rpc("_network_start_cast")
			
		if Input.is_action_just_released("mouse_left"):
			rpc("_network_stop_cast")


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


@rpc("any_peer", "call_local", "reliable")
func _network_start_cast() -> void:
	current_spell.start_cast()


@rpc("any_peer", "call_local", "reliable")
func _network_stop_cast() -> void:
	current_spell.stop_cast()
