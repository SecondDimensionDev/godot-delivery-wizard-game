## EventBus Autoload
extends BaseEventBus
## An event bus to handle global signals.
##
## Handles signals at the global level, to allow communication between unrelated entities. 
## Inner classes are used as namespaces for easier access when list of signals grows.

# ------------ INNER CLASS INSTANCES & SETUP ------------ #
@warning_ignore_start("unused_signal")
var in_game_ui = _GameUI.new()
var wizard_behaviour = _GameplayState.new()

func _ready():
	_all_categories.append(in_game_ui)
	_all_categories.append(wizard_behaviour)
	super()


# ----------- DEFINE INNER CLASSES & SIGNALS ----------- #

class _WizardBehaviour:
	pass


class _GameUI:
	signal in_game_menu_opened
	signal in_game_menu_closed
