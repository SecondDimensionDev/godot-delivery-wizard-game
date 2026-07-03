class_name ExpressionDecal3D
extends Decal
## A decal component designed to project facial expressions onto a 3D mesh.
##
## This component uses a dictionary to map string names (e.g., "happy", "angry")
## to specific Texture2D resources. It provides a simple public API to swap
## the face texture dynamically. Place this as a child of your character's
## MeshInstance3D and position the projection box over their face.

# EXPORT VARIABLES
@export_group("Expressions")
@export var default_expression: String = "neutral" ## The expression to load automatically on ready.
@export var expressions: Dictionary = {} ## Maps expression names (String) to face textures (Texture2D).

# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	if not default_expression.is_empty():
		set_expression(default_expression)

# PUBLIC FUNCTIONS
func set_expression(expression_name: String) -> void:
	## Sets the decal's albedo texture to the specified expression if it exists.
	if expressions.has(expression_name):
		var tex = expressions[expression_name]
		
		# Validate that the dictionary value is actually a texture
		if tex is Texture2D:
			texture_albedo = tex
		else:
			push_warning("ExpressionDecal3D: The value for '%s' is not a valid Texture2D." % expression_name)
	else:
		push_warning("ExpressionDecal3D: Expression '%s' not found in dictionary." % expression_name)

func clear_expression() -> void:
	## Removes the current texture, making the face blank/invisible.
	texture_albedo = null
