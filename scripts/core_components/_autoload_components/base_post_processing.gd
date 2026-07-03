@icon("uid://du0oasi11pme3")
class_name BasePostProcessing
extends CanvasLayer
## A global manager for full-screen post-processing overlays and effects.
##
## This script is designed to be used as an Autoload (Singleton) to manage 
## screen-space visual effects like color tints, vignettes, or damage overlays.
## This is extended for the autoload, where any game-specific logic can be added.


@export var screen_overlay: ColorRect ## The node used for visual screen effects.


func toggle_screen_overlay() -> void: ## Toggles the current visibility of the overlay.
	if screen_overlay:
		if screen_overlay.visible:
			hide_screen_overlay()
		else:
			show_screen_overlay()


func show_screen_overlay() -> void: ## Sets the overlay to visible.
	if screen_overlay:
		screen_overlay.visible = true


func hide_screen_overlay() -> void: ## Hides the overlay.
	if screen_overlay:
		screen_overlay.visible = false


func get_overlay_visibility() -> bool: ## Returns the current visibility state.
	if screen_overlay:
		if screen_overlay.visible == true:
			return true
		else:
			return false
	else:
		return false
