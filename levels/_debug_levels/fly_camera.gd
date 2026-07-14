extends Camera3D

## Minimal dev fly camera for browsing zoo/preview scenes: WASD + mouse look,
## Space/Ctrl up/down, Shift = fast, Escape releases the mouse.

# CONSTANTS
const SPEED := 8.0
const FAST_MULT := 3.0
const MOUSE_SENS := 0.003

# PRIVATE VARIABLES
var _pitch := 0.0


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_pitch = rotation.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -1.5, 1.5)
		rotation.x = _pitch
	elif event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := global_transform.basis * Vector3(input.x, 0.0, input.y)
	if Input.is_action_pressed("jump"):
		wish.y += 1.0
	if Input.is_key_pressed(KEY_CTRL):
		wish.y -= 1.0
	var speed := SPEED * (FAST_MULT if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	global_position += wish * speed * delta
