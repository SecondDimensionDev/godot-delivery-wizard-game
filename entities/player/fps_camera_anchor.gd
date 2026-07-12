extends Marker3D

@export var enable_head_movement: bool = false
@export var head_movement_speed: float = 30.0
@export var head_movement_offset: float = 0.4

var head_movement_target: Vector3
var head_movement_reset: Vector3
var move_head_forward: bool = false


func _ready() -> void:
	head_movement_reset = position
	head_movement_target = head_movement_reset
	head_movement_target.z = (head_movement_reset.z - head_movement_offset)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not enable_head_movement:
		return
	var new_position: Vector3
	if move_head_forward:
		new_position = self.position.lerp(head_movement_target,head_movement_speed * delta)
	else:
		new_position = self.position.lerp(head_movement_reset,head_movement_speed * delta)
	
	self.position = new_position
