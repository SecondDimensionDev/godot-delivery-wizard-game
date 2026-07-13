class_name JobDefs
extends RefCounted

## Static table of the delivery jobs -- the single source of truth read by the job-menu
## UI (labels/rewards) and by DeliveryEconomy when spawning the cargo. The reward IS the
## cargo's start value. The `scene` key names a Directory.GAME_LEVELS entry the job
## routes to; jobs without one load the default "warehouse" map (see
## job_menu_controller.gd).

# CONSTANTS
const JOBS: Array[Dictionary] = [
	# `mass` is in wand-weight units: one wand comfortably handles 250 (Cargo.LIFT_PER_GRABBER),
	# so 250 = solo job, 500 = two wands, 750 = three, 1000 = the full four-player crew.
	{"name": "Easy", "reward": 100.0, "mass": 250.0, "damage_per_speed": 4.0, "zone": "Near",
		"com_offset": Vector3.ZERO, "cargo_kind": "box"},
	{"name": "Medium", "reward": 250.0, "mass": 500.0, "damage_per_speed": 8.0, "zone": "Mid",
		"com_offset": Vector3.ZERO, "cargo_kind": "box"},
	{"name": "Rolling", "reward": 350.0, "mass": 750.0, "damage_per_speed": 10.0,
		"zone": "Mid", "com_offset": Vector3.ZERO, "cargo_kind": "barrel"},
	{"name": "Hard", "reward": 500.0, "mass": 1000.0, "damage_per_speed": 14.0, "zone": "Far",
		"com_offset": Vector3(0.4, 0.0, 0.0), "cargo_kind": "box"},
	{"name": "Deep Delve", "reward": 600.0, "mass": 750.0, "damage_per_speed": 12.0,
		"zone": "Crypt", "com_offset": Vector3.ZERO, "cargo_kind": "box",
		"scene": "level_1"},
]

# PUBLIC VARIABLES
static var current_job_index: int = -1 ## Set by job_menu_controller.gd right before the
	## scene switch; read by the destination level's DeliveryEconomy.begin_play() once
	## its Setup state completes. The one piece of state that needs to survive a scene
	## switch that SystemManager's generic level-swap has no parameter for.
