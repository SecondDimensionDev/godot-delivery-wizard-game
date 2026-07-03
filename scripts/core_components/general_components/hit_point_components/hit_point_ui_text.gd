@icon("uid://cb168okhds4m2")
class_name HitPointUIText
extends Control

## Displays Hit Point data as text using standard Label nodes.
##
## This component connects to a [HitPointComponent] and updates child [Label] nodes
## with current HP, max HP, or overheal values.
## It is designed to be flexible: assign the Labels you want to use in the Inspector,
## and leave unneeded ones empty.

# EXPORT VARIABLES
@export_group("Configuration")
@export var hit_point_component: HitPointComponent ## The data source.

@export_group("Labels")
@export var label_current_hp: Label ## Displays the total current HP.
@export var label_max_hp: Label ## Displays the total max HP (including temp bonuses).
@export var label_overheal: Label ## Displays only the overheal amount (if > 0).

@export_group("Text Settings")
@export var hide_overheal_if_zero: bool = true ## Hides the overheal label if there is no overheal.

# BUILT-IN VIRTUAL METHODS

func _ready() -> void:
	_initial_setup.call_deferred()


# PRIVATE FUNCTIONS

func _on_hp_changed(data: Dictionary) -> void: # Signal listener
	_update_labels(data)


func _update_labels(data: Dictionary) -> void: # Helper function to update label text
	var current = data.total_current_hp
	var max_hp = data.total_max_hp
	var overheal = data.overhealed_hp
	
	if label_current_hp:
		label_current_hp.text = str(current)
		
	if label_max_hp:
		label_max_hp.text = str(max_hp)
		
	if label_overheal:
		label_overheal.text = "+%s" % overheal
		
		if hide_overheal_if_zero:
			label_overheal.visible = overheal > 0


func _initial_setup() -> void:
	if is_instance_valid(hit_point_component):
		hit_point_component.hp_changed.connect(_on_hp_changed)
		
		# Initial update to catch current values on load
		_update_labels({
			"total_current_hp": hit_point_component.current_hp,
			"total_max_hp": hit_point_component.get_total_max_hp(),
			"overhealed_hp": max(0, hit_point_component.current_hp - hit_point_component.get_total_max_hp())
		})
