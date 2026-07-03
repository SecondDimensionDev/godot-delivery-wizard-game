@icon("uid://bbu2krso2kd8m")
class_name JuiceBox
extends Node
## Applies visual "juice" (scaling, flashing, recoil, etc.) to a target sprite.
##
## Listens to a HitPointComponent's damaged signal for automated impacts. 
## Requires the target sprite to be a Node2D (supports Sprite2D or AnimatedSprite2D).
## Includes a public API for triggering independent juice effects like recoil and wobble.

# EXPORT VARIABLES
@export_group("References")
@export var target_visuals: CanvasItem ## The visual sprite or UI element to apply juice to.


@export_group("Automation")
@export_subgroup("Hit Point Automation")
@export var hit_point_component: HitPointComponent ## The component that tracks health.
@export var use_automated_flash: bool = false ## Toggle the automated flash effect on or off.
@export var use_automated_scale_bump: bool = false ## Toggle the automated scale bump effect on or off.

@export_subgroup("Default Flash Settings")
@export var default_flash_colour: Color = Color.WHITE ## The color to flash when hit.
@export var default_flash_duration: float = 0.15 ## How long the flash effect lasts.

@export_subgroup("Default Scale Settings")
@export var default_scale_bump: Vector2 = Vector2(1.2, 1.2) ## How much to scale up when hit.
@export var default_scale_duration: float = 0.2 ## How long the scale effect lasts.

# CONSTANTS
const FLASH_SHADER_CODE = """
shader_type canvas_item;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_modifier : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	color.rgb = mix(color.rgb, flash_color.rgb, flash_modifier);
	COLOR = color;
}
"""

# PRIVATE VARIABLES
var _original_position: Vector2 = Vector2.ZERO
var _original_scale: Vector2 = Vector2.ONE
var _original_rotation: float = 0.0
var _original_modulate: Color = Color.WHITE

var _flash_material: ShaderMaterial
var _flash_tween: Tween
var _scale_tween: Tween
var _transform_tween: Tween


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	if target_visuals:
		_original_position = target_visuals.position
		_original_scale = target_visuals.scale
		_original_rotation = target_visuals.rotation
		_original_modulate = target_visuals.modulate
		
		# Setup Shader Material for flashing
		if target_visuals.material is ShaderMaterial:
			_flash_material = target_visuals.material
		else:
			_flash_material = ShaderMaterial.new()
			var shader = Shader.new()
			shader.code = FLASH_SHADER_CODE
			_flash_material.shader = shader
			target_visuals.material = _flash_material
	
	if hit_point_component and hit_point_component.has_signal("damaged"):
		hit_point_component.damaged.connect(_on_damaged)


# PUBLIC FUNCTIONS
func flash_colour(colour: Color = default_flash_colour, duration: float = default_flash_duration) -> void: ## Flashes the target a specific color using the local shader.
	if not target_visuals or not _flash_material:
		return
		
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
		
	_flash_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Set the uniform values in the shader material and tween the modifier back to 0.0
	_flash_material.set_shader_parameter("flash_color", colour)
	_flash_material.set_shader_parameter("flash_modifier", 1.0)
	_flash_tween.tween_property(_flash_material, "shader_parameter/flash_modifier", 0.0, duration)


func scale_bump(scale_bump_amount: Vector2 = default_scale_bump, scale_duration: float = default_scale_duration) -> void: ## Triggers the default scale bump effect.
	if not target_visuals:
		return
		
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
		
	_scale_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	target_visuals.scale = scale_bump_amount
	_scale_tween.tween_property(target_visuals, "scale", _original_scale, scale_duration)


func apply_flicker(duration: float, blink_speed: float = 0.1) -> void: ## Rapidly drops opacity to 0 and back to 1, simulating i-frames.
	if not target_visuals:
		return
	
	# We use a separate tween for alpha modulation so it doesn't conflict with shader flashes
	var flicker_tween = create_tween()
	var loops = int(duration / blink_speed)
	
	for i in range(loops):
		var target_alpha = 0.0 if i % 2 == 0 else _original_modulate.a
		var target_color = _original_modulate
		target_color.a = target_alpha
		flicker_tween.tween_property(target_visuals, "modulate", target_color, blink_speed)
		
	flicker_tween.tween_property(target_visuals, "modulate", _original_modulate, blink_speed)


func squash_and_stretch(scale_multiplier: Vector2, duration: float) -> void: ## Tweens the scale of the target visuals and bounces back.
	if not target_visuals:
		return

	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()

	_scale_tween = create_tween()
	var target_scale := _original_scale * scale_multiplier
	
	_scale_tween.tween_property(target_visuals, "scale", target_scale, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(target_visuals, "scale", _original_scale, duration * 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func pop_in(duration: float = 0.3) -> void: ## Scales the object up from zero with an overshoot bounce.
	if not target_visuals:
		return
	
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	
	_scale_tween = create_tween()
	target_visuals.scale = Vector2.ZERO
	
	_scale_tween.tween_property(target_visuals, "scale", _original_scale, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func apply_recoil(kickback_vector: Vector2, duration: float) -> void: ## Kicks the visuals backward along a vector, then smoothly interpolates back.
	if not target_visuals:
		return
	
	if _transform_tween and _transform_tween.is_valid():
		_transform_tween.kill()
	
	_transform_tween = create_tween()
	var target_pos := _original_position + kickback_vector
	
	_transform_tween.tween_property(target_visuals, "position", target_pos, duration * 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_transform_tween.tween_property(target_visuals, "position", _original_position, duration * 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func apply_wobble(angle_degrees: float, duration: float) -> void: ## Rocks the visuals back and forth past the center with a decaying amplitude.
	if not target_visuals:
		return
	
	if _transform_tween and _transform_tween.is_valid():
		_transform_tween.kill()
	
	_transform_tween = create_tween()
	var rads := deg_to_rad(angle_degrees)
	
	_transform_tween.tween_property(target_visuals, "rotation", _original_rotation + rads, duration * 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_transform_tween.tween_property(target_visuals, "rotation", _original_rotation - (rads * 0.5), duration * 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transform_tween.tween_property(target_visuals, "rotation", _original_rotation, duration * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func reset_visuals() -> void: ## Instantly stops all juice effects and returns visuals to their original state.
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	if _transform_tween and _transform_tween.is_valid():
		_transform_tween.kill()
	
	if target_visuals:
		target_visuals.modulate = _original_modulate
		target_visuals.position = _original_position
		target_visuals.scale = _original_scale
		target_visuals.rotation = _original_rotation
			
	if _flash_material:
		_flash_material.set_shader_parameter("flash_modifier", 0.0)


# PRIVATE FUNCTIONS
func _on_damaged(_amount: int) -> void: # Triggers the juice effects based on settings when the damaged signal is received.
	if use_automated_flash:
		flash_colour()
		
	if use_automated_scale_bump:
		scale_bump()
