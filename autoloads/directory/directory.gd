## Directory Autoload
extends BaseDirectory
## An autoload that hold constants for easy access across the whole project.
## 
## This is a service for providing common referencse, predominantly used for 
## holding references to scene paths as UIDs. It extends the BaseDirectory class, 
## which hold core reference used across projects. Use this extended Autoload script
## for game specific references.


const GAME_LEVELS: Dictionary = {
	"forest" : "uid://bqtk4n0u250kb",
	# Referenced by plain res:// path rather than a fabricated uid:// -- Godot's loader
	# accepts either, and only the editor can safely mint new uids on first import.
	"warehouse" : "uid://cqtcmhntie66",
	"level_1" : "res://levels/main_game_levels/level_1/lvl_level_1.tscn",
}

const MUSIC: Dictionary = {
	"title_music" : "uid://djegj6wa4ft57",
	"menu_music" : "uid://djegj6wa4ft57",
	"game_music" : "uid://djegj6wa4ft57",
}

func _init() -> void:
	# Override Core Levels
	CORE_LEVELS = {
		"splash" : "uid://1ta4uyq1kbo4",
		"main_menu" : "uid://boamc4f1glu8m",
		# The lobby is now the real hub/first-level; warehouse (formerly the stand-in
		# for both) is reachable as an ordinary job via GAME_LEVELS.warehouse instead.
		"hub" : "res://levels/hub_lobby_levels/lobby/lvl_lobby.tscn",
		"first_level" : "res://levels/hub_lobby_levels/lobby/lvl_lobby.tscn",
	}
