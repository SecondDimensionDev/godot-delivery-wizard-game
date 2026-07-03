class_name BaseSettings
extends Node
## A persistent configuration manager for game settings.
##
## This script handles the saving and loading of audio, graphics, and user 
## preferences using Godot's [ConfigFile] system. 


# CONSTANTS
const SETTINGS_FILEPATH = "user://settings.cfg" ## Path to the configuration file.
const SECTION_AUDIO = "Audio" ## Config section for audio levels.
const SECTION_GRAPHICS = "Graphics" ## Config section for visual quality.
const SECTION_PREFERENCES = "Preferences" ## Config section for user behavior.

# AUDIO
var master_volume: float = 1.0: ## Master audio bus volume (0.0 to 1.0).
	set(value):
		master_volume = value
		_save_settings()

var music_volume: float = 1.0: ## Music bus volume.
	set(value):
		music_volume = value
		_save_settings()

var sfx_volume: float = 1.0: ## Sound effects bus volume.
	set(value):
		sfx_volume = value
		_save_settings()

var ui_volume: float = 1.0: ## User interface audio volume.
	set(value):
		ui_volume = value
		_save_settings()

var mute_all: bool = false: ## Global mute toggle.
	set(value):
		mute_all = value
		_save_settings()


# GRAPHICS
var show_screen_overlay: bool = false: ## Toggle for performance/debug overlays.
	set(value):
		show_screen_overlay = value
		_save_settings()

var graphics_quality: int = 0: ## Enumerated graphics quality level.
	set(value):
		graphics_quality = value
		_save_settings()


# CORE PREFERENCES
var fullscreen_on_startup: bool = false: ## Toggle for window mode on launch.
	set(value):
		fullscreen_on_startup = value
		_save_settings()



# VIRTUAL BUILT-IN FUNCTIONS

func _ready() -> void:
	_load_settings() 


# PRIVATE FUNCTIONS

func _save_settings() -> ConfigFile: # Persists current variable states to the config file.
	var config = ConfigFile.new()
	
	# AUDIO
	config.set_value(SECTION_AUDIO, "master_volume", master_volume) 
	config.set_value(SECTION_AUDIO,"music_volume",music_volume)
	config.set_value(SECTION_AUDIO,"sfx_volume",sfx_volume)
	config.set_value(SECTION_AUDIO,"ui_volume",ui_volume)
	config.set_value(SECTION_AUDIO,"mute_all",mute_all)
	
	# GRAPHICS
	config.set_value(SECTION_GRAPHICS,"graphics_quality",graphics_quality)
	config.set_value(SECTION_GRAPHICS,"show_screen_overlay",show_screen_overlay)
	
	# PREFERENCES
	config.set_value(SECTION_PREFERENCES, "fullscreen_on_startup", fullscreen_on_startup) 
	
	return config


func _load_settings() -> ConfigFile: 
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILEPATH)
	
	if err == OK: 
		master_volume = config.get_value(SECTION_AUDIO, "master_volume", 1.0)
		music_volume = config.get_value(SECTION_AUDIO, "music_volume", 1.0)
		sfx_volume = config.get_value(SECTION_AUDIO, "sfx_volume", 1.0)
		ui_volume = config.get_value(SECTION_AUDIO, "ui_volume", 1.0)
		mute_all = config.get_value(SECTION_AUDIO, "mute_all", false)
		show_screen_overlay = config.get_value(SECTION_GRAPHICS, "show_screen_overlay", true)
		graphics_quality = config.get_value(SECTION_GRAPHICS, "graphics_quality", 0)
		fullscreen_on_startup = config.get_value(SECTION_PREFERENCES, "fullscreen_on_startup", true)
		return config # Return the loaded config
	else:
		return _save_settings() # Save defaults and return the new config


func _write_settings_to_disk(settings: ConfigFile) -> void:
	settings.save(SETTINGS_FILEPATH)
