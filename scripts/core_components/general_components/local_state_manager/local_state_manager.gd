@icon("uid://drncudjrhjet6")
class_name LocalStateManager
extends Node

## Level-specific local manager object. 
## 
## To handle local game states. Extend for game-specific code.


@export var state_machine: StateMachine ## Reference to the local state machine associated with this manager.

func _ready() -> void:
	state_machine.state_changed.connect(_state_changed)


func _state_changed(old_state_name: String, new_state_name: String) -> void:
	EventBus.system_state.local_state_changed.emit(old_state_name, new_state_name)
