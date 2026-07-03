## SELECT GAME MODE MENU SCRIPT
extends Control

@export_group("Standard Buttons")
@export var start_button: Button
@export var back_button: Button

@export_group("Load Game Buttons")
@export var show_continue_run: bool = false
@export var continue_button: Button
@export var show_load_game: bool = false
@export var load_games_button: Button

@export_group("Sound Effects")
@export var confirm_sound: AudioStream
@export var back_sound: AudioStream


func _ready() -> void:
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
		
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	
	if continue_button:
		continue_button.pressed.connect(_on_continue_button_pressed)
	
	if load_games_button:
		load_games_button.pressed.connect(_on_load_game_button_pressed)

	process_mode = Node.PROCESS_MODE_INHERIT
	
	EventBus.system_state.loading_started.connect(_loading_started)
	
	if continue_button and show_continue_run and SessionManager.has_saved_run():
		continue_button.visible = true
	elif continue_button:
		continue_button.visible = false
	
	if load_games_button and show_load_game:
		load_games_button.visible = true
	elif load_games_button:
		load_games_button.visible = false


func _on_start_button_pressed() -> void:
	AudioPlayer.sfx.play_ui_sound(confirm_sound)
	EventBus.menu_navigation.confirm_start_game.emit()


func _on_continue_button_pressed() -> void:
	AudioPlayer.sfx.play_ui_sound(confirm_sound)
	EventBus.menu_navigation.confirm_continue_game.emit()


func _on_back_button_pressed() -> void:
	AudioPlayer.sfx.play_ui_sound(back_sound)
	EventBus.menu_navigation.request_go_back.emit()


func _on_load_game_button_pressed() -> void:
	AudioPlayer.sfx.play_ui_sound(back_sound)
	EventBus.menu_navigation.request_goto_load_game.emit()


func _loading_started() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED # Disable Processing
	set_process_unhandled_input(false) # Disable _unhandled_input
	set_process_input(false) # Disable _gui_inputs
