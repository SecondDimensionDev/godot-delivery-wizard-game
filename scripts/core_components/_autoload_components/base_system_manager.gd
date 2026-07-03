@icon("uid://kfu7cw4ooxsh")
class_name BaseSystemManager
extends Node
## Global system coordinator for state management and scene transitions.
##
## The SystemManager acts as a central hub for controlling the application flow. 
## It orchestrates transitions between high-level system states (e.g., Menu, Gameplay, Cinematic) 
## and handles asynchronous scene loading through a dedicated Loading state.
## This is extended for the autoload, where any game-specific logic can be added.


# VARIABLES
@export var state_machine: StateMachine ## Reference to the primary system state machine.
var use_debug_tools: bool = true ## Toggle for enabling internal developer tools.
var debug_tools ## Instance of the internal debug utility class.

# VIRTUAL BUILT-IN METHODS
func _ready() -> void:
	state_machine.state_changed.connect(_state_changed)
	debug_tools = _DebugToolkit.new()
	debug_tools._setup()


func _unhandled_input(event: InputEvent) -> void:
	if use_debug_tools:
		debug_tools._unhandled_input(event)


# PUBLIC FUNCTIONS
func request_system_state_and_scene_change(target_state_name: String, target_scene_path: String, target_scene_type: LoadingScreen.LevelType, transition_in: bool = false, transition_out:bool = true, wait_for_setup: bool = false) -> void: ## Triggers a full transition to a specific scene and a new system state.
	
	# Get the Loading state instance from the StateMachine component
	var loading_state = state_machine.states.get("Loading")
	
	# Safety check - return if Loading state not found
	if not loading_state:
		push_error("SystemStateManager: Could not transition. Check Loading state.")
	
	var path = target_scene_path
	
	# Safety check - return if target scene path not found
	if not path:
		push_error("SystemStateManager: Could not transition. Check scene name or path.")
		return
	
	var target_state: State = state_machine.states.get(target_state_name)
	
	#Safety Check - if target state is not valid then return
	if not target_state:
		push_error("SystemStateManager: Could not transition. Invalid target state requested.")
	
	# Setup transition in loading state
	loading_state.setup_transition(target_state, path, target_scene_type, transition_in, transition_out, wait_for_setup)
	
	# Switch to the Loading state
	state_machine.change_state(loading_state)


func request_system_scene_only_change(target_scene_path: String, target_scene_type: LoadingScreen.LevelType, transition_in: bool = false, transition_out:bool = true, wait_for_setup: bool = false) -> void: ## Changes the active scene while maintaining the current system state.
	request_system_state_and_scene_change(state_machine.current_state_name, target_scene_path, target_scene_type, transition_in, transition_out, wait_for_setup)


func request_system_state_only_change(target_state_name: String) -> void: ## Swaps the system state immediately without changing the active scene.
	var target_state = state_machine.states.get(target_state_name)
	
	if target_state:
		state_machine.change_state(target_state)


# PRIVATE FUNCTIONS
func _state_changed(old_state_name: String, new_state_name: String) -> void: # Relays state changes to the global EventBus.
	EventBus.system_state.system_state_changed.emit(old_state_name, new_state_name)


class _DebugToolkit: # Internal helper for developer shortcuts and formatted console output.
	var _debug_tools_enabled: bool
	
	func _setup() -> void:
		_debug_tools_enabled = SystemManager.use_debug_tools
	
	
	func _unhandled_input(event: InputEvent) -> void:
		if not _debug_tools_enabled:
			return
		if event.is_action_pressed("debug_fullscreen"):
			_debug_fullscreen()
	
	
	func _debug_fullscreen() -> void:
		if not _debug_tools_enabled:
			return
		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	
	
	func print_debug_message(message: String, highlight: String = "") -> void:
		if not _debug_tools_enabled:
			return
		# figure out who called us
		var stack := get_stack()
		var caller := "Unknown"
		if stack.size() > 1:
			caller = str(stack[1].source).get_file().get_basename()

		# defaults
		var _colour_checker: Color = Color("#CCCCCC")
		var color := "#CCCCCC"
		var supress: bool = false
		var full_message_color: bool = false
		var make_bold: bool = false
		var make_italic: bool = false
		var add_line: bool = false
		
		# category presets
		match highlight.to_lower():
			"critical":
				_colour_checker = Color("#FF4444")
				color = "#FF4444"
				make_bold = true
				full_message_color = true
			"blue":
				_colour_checker = Color("4bced9ff")
				color = "4bced9ff"
			"blue bold":
				_colour_checker = Color("4bced9ff")
				color = "4bced9ff"
				make_bold = true
			"blue italic":
				_colour_checker = Color("4bced9ff")
				color = "4bced9ff"
				make_italic = true
				full_message_color = true
				add_line = true
			"purple":
				_colour_checker = Color("d164daff")
				color = "d164daff"
			"pink":
				_colour_checker = Color("f894a4ff")
				color = "faa6b7ff"
			"light green":
				_colour_checker = Color("c1feacff")
				color = "c1feacff"
			"orange":
				_colour_checker = Color("c48355ff")
				color = "c48355ff"
			"yellow":
				_colour_checker = Color("f9e3a9ff")
				color = "f9e3a9ff"
			"grey":
				_colour_checker = Color("606060ff")
				color = "606060ff"
				full_message_color = true
			"dull grey":
				_colour_checker = Color("424242ff")
				color = "424242ff"
				full_message_color = true
			
		if supress:
			return
			
		# style tags
		var open_tags := ""
		var close_tags := ""
		if make_bold:
			open_tags += "[b]"
			close_tags = "[/b]" + close_tags
		if make_italic:
			open_tags += "[i]"
			close_tags = "[/i]" + close_tags

		# print: either color whole message, or just the caller label
		if full_message_color:
			print_rich("[color=%s]%s[%s]: %s%s[/color]" % [color, open_tags, caller, message, close_tags])
		else:
			print_rich("%s[color=%s][%s][/color]: %s%s" % [open_tags, color, caller, message, close_tags])
		if add_line:
			print("------------------------------------------------------------")
