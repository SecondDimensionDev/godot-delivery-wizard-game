class_name MenuManager
extends LocalStateManager

@export_group("Standard Menu Scenes")
@export var main_menu_scene: Control
@export var game_modes_scene: Control
@export var options_scene: Control
@export var help_scene: Control
@export var credit_scene: Control
@export var quit_game_scene: Control

@export_group("Game Prep Scenes")
@export var setup_new_game_scene: Control
@export var load_game_scene: Control
@export var continue_game_scene: Control

@export_group("Multiplayer Scenes")
@export var join_game_scene: Control
@export var host_game_scene: Control
@export var lobby_scene: Control

func _state_changed(old_state_name: String, new_state_name: String) -> void:
	EventBus.menu_navigation.menu_state_changed.emit(old_state_name, new_state_name)
