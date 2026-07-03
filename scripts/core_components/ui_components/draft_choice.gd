class_name DraftChoice
extends PanelContainer
## A generic UI component for "Choose 1 of X" drafting scenarios.
##
## This wrapper utilizes the [InterfaceList] to display options and handles
## the high-level flow of drafting, skipping, or re-rolling. It is completely
## data-agnostic, meaning it passes the chosen data dictionary back to the 
## caller without needing to know what the data represents.
	
# SIGNALS
signal choice_made(item_data: Dictionary) ## Emitted when a valid draft choice is finalized
signal skipped ## Emitted when the skip button is pressed
signal rerolled ## Emitted when the re-roll button is pressed

# EXPORT VARIABLES
@export_group("Internal References")
@export var title_label: Label ## The label displaying the draft prompt
@export var interface_list: InterfaceList ## The core list handling item visuals and selection
@export var skip_button: Button ## Button to skip the draft entirely
@export var reroll_button: Button ## Button to re-roll the draft options
@export var confirm_button: Button ## Optional button to finalize a selection manually

@export_group("Settings")
@export var default_title_text: String = "Choose an Upgrade" ## Text to display if none is provided
@export var auto_confirm_on_click: bool = false ## If true, interacting with an item finalizes the choice

# PUBLIC VARIABLES
var current_options: Array[Dictionary] = [] ## Stores the current data options being presented

# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	if title_label:
		title_label.text = default_title_text
		
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)
		
	if reroll_button:
		reroll_button.pressed.connect(_on_reroll_pressed)
		
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
		confirm_button.disabled = true
		
	if interface_list:
		interface_list.selection_changed.connect(_on_list_selection_changed)
		
		if auto_confirm_on_click:
			interface_list.item_action_requested.connect(_on_item_action_requested)


# PUBLIC FUNCTIONS
func present_choices(options: Array[Dictionary], prompt_title: String = "") -> void: ## Starts the draft with new data
	current_options = options
	
	if title_label and prompt_title != "":
		title_label.text = prompt_title
		
	if interface_list:
		interface_list.set_data(options, false, false)
		
	if confirm_button:
		confirm_button.disabled = true
		
	show()


func close_draft() -> void: ## Cleans up and hides the draft UI
	if interface_list:
		interface_list.cleardown_list()
	hide()


# PRIVATE FUNCTIONS
func _on_skip_pressed() -> void: # Handles skip logic
	skipped.emit()
	close_draft()


func _on_reroll_pressed() -> void: # Handles reroll logic
	# Note: We do not call close_draft() here, because a re-roll 
	# usually keeps the UI open and waits for the manager to call 
	# present_choices() again with fresh data.
	rerolled.emit()


func _on_list_selection_changed(selected_items: Array[Dictionary]) -> void: # Updates confirm button state
	if confirm_button:
		confirm_button.disabled = selected_items.is_empty()


func _on_item_action_requested(item_data: Dictionary) -> void: # Handles auto-confirm via double click
	if auto_confirm_on_click:
		choice_made.emit(item_data)
		close_draft()


func _on_confirm_pressed() -> void: # Handles manual confirmation
	if interface_list:
		var selected: Dictionary = interface_list.get_selected_item()
		if not selected.is_empty():
			choice_made.emit(selected)
			close_draft()
