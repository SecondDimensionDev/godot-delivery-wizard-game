class_name PauseManager
extends LocalStateManager

@export_group("Pause Menu Parent")
@export var pause_menu_parent: CanvasLayer

@export_group("Pause Menu Scenes")
@export var main_menu_scene: Control
@export var options_scene: Control
@export var help_scene: Control
@export var exit_to_menu_scene: Control
@export var quit_game_scene: Control

func _state_changed(old_state_name: String, new_state_name: String) -> void:
	EventBus.menu_navigation.pause_menu_state_changed.emit(old_state_name, new_state_name)
