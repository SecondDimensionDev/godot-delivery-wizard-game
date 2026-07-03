class_name TabContainerImproved
extends TabContainer

@export var tab_padding: int
@export var tab_names: Array[String]


func _ready():
	if tab_names.size() == 0 or get_tab_count() == 0:
		return
	
	var tabs_to_update: int = min(tab_names.size(), get_tab_count())
	
	for tab_index in tabs_to_update:
		var custom_name = tab_names[tab_index]
		set_custom_tab_title(tab_index, custom_name)


func set_custom_tab_title(tab_index: int, new_title: String):
	var padded_title: String = add_padding() + new_title + add_padding()
	set_tab_title(tab_index, padded_title)


func add_padding() -> String:
	var padding_str: String = ""
	for i in range(tab_padding):
		padding_str += " "
	return padding_str
