@icon("uid://dkpcsf7vmdq0e")
class_name UtilityAI
extends Node

## A utility-based AI component for calculating and prioritizing needs.
##
## This node manages a list of needs (represented as strings) and their values.
## It sorts these needs to determine which is currently the most urgent.
##
## Usage:
## 1. Extend this script to create a specific AI controller.
## 2. Populate [member possible_needs] in the Inspector with need names (e.g., "Hunger", "Sleep").
## 3. Implement logic to update the values in [member all_current_needs] over time.
## 4. Call [method recalculate_needs] periodically to update the highest/lowest need references.
## 5. Use [member current_highest_need] to drive StateMachine decisions.

# EXPORTED VARIABLES
@export var possible_needs: Array[String] ## List of need names this AI tracks.

# PUBLIC VARIABLES
var all_current_needs: Dictionary[String, float] ## Map of need names to their current values.
var current_highest_need: String ## The name of the need with the highest value.
var previous_highest_need: String ## The name of the previous highest need.
var current_lowest_need: String ## The name of the need with the lowest value.
var previous_lowest_need: String ## The name of the previous lowest need.

# VIRTUAL METHODS
func _ready() -> void:
	for need in possible_needs:
		all_current_needs[need] = 0.0

# PUBLIC METHODS
func recalculate_needs() -> void: ## Sorts needs and updates the highest/lowest variables.
	if all_current_needs.is_empty():
		return
	var sorted := _sort_needs()
	previous_highest_need = current_highest_need
	current_highest_need = sorted[0]
	previous_lowest_need = current_lowest_need
	current_lowest_need = sorted[-1]

# PRIVATE METHODS
func _sort_needs() -> Array: ## Helper to sort needs by value descending.
	var sorted_keys := all_current_needs.keys()
	sorted_keys.sort_custom(func(a, b):
		return all_current_needs[a] > all_current_needs[b]
	)
	return sorted_keys
