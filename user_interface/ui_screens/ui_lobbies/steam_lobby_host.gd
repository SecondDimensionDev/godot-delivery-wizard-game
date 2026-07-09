@icon("uid://bg2lm15tg20gg")
extends Control
## Steam Lobby Host
##
## A custom scene to set up a lobby as the host.
##
## @tutorial(Valve's overview of matchmaking/lobbies): https://partner.steamgames.com/doc/features/multiplayer/matchmaking
## @tutorial(GodotSteam's lobbies tutorial): https://godotsteam.com/tutorials/lobbies/
## @tutorial(GodotSteamKit lobbies usage tutoral): https://godotsteam.com/tutorials/godotsteamkit/lobbies

signal close_panel

@onready var close: Button = %Close
@onready var create: Button = %Create
@onready var lobby_data: LineEdit = %LobbyData
@export var custom_lobby_data: String ## Used to tag every lobby as belonging to this game, only needed during development
@onready var max_players: SpinBox = %MaxPlayers
@onready var visibility: OptionButton = %Visibility


func _ready() -> void:
	if not Engine.has_singleton("Steam"):
		printerr("Steam singleton not found, scene will not function correctly")
		return
	_connect_signals()
	_connect_steam_callbacks()


#region Signals
func _connect_signals() -> void:
	close.pressed.connect(_on_close_pressed)
	create.pressed.connect(_on_create_pressed)
	visibility.pressed.connect(size_dropdown_popup.bind(visibility))


func _on_close_pressed() -> void:
	close_panel.emit()


func _on_create_pressed() -> void:
	var lobby_type: Steam.LobbyType = visibility.selected as Steam.LobbyType
	Steam.createLobby(lobby_type, int(max_players.value))
	print("Creating %s Steam lobby, %s max players" % [lobby_type, int(max_players.value)])
#endregion


#region Steam callbacks
func _connect_steam_callbacks() -> void:
	steam_callback_wrapper("lobby_created", "_on_lobby_created")


func _on_lobby_created(connect_status: Steam.Result, lobby_id: int) -> void:
	if connect_status == Steam.RESULT_OK:
		Steamworks.lobby_id = lobby_id

		# Set the lobby name here.
		if not Steam.setLobbyData(Steamworks.lobby_id, "lobby_name", "%s's Lobby" % Steamworks.username):
			printerr("Failed to set lobby name")
		# We will grab and set all lobby data sets; these must have been both
		# comma-separated and in key:value pairs
		var search_string = custom_lobby_data + "," + lobby_data.text
		#var data_sets: PackedStringArray = lobby_data.text.split(",", false)
		var data_sets: PackedStringArray = search_string.split(",", false)
		for this_data in data_sets:
			var data_key_value: PackedStringArray = this_data.split(":", false, 1)
			if data_key_value.size() == 2:
				if not Steam.setLobbyData(Steamworks.lobby_id, data_key_value[0], data_key_value[1]):
					printerr("Failed to set lobby %s data [%s : %s]" % [Steamworks.lobby_id, data_key_value[0], data_key_value[1]])
		_on_close_pressed()
	else:
		printerr("Failed to create a lobby: %s" % connect_status)
		create.disabled = false


func steam_callback_wrapper(this_signal: String, this_function: String) -> void:
	var callback_connect: int = Steam.connect(this_signal, Callable(self, this_function))
	if callback_connect > OK:
		printerr("Connecting callback %s to %s failed: %s" % [this_signal, this_function, callback_connect])
#endregion


#region Helpers
# This resize the dropdown pop-up windows based on number of items because it is
# a mess otherwise.
func size_dropdown_popup(this_node: OptionButton) -> void:
	this_node.get_popup().size.y = this_node.get_item_count() * 40
#endregion
