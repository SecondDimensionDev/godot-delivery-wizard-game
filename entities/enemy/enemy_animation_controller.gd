class_name EnemyAnimationController
extends Node
## Plays clips on the Enemy's AnimationPlayer, one clip per state.
##
## Unlike the Player's blend-tree-driven components, the ported enemies
## (Listener, Stone Choir) each just play a single clip per StateMachine
## state, so this drives an [AnimationPlayer] directly rather than an
## [AnimationTree]. [member Enemy.enemy_anim_tree] is kept on the Enemy scene
## for future blend-tree-driven enemy types but isn't used here.

# CONSTANTS
const DEFAULT_BLEND := 0.25

# EXPORT VARIABLES
@export var parent: Enemy
@export var anim_player: AnimationPlayer


# PUBLIC FUNCTIONS
func play_clip(clip_name: StringName, blend: float = DEFAULT_BLEND, speed: float = 1.0) -> void: ## Plays a clip by name if present.
	if not anim_player.has_animation(clip_name):
		push_warning("[EnemyAnimationController] clip '%s' missing -- staying on current pose" % clip_name)
		return
	anim_player.play(clip_name, blend, speed)


func play_for_state(state_name: String) -> void: ## Looks up and plays the clip mapped to a StateMachine state name.
	if not parent.behaviour_data or not parent.behaviour_data.state_clip_map.has(state_name):
		return
	var clip_name: String = parent.behaviour_data.state_clip_map[state_name]
	var speed: float = parent.behaviour_data.state_clip_speed_map.get(state_name, 1.0)
	play_clip(clip_name, DEFAULT_BLEND, speed)


func copy_library_from(source_player: AnimationPlayer) -> void: ## Copies every animation from another AnimationPlayer's library into this one.
	if source_player == null:
		return
	var library := anim_player.get_animation_library(&"")
	for clip_name in source_player.get_animation_list():
		if not library.has_animation(clip_name):
			library.add_animation(clip_name, source_player.get_animation(clip_name).duplicate())


func merge_motion_clips(clip_sources: Dictionary, donor_root: Node) -> void: ## Pulls named clips from donor scenes (one clip per file) into this AnimationPlayer's library.
	var library := anim_player.get_animation_library(&"")
	for clip_name: String in clip_sources:
		if anim_player.has_animation(clip_name):
			continue
		var packed := load(clip_sources[clip_name]) as PackedScene
		if packed == null:
			push_warning("[EnemyAnimationController] donor scene missing: %s" % clip_sources[clip_name])
			continue
		var donor := packed.instantiate()
		var donor_anim := donor.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if donor_anim == null or not donor_anim.has_animation(clip_name):
			push_warning("[EnemyAnimationController] clip '%s' not inside %s" % [clip_name, clip_sources[clip_name]])
			donor.free()
			continue
		var clip := donor_anim.get_animation(clip_name).duplicate() as Animation
		_strip_dead_tracks(clip, donor_root)
		library.add_animation(clip_name, clip)
		donor.free()


func force_loop_clips(clip_names: Array[String]) -> void: ## Forces LOOP_LINEAR on clips that ship non-looping, independent of import settings.
	for clip_name in clip_names:
		if anim_player.has_animation(clip_name):
			anim_player.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR


# PRIVATE FUNCTIONS
func _strip_dead_tracks(clip: Animation, donor_root: Node) -> void: # Drops tracks aimed at nodes that don't exist under the real model root.
	for i in range(clip.get_track_count() - 1, -1, -1):
		var node_part := String(clip.track_get_path(i)).get_slice(":", 0)
		if donor_root.get_node_or_null(node_part) == null:
			clip.remove_track(i)
