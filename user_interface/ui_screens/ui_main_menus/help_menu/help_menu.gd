## HELP MENU SCRIPT
extends Control

@export_group("Buttons")
@export var back_button: Button

@export_group("Sound Effects")
@export var confirm_sound: AudioStream
@export var back_sound: AudioStream


func _ready() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)


func _on_back_button_pressed() -> void:
	AudioPlayer.sfx.play_ui_sound(back_sound)
	EventBus.menu_navigation.request_go_back.emit()
