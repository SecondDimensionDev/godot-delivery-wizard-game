class_name WindZone
extends Area3D

## Drop-in environmental force zone: applies a continuous force to overlapping
## RigidBody3Ds (mainly the cargo -- server-side, since only the server runs cargo
## physics) and optionally nudges players (each OWNING peer applies its own nudge --
## players are owner-authoritative). Faint particle streaks swish along the wind on
## every peer so the zone and its direction are glance-readable. Standalone: place
## in any level, size the CollisionShape3D box, point `direction`, done.

# EXPORT VARIABLES
@export var direction := Vector3(1.0, 0.0, 0.0) ## World-space wind direction; magnitude is ignored -- strength sets the force.
@export var strength := 30.0 ## Newtons of continuous force on each overlapping RigidBody3D.
@export var affects_players := false ## Also nudge overlapping players (applied by their owning peer).
@export var player_force_scale := 0.3 ## Fraction of strength applied to players.

# PRIVATE VARIABLES
@onready var _shape: BoxShape3D = ($CollisionShape3D as CollisionShape3D).shape as BoxShape3D
@onready var _particles: GPUParticles3D = $Streaks

var _force := Vector3.ZERO


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	_force = direction.normalized() * strength
	_configure_streaks()


func _physics_process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	for body in get_overlapping_bodies():
		if body is RigidBody3D:
			if multiplayer.is_server():
				# Continuous newtons, not an impulse -- the server integrates it and
				# clients see the drift via the cargo's existing net interpolation.
				(body as RigidBody3D).apply_central_force(_force)
		elif affects_players and body is CharacterBody3D \
				and (body as CharacterBody3D).is_multiplayer_authority():
			# Players are owner-authoritative: each peer nudges only its OWN capsule.
			(body as CharacterBody3D).velocity += _force * player_force_scale * delta


# PRIVATE FUNCTIONS
func _configure_streaks() -> void:
	# Fill the zone volume with faint streaks flying along the wind, on every peer
	# (purely cosmetic, unsynced). Emission volume and lifetime derive from the
	# collision box so resizing the zone in the editor keeps the visual honest.
	var mat := _particles.process_material as ParticleProcessMaterial
	var dir := direction.normalized()
	mat.direction = dir
	mat.emission_box_extents = _shape.size * 0.5
	var speed := (mat.initial_velocity_min + mat.initial_velocity_max) * 0.5
	var travel := absf(_shape.size.dot(dir.abs())) # zone extent along the wind
	_particles.lifetime = maxf(0.4, travel / speed)
	_particles.visibility_aabb = AABB(-_shape.size, _shape.size * 2.0)
