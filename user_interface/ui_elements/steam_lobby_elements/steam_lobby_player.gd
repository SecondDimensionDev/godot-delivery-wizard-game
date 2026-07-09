@icon("uid://bg2lm15tg20gg")
extends Panel
## Steam Lobby Player
##
## A custom scene to display a lobby player and interact with them.
##
## @tutorial(Valve's overview of matchmaking/lobbies): https://partner.steamgames.com/doc/features/multiplayer/matchmaking
## @tutorial(GodotSteam's lobbies tutorial): https://godotsteam.com/tutorials/lobbies/
## @tutorial(GodotSteamKit lobbies usage tutoral): https://godotsteam.com/tutorials/godotsteamkit/lobbies

## The Steam ID for this lobby player.
var steam_id: int = 0 : set = set_steam_id

@onready var _achievements: Button = %Achievements
@onready var _avatar: SteamAvatarRect = %Avatar
@onready var _host: TextureRect = %Host
@onready var _kick: Button = %Kick
@onready var _options: Button = %Options
@onready var _options_list: HBoxContainer = %OptionList
@onready var _profile: Button = %Profile
@onready var _promote: Button = %Promote
@onready var _username: SteamUsername = %Name


func _ready() -> void:
	_connect_signals()
	_set_defaults()


func _set_defaults() -> void:
	print("Steam IDs: %s (instance) / %s (local)" % [steam_id, Steamworks.steam_id])
	_host.visible = is_lobby_host(steam_id)
	_kick.visible = is_lobby_host() and steam_id != Steamworks.steam_id
	_promote.visible = is_lobby_host() and steam_id != Steamworks.steam_id


## Set the player's Steam ID.  This will in turn set the avatar and username for this player; they
## should also automatically update with any changes.
func set_steam_id(new_id: int) -> void:
	steam_id = new_id
	if not is_node_ready(): await ready
	_avatar.steam_id = steam_id
	_username.steam_id = steam_id
	_set_defaults()


#region Signals
func _connect_signals() -> void:
	_achievements.pressed.connect(_on_achievements_pressed)
	_kick.pressed.connect(_on_kick_pressed)
	_options.toggled.connect(_on_options_toggled)
	_profile.pressed.connect(_on_profile_pressed)
	_promote.pressed.connect(_on_promote_pressed)


func _on_achievements_pressed() -> void:
	Steam.activateGameOverlayToUser("achievements", steam_id)


func _on_kick_pressed() -> void:
	if is_lobby_host() and steam_id != Steamworks.steam_id:
		print("Sending kick command for %s" % steam_id)
		if not Steam.sendLobbyChatMsg(Steamworks.lobby_id, "/kick %s" % steam_id):
			printerr("Failed to send kick command for %s" % steam_id)


func _on_add_friend_pressed() -> void:
	Steam.activateGameOverlayToUser("friendadd", steam_id)


func _on_options_toggled(show_options: bool) -> void:
	_username.visible = not show_options
	_options_list.visible = show_options


func _on_profile_pressed() -> void:
	Steam.activateGameOverlayToUser("steamid", steam_id)


func _on_promote_pressed() -> void:
	if is_lobby_host() and steam_id != Steamworks.steam_id:
		print("Promoting %s to lobby owner" % steam_id)
		if not Steam.setLobbyOwner(Steamworks.lobby_id, steam_id):
			printerr("Failed to promote %s to lobby owner" % steam_id)
	_set_defaults()
#endregion


#region Helpers
## Check to see if this player is the lobby host.
func is_lobby_host(check_id: int = Steamworks.steam_id) -> bool:
	return Steam.getLobbyOwner(Steamworks.lobby_id) == check_id
#endregion
