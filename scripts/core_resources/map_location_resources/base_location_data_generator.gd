class_name BaseLocationDataGenerator
extends Resource
## Base class for injecting game-specific content into map nodes.
##
## Extend this script for each specific game prototype to define how 
## location types, names, biomes, and enemy encounters are generated 
## based on the run's current depth (step_index).


# PUBLIC FUNCTIONS
func populate_node_content(node: LinearMapNodeData, step_index: int, grid_breadth: int) -> void: ## Populates the given map node with specific game data.
	pass
