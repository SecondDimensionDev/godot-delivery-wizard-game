class_name BaseSessionManager
extends Node
## An autoload to manage data for the current game session.
## Stores data that needs to persist for the current game run, across multiple levels.
## Handles saving and loading, along with serialisation of resources.

# CONSTANTS
const RUN_DATA_SAVE_PATH: String = "user://current_run.tres" ## The file path for the prototype save data.


# PUBLIC VARIABLES
var current_run: BaseRunData ## The active data for the current gameplay run.


# PUBLIC FUNCTIONS
func start_new_run() -> void: ## Initializes a fresh run. Extend with game logic.
	clear_run()


func save_run() -> void: ## Saves the current run data to disk
	if not current_run:
		return
		
	var error := ResourceSaver.save(current_run, RUN_DATA_SAVE_PATH)
	if error != OK:
		push_error("SessionManager: Failed to save run data.")


func load_run() -> bool: ## Loads the current run data from disk
	if not FileAccess.file_exists(RUN_DATA_SAVE_PATH):
		return false
		
	var loaded_data := ResourceLoader.load(RUN_DATA_SAVE_PATH) as BaseRunData
	if loaded_data:
		current_run = loaded_data
		return true
	return false


func has_saved_run() -> bool: ## Utility to check if a 'Continue' option should be shown.
	return FileAccess.file_exists(RUN_DATA_SAVE_PATH)


func clear_run() -> void: ## Deletes the save file and clears the data (e.g., on Game Over).
	if FileAccess.file_exists(RUN_DATA_SAVE_PATH):
		DirAccess.remove_absolute(RUN_DATA_SAVE_PATH)
	current_run = null
