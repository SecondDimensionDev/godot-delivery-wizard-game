class_name LinearMapLocation
extends Node2D

## Visual representation of a map node.
##
## Handles input (Mouse/Controller) and displays the state of a specific [LinearMapNodeData].
## Connects back to the manager via signals.

# SIGNALS
signal location_selected(node_data: LinearMapNodeData) ## Emitted when clicked or selected via code
signal location_confirmed(node_data: LinearMapNodeData) ## Emitted when interaction is confirmed (double click/button press)

# EXPORT VARIABLES
@export_group("References")
@export var background_sprite: Sprite2D
@export var icon_sprite: Sprite2D
@export var location_name_label: Label
@export var location_type_label: Label
@export var location_status_label: Label
@export var click_area: Area2D

@export_group("Connection Ports")
@export var port_north: Marker2D
@export var port_south: Marker2D
@export var port_east: Marker2D
@export var port_west: Marker2D

@export_group("Player Indicator")
@export var player_inicator_location: Marker2D

@export_group("Visual Settings")
@export var color_locked: Color = Color.GRAY
@export var color_unreachable: Color = Color(0.2, 0.2, 0.2, 0.5) # Dark/Transparent
@export var color_next_locked: Color = Color.ORANGE
@export var color_available: Color = Color.WHITE
@export var color_current_incomplete: Color = Color.CYAN
@export var color_current_complete: Color = Color.BLUE
@export var color_visited: Color = Color.GREEN
@export var color_skipped: Color = Color(0.5, 0.5, 0.5, 0.5)

# PUBLIC VARIABLES
var node_data: LinearMapNodeData

# PRIVATE VARIABLES
var _is_hovered: bool = false


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	if click_area:
		click_area.mouse_entered.connect(_on_mouse_entered)
		click_area.mouse_exited.connect(_on_mouse_exited)
		click_area.input_event.connect(_on_input_event)


# PUBLIC FUNCTIONS
func setup(data: LinearMapNodeData) -> void: ## Initialize the visual with data.
	node_data = data
	name = "Location_%s" % data.id
	
	if location_name_label and data.location_name:
		location_name_label.text = data.location_name
	
	if location_type_label and data.type:
		location_type_label.text = data.type
	
	if icon_sprite and data.icon:
		icon_sprite.texture = data.icon
	
	refresh_status()


func get_port_position(direction: String) -> Vector2: ## Returns local position of the requested port.
	var target: Marker2D
	match direction:
		"North": target = port_north
		"South": target = port_south
		"East": target = port_east
		"West": target = port_west
	
	# Fallback to center (0,0) if the marker isn't assigned or found
	if target:
		return target.position
	return Vector2.ZERO


func refresh_status() -> void: ## Updates visual coloring based on data status.
	if not node_data: return
	
	match node_data.status:
		LinearMapNodeData.LocationStatus.LOCKED:
			_visualize_locked()
		LinearMapNodeData.LocationStatus.UNREACHABLE:
			_visualize_unreachable()
		LinearMapNodeData.LocationStatus.NEXT_LOCKED:
			_visualize_next_locked()
		LinearMapNodeData.LocationStatus.AVAILABLE:
			_visualize_available()
		LinearMapNodeData.LocationStatus.CURRENT_INCOMPLETE:
			_visualize_current_incomplete()
		LinearMapNodeData.LocationStatus.CURRENT_COMPLETE:
			_visualize_current_complete()
		LinearMapNodeData.LocationStatus.VISITED:
			_visualize_visited()
		LinearMapNodeData.LocationStatus.SKIPPED:
			_visualize_skipped()


func select() -> void: ## Programmatic selection (e.g. from Controller/Manager).
	if node_data:
		location_selected.emit(node_data)


func confirm() -> void: ## Programmatic confirmation (e.g. "Enter Level").
	if node_data:
		location_confirmed.emit(node_data)


# PRIVATE FUNCTIONS
func _on_mouse_entered() -> void:
	_is_hovered = true
	# Optional: Add scale tween here for "Pop" effect


func _on_mouse_exited() -> void:
	_is_hovered = false


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# THIS IS DEBUG CODE
	if event.is_action_pressed("mouse_left"): # Ensure 'mouse_left' is in InputMap
		select()
		# Optional: Simple double-click logic could go here to trigger confirm()


func _visualize_locked() -> void:
	modulate = color_locked
	location_status_label.text = "Locked"
	# Example: scale = Vector2(0.8, 0.8)


func _visualize_unreachable() -> void:
	modulate = color_unreachable
	location_status_label.text = "Unreachable"


func _visualize_next_locked() -> void:
	modulate = color_next_locked
	location_status_label.text = "Next Up"
	# Example: Add a padlock icon here


func _visualize_available() -> void:
	modulate = color_available
	location_status_label.text = "Available"
	# Example: Add a pulsing animation here


func _visualize_current_incomplete() -> void:
	modulate = color_current_incomplete
	location_status_label.text = "Just Arrived"
	# Example: Show a "Player" icon here


func _visualize_current_complete() -> void:
	modulate = color_current_complete
	location_status_label.text = "Ready to Move"
	# Example: Show a "Checkmark" here


func _visualize_visited() -> void:
	modulate = color_visited
	location_status_label.text = "Visited"


func _visualize_skipped() -> void:
	modulate = color_skipped
	location_status_label.text = "Skipped"
