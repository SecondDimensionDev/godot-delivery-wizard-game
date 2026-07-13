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


func _ready() -> void:
	visible = false
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


func _on_job_button_pressed(index: int) -> void:
	AudioPlayer.sfx.play_ui_sound(confirm_sound)
	controller.select_job(index)


func _on_back_button_pressed() -> void:
	AudioPlayer.sfx.play_ui_sound(back_sound)
	controller.close_menu()


func _on_menu_opened() -> void:
	visible = true


func _on_menu_closed() -> void:
	visible = false
