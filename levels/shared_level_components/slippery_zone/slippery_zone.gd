class_name SlipperyZone
extends Area3D

## Drop-in floor zone that reduces the grip of players inside it. Fully standalone: on
## overlap it calls enter_slip_zone/exit_slip_zone on any body that implements them
## (Player does) -- no groups, no RPCs. The effect itself is applied locally by each
## player's OWNING peer (players are owner-authoritative), so peers stay in agreement
## for free: same input, same slip, same motion.

# EXPORT VARIABLES
@export_range(0.05, 1.0) var slip_factor := 0.1 ## 1.0 = normal grip, lower = slidier (ice ~0.1).


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


# PRIVATE FUNCTIONS
func _on_body_entered(body: Node3D) -> void:
	if body.has_method("enter_slip_zone"):
		body.enter_slip_zone(slip_factor)


func _on_body_exited(body: Node3D) -> void:
	if body.has_method("exit_slip_zone"):
		body.exit_slip_zone(slip_factor)
