## LOBBY JOB MENU SCRIPT
extends CanvasLayer

@export_group("References")
@export var controller: JobMenuController

@export_group("Job Buttons")
@export var job_buttons: Array[Button] = [] ## One per JobDefs.JOBS entry, same order.

@export_group("Sound Effects")
@export var confirm_sound: AudioStream
@export var back_sound: AudioStream
@export var back_button: Button

# PRIVATE VARIABLES
var _menu_was_open_on_pause: bool = false

func _ready() -> void:
	visible = false
	EventBus.system_state.game_paused.connect(_on_game_paused)
	EventBus.system_state.game_resumed.connect(_on_game_resumed)
	controller.menu_opened.connect(_on_menu_opened)
	controller.menu_closed.connect(_on_menu_closed)
	
	for i in job_buttons.size():
		if i >= JobDefs.JOBS.size():
			break
		var job: Dictionary = JobDefs.JOBS[i]
		job_buttons[i].text = "%s -- $%d" % [job["name"], job["reward"]]
		job_buttons[i].pressed.connect(_on_job_button_pressed.bind(i))
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)


func _on_game_paused() -> void:
	if visible:
		visible = false
		_menu_was_open_on_pause = true


func _on_game_resumed() -> void:
	if _menu_was_open_on_pause:
		_on_menu_opened.call_deferred()


func _on_job_button_pressed(index: int) -> void:
	AudioPlayer.sfx.play_ui_sound(confirm_sound)
	controller.select_job(index)


func _on_back_button_pressed() -> void:
	AudioPlayer.sfx.play_ui_sound(back_sound)
	controller.close_menu()


func _on_menu_opened() -> void:
	visible = true
	EventBus.in_game_ui.in_game_menu_opened.emit()


func _on_menu_closed() -> void:
	visible = false
	EventBus.in_game_ui.in_game_menu_closed.emit()
