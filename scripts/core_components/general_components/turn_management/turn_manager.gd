@icon("uid://cqr1itkxvpij8")
class_name TurnManager
extends Node

## Central manager for turn-based gameplay loops.
##
## Manages a queue of [TurnParticipant] components and controls the flow of battle.
## Handles Round counting, Turn Order sorting, and switching active units.


# SIGNALS

signal battle_started ## Emitted when the battle logic begins.
signal battle_ended(winning_team_id: int) ## Emitted when only one team remains.
signal turn_started(participant: TurnParticipant) ## Emitted when a specific unit begins their turn.
signal turn_ended(participant: TurnParticipant) ## Emitted when a specific unit ends their turn.
signal team_turn_started(team_id: int) ## Emitted when a specific team becomes active (Phase mode only).
signal team_turn_ended(team_id: int) ## Emitted when a team yields their turn.
signal round_changed(new_round: int) ## Emitted when the full queue has finished and restarted.
signal waiting_for_next_team_confirmation(finished_team_id: int) ## Emitted when pausing at the end of a round, waiting for confirmation to end the turn
signal team_eliminated(team_id: int) ## Emitted when a specific team loses their last unit.


# ENUMS

enum TurnStrategy {
	INITIATIVE_SORT, ## Sort by initiative stat (Highest first).
	TEAM_SORT, ## Sort by Team ID (Team 0, then Team 1, etc).
	TEAM_PHASE ## Active Team is selected. Units are chosen manually.
}


# CONFIGURATION

@export_group("Settings")
@export var turn_strategy: TurnStrategy = TurnStrategy.INITIATIVE_SORT ## The turn type - individual initiative, team initiative and team manual
@export var total_teams: int = 2 ## The number of teams expected (IDs 0 to total_teams - 1).
@export var start_battle_on_ready: bool = false ## If true, starts immediately.
@export var auto_end_team_turn: bool = false ## Should a teams' turn automatically end turn when participants have acted, or is confirmation required?
@export var team_names: Dictionary[int, String] ## A dictionary mapping the team ID to a team name, for UI display
# INTERNAL STATE

var current_round: int = 0 ## What round is this, think of round as the global turn
var _participants: Array[TurnParticipant] = []
var _current_turn_index: int = -1
var _active_participant: TurnParticipant
var _active_team_id: int = -1


# BUILT-IN VIRTUAL METHODS

func _ready() -> void:
	add_to_group("turn_manager")
	if start_battle_on_ready:
		call_deferred("start_battle")


# PUBLIC FUNCTIONS

func register_participant(participant: TurnParticipant) -> void: ## Adds a unit to the battle roster.
	if participant not in _participants:
		_participants.append(participant)
		# Connect to the participant's death/removal signal if you have one


func unregister_participant(participant: TurnParticipant) -> void: ## Removes a unit (e.g. death).
	if participant in _participants:
		var team_id_to_check = participant.team_id # Capture ID before checking the list
		_participants.erase(participant)
		
		# Check if that specific team has been eliminated
		_check_team_elimination(team_id_to_check)
		
		# Check if the game is over
		_check_win_condition()


func select_active_participant(participant: TurnParticipant) -> void: ## Set a specific unit as the active participant
	# Validation: Can we select this unit?
	if turn_strategy == TurnStrategy.TEAM_PHASE:
		if participant.team_id != _active_team_id:
			push_warning("Cannot select unit from Team %s during Team %s's turn." % [participant.team_id, _active_team_id])
			return
	
	if _active_participant == participant:
		return # Already active
	
	if participant.has_acted_this_round:
		participant.already_acted_this_turn.emit()
		return
	
	# If someone else was active, end their turn first
	if _active_participant:
		_active_participant.on_my_turn_end()
		turn_ended.emit(_active_participant)
	
	_active_participant = participant
	turn_started.emit(_active_participant)
	_active_participant.on_my_turn_start()


func start_battle() -> void: ## Initializes the queue and starts the first turn.
	current_round = 1
	_sort_participants()
	
	battle_started.emit()
	round_changed.emit(current_round)
	
	if turn_strategy == TurnStrategy.TEAM_PHASE:
		_start_team_phase(0) # Start with Team 0
	else:
		_current_turn_index = 0
		_start_turn_for_index(_current_turn_index)	


func advance_turn() -> void: ## Called (usually by the unit) to end the current turn and start the next.
	var finished_team_id = -1
	
	if _active_participant:
		# 1. Capture the team ID before we null the active participant
		finished_team_id = _active_participant.team_id
		
		# [Existing logic] Handle Team Phase specific flag
		if turn_strategy == TurnStrategy.TEAM_PHASE:
			_active_participant.has_acted_this_round = true
		
		# [Existing logic] Cleanup the active unit
		turn_ended.emit(_active_participant)
		_active_participant.on_my_turn_end()
		_active_participant = null
	
	# --- STRICT QUEUE LOGIC (INITIATIVE & TEAM_SORT) ---
	if turn_strategy != TurnStrategy.TEAM_PHASE:
		
		# 2. Check for TEAM_SORT Pause Condition
		if turn_strategy == TurnStrategy.TEAM_SORT and finished_team_id != -1:
			if auto_end_team_turn and _should_pause_for_team_swap(finished_team_id):
				waiting_for_next_team_confirmation.emit(finished_team_id)
				return # <--- PAUSE HERE
		
		# 3. If no pause needed (or INITIATIVE mode), proceed immediately
		_proceed_to_next_index()
	
	# --- TEAM PHASE LOGIC ---
	else: 
		if auto_end_team_turn:
			_check_if_team_phase_is_complete()


