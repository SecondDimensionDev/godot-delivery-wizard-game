class_name BaseAudioPlayer
extends Node
## Global manager for all persistent audio in the game.
##
## Combines BGM (crossfading) and SFX (pooling) into a single 
## autoload with namespaced inner classes. The base class is extended for the autoload,
## and game-specific audio can be appended there.


# EXPORT VARIABLES
@export_group("Music Settings")
@export var default_crossfade: float = 1.5 ## Default time in seconds to crossfade tracks

@export_group("SFX Settings")
@export var sfx_pool_size: int = 8 ## The number of concurrent sounds allowed

# PUBLIC VARIABLES
var music: _MusicController ## Namespace for BGM functions
var sfx: _SFXController ## Namespace for SFX functions


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Instantiate, configure, and add the Music inner class
	music = _MusicController.new()
	music.default_crossfade = default_crossfade
	add_child(music)
	
	# Instantiate, configure, and add the SFX inner class
	sfx = _SFXController.new()
	sfx.pool_size = sfx_pool_size
	add_child(sfx)


class _MusicController extends Node:
	# PUBLIC VARIABLES
	var default_crossfade: float = 1.5 ## Default time to cross fade between music tracks
	
	# PRIVATE VARIABLES
	var _player_a: AudioStreamPlayer
	var _player_b: AudioStreamPlayer
	var _active_player: AudioStreamPlayer
	var _fade_tween: Tween
	
	# BUILT-IN VIRTUAL METHODS
	func _ready() -> void:
		_player_a = AudioStreamPlayer.new()
		_player_b = AudioStreamPlayer.new()
		_player_a.bus = "Music"
		_player_b.bus = "Music"
		add_child(_player_a)
		add_child(_player_b)
		_active_player = _player_a
	
	# PUBLIC FUNCTIONS
	func play_track(stream: AudioStream, fade_time: float = -1.0) -> void: ## Plays a new track with crossfade
		if fade_time < 0.0:
			fade_time = default_crossfade
			
		if stream == _active_player.stream and _active_player.playing:
			return 
			
		var old_player := _active_player
		_active_player = _player_b if _active_player == _player_a else _player_a
		
		_active_player.stream = stream
		_active_player.volume_db = -80.0
		_active_player.play()
		
		if _fade_tween and _fade_tween.is_valid():
			_fade_tween.kill()
			
		_fade_tween = create_tween().set_parallel(true)
		_fade_tween.tween_property(_active_player, "volume_db", 0.0, fade_time)
		
		if old_player.playing:
			_fade_tween.tween_property(old_player, "volume_db", -80.0, fade_time)
			
		_fade_tween.chain().tween_callback(old_player.stop)
	
	
	func stop_track(fade_time: float = -1.0) -> void: ## Fades out active music
		if fade_time < 0.0:
			fade_time = default_crossfade
			
		if not _active_player.playing:
			return
			
		if _fade_tween and _fade_tween.is_valid():
			_fade_tween.kill()
			
		_fade_tween = create_tween()
		_fade_tween.tween_property(_active_player, "volume_db", -80.0, fade_time)
		_fade_tween.tween_callback(_active_player.stop)



class _SFXController extends Node:
	# PUBLIC VARIABLES
	var pool_size: int = 8
	
	# PRIVATE VARIABLES
	var _players: Array[AudioStreamPlayer] = []
	var _next_player_index: int = 0
	
	
	# BUILT-IN VIRTUAL METHODS
	func _ready() -> void:
		for i in range(pool_size):
			var player := AudioStreamPlayer.new()
			add_child(player)
			_players.append(player)
	
	
	# PUBLIC FUNCTIONS
	func play_sound(stream: AudioStream, pitch_variance: float = 0.0, volume_variance: float = 0.0) -> void: ## Play a sound on the Game SFX Audio Bus
		_play_sound_effect(stream, "Game_SFX", pitch_variance, volume_variance)
	
	
	func play_ui_sound(stream: AudioStream, pitch_variance: float = 0.0, volume_variance: float = 0.0) -> void: ## Play a sound on the Game UI Audio Bus
		_play_sound_effect(stream, "UI_SFX", pitch_variance, volume_variance)
	
	
	# PRIVATE FUNCTIONS
	
	func _play_sound_effect(stream: AudioStream, bus_name: String, pitch_variance: float = 0.0, volume_variance: float = 0.0) -> void: ## Plays dynamic SFX from the pool
		if not stream:
			return
			
		var player: AudioStreamPlayer = _get_available_player()
		player.stream = stream
		player.bus = bus_name
		
		player.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance) if pitch_variance > 0.0 else 1.0
		player.volume_db = randf_range(-volume_variance, volume_variance) if volume_variance > 0.0 else 0.0
		
		player.play()
	
	
	func _get_available_player() -> AudioStreamPlayer:
		for player in _players:
			if not player.playing:
				return player
		
		var forced_player: AudioStreamPlayer = _players[_next_player_index]
		_next_player_index = (_next_player_index + 1) % pool_size
		return forced_player
