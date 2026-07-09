## SELECT GAME MODE MENU SCRIPT
extends Control

@export_group("References")
@export var menu_panel: PanelContainer

@export_group("Buttons")
@export var back_button: Button
@export var host_game_button: Button
@export var join_game_button: Button

@export_group("Sound Effects")
@export var confirm_sound: AudioStream
@export var back_sound: AudioStream


## The main lobby scene that is displayed when the user has successfully joined a lobby.
const LOBBY = preload("uid://bai03oh2ugyst")
## The hosting scene which allows the user to set up their own lobby.
const LOBBY_HOST = preload("uid://b3pqyjio5xjv")
## The join / lobby list scene to browse up to 50 lobbies and set filters for searching.
const LOBBY_JOIN = preload("uid://cvxjg0tqcxjd8")

@onready var _scene: Control = %Scene


func _ready() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)

	if host_game_button:
		host_game_button.pressed.connect(_on_host_button_pressed)
	
	if join_game_button:
		join_game_button.pressed.connect(_on_join_button_pressed)
	
	process_mode = Node.PROCESS_MODE_INHERIT
	
	_connect_signals()
	_connect_steam_signals()
	_get_command_line_invite()
	
	EventBus.system_state.loading_started.connect(_loading_started)


func _on_back_button_pressed() -> void:
	AudioPlayer.sfx.play_ui_sound(back_sound)
	EventBus.menu_navigation.request_go_back.emit()


func _connect_signals() -> void:
	pass


func _on_host_button_pressed() -> void:
	AudioPlayer.sfx.play_ui_sound(back_sound)
	menu_panel.hide()
	_clear_lobby()
	_clear_scene()
	#_host.disabled = true
	#_join.disabled = false
	var new_host := LOBBY_HOST.instantiate()
	new_host.close_panel.connect(_on_close_panel.bind(new_host))
	_scene.call_deferred("add_child", new_host)


func _on_close_panel(this_panel: Control) -> void:
	#_host.disabled = false
	#_join.disabled = false
	this_panel.visible = false
	this_panel.queue_free()


func _on_join_button_pressed() -> void:
	menu_panel.hide()
	AudioPlayer.sfx.play_ui_sound(back_sound)
	_clear_lobby()
	_clear_scene()
	#_host.disabled = false
	#_join.disabled = true
	var new_join := LOBBY_JOIN.instantiate()
	new_join.close_panel.connect(_on_close_panel.bind(new_join))
	_scene.call_deferred("add_child", new_join)


func _loading_started() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED # Disable Processing
	set_process_unhandled_input(false) # Disable _unhandled_input
	set_process_input(false) # Disable _gui_inputs
	

func _clear_lobby() -> void:
	if Steamworks.lobby_id > 0:
		Steam.leaveLobby(Steamworks.lobby_id)
		Steamworks.lobby_id = 0


func _clear_scene() -> void:
	if _scene.get_child_count() > 0:
		for this_child in _scene.get_children():
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


func _connect_steam_signals() -> void:
	_steam_callback_wrapper("lobby_joined", "_on_lobby_joined")


func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: int, response: Steam.ChatRoomEnterResponse) -> void:
	if response == Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		print("Lobby %s joined successfully" % lobby_id)
		Steamworks.lobby_id = lobby_id
		_clear_scene()

		var new_lobby := LOBBY.instantiate()
		#new_lobby.close_panel.connect(_on_close_panel.bind(new_lobby))
		_scene.call_deferred("add_child", new_lobby)
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


func _steam_callback_wrapper(this_signal: String, this_function: String) -> void: #check if steam has failed to connect
	var callback_connect: int = Steam.connect(this_signal, Callable(self, this_function))
	if callback_connect > OK:
		printerr("Connecting callback %s to %s failed: %s" % [this_signal, this_function, callback_connect])
