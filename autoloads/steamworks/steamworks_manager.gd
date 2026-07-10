extends BaseSteamworks


func _ready() -> void:
	super()
	Steam.initRelayNetworkAccess()


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
#endregion
