class_name PlayerViewModel
extends Node3D

enum HideMode {SHADOWS_ONLY, MOVE_TO_HIDDEN_LAYER}

@export_group("Animation Control")
@export var animation_control: PlayerAnimationControl
@export var bone_bone: CopyTransformModifier3D
@export var spell_beam_pivot: Marker3D
@export var current_spell_beam: MeshInstance3D

@export_group("Local Visibility")
@export var hide_mode: HideMode = HideMode.SHADOWS_ONLY
@export var meshes_to_hide: Array[GeometryInstance3D] 
@export_flags_3d_render var hidden_layer: int 


func _ready() -> void:
	# Check if the root node (PlayerController) belongs to the local client
	if not get_parent().is_multiplayer_authority():
		_hide_meshes_from_local_camera()


func _hide_meshes_from_local_camera() -> void:
	for mesh in meshes_to_hide:
		if mesh:
			if hide_mode == HideMode.SHADOWS_ONLY:
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			elif hide_mode == HideMode.MOVE_TO_HIDDEN_LAYER:
				mesh.layers = hidden_layer
