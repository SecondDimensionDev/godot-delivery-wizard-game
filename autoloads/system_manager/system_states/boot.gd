## Boot State
extends State

var next_state: State

func enter():
	_first_time_setup()
	var current_path = state_machine.parent.get_tree().current_scene.scene_file_path
	var uid_int = ResourceLoader.get_resource_uid(current_path)
	if uid_int != ResourceUID.INVALID_ID:
		var current_uid_string = ResourceUID.id_to_text(uid_int)
		if current_uid_string in Directory.CORE_LEVELS.values():
			match current_uid_string:
				Directory.CORE_LEVELS.splash:
					next_state = state_machine.states["Splash"]
				Directory.CORE_LEVELS.hub:
					next_state = state_machine.states["Hub"]
				Directory.CORE_LEVELS.main_menu:
					next_state = state_machine.states["Menu"]
				_:
					next_state = state_machine.states["Gameplay"]


func exit():
	
	next_state = null


func handle_input(_event: InputEvent) -> State:
	if next_state:
		return next_state
	
	return null


func update(_delta: float) -> State:
	if next_state:
		return next_state
	
	return null


func _first_time_setup() -> void:
	# PLAY MUSIC
	AudioPlayer.music.play_track(load(Directory.MUSIC.title_music),0)
	
	# FULLSCREEN ON STARTUP
	if Settings.fullscreen_on_startup:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	# SHOW OVERLAY
	if Settings.show_screen_overlay:
		PostProcessing.show_screen_overlay()
	else:
		PostProcessing.hide_screen_overlay()
	
	# GRAPHICS QUALITY
	var value: float = Directory.QUALITY_SCALES[Settings.graphics_quality]
	state_machine.get_tree().root.scaling_3d_scale = value
	
	# VOLUMES
	var bus_indexes: Dictionary = {
		AudioServer.get_bus_index("Master"):Settings.master_volume,
		AudioServer.get_bus_index("Music"):Settings.music_volume,
		AudioServer.get_bus_index("UI_SFX"):Settings.ui_volume,
		AudioServer.get_bus_index("Game_SFX"):Settings.sfx_volume
		}
	
	for bus in bus_indexes:
		AudioServer.set_bus_volume_db(bus,linear_to_db(bus_indexes[bus]))
	
	# MUTE
	var master_audio_bus = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_audio_bus,Settings.mute_all)
	
	# RUN DATA
	SessionManager.load_run()
