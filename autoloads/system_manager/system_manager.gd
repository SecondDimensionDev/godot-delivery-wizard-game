## SystemManager Autoload
@icon("uid://kfu7cw4ooxsh")
extends BaseSystemManager
## Global system coordinator for state management and scene transitions.
##
## The SystemManager acts as a central hub for controlling the application flow. 
## It orchestrates transitions between high-level system states (e.g., Menu, Gameplay, Cinematic) 
## and handles asynchronous scene loading through a dedicated Loading state.
## This extends the [BaseSystemManager] class, add any game-specific logic here
