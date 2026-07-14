## Directory Autoload
extends BaseDirectory
## An autoload that hold constants for easy access across the whole project.
## 
## This is a service for providing common referencse, predominantly used for 
## holding references to scene paths as UIDs. It extends the BaseDirectory class, 
## which hold core reference used across projects. Use this extended Autoload script
## for game specific references.


const GAME_LEVELS: Dictionary = {
	"dungeon" : "uid://dph0olcl5aio",
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
		"hub" : "uid://dph0olcl5aio",
		"first_level" : "uid://dph0olcl5aio",
	}
