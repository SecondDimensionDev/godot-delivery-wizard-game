@icon("uid://ewanfsn1bty6")
class_name TurnParticipant
extends Node

## Component that allows a Node2D to take turns in the TurnManager.
##
## Stores turn stats (Initiative, Team) and provides signals for
## when this specific entity starts or ends its turn.

# SIGNALS

signal my_turn_started ## Trigger for the parent to enable input/AI.
signal my_turn_ended ## Trigger for the parent to disable input/AI.
signal my_team_turn_started ## Trigger for the parent to enable input/AI.
signal my_team_turn_ended ## Trigger for the parent to disable input/AI.
signal already_acted_this_turn ## Triggers when trying to manually select a participant that has already acted

# CONFIGURATION

@export_group("Stats")
@export var team_id: int = 0 ## 0 = Player, 1 = Enemy, etc.
@export var initiative: int = 10 ## Higher value = Earlier turn (in Initiative mode).
@export var is_active_in_battle: bool = true ## If false, skipped by TurnManager.

@export_group("Visuals")
@export var display_portrait: Texture2D ## Optional: For UI Timeline display.
@export var display_name: String = "Unit" ## Optional: For UI notifications.


# PUBLIC VARIABLES
var turn_type: TurnManager.TurnStrategy ## What type of turns are in play - Individual Initiative, Team Initiative, Team Manual
var is_my_turn: bool = false ## True if I am the currently active turn participant
var is_my_teams_turn: bool = false ## True if the TurnManager considers my team currently active.
var has_acted_this_round: bool = false ## Has this unit completed all actions this turn, resets on round change

# INTERNAL VARIABLES

var _manager: TurnManager


# BUILT-IN VIRTUAL METHODS

func _ready() -> void:
	_locate_manager()
	if _manager:
		_manager.register_participant(self)
		turn_type = _manager.turn_strategy
		_manager.round_changed.connect(_on_round_changed)


func _exit_tree() -> void:
	if _manager:
		_manager.unregister_participant(self)


# PUBLIC FUNCTIONS

func on_my_turn_start() -> void: ## Called by TurnManager.
	is_my_turn = true
	my_turn_started.emit()


func on_my_turn_end() -> void: ## Called by TurnManager.
	is_my_turn = false
	my_turn_ended.emit()


func request_selection() -> void: ## Allows the unit to try and select itself (e.g. on mouse click)
	if not _manager:
		return
	
	if has_acted_this_round:
		already_acted_this_turn.emit()
		return
	
	if _manager.turn_strategy == TurnManager.TurnStrategy.TEAM_PHASE:
		_manager.select_active_participant(self)


func on_team_turn_start() -> void: ## Called by TurnManager when this unit's team becomes active
	if not is_my_teams_turn:
		is_my_teams_turn = true
		my_team_turn_started.emit()


func on_team_turn_end() -> void: ## Called by TurnManager when this unit's team ends their phase
	if is_my_teams_turn:
		is_my_teams_turn = false
		my_team_turn_ended.emit()


func end_my_turn() -> void: ## Call this from Unit script when action is done.
	if _manager and is_my_turn:
		_manager.advance_turn()


# PRIVATE FUNCTIONS

func _locate_manager() -> void:
	var managers = get_tree().get_nodes_in_group("turn_manager")
	if managers.size() > 0:
		_manager = managers[0]
	else:
		push_warning("TurnParticipant: No TurnManager found in group 'turn_manager'")


func _on_round_changed(_new_round: int) -> void:
	has_acted_this_round = false
