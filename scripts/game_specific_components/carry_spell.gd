class_name CarrySpell
extends Spell

## The wand-cast carry tether: grab and haul the shared networked [Cargo] body. Follows
## the same Spell lifecycle as LevitationSpell (start_cast/process_cast/stop_cast), but
## the actual grab-point math, spring force, and carry limits all live on Cargo itself
## (server-authoritative) -- this node only contributes the caster's identity, so Cargo
## can find every currently-grabbing player each physics tick.
##
## Registers itself in the "carry_spells" group for the lifetime of the node (regardless
## of whether it's the player's currently-equipped spell) so Cargo can iterate every
## player's carry state directly; [member Spell.is_casting] (only ever true while this
## was actually the equipped + held spell) is what makes a player an active grabber.

# EXPORT VARIABLES
@export var player: Player ## The player this spell belongs to.


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	add_to_group("carry_spells")


func start_cast() -> void:
	super()
	# No local-side grab logic: Cargo's _apply_player_forces reads is_casting +
	# player.aim/global_position directly from every "carry_spells" member each
	# server tick and decides eligibility itself (range + looking-at-the-box).


func stop_cast() -> void:
	super()
	# Releasing is just as passive: Cargo erases the grabber once is_casting goes
	# false (or the player walks out of HOLD_BREAK_RANGE, or line of sight breaks).
