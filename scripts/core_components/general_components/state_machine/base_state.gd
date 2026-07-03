class_name State
extends RefCounted

## Base class for all states controlled by a StateMachine.
##
## This class is a RefCounted object, not a Node, making it lightweight.
## It is designed to be extended to create specific logic (e.g., IdleState, RunState).
##
## Usage:
## 1. Create a new script extending [State].
## 2. Override [method enter], [method exit], [method update], and [method handle_input].
## 3. In [method update] or [method handle_input], return a different [State] instance
##    (accessed via [member state_machine].states["StateName"]) to trigger a transition,
##    or return null to stay in the current state.

# PUBLIC VARIABLES
var state_machine: StateMachine ## Reference to the owning StateMachine.

# VIRTUAL METHODS
func enter(): ## Called when the state becomes active.
	pass


func exit(): ## Called when the state becomes inactive.
	pass


func handle_input(_event: InputEvent) -> State: ## Processes input events; returns a new State or null.
	return null


func update(_delta: float) -> State: ## Processes frame updates; returns a new State or null.
	return null
