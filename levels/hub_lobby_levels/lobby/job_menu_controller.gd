class_name JobMenuController
extends Node

## Opens the job menu when the host activates the lobby's JobComputer, and routes the
## selected job to its destination scene. Replaces fedex's Main.gd job-menu/routing
## logic; the actual level switch goes through SystemManager's existing, generic
## level-swap flow -- `wait_for_setup: true` is the built-in replacement for fedex's
## whole ACK-barrier RPC protocol, so no bespoke networking is needed here at all.
##
## No job-menu Control/UI exists yet -- this component owns the routing LOGIC only.
## Wire a menu's button presses to call select_job(index) directly; connect to
## menu_opened/menu_closed to show/hide it. Both signals and select_job() are the
## complete, stable API a UI needs.

# SIGNALS
signal menu_opened
signal menu_closed

# EXPORT VARIABLES
@export var lobby: Lobby

# PUBLIC VARIABLES
var menu_open := false


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	lobby.job_menu_requested.connect(_open_menu)


# PUBLIC FUNCTIONS
func close_menu() -> void:
	## Cancel without picking a job -- lets a UI offer a "back out" option.
	menu_open = false
	menu_closed.emit()


func select_job(job_index: int) -> void:
	## Host-only: apply the job and switch every peer to its destination scene.
	if not multiplayer.is_server() or job_index < 0 or job_index >= JobDefs.JOBS.size():
		return
	var scene_key: String = JobDefs.JOBS[job_index].get("scene", "warehouse")
	var target_uid: String = Directory.GAME_LEVELS.get(scene_key, Directory.GAME_LEVELS["warehouse"])
	JobDefs.current_job_index = job_index
	menu_open = false
	menu_closed.emit()
	AudioPlayer.music.stop_track() ## Fade out the lobby's BGM -- the destination level's
		## own ambience (client-local, like the lobby's) takes over once it loads.
	SystemManager.request_system_scene_only_change(
		target_uid, LoadingScreen.LevelType.COMPLEX_3D, true, true, true)


# PRIVATE FUNCTIONS
func _open_menu() -> void:
	menu_open = true
	menu_opened.emit()
