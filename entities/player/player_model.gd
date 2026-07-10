extends Node3D

@export_group("Local Visibility")
## Drag the meshes (e.g., the head) you want to hide from the local player here.
@export var meshes_to_hide: Array[VisualInstance3D] 

## Select the render layer you want to move these meshes to.
## This uses Godot's built-in layer checklist in the Inspector!
@export_flags_3d_render var hidden_layer: int 


func _ready() -> void:
	# Check if the root node (PlayerController) belongs to the local client
	if get_parent().is_multiplayer_authority():
		_hide_meshes_from_local_camera()


func _hide_meshes_from_local_camera() -> void:
	for mesh in meshes_to_hide:
		if mesh:
			# Reassign the mesh's visual layer to your chosen 'hidden' layer
			mesh.layers = hidden_layer
