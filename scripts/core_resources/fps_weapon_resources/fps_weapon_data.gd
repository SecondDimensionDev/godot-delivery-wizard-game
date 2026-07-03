class_name FPSWeaponData
extends Resource
## Defines the foundational data and configuration for a specific weapon.
##
## Used by the FPSWeaponManager to instantiate the weapon's physical scene
## and configure its base stats like ammo usage, damage, and fire rate.

enum FireMode { MANUAL, AUTOMATIC, BURST }

# EXPORT VARIABLES
@export_group("General")
@export var weapon_name: String = "New Weapon" ## The display name of the weapon
@export var weapon_scene: PackedScene ## The visual 3D model and logic scene to instantiate
@export var bullet_impact_scene: PackedScene ## The visual decal for bullet holes

@export_group("Weapon Feel")
@export var apply_recoil: bool
@export var recoil_rotation: Vector3 = Vector3(0.05, 0.02, 0.01) ## Base kick amount (Pitch, Yaw, Roll).
@export var recoil_snap_amount: float = 25.0 ## How fast the camera violently snaps to the target kick.
@export var recoil_recovery_speed: float = 10.0 ## How fast the camera rubber-bands back to center.
@export var recoil_randomness: float = 0.5 ## Adds chaos to the horizontal and roll kicks.

@export_group("Combat")
@export var base_damage: int = 10 ## The base damage dealt per shot
@export var fire_mode: FireMode = FireMode.MANUAL ## How the weapon handles continuous trigger pulls
@export var burst_count: int = 3 ## How many shots are fired in a single burst
@export var burst_rate: float = 0.05 ## The cooldown in seconds between individual shots within a burst
@export var fire_rate: float = 0.2 ## The cooldown time in seconds between each shot
@export var weapon_range: float = 80.0 ## The weapons range in metres
@export var bullet_spread: float = 0.0 ## How far the bullet can deviate from the center at max range.

@export_group("Logistics")
@export var equip_time: float = 0.4
@export var unequip_time: float = 0.4

@export_group("Ammo")
@export var ammo_type: String = "bullets" ## The string key used to query the PlayerAmmoComponent
@export var clip_size: int = 10 ## How much ammo a single clip/magazine holds
@export var reload_speed: float = 0.4 ## How long does it take the weapon to reload
@export var reload_animation_length: float = 1.0
@export var discard_clip_on_reload: bool = false ## If true, remaining ammo in the clip is lost on reload
