class_name EnemyNavigationController
extends Node
## Thin wrapper around a NavigationAgent3D for the Enemy's pathfinding.
##
## Configures the agent's radius from [member Enemy.behaviour_data] on ready.
## With no NavigationRegion3D/baked navmesh in a level, NavigationAgent3D
## degrades gracefully to a straight line at the target -- no extra fallback
## logic is required here.

# EXPORT VARIABLES
@export var parent: Enemy
@export var nav_agent: NavigationAgent3D


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	if parent and parent.behaviour_data:
		nav_agent.radius = parent.behaviour_data.catch_range


# PUBLIC FUNCTIONS
func set_target(target_position: Vector3) -> void: ## Sets the point the agent should path toward.
	nav_agent.target_position = target_position


func get_next_step() -> Vector3: ## Returns the next waypoint along the current path.
	return nav_agent.get_next_path_position()


func is_target_reached() -> bool: ## Whether the agent has arrived at its current target.
	return nav_agent.is_target_reached()
