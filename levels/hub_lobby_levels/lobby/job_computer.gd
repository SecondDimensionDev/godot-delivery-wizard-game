class_name JobComputer
extends StaticBody3D

## The cart's crystal ball -- where jobs are scried. Players interact with it via
## JobComputerInteractor (group lookup + distance/facing test -- no networking; the
## host is the server, so a valid activation turns into a direct level switch via
## job_menu_controller.gd).

# SIGNALS
signal activated ## The host pressed interact while close to and facing the screen.

# CONSTANTS
const HINT_SECONDS := 2.0 # how long the non-host hint stays up

# PRIVATE VARIABLES
@onready var _screen: Node3D = $ScreenMesh
@onready var _hint: Label3D = $HintLabel


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	add_to_group("job_computer")


# PUBLIC FUNCTIONS
func screen_position() -> Vector3:
	## World position of the screen -- the point players must be near and looking at.
	return _screen.global_position


func activate(is_host: bool) -> void:
	## Called by the local player's interact. Hosts open the job menu; everyone else
	## gets a polite reminder of who's driving.
	if is_host:
		activated.emit()
		return
	_flash_hint()


# PRIVATE FUNCTIONS
func _flash_hint() -> void:
	_hint.visible = true
	await get_tree().create_timer(HINT_SECONDS).timeout
	_hint.visible = false
