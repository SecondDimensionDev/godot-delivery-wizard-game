## Enemy State - Gone
extends State
## Vanished after a catch. Waits respawn_delay_ms, then resets to the spawn
## pose and returns to Dormant. Holds its own timer for the same reason as
## Catch (states are instantiated once and reused for the node's lifetime).

# PUBLIC VARIABLES
var enemy: Enemy

# PRIVATE VARIABLES
var _reappear_ms := 0

# VIRTUAL METHODS
func enter() -> void:
	enemy = state_machine.parent as Enemy
	_reappear_ms = Time.get_ticks_msec() + enemy.behaviour_data.respawn_delay_ms


func update(_delta: float) -> State:
	if Time.get_ticks_msec() >= _reappear_ms:
		enemy.respawn()
		return state_machine.states.get("Dormant")
	return null
