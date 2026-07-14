class_name MultiplayerGuard
extends Node
## Disables local-only systems for network puppets.
##
## Add nodes to the exported arrays to automatically disable their processing,
## hide their UI, or turn off their cameras if the local client is not the authority.

@export_group("Puppet Disables")
@export var logic_nodes_to_disable: Array[Node] ## Nodes that will have their process, physics, and input turned off.
@export var ui_to_hide: Array[CanvasLayer] ## CanvasLayers that will be hidden.
@export var cameras_to_turn_off: Array[Camera3D] ## Cameras that will have 'current' set to false.
@export var rigid_bodies_to_freeze: Array[RigidBody3D] ## Physics bodies that will become kinematic puppets.

func _ready() -> void:
	# Check if the parent node (the Player CharacterBody3D) is owned by the local client.
	# If we DO have authority, we just return and let everything run normally.
	if get_parent().is_multiplayer_authority():
		return
	
	get_parent().ready.connect(_disable_puppet_systems, CONNECT_ONE_SHOT)


func _disable_puppet_systems() -> void:
	_disable_logic_nodes()
	_hide_ui()
	_deactivate_cameras()
	_freeze_rigid_bodies()


func _disable_logic_nodes() -> void:
	for node in logic_nodes_to_disable:
		if node:
			node.set_process(false)
			node.set_physics_process(false)
			node.set_process_unhandled_input(false)
			node.set_process_input(false)
			node.set_process_unhandled_key_input(false)
			node.set_process_shortcut_input(false)


func _hide_ui() -> void:
	for ui_layer in ui_to_hide:
		if ui_layer:
			ui_layer.hide()


func _deactivate_cameras() -> void:
	for cam in cameras_to_turn_off:
		if cam:
			cam.current = false


func _freeze_rigid_bodies() -> void:
	for body in rigid_bodies_to_freeze:
		if body:
			body.freeze = true
			body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
