class_name Enemy
extends CharacterBody3D
## Root node for an enemy character.
##
## Acts as a data router: wires component references together and owns the
## mechanics shared by every enemy type (model spawning, multiplayer
## authority/replication, catching a player). Per-type behavior (senses
## tuning, movement speed, animation clip names, state set) all comes from
## [member behaviour_data] and the state scripts assigned on
## [member enemy_state_machine] -- see entities/enemy/*/*_enemy.tscn (e.g. listener/, stone_choir/).

# SIGNALS
signal caught_player(peer_id: int) ## Server-side: this enemy reached this peer's player.

# EXPORT VARIABLES
@export_group("Enemy Behaviour")
@export var behaviour_data: EnemyBehaviourData
@export var respawn_marker: Node3D ## Where a caught player is teleported back to. Assigned per level placement.

@export_group("Enemy Visuals")
@export var enemy_model_scene: PackedScene ## Instantiated on spawn; its Skeleton3D/AnimationPlayer are found and linked automatically.

@export_group("Enemy Animation Components")
@export var enemy_skeleton: Skeleton3D
@export var enemy_anim_player: AnimationPlayer
@export var enemy_anim_tree: AnimationTree
@export_group("Enemy Mulitplayer Components")
@export var enemy_multiplayer_guard: MultiplayerGuard
@export_group("Enemy Behaviour Components")
@export var enemy_state_machine: StateMachine
@export var enemy_senses: EnemySenses
@export var enemy_movement_controller: EnemyMovementController
@export var enemy_animation_controller: EnemyAnimationController
@export var enemy_rotation_controller: EnemyRotationController
@export var enemy_naviagation_controller: EnemyNavigationController
@export_group("Enemy Health Components")
@export var enemy_hit_point_component: HitPointComponent

@export_group("Enemy Audio")
@export var state_audio_paths: Dictionary[String, NodePath] ## State name -> path to the AudioStreamPlayer3D that should be playing during that state (others resolved from this map are stopped).


# PRIVATE VARIABLES
var _spawn_position := Vector3.ZERO
var _spawn_rotation := Quaternion.IDENTITY
var _last_applied_state := ""
var _model_instance: Node3D
var _state_audio_players: Dictionary[String, AudioStreamPlayer3D]


# BUILT-IN VIRTUAL METHODS
func _enter_tree() -> void: ## Enemies are server-controlled, not peer-owned.
	set_multiplayer_authority(1)


func _ready() -> void:
	_spawn_position = global_position
	_spawn_rotation = quaternion
	_spawn_model()
	for state_name in state_audio_paths:
		var player := get_node_or_null(state_audio_paths[state_name]) as AudioStreamPlayer3D
		if player:
			_state_audio_players[state_name] = player


func _process(_delta: float) -> void: ## Mirrors the replicated state on every peer, including the authority.
	if not enemy_state_machine or enemy_state_machine.current_state_name == _last_applied_state:
		return
	_last_applied_state = enemy_state_machine.current_state_name
	if enemy_animation_controller:
		enemy_animation_controller.play_for_state(_last_applied_state)
	if _model_instance:
		_model_instance.visible = _last_applied_state != "Gone"
	_apply_state_audio(_last_applied_state)


# PUBLIC FUNCTIONS
func trigger_catch(player: Node3D) -> void: ## Server-side: catches a player, teleporting them back to respawn_marker.
	var peer_id := player.get_multiplayer_authority()
	caught_player.emit(peer_id)
	if respawn_marker == null:
		push_warning("[Enemy] no respawn_marker assigned -- caught player not teleported")
		return
	_player_catch_effect.rpc(peer_id, respawn_marker.global_position)


func respawn() -> void: ## Resets to the spawn pose and clears sensing state (Gone -> Dormant).
	global_position = _spawn_position
	quaternion = _spawn_rotation
	if enemy_senses:
		enemy_senses.reset()


# PRIVATE FUNCTIONS
func _apply_state_audio(state_name: String) -> void: # Plays the audio mapped to this state, stopping any others in the map.
	if _state_audio_players.is_empty():
		return
	var target: AudioStreamPlayer3D = _state_audio_players.get(state_name)
	for player in _state_audio_players.values():
		if player != target and player.playing:
			player.stop()
	if target and not target.playing:
		target.play()


func _spawn_model() -> void:
	if not enemy_model_scene:
		return

	_model_instance = enemy_model_scene.instantiate() as Node3D
	add_child(_model_instance)

	#enemy_skeleton = _model_instance.find_child("Skeleton3D", true, false) as Skeleton3D
	if behaviour_data:
		_model_instance.rotation.y = deg_to_rad(behaviour_data.mesh_forward_offset_deg)
		_model_instance.scale = Vector3.ONE * behaviour_data.model_scale
		_model_instance.position = behaviour_data.model_offset

	if enemy_anim_player:
		enemy_anim_player.root_node = enemy_anim_player.get_path_to(_model_instance)
		var donor_anim := _model_instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if donor_anim:
			enemy_animation_controller.copy_library_from(donor_anim)
			donor_anim.queue_free()

	if behaviour_data and enemy_animation_controller:
		enemy_animation_controller.merge_motion_clips(behaviour_data.motion_clip_sources, _model_instance)
		enemy_animation_controller.force_loop_clips(behaviour_data.looped_clips)


@rpc("authority", "call_local", "reliable")
func _player_catch_effect(peer_id: int, spawn_pos: Vector3) -> void:
	var active_camera := get_viewport().get_camera_3d()
	if active_camera:
		var shake := active_camera.get_node_or_null("CameraShakeComponent")
		if shake and shake.has_method("shake"):
			shake.shake(0.5, 400)

	if multiplayer.get_unique_id() != peer_id:
		return

	for player in get_tree().get_nodes_in_group("player"):
		if player is Player and player.is_multiplayer_authority():
			(player as Player).teleport_to(spawn_pos)
