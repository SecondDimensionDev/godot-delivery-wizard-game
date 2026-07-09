extends Node3D

@export var animation_player: AnimationPlayer


func _ready() -> void:
	animation_player.play("Idle")

func play_animation(animation: String) -> void:
	animation_player.play(animation)
