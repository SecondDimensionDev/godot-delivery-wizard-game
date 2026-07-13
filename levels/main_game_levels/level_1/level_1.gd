class_name Level1
extends Node3D

## The "Deep Delve" dungeon. Composition is entirely scene-side (MultiplayerManager +
## GameplayManager/StateMachine + DeliveryEconomy, same shape as lvl_warehouse.tscn) --
## this script only forces the ambience track to loop in code, since it doesn't trust
## the .mp3 import setting to carry the loop flag.

# PRIVATE VARIABLES
@onready var _ambience: AudioStreamPlayer = $Ambience


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	var stream := _ambience.stream as AudioStreamMP3
	if stream != null:
		stream.loop = true
