class_name LevitationSpell
extends Spell

@export var raycast: RayCast3D
@export var lift_force: float = 15.0
@export var player_camera: Camera3D
@export var player_view_model: PlayerViewModel

@export_group("Beam Visuals")
@export var beam_segments: int = 16
@export var beam_sag: float = 0.18
@export var beam_width: float = 0.05
@export var beam_wobble: float = 0.07
@export var beam_crackle_speed: float = 3.0

# Internal state for the beam animation
var _beam_phase: float = 0.0


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	if player_view_model and player_view_model.current_spell_beam:
		player_view_model.current_spell_beam.visible = false


# PUBLIC FUNCTIONS
func start_cast() -> void:
	super()
	if player_view_model and player_view_model.current_spell_beam:
		player_view_model.current_spell_beam.visible = true


func process_cast(delta: float) -> void:
	super(delta)
	if player_camera:
		raycast.global_transform = player_camera.global_transform
	
	if not is_casting:
		return
		
	var target_point: Vector3
		
	if raycast.is_colliding():
		var target = raycast.get_collider()
		target_point = raycast.get_collision_point()
		
		if target is Node:
			var receiver = _get_spell_receiver(target)
			if receiver:
				var force_vector = Vector3.UP * lift_force
				var torque_vector = Vector3.ZERO 
				
				var authority_id = receiver.get_multiplayer_authority()
				receiver.rpc_id(authority_id, "receive_magic_forces", force_vector, torque_vector)
	else:
		# Project beam to max range if hitting nothing
		target_point = raycast.global_transform * raycast.target_position

	# --- BEAM VISUALS LOGIC ---
	if player_view_model and player_view_model.spell_beam_pivot and player_view_model.current_spell_beam:
		var start_point = player_view_model.spell_beam_pivot.global_position
		_build_beam_mesh(start_point, target_point, delta)


func stop_cast() -> void:
	super()
	if player_view_model and player_view_model.current_spell_beam:
		player_view_model.current_spell_beam.visible = false
		# Clear the mesh data when we stop casting
		var immediate_mesh = player_view_model.current_spell_beam.mesh as ImmediateMesh
		if immediate_mesh:
			immediate_mesh.clear_surfaces()


# PRIVATE FUNCTIONS
func _get_spell_receiver(hit_node: Node) -> SpellReceiver: 
	for child in hit_node.get_children():
		if child is SpellReceiver:
			return child
	return null


func _build_beam_mesh(from: Vector3, to: Vector3, delta: float) -> void:
	var beam_node = player_view_model.current_spell_beam
	var beam_mesh = beam_node.mesh as ImmediateMesh
	
	if not beam_mesh:
		push_warning("LevitationSpell: current_spell_beam is missing an ImmediateMesh!")
		return

	var length := from.distance_to(to)
	if length < 0.01:
		beam_node.visible = false
		return
		
	beam_node.visible = true
	
	# Detach the node's transform from its parent so we can draw in pure global world space
	beam_node.global_transform = Transform3D.IDENTITY 
	
	_beam_phase += delta * beam_crackle_speed
	
	# Calculate the sagging middle point
	var mid := (from + to) * 0.5 - Vector3.UP * length * beam_sag
	var view := Vector3.UP
	
	# Orient the ribbon to face the camera
	if player_camera:
		view = (player_camera.global_position - mid).normalized()
		
	beam_mesh.clear_surfaces()
	beam_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	
	for i in beam_segments + 1:
		var t := float(i) / float(beam_segments)
		
		# Quadratic bezier calculation: hand -> sagging middle -> grab point
		var a := from.lerp(mid, t)
		var b := mid.lerp(to, t)
		var p := a.lerp(b, t) 
		
		var tangent := (b - a).normalized()
		if tangent.length_squared() < 0.5:
			tangent = (to - from) / length
			
		var side := tangent.cross(view)
		if side.length_squared() < 0.0001:
			side = tangent.cross(Vector3.UP)
		side = side.normalized()
		
		var lift := side.cross(tangent).normalized()
		var envelope := sin(t * PI) # Crackle is zero at the start and end points
		
		# Apply wobble
		p += side * sin(_beam_phase * 7.0 + t * 25.0) * beam_wobble * envelope
		p += lift * sin(_beam_phase * 11.0 + t * 19.0) * beam_wobble * 0.6 * envelope
		
		var width := beam_width * (0.6 + 0.4 * envelope) * (0.8 + 0.2 * sin(_beam_phase * 23.0 + t * 40.0))
		
		beam_mesh.surface_add_vertex(p - side * width)
		beam_mesh.surface_add_vertex(p + side * width)
		
	beam_mesh.surface_end()


