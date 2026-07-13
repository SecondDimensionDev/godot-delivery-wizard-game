extends Node3D

## Spawns a warm, gently flickering OmniLight3D over every GridMap cell whose
## MeshLibrary item name is listed in fire_item_names (braziers, fire pits...). Purely
## cosmetic and local -- lights are spawned per-client and never synced.

# EXPORT VARIABLES
@export var grid_map_path: NodePath ## The GridMap to scan for fire cells.
@export var fire_item_names: PackedStringArray = [
	"DungeonSetCube053",
	"DungeonSetCube054",
] ## MeshLibrary item names that count as fires.
@export var light_color := Color(1.0, 0.55, 0.22) ## Warm ember orange.
@export var light_energy := 2.5 ## Base brightness; the flicker wobbles around this.
@export var light_range := 7.0 ## Omni radius in meters.
@export var light_offset := Vector3(0.0, 0.0, 0.0) ## Nudge from the cell center.
@export var shadows_enabled := false ## Per-light shadows (costly with many fires).

# PRIVATE VARIABLES
var _lights: Array[OmniLight3D] = []
var _phases: PackedFloat32Array = []
var _time := 0.0


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	var grid_map := get_node_or_null(grid_map_path) as GridMap
	if grid_map == null or grid_map.mesh_library == null:
		push_warning("GridMapFireLights: no GridMap (with MeshLibrary) at %s" % grid_map_path)
		return
	var fire_ids: Array[int] = []
	for item_name in fire_item_names:
		var id := grid_map.mesh_library.find_item_by_name(item_name)
		if id != -1:
			fire_ids.append(id)
	for cell: Vector3i in grid_map.get_used_cells():
		if grid_map.get_cell_item(cell) in fire_ids:
			_spawn_light(grid_map.to_global(grid_map.map_to_local(cell)) + light_offset)


func _process(delta: float) -> void:
	_time += delta
	for i in _lights.size():
		var t := _time + _phases[i]
		# Layered sines = irregular ember wobble; never fully dark, unlike a torch guttering.
		var n := sin(t * 9.0) * 0.5 + sin(t * 23.0) * 0.3 + sin(t * 2.6) * 0.2
		_lights[i].light_energy = light_energy * (0.85 + n * 0.15)


# PRIVATE FUNCTIONS
func _spawn_light(world_position: Vector3) -> void:
	var light := OmniLight3D.new()
	light.light_color = light_color
	light.light_energy = light_energy
	light.omni_range = light_range
	light.shadow_enabled = shadows_enabled
	add_child(light)
	light.global_position = world_position
	_lights.append(light)
	_phases.append(randf() * 10.0)
