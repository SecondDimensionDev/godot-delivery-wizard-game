class_name HubManager
extends LocalStateManager

# PUBLIC VARIABLES


# VIRTUAL BUILT-IN FUNCTIONS


# PUBLIC FUNCTIONS


# PRIVATE FUNCTIONS
func _state_changed(old_state_name: String, new_state_name: String) -> void:
	EventBus.hub_state.hub_state_changed.emit(old_state_name, new_state_name)
