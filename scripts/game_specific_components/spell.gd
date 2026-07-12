class_name Spell
extends Node3D

var is_casting: bool = false

# Called when the player first clicks the mouse
func start_cast() -> void:
	is_casting = true
	# You can add generic spell sounds or particle triggers here

# Called when the player releases the mouse
func stop_cast() -> void:
	is_casting = false
	# Stop particles or sounds here

# Called every frame while the spell is active
# We pass delta in case spells need to do time-based calculations
func process_cast(_delta: float) -> void:
	pass
