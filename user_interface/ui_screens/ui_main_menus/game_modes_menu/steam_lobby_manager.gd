@icon("uid://bg2lm15tg20gg")
extends Control
## Steam Lobby Manager
##
## This is a purely optional parent scene for the lobby, host, and join scenes.
## Those scenes should work on their own, independent of this manager scene. The
## most important piece here is the _on_lobby_joined function which controls
## showing the lobby node when the player joins one.
##
## @tutorial(Valve's overview of matchmaking/lobbies): https://partner.steamgames.com/doc/features/multiplayer/matchmaking
## @tutorial(GodotSteam's lobbies tutorial): https://godotsteam.com/tutorials/lobbies/
## @tutorial(GodotSteamKit lobbies usage tutoral): https://godotsteam.com/tutorials/godotsteamkit/lobbies

## The main lobby scene that is displayed when the user has successfully joined a lobby.
const LOBBY = preload("uid://bai03oh2ugyst")
## The hosting scene which allows the user to set up their own lobby.
const LOBBY_HOST = preload("uid://b3pqyjio5xjv")
## The join / lobby list scene to browse up to 50 lobbies and set filters for searching.
const LOBBY_JOIN = preload("uid://cvxjg0tqcxjd8")

@export_group("References")
@export var back_button: Button
@export var host_button: Button
@export var join_button: Button
@export var lobby_parent_scene: Control
@export var button_controls: Control

@export_group("Sound Effects")
@export var confirm_sound: AudioStream
@export var back_sound: AudioStream

func _ready() -> void:
	if not Engine.has_singleton("Steam"):
		printerr("Steam singleton not found, scene will not function correctly")
		return
	_connect_signals()
	_connect_steam_signals()
	_get_command_line_invite()


#region Signals
func _connect_signals() -> void:
	back_button.pressed.connect(_on_exit_pressed)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)


func _on_close_panel(this_panel: Control) -> void:
	_show_buttons()
	host_button.disabled = false
	join_button.disabled = false
	this_panel.visible = false
	this_panel.queue_free()


func _on_exit_pressed() -> void:
	AudioPlayer.sfx.play_ui_sound(back_sound)
	EventBus.menu_navigation.request_go_back.emit()


func _on_host_pressed() -> void:
	AudioPlayer.sfx.play_ui_sound(confirm_sound)
	_clear_lobby()
	_clear_scene()
	host_button.disabled = true
	join_button.disabled = false
	var new_host := LOBBY_HOST.instantiate()
	new_host.close_panel.connect(_on_close_panel.bind(new_host))
	lobby_parent_scene.call_deferred("add_child", new_host)


func _on_join_pressed() -> void:
	AudioPlayer.sfx.play_ui_sound(confirm_sound)
	_clear_lobby()
	_clear_scene()
	host_button.disabled = false
	join_button.disabled = true
	var new_join := LOBBY_JOIN.instantiate()
	new_join.close_panel.connect(_on_close_panel.bind(new_join))
	lobby_parent_scene.call_deferred("add_child", new_join)
#endregion


#region Steam signals
func _connect_steam_signals() -> void:
	_steam_callback_wrapper("lobby_joined", "_on_lobby_joined")


func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: int, response: Steam.ChatRoomEnterResponse) -> void:
	if response == Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		print("Lobby %s joined successfully" % lobby_id)
		Steamworks.lobby_id = lobby_id
		_clear_scene()
		_hide_buttons()
		var new_lobby := LOBBY.instantiate()
		new_lobby.close_panel.connect(_on_close_panel.bind(new_lobby))
		lobby_parent_scene.call_deferred("add_child", new_lobby)
	else:
		match response:
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST:
				printerr("Failed joining lobby %s, this lobby no longer exists.")
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_NOT_ALLOWED:
				printerr("Failed joining lobby %s, you don't have permission to join this Lobbies.")
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_FULL:
				printerr("Failed joining lobby %s, the lobby is now full.")
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_ERROR:
				printerr("Failed joining lobby %s, something unexpected happened!")
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_BANNED:
				printerr("Failed joining lobby %s, you are banned from this lobby.")
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_LIMITED:
				printerr("Failed joining lobby %s, you cannot join due to having a limited account.")
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_CLAN_DISABLED:
				printerr("Failed joining lobby %s, this lobby is locked or disabled.")
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_COMMUNITY_BAN:
				printerr("Failed joining lobby %s, this lobby is community locked.")
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_MEMBER_BLOCKED_YOU:
				printerr("Failed joining lobby %s, a user in the lobby has blocked you from joining.")
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_YOU_BLOCKED_MEMBER:
				printerr("Failed joining lobby %s, a user you have blocked is in the lobby.")
			Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_RATE_LIMIT_EXCEEDED:
				printerr("Failed joining lobby %s, you have exceeded the rate limit.")


# A helper function to wrap a Steam callback and check if it has failed to
# connect properly.
func _steam_callback_wrapper(this_signal: String, this_function: String) -> void:
	var callback_connect: int = Steam.connect(this_signal, Callable(self, this_function))
	if callback_connect > OK:
		printerr("Connecting callback %s to %s failed: %s" % [this_signal, this_function, callback_connect])
#endregion


#region Helpers
func _hide_buttons() -> void:
	button_controls.hide()

func _show_buttons() -> void:
	button_controls.show()

func _clear_lobby() -> void:
	if Steamworks.lobby_id > 0:
		Steam.leaveLobby(Steamworks.lobby_id)
		Steamworks.lobby_id = 0


func _clear_scene() -> void:
	if lobby_parent_scene.get_child_count() > 0:
		for this_child in lobby_parent_scene.get_children():
			this_child.visible = false
			this_child.queue_free()


func _get_command_line_invite() -> void:
	var command_line_args: Array = OS.get_cmdline_args()
	if command_line_args.size() > 0:
		print("Command line arguments from Godot: %s" % [OS.get_cmdline_args()])
	if command_line_args[0] != "+connect_lobby":
		return
	if int(command_line_args[1]) > 0:
		Steam.joinLobby(int(command_line_args[1]))
#endregion
