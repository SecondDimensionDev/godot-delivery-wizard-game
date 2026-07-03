class_name FPSWeaponADSComponent
extends Node
## Handles the visual transition of moving the weapon to the center of the screen
## and interpolating the camera FOV for Aim Down Sights (ADS).
##
## Attach this to the weapon scene and assign the required export variables.

# EXPORT VARIABLES
@export_group("Target Nodes")
@export var ads_container: Node3D ## The container holding the visual weapon meshes.

@export_group("ADS Settings")
@export var ads_position: Vector3 ## The target local position for the container when aiming.
@export var ads_fov: float = 55.0 ## The target FOV when aiming.
@export var transition_speed: float = 12.0 ## How fast the weapon snaps to the center.

@export_group("Scope Overlays")
@export var use_2d_scope: bool = false ## If true, hides the weapon and shows a UI scope.
@export var scope_ui_scene: PackedScene ## A simple CanvasLayer/Control with your scope texture.
@export var scope_delay: float = 0.15 ## How long in seconds before the scope UI appears.

# PUBLIC VARIABLES
var camera_viewfinder: FPSCameraViewfinder ## Reference to the active player camera.

# PRIVATE VARIABLES
var _is_aiming: bool = false
var _default_position: Vector3
var _spawned_scope_ui: Node = null


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	if is_instance_valid(ads_container):
		# Store the resting position on spawn so we can reliably return to it
		_default_position = ads_container.position


func _process(delta: float) -> void:
	if not is_instance_valid(ads_container):
		return
		
	var target_pos := ads_position if _is_aiming else _default_position
	
	# Smoothly interpolate the container's local position
	ads_container.position = ads_container.position.lerp(target_pos, transition_speed * delta)


# PUBLIC FUNCTIONS
func aim_down() -> void: ## Triggers the ADS visual transition.
	_is_aiming = true
	if is_instance_valid(camera_viewfinder):
		camera_viewfinder.set_target_fov(ads_fov)
		
	if use_2d_scope:
		# Hide the physical gun immediately so it doesn't clip into the camera
			
		# Wait for the transition delay
		if scope_delay > 0.0:
			await get_tree().create_timer(scope_delay, false).timeout
		
		if is_instance_valid(ads_container):
			ads_container.visible = false 
			
		# CRITICAL: Check if the player released the aim button during the delay!
		if not _is_aiming:
			if is_instance_valid(ads_container):
				ads_container.visible = true 
			return
			
		# Spawn the scope UI
		if is_instance_valid(scope_ui_scene) and not is_instance_valid(_spawned_scope_ui):
			_spawned_scope_ui = scope_ui_scene.instantiate()
			add_child(_spawned_scope_ui)


func stop_aiming() -> void: ## Returns the weapon and camera to resting positions.
	_is_aiming = false
	if is_instance_valid(camera_viewfinder):
		camera_viewfinder.reset_fov()
	if use_2d_scope:
		if is_instance_valid(ads_container):
			ads_container.visible = true # Bring the gun back
			
		if is_instance_valid(_spawned_scope_ui):
			_spawned_scope_ui.queue_free()
