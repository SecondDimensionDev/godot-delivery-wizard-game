class_name GameplayManager
extends LocalStateManager

# PUBLIC VARIABLES


# VIRTUAL BUILT-IN FUNCTIONS


# PUBLIC FUNCTIONS


# PRIVATE FUNCTIONS
func _state_changed(old_state_name: String, new_state_name: String) -> void:
	EventBus.gameplay_state.gameplay_state_changed.emit(old_state_name, new_state_name)
