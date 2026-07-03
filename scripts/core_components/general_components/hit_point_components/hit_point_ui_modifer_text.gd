class_name HitPointModifierUIText
extends Control

## Displays the value of a specific Hit Point Modifier as text.
##
## This component acts as a listener for [HitPointComponent]. It waits for the
## component to broadcast a change regarding a specific [member modifier_name]
## (e.g. "Shield") and updates a target [Label].[br]
## This is the text-based companion to [HitPointModifierUIBar].

# EXPORT VARIABLES
@export_group("Configuration")
@export var hit_point_component: HitPointComponent ## The data source.
@export var modifier_name: String = "" ## The name of the modifier to listen for.
@export var value_is_float: bool = false ## If true, displays decimals (0.00). If false, rounds to int.

@export_group("Label Settings")
@export var label: Label ## The label node to update with the value.
@export var prefix: String = "" ## Optional text to display before the value.
@export var suffix: String = "" ## Optional text to display after the value.
@export var hide_if_zero: bool = true ## Hides the label (or this control) if value is 0.

# PRIVATE VARIABLES
var _current_value: float = 0.0

# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	_initial_setup.call_deferred()


# PRIVATE FUNCTIONS
func _on_modifier_changed(target_name: String, new_value: float) -> void: # Signal listener
	if target_name != modifier_name:
		return
	
	_current_value = new_value
	_update_text()


func _update_text() -> void: # Updates label text and visibility
	if hide_if_zero:
		# Toggle label visibility if assigned, otherwise toggle self
		if label:
			label.visible = _current_value > 0
		visible = _current_value > 0
	
	if label:
		var value_str: String
		
		if value_is_float:
			# Formats as float with 2 decimal places (e.g., "50.25")
			value_str = "%.2f" % _current_value
		else:
			# Formats as integer (e.g., "50")
			value_str = str(roundi(_current_value))
			
		label.text = "%s%s%s" % [prefix, value_str, suffix]


func _initial_setup() -> void:
	if is_instance_valid(hit_point_component):
		if hit_point_component.has_signal("modifier_value_changed"):
			hit_point_component.modifier_value_changed.connect(_on_modifier_changed)
	
	# Initial update to set visibility state
	_update_text()