func force_end_team_turn() -> void: ## Ends the team turn manually
	if turn_strategy != TurnStrategy.TEAM_PHASE:
		return
	
	team_turn_ended.emit(_active_team_id)
	
	# Find next available team ID
	# This is a simple implementation assuming Team 0 -> Team 1 -> Team 0
	var next_team = (_active_team_id + 1) % total_teams
	
	# Optional: Check if we wrapped around to start a new round
	if next_team < _active_team_id: 
		current_round += 1
		round_changed.emit(current_round)
		# Re-sort/Refresh logic here if needed
	
	_start_team_phase(next_team)


func confirm_team_turn_end() -> void: ## Call this to advance to next team's turn in TEAM_SORT mode, if auto_end_team_turn is false
	if turn_strategy != TurnStrategy.TEAM_SORT:
		return
	
	_proceed_to_next_index()


func get_team_name(team_id: int) -> String:
	if team_names.is_empty():
		return ""
	var team_name: String = team_names.get(team_id)
	return team_name


# PRIVATE FUNCTIONS

func _start_turn_for_index(index: int) -> void:
	if _participants.is_empty():
		return # Battle is likely over or empty
		
	var next_unit = _participants[index]
	
	# Skip dead or invalid units just in case
	if not is_instance_valid(next_unit) or not next_unit.is_active_in_battle:
		advance_turn()
		return
	
	_active_participant = next_unit
	_update_team_turn_status(_active_participant.team_id)
	turn_started.emit(_active_participant)
	_active_participant.on_my_turn_start()


# PRIVATE FUNCTIONS

func _should_pause_for_team_swap(current_team_id: int) -> bool:
	# Calculate who is next in line
	var next_check_index = _current_turn_index + 1
	var next_team_id = -1
	
	# If we are at the end of the list, peek at index 0 (New Round)
	if next_check_index >= _participants.size():
		if not _participants.is_empty():
			next_team_id = _participants[0].team_id
	else:
		# Otherwise peek at the immediate next unit
		next_team_id = _participants[next_check_index].team_id
	
	# If the next unit is on a different team, we should pause
	return current_team_id != next_team_id


func _proceed_to_next_index() -> void:
	# This contains the original logic that was inside advance_turn
	_current_turn_index += 1
	
	if _current_turn_index >= _participants.size():
		_start_new_round()
		return
	
	_start_turn_for_index(_current_turn_index)


func _start_new_round() -> void:
	current_round += 1
	round_changed.emit(current_round)
	
	# Re-sort every round (optional, but good for dynamic speed changes)
	_sort_participants()
	
	_current_turn_index = 0
	_start_turn_for_index(0)


func _sort_participants() -> void:
	match turn_strategy:
		TurnStrategy.INITIATIVE_SORT:
			# Descending sort: Higher Initiative goes first
			_participants.sort_custom(func(a, b): return a.initiative > b.initiative)
			
		TurnStrategy.TEAM_SORT, TurnStrategy.TEAM_PHASE:
			# Ascending sort: Team 0, then Team 1
			_participants.sort_custom(func(a, b): 
				if a.team_id == b.team_id:
					return a.initiative > b.initiative # Tie-break with initiative
				return a.team_id < b.team_id
			)


func _start_team_phase(team_id: int) -> void:
	_active_team_id = team_id
	_active_participant = null
	
	_update_team_turn_status(_active_team_id)
	team_turn_started.emit(_active_team_id)
	
	var team_has_units = _participants.any(func(p): return p.team_id == team_id and p.is_active_in_battle)
	if not team_has_units:
		force_end_team_turn()


func _check_team_elimination(team_id: int) -> void:
	# Look for any remaining member of this team
	var team_has_survivors = false
	for unit in _participants:
		if unit.team_id == team_id:
			team_has_survivors = true
			break
	
	# If no survivors found, emit the signal
	if not team_has_survivors:
		team_eliminated.emit(team_id)


func _check_win_condition() -> void:
	# Simple check: Are all remaining participants on the same team?
	if _participants.is_empty(): return
	
	var first_team = _participants[0].team_id
	for unit in _participants:
		if unit.team_id != first_team:
			return # We still have at least two different teams
	
	battle_ended.emit(first_team)


func _update_team_turn_status(active_team_id: int) -> void:
	if turn_strategy == TurnStrategy.INITIATIVE_SORT:
		for participant in _participants:
			if is_instance_valid(participant):
				participant.on_team_turn_end()
		return
	
	for participant in _participants:
		if not is_instance_valid(participant):
			continue
			
		# If this participant belongs to the active team
		if participant.team_id == active_team_id:
			# Only call start if it wasn't ALREADY their team's turn.
			# This prevents signal spam when passing turn from P1 -> P2 on the same team.
			if not participant.is_my_teams_turn:
				participant.on_team_turn_start()
		
		# If this participant belongs to a different team
		else:
			# Only call end if it currently IS their team's turn.
			if participant.is_my_teams_turn:
				participant.on_team_turn_end()


func _check_if_team_phase_is_complete() -> void:
	var team_units = _participants.filter(func(p): return p.team_id == _active_team_id and p.is_active_in_battle)
	
	var all_done = true
	for unit in team_units:
		if not unit.has_acted_this_round:
			all_done = false
			break
	
	if all_done:
		force_end_team_turn()
