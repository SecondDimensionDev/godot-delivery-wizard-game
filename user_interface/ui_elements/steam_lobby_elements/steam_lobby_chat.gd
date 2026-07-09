@icon("uid://bg2lm15tg20gg")
extends Control
## Steam Chat
##
## A custom scene for using Steam Chat through the lobby system.
##
## @tutorial(GodotSteamKit chat usage tutoral): https://godotsteam.com/tutorials/godotsteamkit/chat

## If SteamChat is a child of SteamLobby, let the lobby know the list of players has been updated.
signal close_panel

@onready var _log: RichTextLabel = %Log
@onready var _message: LineEdit = %Message
@onready var _send: Button = %Send


func _ready() -> void:
	if not Engine.has_singleton("Steam"):
		printerr("Steam singleton not found, scene will not function correctly")
		return
	_connect_signals()
	_connect_steam_signals()
	_setup_defaults()


func _setup_defaults() -> void:
	_send.disabled = true


#region Message processing
func _add_message_to_stack(message: String) -> void:
	_log.add_text("%s" % message)


func _process_chat_commands(message: String) -> void:
	print("Command message: %s" % message)
	var command: PackedStringArray = message.split(" ", false)
	print("Command array: %s" % [command])
	if command.size() == 1:
		printerr("Could not process chat command %s, missing value" % command[0])
	if command[0] == "/kick":
		print("Steam ID / kicked: %s / %s" % [Steamworks.steam_id, command[1]])
		if Steamworks.steam_id == int(command[1]):
			print("You are being kicked")
			print("Lobby ID: %s" % Steamworks.lobby_id)
			close_panel.emit()
#endregion


#region Signals
func _connect_signals() -> void:
	_message.text_changed.connect(_on_message_text_changed)
	_message.text_submitted.connect(_on_message_text_submitted)
	_send.pressed.connect(_on_send_pressed)


func _on_message_text_changed(new_text: String) -> void:
	_send.disabled = true if new_text.length() == 0 else false


func _on_message_text_submitted(_new_text: String) -> void:
	_on_send_pressed()


func _on_send_pressed() -> void:
	Steam.sendLobbyChatMsg(Steamworks.lobby_id, _message.text)
	_message.clear()
#endregion


#region Steam signals
func _connect_steam_signals() -> void:
	_steam_callback_wrapper("lobby_chat_update", "_on_lobby_chat_update")
	_steam_callback_wrapper("lobby_message", "_on_lobby_message")


func _on_lobby_chat_update(lobby_id: int, user_changed_id: int, _making_change_id: int, chat_state: Steam.ChatMemberStateChange) -> void:
	if lobby_id != Steamworks.lobby_id:
		return
	
	var changed_user: String = Steam.getFriendPersonaName(user_changed_id)
	if chat_state == Steam.ChatMemberStateChange.CHAT_MEMBER_STATE_CHANGE_ENTERED:
		_add_message_to_stack("%s joined the lobby\n" % changed_user)
	else:
		_add_message_to_stack("%s left the lobby\n" % changed_user)


func _on_lobby_message(lobby_id: int, sender: int, message: String, chat_type: Steam.ChatEntryType) -> void:
	if lobby_id != Steamworks.lobby_id:
		return

	var sender_name: String = Steam.getFriendPersonaName(sender)
	if chat_type == Steam.ChatEntryType.CHAT_ENTRY_TYPE_CHAT_MSG:
		# For kicking players from the lobby.
		if message.begins_with("/") and sender == Steam.getLobbyOwner(Steamworks.lobby_id):
			_process_chat_commands(message)
		else:
			_add_message_to_stack("%s: %s\n" % [sender_name, message])


func _steam_callback_wrapper(this_signal: String, this_function: String) -> void:
	var callback_connect: int = Steam.connect(this_signal, Callable(self, this_function))
	if callback_connect > OK:
		printerr("Connecting callback %s to %s failed: %s" % [this_signal, this_function, callback_connect])
#endregion
