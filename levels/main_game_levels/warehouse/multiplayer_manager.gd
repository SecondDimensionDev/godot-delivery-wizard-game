class_name MultiplayerManager
extends Node
## Handles spawning and despawning of player controllers across the network.
##
## This manager is designed to be called by the Setup state of the GameplayManager.
## It strictly enforces host-authority for instantiation.

# EXPORT VARIABLES
@export_group("Spawning Details")
@export var player_scene: PackedScene ## The player controller scene to instantiate
@export var spawn_points: Array[Marker3D]
@export var player_container: Node ## The node that the MultiplayerSpawner is watching

# PRIVATE VARIABLES
var _spawn_index: int = 0


# PUBLIC FUNCTIONS
func setup_multiplayer() -> void: ## Initializes the multiplayer environment.
	
	# 1. Authority Check: Only the host should spawn objects
	if not multiplayer.is_server():
		return
		
	# 2. Connect Signals: Listen for drop-ins and drop-outs
	multiplayer.peer_connected.connect(_on_player_joined)
	multiplayer.peer_disconnected.connect(_on_player_left)
	
	# 3. Spawn the Host: Get the unique ID for the local host instance
	_spawn_player(multiplayer.get_unique_id())
	
	# 4. Spawn Existing Peers: Spawn anyone already connected to the lobby
	for peer_id in multiplayer.get_peers():
		_spawn_player(peer_id)


# PRIVATE FUNCTIONS
func _on_player_joined(peer_id: int) -> void:
	# Triggered when a new client connects mid-game
	_spawn_player(peer_id)


func _on_player_left(peer_id: int) -> void:
	# Clean up the player node when they disconnect
	var player_node_name := str(peer_id)
	if player_container.has_node(player_node_name):
		var player_to_remove = player_container.get_node(player_node_name)
		player_to_remove.queue_free()


func _spawn_player(peer_id: int) -> void:
	if not player_scene:
		push_error("MultiplayerManager: No player scene assigned!")
		return
		
	var new_player = player_scene.instantiate()
	new_player.name = str(peer_id)
	
	player_container.add_child(new_player)
	
	# Grab the spawn point at the current index
	if spawn_points.size() > 0:
		var current_spawn = spawn_points[_spawn_index]
		
		# Move the player to that spawn point
		if new_player is Node3D:
			new_player.global_position = current_spawn.global_position
		
		# Increment the index, and wrap it back to 0 if we exceed the array size (modulo operator)
		_spawn_index = (_spawn_index + 1) % spawn_points.size()
