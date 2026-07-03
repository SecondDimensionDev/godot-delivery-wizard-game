## EXIT TO MAIN MENU FROM GAME SCRIPT
extends Control

@export_group("Buttons")
@export var quit_button: Button
@export var back_button: Button

@export_group("Sound Effects")
@export var confirm_sound: AudioStream
@export var back_sound: AudioStream


func _ready() -> void:
	EventBus.system_state.loading_started.connect(_loading_started)
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)


func _on_quit_button_pressed() -> void:
	AudioPlayer.sfx.play_ui_sound(back_sound)
	EventBus.menu_navigation.confirm_exit.emit()


func _on_back_button_pressed() -> void:
	AudioPlayer.sfx.play_ui_sound(confirm_sound)
	EventBus.menu_navigation.request_go_back.emit()


func _loading_started() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED # Disable Processing
	set_process_unhandled_input(false) # Disable _unhandled_input
	set_process_input(false) # Disable _gui_inputs
