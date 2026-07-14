class_name Enemy
extends CharacterBody3D

# SIGNALS


# EXPORT VARIABLES
@export_group("Enemy Visuals")
@export var enemy_model: Node3D
@export_group("Enemy Animation Components")
@export var enemy_skeleton: Skeleton3D
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


# PUBLIC VARIABLES


# PRIVATE VARIABLES


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	pass


# PUBLIC FUNCTIONS


# PRIVATE FUNCTIONS
