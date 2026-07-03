## TimescaleManager Autoload
extends BaseTimescaleManager
## Global manager for game speed, pausing, and time-based effects.
##
## The TimescaleManager should be set as a Global Autoload. It provides
## standardized methods for pausing the game via the [SceneTree], manipulating 
## the [member Engine.time_scale] with smooth transitions, and triggering 
## 'hit-stop' effects for combat feedback.  This extends [BaseTimescaleManager],
## add any game-specific logic here.
