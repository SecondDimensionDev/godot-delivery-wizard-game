@icon("uid://d4anil8oydwe")
class_name StateMachine
extends Node

## A component-based State Machine that manages and switches between State objects.
##
## This node is designed to be added as a child of an entity (the "parent").
## It instantiates non-Node state scripts provided in the [param set_state_scripts] dictionary.
##
## Usage:
## 1. Add this node to your entity scene.
## 2. In the Inspector, add elements to [param set_state_scripts].
##    - Key: A unique string name for the state (e.g., "Idle", "Attack").
##    - Value: Drag in or select a GDScript resource that extends the [State] class.
## 3. Set [param set_initial_state] to the string key of the state you want to start in.
## 4. Ensure the parent node has the necessary logic required by the individual states.
## 5. Set the use_physics_state bool to true if the states will directly control physics movements

# SIGNALS
signal state_changed(old_state_name: String, new_state_name: String)

# EXPORTED VARIABLES
@export var parent: Node ## The owner of this state machine.
@export var set_state_scripts: Dictionary[String, Script] ## Dictionary mapping state names to State scripts.
@export var set_initial_state: String ## The name of the state to enter on _ready.
@export var use_physics_state: bool = false

# PUBLIC VARIABLES
var states: Dictionary[String, State] ## Map of instantiated State objects.
var initial_state: State ## The specific state instance to start with.
var current_state: State ## The currently active state instance.
var current_state_name: String ## The name key of the current state.

# VIRTUAL METHODS
func _ready():
	for state_name in set_state_scripts:
		var state_script: Script = set_state_scripts[state_name]
		
		if state_script:
			var new_instance = state_script.new()
			new_instance.state_machine = self
			
			if new_instance is State:
				states[state_name] = new_instance
			else:
				push_warning("Script for state '%s' does not inherit from State." % state_name)
		else:
			push_warning("No script provided for state key '%s'." % state_name)
	
	if states.has(set_initial_state):
		initial_state = states[set_initial_state]
	else:
		if not set_initial_state.is_empty():
			push_error("Initial state '%s' not found in states dictionary." % set_initial_state)
		elif states.is_empty():
			push_error("State machine has no states loaded. Check 'set_state_scripts'.")
	
	if initial_state:
		change_state.call_deferred(initial_state)


func _process(delta):
	if use_physics_state:
		return
	
	if current_state:
		var new_state = current_state.update(delta)
		if new_state:
			change_state(new_state)


func _physics_process(delta):
	if not use_physics_state:
		return
	
	if current_state:
		var new_state = current_state.update(delta)
		if new_state:
			change_state(new_state)


func _unhandled_input(event):
	if current_state:
		var new_state = current_state.handle_input(event)
		if new_state:
			change_state(new_state)
			get_viewport().set_input_as_handled()

# PUBLIC METHODS
func change_state(new_state: State): ## Transitions the machine to a new state.
	var previous_state_name: String = ""
	
	if current_state:
		current_state.exit()
		previous_state_name = states.find_key(current_state)
	
	current_state = new_state
	current_state_name = states.find_key(current_state)
	current_state.enter()
	state_changed.emit(previous_state_name, current_state_name)


func broadcast_global_state_change(group: String, new_state_name: String) -> void: ## Notifies a group to change states.
	get_tree().call_group_flags(
		SceneTree.GROUP_CALL_DEFERRED,
		group,
		"receive_global_state_change_broadcast",
		self, new_state_name
	)


func receive_global_state_change_broadcast(sender: StateMachine, new_state_name: String) -> void: ## Reacts to a global state change broadcast.
	if self != sender:
		if current_state_name != new_state_name:
			var state_ref: State = states.get(new_state_name)
			change_state(state_ref)
