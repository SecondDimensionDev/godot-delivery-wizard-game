class_name Lobby
extends Node3D

## Grey-box open horse-drawn cart -- the between-jobs lobby (also the game's actual
## hub/first-level, see Directory.CORE_LEVELS.hub). A flat bed with low rails, spinning
## wheels, shafts, and a grey-box horse up front, rolling through night woods under the
## star/moon sky (fake scrolling scenery all around; invisible barriers keep players
## aboard). The JobComputer (a crystal ball) lets the host open the job menu via
## JobMenuController. No cargo or delivery zone in here.

# SIGNALS
signal job_menu_requested ## Host activated the job computer; JobMenuController opens the menu.

# PRIVATE VARIABLES
@onready var _ambience: AudioStreamPlayer = $Ambience
@onready var _bgm: AudioStreamPlayer = $Bgm ## Not played directly -- just holds the stream
	## resource in the editor; playback goes through AudioPlayer.music so entering the
	## lobby correctly crossfades away from whatever menu/global music was playing.
@onready var _horse_walk: AudioStreamPlayer = $HorseWalk
@onready var _horse_ambience: AudioStreamPlayer = $HorseAmbience

var _bgm_on := true


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	# Horse-and-cart woods ambience, client-local for everyone in the lobby. Force
	# looping in code so it doesn't depend on the .mp3's import setting.
	var stream := _ambience.stream as AudioStreamMP3
	if stream != null:
		stream.loop = true
	var bgm_stream := _bgm.stream as AudioStreamMP3
	if bgm_stream != null:
		bgm_stream.loop = true
	var horse_ambience_stream := _horse_ambience.stream as AudioStreamOggVorbis
	if horse_ambience_stream != null:
		horse_ambience_stream.loop = true
	# horse_walk.wav: the importer's edit/loop_mode setting doesn't reach the loaded
	# resource (reads back as LOOP_DISABLED regardless), so loop_mode/loop_end are set
	# here instead -- safe on this PCM stream (unlike QOA, mutating loop_mode mid-playback
	# doesn't corrupt a stateful compressed decoder).
	var horse_walk_stream := _horse_walk.stream as AudioStreamWAV
	if horse_walk_stream != null:
		var bytes_per_sample := 1 if horse_walk_stream.format == AudioStreamWAV.FORMAT_8_BITS else 2
		var channels := 2 if horse_walk_stream.stereo else 1
		horse_walk_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		horse_walk_stream.loop_begin = 0
		@warning_ignore("integer_division")
		horse_walk_stream.loop_end = horse_walk_stream.data.size() / (bytes_per_sample * channels)
	# Replace whatever was playing globally (menu music, etc.) with the lobby's own
	# track -- AudioPlayer.music.play_track crossfades, so this is a clean handoff.
	AudioPlayer.music.play_track(_bgm.stream)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("stabilize"):
		_toggle_bgm()


# PRIVATE FUNCTIONS
func _on_job_computer_activated() -> void:
	job_menu_requested.emit()


func _toggle_bgm() -> void:
	## Q toggles the cart's scrying-orb music, client-local (like the ambience bed).
	if _bgm_on:
		AudioPlayer.music.stop_track()
	else:
		AudioPlayer.music.play_track(_bgm.stream)
	_bgm_on = not _bgm_on
