class_name LinearMapNodeData
extends Resource

## Data container for a single location node in the linear map.
##
## Stores strict data regarding connections, status, and grid positioning.
## Used by LinearMapManager to handle logic and LinearMapDisplay to handle visuals.

# ENUMS
enum LocationStatus {
	LOCKED, ## Visible, far future, path exists but not next.
	UNREACHABLE, ## Path broken (player took a different route).
	NEXT_LOCKED, ## Connected to current, but current level not finished.
	AVAILABLE, ## Accessible (Current level finished, ready to travel).
	CURRENT_INCOMPLETE, ## Player is here, level not done.
	CURRENT_COMPLETE, ## Player is here, level done.
	VISITED, ## Past node, successfully cleared.
	SKIPPED ## Past node, not visited.
}	

# EXPORT VARIABLES
@export_group("Location Details")
@export var id: String
@export var location_name: String = "Unknown"
@export var type: String = "Event" ## 'Enemy', 'Shop', etc.
@export var icon: Texture2D
@export_group("Location State")
@export var grid_position: Vector2i ## X = Column, Y = Row
@export var connected_to_ids: Array[String] = [] ## IDs of nodes in the NEXT column this connects to
@export var status: LocationStatus = LocationStatus.LOCKED
@export_group("Game Data")
@export var location_contents: BaseMapLocationContents ## The game-specific data for this node.


# PUBLIC FUNCTIONS
func add_connection(target_node_id: String) -> void:
	if target_node_id not in connected_to_ids:
		connected_to_ids.append(target_node_id)
