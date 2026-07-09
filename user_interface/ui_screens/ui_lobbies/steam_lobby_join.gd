@icon("uid://bg2lm15tg20gg")
extends Control
## Steam Lobby List
##
## A custom scene to view Steam lobbies and join them. You can also set a variety of filters to
## narrow down your search.
##
## @tutorial(Valve's overview of matchmaking/lobbies): https://partner.steamgames.com/doc/features/multiplayer/matchmaking
## @tutorial(GodotSteam's lobbies tutorial): https://godotsteam.com/tutorials/lobbies/
## @tutorial(GodotSteamKit lobbies usage tutoral): https://godotsteam.com/tutorials/godotsteamkit/lobbies

signal close_panel

## A custom scene for displaying and joining a returned lobby.
const LOBBY_ENTRY = preload("uid://dy2hb6juqjyqi")
## A label setting for lobby subtitle messages.
const LOBBY_SUBTITLE = preload("uid://cccv0hcqhqvac")

@export var custom_lobby_data: String ## Used to tag every lobby as belonging to this game, only needed during development
@onready var _close: Button = %Close
@onready var _close_filters: Button = %CloseFilters
@onready var _distance: OptionButton = %Distance
@onready var _filters: Button = %Filters
@onready var _lobby_filters: Control = %LobbyFilters
@onready var _lobby_list: VBoxContainer = %LobbyList
@onready var _max_lobbies: SpinBox = %MaxLobbies
@onready var _open_slots: SpinBox = %OpenSlots
@onready var _refresh: Button = %Refresh
@onready var _search_terms: LineEdit = %SearchTerms


func _ready() -> void:
	if not Engine.has_singleton("Steam"):
		printerr("Steam singleton not found, scene will not function correctly")
		return
	_connect_signals()
	_connect_steam_callbacks()
	_reset_filters()


#region Signals
func _connect_signals() -> void:
	_close.pressed.connect(_on_close_pressed)
	_close_filters.pressed.connect(_on_close_filters_pressed)
	_distance.pressed.connect(_size_dropdown_popup.bind(_distance))
	_filters.pressed.connect(_on_filters_pressed)
	_refresh.pressed.connect(_on_refresh_pressed)


func _on_close_pressed() -> void:
	close_panel.emit()


func _on_close_filters_pressed() -> void:
	_lobby_filters.visible = false


func _on_filters_pressed() -> void:
	_lobby_filters.visible = true


func _on_joining_lobby(lobby_id: int) -> void:
	print("Attempting to join lobby %s from the lobby list" % lobby_id)
	Steam.joinLobby(lobby_id)


func _on_refresh_pressed() -> void:
	print("Refresh lobby list with new filters")
	_clear_lobby_list()
	_add_request_lobby_filters()
	_set_note("Searching for new lobbies...")
	Steam.requestLobbyList()
#endregion


#region Filters
# Add in any filters the player may have set before calling for the list
func _add_request_lobby_filters() -> void:
	Steam.addRequestLobbyListDistanceFilter(_distance.selected as Steam.LobbyDistanceFilter)
	Steam.addRequestLobbyListFilterSlotsAvailable(int(_open_slots.value))
	Steam.addRequestLobbyListResultCountFilter(int(_max_lobbies.value))
	var search_string = custom_lobby_data + "," + _search_terms.text
	var these_terms: PackedStringArray = search_string.split(",", false)
	if these_terms.size() > 0:
		for this_term in these_terms:
			var data_key_value: PackedStringArray = this_term.split(":", false, 1)
			if data_key_value.size() == 2:
				if data_key_value[0].length() > Steam.MAX_LOBBY_KEY_LENGTH:
					printerr("Invalid term passed, too long: %s" % this_term)
					return
				Steam.addRequestLobbyListStringFilter(data_key_value[0], data_key_value[1], Steam.LOBBY_COMPARISON_EQUAL)


func _reset_filters() -> void:
	_clear_lobby_list()
	_distance.selected = 1
	_open_slots.value = 1
	_max_lobbies.value = 50
	_search_terms.clear()
	_search_terms.max_length = Steam.MAX_LOBBY_KEY_LENGTH
	_set_note("Pick some filters and refresh")
#endregion


#region Steam callbacks
func _connect_steam_callbacks() -> void:
	_steam_callback_wrapper("lobby_match_list", "_on_lobby_match_list")


func _on_lobby_match_list(these_lobbies: Array) -> void:
	if these_lobbies.size() == 0:
		_set_note("No lobbies were found")
		return

	for this_lobby in these_lobbies:
		var lobby_object  := LOBBY_ENTRY.instantiate()
		lobby_object.name = "Lobby%s" % this_lobby
		lobby_object.set_lobby_id(this_lobby)
		lobby_object.joining_lobby.connect(_on_joining_lobby)
		_lobby_list.call_deferred("add_child", lobby_object)


func _steam_callback_wrapper(this_signal: String, this_function: String) -> void:
	var callback_connect: int = Steam.connect(this_signal, Callable(self, this_function))
	if callback_connect > OK:
		printerr("Connecting callback %s to %s failed: %s" % [this_signal, this_function, callback_connect])
#endregion


#region Helpers
func _clear_lobby_list() -> void:
	if _lobby_list.get_child_count() > 0:
		for this_child in _lobby_list.get_children():
			this_child.visible = false
			this_child.queue_free()


func _set_note(new_note_text: String) -> void:
	var note_label: Label = Label.new()
	note_label.label_settings = LOBBY_SUBTITLE
	note_label.text = new_note_text
	_lobby_list.call_deferred("add_child", note_label)


# This resize the dropdown pop-up windows based on number of items because it is
# a mess otherwise.
func _size_dropdown_popup(this_node: OptionButton) -> void:
	this_node.get_popup().size.y = this_node.get_item_count() * 40
#endregion
