## Mute Checkbox
extends CheckBox

var master_audio_bus = AudioServer.get_bus_index("Master")

func _ready() -> void:
	_setup.call_deferred()


func _setup() -> void:
	toggled.connect(_on_toggled)
	_set_button_state()


func _on_toggled(toggled_on: bool) -> void:
	AudioServer.set_bus_mute(master_audio_bus,toggled_on)
	Settings.mute_all = toggled_on


func _set_button_state() -> void:
	button_pressed = _is_muted()


func _is_muted() -> bool:
	return AudioServer.is_bus_mute(master_audio_bus)
