extends MouseCaptureComponent


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	EventBus.in_game_ui.in_game_menu_opened.connect(release)
	EventBus.in_game_ui.in_game_menu_closed.connect(capture)
