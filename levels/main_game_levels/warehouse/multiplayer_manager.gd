class_name MultiplayerManager
extends Node
## Handles spawning and despawning of player controllers across the network.
##
## This manager is designed to be called by the Setup state of the GameplayManager.
## It strictly enforces host-authority for instantiation.

## Emitted when the player controlled by this machine has been spawned.
signal local_player_spawned

# EXPORT VARIABLES
@export_group("Spawning Details")
@export var player_scene: PackedScene ## The player controller scene to instantiate
@export var spawn_points: Array[Marker3D]
@export var player_container: Node ## The node that the MultiplayerSpawner is watching
@export var player_spawner: MultiplayerSpawner ## The spawner that replicates player instances

# PRIVATE VARIABLES
var _spawn_index: int = 0


# PUBLIC FUNCTIONS
func setup_multiplayer() -> void: ## Initializes the multiplayer environment.

	# 1. Spawn Function: Players spawn through this on every peer so the spawn
	# position is applied at instantiation. Replicated spawn state can't do
	# this: it is never applied on the peer that has authority over the node,
	# so the owning client's copy would start at the world origin.
	player_spawner.spawn_function = _spawn_player_scene

	# 2. Role Check: Clients connect to the host only now, once this level is
	# loaded — the host's MultiplayerSpawner replicates all existing players
	# the moment a peer connects, which requires the spawner to be in the tree
	if Steamworks.is_session_client():
		multiplayer.connected_to_server.connect(_on_connected_to_host, CONNECT_ONE_SHOT)
		multiplayer.connection_failed.connect(_on_connection_to_host_failed, CONNECT_ONE_SHOT)
		Steamworks.start_session_as_client(Steamworks.session_host_id)
		return

	# 3. Connect Signals: Listen for drop-outs
	multiplayer.peer_disconnected.connect(_on_player_left)

	# 4. Spawn the Host: Get the unique ID for the local host instance
	_spawn_player(multiplayer.get_unique_id())


func has_local_player() -> bool: ## Whether this machine's own player exists yet.
	return player_container.has_node(str(multiplayer.get_unique_id()))


# PRIVATE FUNCTIONS
func _on_connected_to_host() -> void:
	if multiplayer.connection_failed.is_connected(_on_connection_to_host_failed):
		multiplayer.connection_failed.disconnect(_on_connection_to_host_failed)
	_notify_ready.rpc_id(1)


func _on_connection_to_host_failed() -> void:
	if multiplayer.connected_to_server.is_connected(_on_connected_to_host):
		multiplayer.connected_to_server.disconnect(_on_connected_to_host)
	printerr("Failed to connect to the host's game session")
	Steamworks.end_session()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	EventBus.system_state.mouse_released.emit()
	# Unblock anything waiting on level setup (e.g. the loading screen) before
	# abandoning the level
	EventBus.system_state.scene_setup_complete.emit()
	SystemManager.request_system_state_and_scene_change("Menu", Directory.CORE_LEVELS.main_menu, LoadingScreen.LevelType.MENU, true, true)


# The host spawns a remote player only once that client has connected from
# inside the loaded level, so its MultiplayerSpawner can receive the spawn.
@rpc("any_peer", "call_remote", "reliable")
func _notify_ready() -> void:
	if not multiplayer.is_server():
		return
	_spawn_player(multiplayer.get_remote_sender_id())


func _on_player_left(peer_id: int) -> void:
	# Clean up the player node when they disconnect
	var player_node_name := str(peer_id)
	if player_container.has_node(player_node_name):
		var player_to_remove = player_container.get_node(player_node_name)
		player_to_remove.queue_free()


# Host-only: picks a spawn point and requests the replicated spawn.
func _spawn_player(peer_id: int) -> void:
	if not player_scene:
		push_error("MultiplayerManager: No player scene assigned!")
		return

	# Grab the spawn point at the current index (the player container sits at
	# the world origin, so global spawn coordinates map directly)
	var spawn_position := Vector3.ZERO
	if spawn_points.size() > 0:
		spawn_position = spawn_points[_spawn_index].global_position

		# Increment the index, and wrap it back to 0 if we exceed the array size (modulo operator)
		_spawn_index = (_spawn_index + 1) % spawn_points.size()

	player_spawner.spawn({"peer_id": peer_id, "position": spawn_position})


# Runs on every peer (via the MultiplayerSpawner) with the data passed to
# spawn() by the host. The spawner parents the returned node to the container.
func _spawn_player_scene(data: Dictionary) -> Node:
	var new_player = player_scene.instantiate()
	new_player.name = str(data.peer_id)

	if new_player is Node3D:
		new_player.position = data.position

	if data.peer_id == multiplayer.get_unique_id():
		local_player_spawned.emit.call_deferred()

	return new_player