#class_name LevitationSpell
#extends Spell
#
#@export var raycast: RayCast3D
#@export var lift_force: float = 15.0
#@export var player_camera: Camera3D
#@export var player_view_model: PlayerViewModel
#
#
## BUILT-IN VIRTUAL METHODS
#func _ready() -> void:
	#if player_view_model and player_view_model.current_spell_beam:
		#player_view_model.current_spell_beam.visible = false
#
#
## PUBLIC FUNCTIONS
#func start_cast() -> void:
	#super()
	#if player_view_model and player_view_model.current_spell_beam:
			#player_view_model.current_spell_beam.visible = true
#
##func process_cast(delta: float) -> void:
	##super(delta)
	##if player_camera:
		##raycast.global_transform = player_camera.global_transform
	##
	##if not is_casting:
		##return
		##
	##if raycast.is_colliding():
		##var target = raycast.get_collider()
		##var hit_point = raycast.get_collision_point()
		##
		##if target is Node:
			### Look for our custom component on the hit object
			##var receiver = _get_spell_receiver(target)
			##if receiver:
				### Define our forces
				##var force_vector = Vector3.UP * lift_force
				##var torque_vector = Vector3.ZERO 
				##
				### Send the forces directly to whoever is simulating this box's physics
				##var authority_id = receiver.get_multiplayer_authority()
				##receiver.rpc_id(authority_id, "receive_magic_forces", force_vector, torque_vector)
	##
	##else:
		### If the raycast hits nothing (e.g., aiming at the sky), project the beam to the max range
		##hit_point = raycast.global_transform * raycast.target_position
#
#func process_cast(delta: float) -> void:
	#super(delta)
	#if player_camera:
		#raycast.global_transform = player_camera.global_transform
	#
	#if not is_casting:
		#return
		#
	#var target_point: Vector3
		#
	#if raycast.is_colliding():
		#var target = raycast.get_collider()
		#target_point = raycast.get_collision_point()
		#
		#if target is Node:
			## Look for our custom component on the hit object
			#var receiver = _get_spell_receiver(target) 
			#if receiver:
				## Define our forces
				#var force_vector = Vector3.UP * lift_force 
				#var torque_vector = Vector3.ZERO 
				#
				## Send the forces directly to whoever is simulating this box's physics
				#var authority_id = receiver.get_multiplayer_authority() 
				#receiver.rpc_id(authority_id, "receive_magic_forces", force_vector, torque_vector) 
	#else:
		## If the raycast hits nothing (e.g., aiming at the sky), project the beam to the max range
		#target_point = raycast.global_transform * raycast.target_position
		#
	## --- BEAM VISUALS LOGIC ---
	#if player_view_model and player_view_model.spell_beam_pivot and player_view_model.current_spell_beam:
		#var pivot = player_view_model.spell_beam_pivot
		#var beam = player_view_model.current_spell_beam
		#
		## Prevent look_at errors if the target is exactly at the pivot's location
		#if pivot.global_position.distance_to(target_point) > 0.01:
			## 1. Point the pivot at the target (Pivot's local -Z axis now points forward)
			#pivot.look_at(target_point, Vector3.UP, true)
			#
			#var distance = pivot.global_position.distance_to(target_point)
			#
			## 2. Godot Cylinders point UP (Y-axis). 
			## We rotate the beam 90 degrees on X so its top points forward.
			#beam.rotation_degrees = Vector3(-90, 0, 0)
			#
			## 3. Scale the Y-axis (height) to match the distance. 
			## We divide by 2.0 because the default Godot cylinder is exactly 2.0 units tall.
			#beam.scale = Vector3(1.0, distance, 1.0)
			#
			## 4. Shift the beam forward in the parent's local space.
			## By moving it forward by half the total distance, the base perfectly aligns with the pivot.
			#beam.position = Vector3(0, 0, distance / 2)
#
#
#func stop_cast() -> void:
	#super()
	#if player_view_model and player_view_model.current_spell_beam:
			#player_view_model.current_spell_beam.visible = false
#
#
## PRIVATE FUNCTIONS
#func _get_spell_receiver(hit_node: Node) -> SpellReceiver: # Helper function to search the hit object's children for the receiver
	#for child in hit_node.get_children():
		#if child is SpellReceiver:
			#return child
	#return null
