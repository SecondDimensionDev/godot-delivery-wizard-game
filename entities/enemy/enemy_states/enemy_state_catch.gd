## Enemy State - Catch
extends State
## One-shot catch lunge. The actual catch (teleport RPC) already fired in
## Chase.update() before transitioning here; this state just holds the lunge
## animation for attack_linger_ms before vanishing. Holds its own timer --
## states are instantiated once and reused for the node's lifetime (see
## StateMachine._ready), so a per-state member is safe.

# PUBLIC VARIABLES
var enemy: Enemy

# PRIVATE VARIABLES
var _end_ms := 0

# VIRTUAL METHODS
func enter() -> void:
	enemy = state_machine.parent as Enemy
	_end_ms = Time.get_ticks_msec() + enemy.behaviour_data.attack_linger_ms


func update(_delta: float) -> State:
	if Time.get_ticks_msec() >= _end_ms:
		return state_machine.states.get("Gone")
	return null
