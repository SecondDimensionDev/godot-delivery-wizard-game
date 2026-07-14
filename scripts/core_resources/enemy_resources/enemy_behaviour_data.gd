class_name EnemyBehaviourData
extends Resource

## Tunable data for one Enemy "flavor" (e.g. Listener, Stone Choir).
##
## The Enemy components read this instead of hardcoding numbers, so a new
## enemy type is authored by making a new resource + inherited scene rather
## than editing component scripts.

# EXPORT VARIABLES
@export_group("Movement")
@export var move_speed: float = 1.6 ## Metres per second while chasing a sensed target.
@export var turn_rate: float = 6.0 ## Facing slerp rate (radians/sec-ish, exponential).

@export_group("Hearing")
@export var use_hearing: bool = false ## Enables EnemySenses' attention/hearing tracking.
@export var hearing_range: float = 22.0 ## Beyond this, motion makes no impression at all.
@export var agitate_threshold: float = 2.0 ## Attention at which it wakes and turns toward the sound.
@export var chase_threshold: float = 6.0 ## Attention at which it commits and walks at the sound.
@export var attention_decay: float = 1.5 ## Attention lost per second of relative quiet.

@export_group("Sight")
@export var use_sight: bool = false ## Enables EnemySenses' FOV/line-of-sight tracking.
@export var fov_half_angle_deg: float = 50.0 ## Cone half-angle a player must aim within to "see" it.
@export var detect_range: float = 18.0 ## Max distance for the dormant awaken check.
@export var body_height: float = 1.8 ## Sampled (feet/torso/head) when checking if any player can see this enemy.

@export_group("Catch")
@export var catch_range: float = 1.5 ## Horizontal distance to a player that counts as a catch.
@export var attack_linger_ms: int = 900 ## How long the Catch/Attacking state holds before vanishing.
@export var respawn_delay_ms: int = 3000 ## Time spent Gone before reappearing at its spawn point.

@export_group("Animation")
@export var mesh_forward_offset_deg: float = 0.0 ## Correction for the mesh's authored forward axis.
@export var model_scale: float = 1.0 ## Uniform scale correction applied to the spawned model.
@export var model_offset: Vector3 = Vector3.ZERO ## Local position correction applied to the spawned model.
@export var state_clip_map: Dictionary[String, String] ## State name -> AnimationPlayer clip name.
@export var state_clip_speed_map: Dictionary[String, float] ## State name -> playback speed (defaults to 1.0).
@export var motion_clip_sources: Dictionary[String, String] ## Extra clip name -> donor scene path to merge in on spawn.
@export var looped_clips: Array[String] ## Clip names to force into Animation.LOOP_LINEAR on spawn (packs often ship them non-looping).
