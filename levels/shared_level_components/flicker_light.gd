extends OmniLight3D

## Cheap horror flicker for any OmniLight3D: an irregular brightness stutter with
## occasional full blackouts. Purely cosmetic and local -- never synced.

# PRIVATE VARIABLES
var _base_energy := 0.0
var _time := 0.0


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	_base_energy = light_energy
	_time = randf() * 10.0 # desync the pattern between lights (and between clients)


func _process(delta: float) -> void:
	_time += delta
	# Layered sines make an irregular stutter; the threshold snaps it fully dark.
	var n := sin(_time * 13.0) * 0.5 + sin(_time * 47.0) * 0.35 + sin(_time * 3.7) * 0.15
	if n < -0.55:
		light_energy = 0.0
	else:
		light_energy = _base_energy * clampf(0.7 + n * 0.4, 0.2, 1.2)
