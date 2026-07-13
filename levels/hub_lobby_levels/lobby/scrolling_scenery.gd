extends Node3D

## Client-local fake motion around the open cart: mud clods and trees under $Movers
## scroll toward +Z (front to back -- the cart "travels" -Z) and wrap, so the cart,
## which never actually moves, reads as trundling through the woods. Purely cosmetic
## and unsynced; peers seeing different scroll phases is irrelevant.

# CONSTANTS
const SCROLL_SPEED := 4.0 # m/s the world slides past the cart (horse pace)
const LOOP_LENGTH := 80.0 # movers wrap back by this much...
const WRAP_END := 40.0 # ...once they scroll past this Z (the cart sees ±40 all around)
const SWAY_AMOUNT := 0.04 # vertical bob of the outside world (reads as cart rattle)
const SWAY_HZ := 1.1

# PRIVATE VARIABLES
@onready var _movers: Node3D = $Movers

var _base_y := 0.0
var _time := 0.0


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	_base_y = position.y


func _process(delta: float) -> void:
	_time += delta
	for mover: Node3D in _movers.get_children():
		mover.position.z += SCROLL_SPEED * delta
		if mover.position.z > WRAP_END:
			mover.position.z -= LOOP_LENGTH
	# Bob the OUTSIDE world, never the interior: players are owner-authoritative,
	# so a client-local moving floor under them would look desynced.
	position.y = _base_y + sin(_time * TAU * SWAY_HZ) * SWAY_AMOUNT
