## PAUSE SCREEN
@icon("uid://cksjj08ihbyv2")
extends CanvasLayer

@export var pause_manager: PauseManager

func _ready() -> void:
	EventBus.menu_navigation.request_resume_game.connect(close_menu_and_resume_game)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		if get_tree().paused:
			close_menu_and_resume_game()
		else:
			pause_game_and_open_menu()


func pause_game_and_open_menu() -> void:
	TimescaleManager.pause_game()
	pause_manager.state_machine.change_state(pause_manager.state_machine.states["MainMenu"])
	show()


func close_menu_and_resume_game() -> void:
	TimescaleManager.resume_game()
	hide()
