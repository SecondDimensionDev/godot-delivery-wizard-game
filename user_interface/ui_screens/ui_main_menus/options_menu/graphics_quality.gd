## Graphics Quality Options
extends OptionButton


func _ready() -> void:
	_setup.call_deferred()


func _setup() -> void:
	var current_scale: float = get_tree().root.scaling_3d_scale
	var index := _get_index_for_scale(current_scale)
	select(index)
	item_selected.connect(_on_item_selected)


func _on_item_selected(index: int) -> void:
	var value: float = Directory.QUALITY_SCALES[index]
	get_tree().root.scaling_3d_scale = value
	Settings.graphics_quality = index


func _get_index_for_scale(quality_scale: float) -> int:
	var best_index := 0
	var best_diff: float = INF

	for i in Directory.QUALITY_SCALES.size():
		var item_scale: float = float(Directory.QUALITY_SCALES[i])
		var diff: float = abs(item_scale - quality_scale)

		if diff < best_diff:
			best_diff = diff
			best_index = i

	return best_index
