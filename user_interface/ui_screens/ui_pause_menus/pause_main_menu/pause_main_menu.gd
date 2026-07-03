## PAUSE MAIN MENU SCRIPT
extends Control

@export_group("Buttons")
@export var resume_button: Button
@export var options_button: Button
@export var help_button: Button
@export var quit_to_menu_button: Button
@export var quit_to_desktop_button: Button

@export_group("Sound Effects")
@export var confirm_sound: AudioStream
@export var back_sound: AudioStream


func _ready() -> void:
	if resume_button:
		resume_button.pressed.connect(_on_resume_game_button_pressed)
		
	if options_button:
		options_button.pressed.connect(_on_options_button_pressed)
	
	if help_button:
		help_button.pressed.connect(_on_help_button_pressed)
	
	if quit_to_menu_button:
		quit_to_menu_button.pressed.connect(_on_quit_button_pressed)
	
	if quit_to_desktop_button:
		quit_to_desktop_button.pressed.connect(_on_quit_to_desktop_button_pressed)


func _on_resume_game_button_pressed() -> void:
	AudioPlayer.sfx.play_ui_sound(confirm_sound)
	EventBus.menu_navigation.request_resume_game.emit()


func _on_options_button_pressed() -> void:
	AudioPlayer.sfx.play_ui_sound(confirm_sound)
	EventBus.menu_navigation.request_goto_options.emit()


func _on_help_button_pressed() -> void:
	AudioPlayer.sfx.play_ui_sound(confirm_sound)
	EventBus.menu_navigation.request_goto_help.emit()


func _on_quit_button_pressed() -> void:
	AudioPlayer.sfx.play_ui_sound(confirm_sound)
	EventBus.menu_navigation.request_goto_exit_confirmation.emit()


func _on_quit_to_desktop_button_pressed() -> void:
	AudioPlayer.sfx.play_ui_sound(confirm_sound)
	EventBus.menu_navigation.request_goto_quit_confirmation.emit()
