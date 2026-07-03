## LoadingScreen Autoload
@icon("uid://cqr1itkxvpij8")
extends BaseLoadingScreen
## A global manager that handles asynchronous scene loading, transitions, and loading UI.
##
## This system completely decouples the visual transition (fade in/out) and the 
## loading screen content (spinners, tips) from the multi-threaded resource loading logic.
## Extends the [BaseLoadingScreen] class, which handles core logic.
