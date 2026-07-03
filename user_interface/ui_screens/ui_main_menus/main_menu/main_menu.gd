extends Control
# MAIN MENU SCRIPT

@export_group("Buttons")
@export var start_button: Button
@export var options_button: Button
@export var credits_button: Button
@export var help_button: Button
@export var quit_button: Button

@export_group("Sound Effects")
@export var confirm_sound: AudioStream
@export var back_sound: AudioStream


func _ready() -> void:
	if start_button:
		start_button.pressed.connect(_on_start_game_button_pressed)
	if options_button:
		options_button.pressed.connect(_on_options_button_pressed)
	if credits_button:
		credits_button.pressed.connect(_on_credits_button_pressed)
	if help_button:
		help_button.pressed.connect(_on_help_button_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)


func _on_start_game_button_pressed() -> void:
	AudioPlayer.sfx.play_ui_sound(confirm_sound)
	EventBus.menu_navigation.request_goto_game_modes.emit()


func _on_options_button_pressed() -> void:
	AudioPlayer.sfx.play_ui_sound(confirm_sound)
	EventBus.menu_navigation.request_goto_options.emit()


func _on_credits_button_pressed() -> void:
	AudioPlayer.sfx.play_ui_sound(confirm_sound)
	EventBus.menu_navigation.request_goto_credits.emit()


func _on_help_button_pressed() -> void:
	AudioPlayer.sfx.play_ui_sound(confirm_sound)
	EventBus.menu_navigation.request_goto_help.emit()


func _on_quit_button_pressed() -> void:
	AudioPlayer.sfx.play_ui_sound(confirm_sound)
	EventBus.menu_navigation.request_goto_quit_confirmation.emit()
