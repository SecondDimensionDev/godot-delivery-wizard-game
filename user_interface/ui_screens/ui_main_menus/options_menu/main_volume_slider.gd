extends HSlider

@export var bus_name: String
@export var volume_preference_name: String
var bus_index: int


func _ready() -> void:
	_setup.call_deferred()


func _setup() -> void:
	bus_index = AudioServer.get_bus_index(bus_name)
	if not drag_ended.is_connected(_on_drag_ended):
		drag_ended.connect(_on_drag_ended)
	value = db_to_linear(AudioServer.get_bus_volume_db(bus_index))


func _on_value_changed(slider_value: float) -> void:
	_set_volume(slider_value)


func _on_drag_ended(value_has_changed):
	if value_has_changed:
		match volume_preference_name:
			"master_volume":
				Settings.master_volume = value
			"music_volume":
				Settings.music_volume = value
			"sfx_volume":
				Settings.sfx_volume = value
			"ui_volume":
				Settings.ui_volume = value


func _set_volume(volume_value) -> void:
	AudioServer.set_bus_volume_db(
		bus_index,
		linear_to_db(volume_value)
	)
