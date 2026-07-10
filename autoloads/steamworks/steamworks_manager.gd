extends BaseSteamworks


func _ready() -> void:
	super()
	Steam.initRelayNetworkAccess()
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# Ensures clients are disconnected immediately (instead of timing out) when
# the host closes the window directly.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		leave_game_session()


func _process(_delta) -> void:
	Steam.run_callbacks()


#region Multiplayer sessions
## Steam ID of the host this game should connect to as a client once the level
## has loaded. 0 means this game is the host (or offline).
var session_host_id: int = 0


func is_session_client() -> bool: ## Whether this game should join a host rather than act as one.
	return session_host_id != 0


func start_session_as_host() -> void: ## Creates a Steam host peer so lobby members can connect.
	session_host_id = 0
	var peer := SteamMultiplayerPeer.new()
	var error: int = peer.create_host(0)
	if error != OK:
		printerr("Failed to create Steam host peer: %s" % error)
		return
	multiplayer.multiplayer_peer = peer


func start_session_as_client(host_steam_id: int) -> void: ## Connects a Steam client peer to the given host.
	var peer := SteamMultiplayerPeer.new()
	var error: int = peer.create_client(host_steam_id, 0)
	if error != OK:
		printerr("Failed to create Steam client peer: %s" % error)
		return
	multiplayer.multiplayer_peer = peer


func end_session() -> void: ## Closes any active multiplayer peer, returning to offline mode.
	session_host_id = 0
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null


func is_lobby_owner() -> bool: ## Whether the local player owns the current lobby.
	return lobby_id > 0 and Steam.getLobbyOwner(lobby_id) == steam_id


## Call when deliberately leaving a running game (exit to menu, quit). The
## host also clears the start flag so lobby members stop auto-joining a game
## that no longer exists. Closing the host peer disconnects every client,
## which returns them to the main menu via their server_disconnected signal.
func leave_game_session() -> void:
	if is_lobby_owner():
		Steam.setLobbyData(lobby_id, "game_started", "")
	end_session()


# Fires on clients when the host quits or the connection drops. The client
# stays in the Steam lobby, so they can rejoin it (or be re-invited) and drop
# back into the game if the host is still running.
func _on_server_disconnected() -> void:
	end_session()
	var current_state: String = SystemManager.state_machine.current_state_name
	if current_state == "Loading":
		# Still loading into the game: the loading screen is waiting on level
		# setup, which now can never finish (no host to spawn our player).
		# Unblock it and let the load finish before redirecting to the menu.
		EventBus.system_state.scene_setup_complete.emit()
		await LoadingScreen.scene_loaded
	elif current_state != "Gameplay":
		return
	printerr("Disconnected from the host's game session")
	# The pause menu normally releases the cursor on the way out; this
	# path skips it, so free the mouse for the menu here.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	EventBus.system_state.mouse_released.emit()
	SystemManager.request_system_state_and_scene_change("Menu", Directory.CORE_LEVELS.main_menu, LoadingScreen.LevelType.MENU, true, true)
#endregion
