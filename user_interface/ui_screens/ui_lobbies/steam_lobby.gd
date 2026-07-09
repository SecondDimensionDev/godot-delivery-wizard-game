@icon("uid://bg2lm15tg20gg")
extends Control
## Steam Lobby
##
## A custom scene for a Steam lobby once the user has joined. Hosts can start the match from here.
##
## @tutorial(Valve's overview of matchmaking/lobbies): https://partner.steamgames.com/doc/features/multiplayer/matchmaking
## @tutorial(GodotSteam's lobbies tutorial): https://godotsteam.com/tutorials/lobbies/
## @tutorial(GodotSteamKit lobbies usage tutoral): https://godotsteam.com/tutorials/godotsteamkit/lobbies

## Used to inform the parent node that this lobby has been left and this scene is no longer needed.
signal close_panel

## A custom scene for the lobby  player.
const LOBBY_PLAYER = preload("uid://jhrhtpolcnpk")

@onready var _chat: Control = %Chat
@onready var _invite: Button = %Invite
@onready var _leave: Button = %Leave
@onready var _player_list: VBoxContainer = %PlayerList
@onready var _start: Button = %Start
@onready var _title: Label = %Title


func _ready() -> void:
	if not Engine.has_singleton("Steam"):
		printerr("Steam singleton not found, scene will not function correctly")
		return
	if Steamworks.lobby_id == 0:
		printerr("You are not in a lobby currently")
		return
	_connect_signals()
	_connect_steam_signals()
	_get_lobby_name()
	_get_lobby_members()


func _get_lobby_members() -> void:
	print("Getting lobby members for lobby %s" % Steamworks.lobby_id)
	for this_player in _player_list.get_children():
		this_player.visible = false
		this_player.queue_free()
	var num_lobby_members: int = Steam.getNumLobbyMembers(Steamworks.lobby_id)
	for this_player in range(0, num_lobby_members):
		var player_object := LOBBY_PLAYER.instantiate()
		player_object.steam_id = Steam.getLobbyMemberByIndex(Steamworks.lobby_id, this_player)
		_player_list.call_deferred("add_child", player_object)


func _get_lobby_name() -> void:
	var owner_id: int = Steam.getLobbyOwner(Steamworks.lobby_id)
	var owner_name: String = Steam.getFriendPersonaName(owner_id)
	_title.text = "%s's Lobby" % owner_name


#region Signals
func _connect_signals() -> void:
	_chat.close_panel.connect(_on_leave_pressed)
	_invite.pressed.connect(_on_invite_pressed)
	_leave.pressed.connect(_on_leave_pressed)
	_start.pressed.connect(_on_start_pressed)


func _on_invite_pressed() -> void:
	Steam.activateGameOverlayInviteDialog(Steamworks.lobby_id)


func _on_leave_pressed() -> void:
	Steam.leaveLobby(Steamworks.lobby_id)
	Steamworks.lobby_id = 0
	close_panel.emit()


# This should start your match or game.  Depending on if you are using
# persistent lobbies or not, you can close the lobby connections here.
func _on_start_pressed() -> void:
	SystemManager.request_system_state_and_scene_change("Gameplay", Directory.CORE_LEVELS.first_level, LoadingScreen.LevelType.SIMPLE_2D, true, true)
#endregion


#region Steam signals
func _connect_steam_signals() -> void:
	_steam_callback_wrapper("lobby_chat_update", "_on_lobby_chat_update")
	_steam_callback_wrapper("lobby_data_update", "_on_lobby_data_update")


func _on_lobby_chat_update(lobby_id: int, _changed_id: int, _making_change_id: int, _chat_state: int) -> void:
	if Steamworks.lobby_id != lobby_id:
		return
	_get_lobby_members()


func _on_lobby_data_update(_success: int, lobby_id: int, _member_id: int) -> void:
	print("Lobby update: %s" % lobby_id)
	if Steamworks.lobby_id != lobby_id:
		return
	_get_lobby_members()


func _steam_callback_wrapper(this_signal: String, this_function: String) -> void:
	var callback_connect: int = Steam.connect(this_signal, Callable(self, this_function))
	if callback_connect > OK:
		printerr("Connecting callback %s to %s failed: %s" % [this_signal, this_function, callback_connect])
#endregion
