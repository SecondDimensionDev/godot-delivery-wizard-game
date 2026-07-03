## Settings Autoload
extends BaseSettings
## A persistent configuration manager for game settings.
##
## This script handles the saving and loading of audio, graphics, and user 
## preferences using Godot's [ConfigFile] system, and extends the BaseSettings class.
## The BaseSettings class hold common settings used on all projects, this extended script 
## is for game specific settings or preferences.


# CONSTANTS

# GAME SETTINGS

# PREFERENCES


# VIRTUAL BUILT-IN FUNCTIONS
func _ready() -> void:
	super() 


# PRIVATE FUNCTIONS
func _save_settings() -> ConfigFile: # Persists current variable states to the config file.
	var config: ConfigFile = super() 
	
	_write_settings_to_disk(config)
	return config


func _load_settings() -> ConfigFile: 
	var config: ConfigFile = super()
	
	return config
