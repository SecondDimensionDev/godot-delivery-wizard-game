class_name StabilizeComponent
extends Node

## Non-grabbing players can damp the shared cargo's velocity (the "stabilize" verb) --
## a legitimate "one person off the box" role. Fires a request at the cargo; the server
## validates aim/range/not-grabbing/cooldown and does the actual damping (see
## Cargo.request_stabilize). Attach as a child of Player; wire `player`/`carry_spell` in
## the editor.

# EXPORT VARIABLES
@export var player: Player
@export var carry_spell: CarrySpell ## Optional: if set, stabilizing is blocked while grabbing.


# BUILT-IN VIRTUAL METHODS
func _unhandled_input(event: InputEvent) -> void:
	if not player.is_multiplayer_authority():
		return
	if event.is_action_pressed("stabilize"):
		_try_stabilize()


# PRIVATE FUNCTIONS
func _try_stabilize() -> void:
	if carry_spell != null and carry_spell.is_casting:
		return # grabbers don't get to stabilize -- that's the point
	var cargo := get_tree().get_first_node_in_group("cargo") as Cargo
	if cargo == null:
		return
	if multiplayer.is_server():
		cargo.request_stabilize() # host: rpc_id(1) to self is disallowed (call_remote)
	else:
		cargo.request_stabilize.rpc_id(1)
