class_name BaseEventBus
extends Node
## An base script for the event bus, to handle global signals.
##
## Handles signals at the global level, to allow communication between unrelated entities. 
## Inner classes are used as namespaces for easier access when list of signals grows.
## This bse script contains global events used for all games, 
## extend to add game specific signal.


# ------------ INNER CLASS INSTANCES & SETUP ------------ #

@warning_ignore_start("unused_signal")
var system_state = _SystemState.new()
var gameplay_state = _GameplayState.new()
var hub_state = _HubState.new()
var menu_navigation = _MenuNavigation.new()
var _all_categories = [system_state, gameplay_state, hub_state, menu_navigation]
const DEBUG_MODE: bool = true




# ----------- DEFINE INNER CLASSES & SIGNALS ----------- #

# System State Events
class _SystemState:
	signal system_state_changed(old_state_name: String, new_state_name: String)
	signal local_state_changed(old_state_name: String, new_state_name: String)
	signal start_splash_process
	signal loading_started
	signal loading_finished
	signal scene_setup_complete
	signal game_paused
	signal game_resumed
	signal mouse_captured
	signal mouse_released


# Manu Navigation Events
class _MenuNavigation:
	signal menu_state_changed(old_state_name: String, new_state_name: String)
	signal pause_menu_state_changed(old_state_name: String, new_state_name: String)
	signal request_goto_game_modes
	signal request_goto_setup_new
	signal request_goto_load_game
	signal request_goto_continue_game
	
	signal request_goto_help
	signal request_goto_options
	signal request_goto_credits
	
	signal request_goto_quit_confirmation
	signal confirm_quit
	signal request_goto_exit_confirmation
	signal confirm_exit
	
	signal request_go_back
	
	signal request_resume_game
	signal request_pause_game
	
	signal confirm_start_game
	signal confirm_continue_game


# Game State Events
class _GameplayState:
	signal gameplay_state_changed(old_state_name: String, new_state_name: String)


# Hub State Events
class _HubState:
	signal hub_state_changed(old_state_name: String, new_state_name: String)


# --------------------- DEBUG CODE --------------------- #

func _ready():
	if not DEBUG_MODE:
		return
	
	# Loop through every category
	for category in _all_categories:
		var signals_list = category.get_signal_list()
		
		for sig in signals_list:
			var signal_name = sig["name"]
			var args_count = sig["args"].size()
			
			# Start by binding the name so our printer knows which signal it is
			var listener = _print_debug_signal.bind(signal_name)
			
			# ONLY use unbind if the signal actually has arguments to ignore
			if args_count > 0:
				listener = listener.unbind(args_count)
			
			category.connect(signal_name, listener)


func _print_debug_signal(sig_name: String):
	print("[EventBus Signal]: ", sig_name)
