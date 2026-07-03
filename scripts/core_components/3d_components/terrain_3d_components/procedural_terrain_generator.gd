@tool
class_name ProceduralTerrainGenerator
extends MeshInstance3D
## Generates a procedural low-poly terrain using the marching squares algorithm.
##
## This component builds a local heightmap from a FastNoiseLite resource,
## respects exclusion zones to create flat areas, and constructs an ArrayMesh 
## using SurfaceTool.

# EXPORT VARIABLES
## Click this to trigger generation in the editor.
@export_tool_button("Generate Terrain") var generate_button = _on_generate_button_pressed

## Click this to wipe the mesh before saving the scene.
@export_tool_button("Clear Terrain") var clear_button = _clear_existing_data

@export_group("Grid Settings")
@export var grid_size := Vector2i(32, 32) ## The number of cells in the X and Z axes.
@export var cell_size: float = 2.0 ## The physical width/length of each cell.

@export_group("Height Settings")
@export var noise: FastNoiseLite ## The procedural noise used for height generation.
@export var noise_amplitude: float = 10.0 ## Multiplier for the noise to create taller hills.
@export var merge_threshold: float = 0.5 ## The height difference below which vertices are flattened.
@export var shift_noise_up: bool = true ## Shifts noise so terrain only builds upward from Y=0.

@export_group("Exclusion Flat Zones")
@export var auto_flatten_center: bool = false ## Automatically creates a flat zone at the center of the mesh.
@export var center_flat_size := Vector2(50.0, 50.0) ## The X and Z size (in meters) of the flat center.
@export var center_blend_distance: float = 10.0 ## The distance to smoothly slope up from the center flat zone.
@export var use_exclusion_group: bool = false ## Use items in the exlusion group to create flat areas.
@export var exclusion_group: String = "terrain_exclusion_zone" ## Nodes in this group are automatically added.
@export var exclusion_zones: Array[NodePath] ## Explicitly assigned nodes to flatten terrain.
@export var exclusion_blend_distance: float = 10.0 ## The distance (in meters) to smoothly slope up from exclusion zones.

@export_group("Meshing Options")
@export var generate_on_startup: bool = false ## Forces terrain to regenerate during _ready function
@export var use_marching_squares: bool = true ## Toggle between sharp diagonal cliffs and simple smooth ramps.

@export_group("Features")
@export var terrain_material: Material ## The shader material applied to the generated mesh.
@export var cast_shadows: bool = true ## If false, the terrain will not cast directional light shadows.
@export var generate_collisions: bool = true ## If true, a StaticBody3D will be generated.

# PRIVATE VARIABLES
var _height_map: Array = []
var _active_exclusion_nodes: Array[VisualInstance3D] = [] ## Cached nodes for performance.


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	if not Engine.is_editor_hint() and generate_on_startup:
		generate_terrain.call_deferred()


# PUBLIC FUNCTIONS
func generate_terrain() -> void: ## Main orchestrator function to build the terrain from scratch.
	if not noise:
		push_warning("ProceduralMarchingTerrain: No FastNoiseLite assigned!")
		return
	
	_clear_existing_data()
	_cache_exclusion_nodes()
	_generate_heightmap()
	_build_mesh()
	
	if generate_collisions:
		_generate_collision()


# PRIVATE FUNCTIONS
func _on_generate_button_pressed() -> void: # Triggers from the editor inspector button
	generate_terrain()


func _clear_existing_data() -> void: # Wipes the current mesh and child collision nodes
	mesh = null
	_height_map.clear()
	
	# Remove any existing StaticBody3D children we previously generated
	for child in get_children():
		if child is StaticBody3D:
			child.queue_free()


func _generate_heightmap() -> void:
	_height_map.clear()
	_height_map.resize(grid_size.y)
	
	var half_width := grid_size.x / 2.0
	var half_depth := grid_size.y / 2.0
	
	for z in range(grid_size.y):
		var row: Array[float] = []
		row.resize(grid_size.x)
		
		for x in range(grid_size.x):
			var local_pos := Vector3(
				(x - half_width) * cell_size,
				0.0,
				(z - half_depth) * cell_size
			)
			
			var world_pos := to_global(local_pos)
			
			# 1. Get the raw noise
			var raw_noise := noise.get_noise_2d(world_pos.x, world_pos.z)
			
			# 2. Shift the noise if requested (maps -1.0 to 1.0 into 0.0 to 1.0)
			if shift_noise_up:
				raw_noise = (raw_noise + 1.0) / 2.0
				
			var raw_height := raw_noise * noise_amplitude
			
			# 3. Apply the smooth exclusion zone multiplier
			var exclusion_mult := _get_exclusion_multiplier(world_pos, local_pos)
			raw_height *= exclusion_mult
			
			# 4. Snap the final result to our layer cake heights
			row[x] = snapped(raw_height, merge_threshold)
				
		_height_map[z] = row


func _get_exclusion_multiplier(world_pos: Vector3, local_pos: Vector3) -> float: 
	var min_multiplier := 1.0
	
	# 1. Check the built-in center flat zone (Ultra-fast local math)
	if auto_flatten_center:
		var half_extents := center_flat_size / 2.0
		
		# Mathematically find the closest point ON or INSIDE the virtual center box
		var closest_point := Vector3(
			clamp(local_pos.x, -half_extents.x, half_extents.x),
			0.0, 
			clamp(local_pos.z, -half_extents.y, half_extents.y)
		)
		
		var dist := local_pos.distance_to(closest_point)
		var multiplier := 0.0
		
		if center_blend_distance > 0.0:
			multiplier = clamp(dist / center_blend_distance, 0.0, 1.0)
		else:
			multiplier = 0.0 if dist == 0.0 else 1.0
			
		min_multiplier = min(min_multiplier, multiplier)
	
	# 2. Check external cached exclusion zones
	for node in _active_exclusion_nodes:
		var node_local_pos := node.to_local(world_pos)
		var aabb := node.get_aabb()
		
		var closest_point := Vector3(
			clamp(node_local_pos.x, aabb.position.x, aabb.end.x),
			clamp(node_local_pos.y, aabb.position.y, aabb.end.y),
			clamp(node_local_pos.z, aabb.position.z, aabb.end.z)
		)
		
		var dist := node_local_pos.distance_to(closest_point)
		var multiplier := 0.0
		
		if exclusion_blend_distance > 0.0:
			multiplier = clamp(dist / exclusion_blend_distance, 0.0, 1.0)
		else:
			multiplier = 0.0 if dist == 0.0 else 1.0
			
		min_multiplier = min(min_multiplier, multiplier)
			
	return min_multiplier


func _build_mesh() -> void: 
	if _height_map.is_empty() or grid_size.x < 2 or grid_size.y < 2:
		return
		
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	if use_marching_squares:
		_build_mesh_marching_squares(st)
	else:
		_build_mesh_simple(st)
		
	# This automatically calculates sharp, flat-shaded normals for us!
	st.generate_normals() 
	mesh = st.commit()
	# Re-apply the material to the newly generated mesh
	if terrain_material:
		mesh.surface_set_material(0, terrain_material)
	
	# Apply shadow casting preference
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_mesh_simple(st: SurfaceTool) -> void:
	var half_width := grid_size.x / 2.0
	var half_depth := grid_size.y / 2.0
	
	for z in range(grid_size.y - 1):
		for x in range(grid_size.x - 1):
			var h_tl: float = _height_map[z][x]
			var h_tr: float = _height_map[z][x + 1]
			var h_bl: float = _height_map[z + 1][x]
			var h_br: float = _height_map[z + 1][x + 1]
			
			var p_tl := Vector3((x - half_width) * cell_size, h_tl, (z - half_depth) * cell_size)
			var p_tr := Vector3((x + 1 - half_width) * cell_size, h_tr, (z - half_depth) * cell_size)
			var p_bl := Vector3((x - half_width) * cell_size, h_bl, (z + 1 - half_depth) * cell_size)
			var p_br := Vector3((x + 1 - half_width) * cell_size, h_br, (z + 1 - half_depth) * cell_size)
			
			if abs(h_tl - h_br) < abs(h_tr - h_bl):
				_add_triangle(st, p_tl, p_tr, p_br)
				_add_triangle(st, p_tl, p_br, p_bl)
			else:
				_add_triangle(st, p_tr, p_br, p_bl)
				_add_triangle(st, p_tr, p_bl, p_tl)


func _build_mesh_marching_squares(st: SurfaceTool) -> void:
	var half_width := grid_size.x / 2.0
	var half_depth := grid_size.y / 2.0
	
	for z in range(grid_size.y - 1):
		for x in range(grid_size.x - 1):
			var h_tl: float = _height_map[z][x]
			var h_tr: float = _height_map[z][x + 1]
			var h_bl: float = _height_map[z + 1][x]
			var h_br: float = _height_map[z + 1][x + 1]
			
			var min_h: float = min(h_tl, h_tr, h_bl, h_br)
			var max_h: float = max(h_tl, h_tr, h_bl, h_br)
			
			var x0 := (x - half_width) * cell_size
			var x1 := (x + 1 - half_width) * cell_size
			var z0 := (z - half_depth) * cell_size
			var z1 := (z + 1 - half_depth) * cell_size
			var xm := (x0 + x1) / 2.0
			var zm := (z0 + z1) / 2.0
			
			# 1. Always draw a sealed base floor for the cell
			_add_quad(st, Vector3(x0, min_h, z0), Vector3(x1, min_h, z0), Vector3(x1, min_h, z1), Vector3(x0, min_h, z1))
			
			# 2. Process layer by layer upward
			var current_h := min_h + merge_threshold
			while current_h <= max_h + 0.01: # 0.01 margin for float precision
				var lower_h := current_h - merge_threshold
				
				var mask := 0
				if h_tl >= current_h - 0.01: mask |= 1
				if h_tr >= current_h - 0.01: mask |= 2
				if h_br >= current_h - 0.01: mask |= 4
				if h_bl >= current_h - 0.01: mask |= 8
				
				# High points for the top of this layer
				var p0 := Vector3(x0, current_h, z0); var p1 := Vector3(x1, current_h, z0)
				var p2 := Vector3(x1, current_h, z1); var p3 := Vector3(x0, current_h, z1)
				var p01 := Vector3(xm, current_h, z0); var p12 := Vector3(x1, current_h, zm)
				var p23 := Vector3(xm, current_h, z1); var p30 := Vector3(x0, current_h, zm)
				
				# Low points for the bottom of the walls
				var p01_lo := Vector3(xm, lower_h, z0); var p12_lo := Vector3(x1, lower_h, zm)
				var p23_lo := Vector3(xm, lower_h, z1); var p30_lo := Vector3(x0, lower_h, zm)
				
				match mask:
					1: # TL is high
						_add_triangle(st, p0, p01, p30)
						_add_quad(st, p30, p01, p01_lo, p30_lo) # Wall
					2: # TR is high
						_add_triangle(st, p1, p12, p01)
						_add_quad(st, p01, p12, p12_lo, p01_lo) # Wall
					3: # Top half is high
						_add_quad(st, p0, p1, p12, p30)
						_add_quad(st, p30, p12, p12_lo, p30_lo) # Wall
					4: # BR is high
						_add_triangle(st, p2, p23, p12)
						_add_quad(st, p12, p23, p23_lo, p12_lo) # Wall
					5: # TL and BR high
						_add_triangle(st, p0, p01, p30)
						_add_triangle(st, p2, p23, p12)
						_add_quad(st, p30, p01, p01_lo, p30_lo) # Wall 1
						_add_quad(st, p12, p23, p23_lo, p12_lo) # Wall 2
					6: # TR and BR high
						_add_quad(st, p1, p2, p23, p01)
						_add_quad(st, p01, p23, p23_lo, p01_lo) # Wall
					7: # TL, TR, BR high
						_add_triangle(st, p0, p1, p30); _add_triangle(st, p1, p2, p30); _add_triangle(st, p2, p23, p30)
						_add_quad(st, p30, p23, p23_lo, p30_lo) # Wall
					8: # BL is high
						_add_triangle(st, p3, p30, p23)
						_add_quad(st, p23, p30, p30_lo, p23_lo) # Wall
					9: # TL and BL high
						_add_quad(st, p0, p01, p23, p3)
						_add_quad(st, p23, p01, p01_lo, p23_lo) # Wall
					10: # TR and BL high
						_add_triangle(st, p1, p12, p01)
						_add_triangle(st, p3, p30, p23)
						_add_quad(st, p01, p12, p12_lo, p01_lo) # Wall 1
						_add_quad(st, p23, p30, p30_lo, p23_lo) # Wall 2
					11: # TL, TR, BL high
						_add_triangle(st, p0, p1, p3); _add_triangle(st, p1, p12, p3); _add_triangle(st, p12, p23, p3)
						_add_quad(st, p23, p12, p12_lo, p23_lo) # Wall
					12: # BL and BR high
						_add_quad(st, p3, p30, p12, p2)
						_add_quad(st, p12, p30, p30_lo, p12_lo) # Wall
					13: # TL, BR, BL high
						_add_triangle(st, p0, p01, p3); _add_triangle(st, p01, p12, p3); _add_triangle(st, p12, p2, p3)
						_add_quad(st, p12, p01, p01_lo, p12_lo) # Wall
					14: # TR, BR, BL high
						_add_triangle(st, p1, p2, p01); _add_triangle(st, p2, p3, p01); _add_triangle(st, p3, p30, p01)
						_add_quad(st, p01, p30, p30_lo, p01_lo) # Wall
					15: # All high
						_add_quad(st, p0, p1, p2, p3) # Just a flat top, no walls needed
						
				current_h += merge_threshold


func _add_triangle(st: SurfaceTool, v1: Vector3, v2: Vector3, v3: Vector3) -> void:
	st.add_vertex(v1)
	st.add_vertex(v2)
	st.add_vertex(v3)


func _add_quad(st: SurfaceTool, v1: Vector3, v2: Vector3, v3: Vector3, v4: Vector3) -> void:
	# Splits a 4-point polygon into two triangles safely
	_add_triangle(st, v1, v2, v3)
	_add_triangle(st, v1, v3, v4)


func _cache_exclusion_nodes() -> void: # Gathers and caches nodes to optimize the generation loops
	_active_exclusion_nodes.clear()
	
	# 1. Add explicitly assigned paths
	for path in exclusion_zones:
		var node := get_node_or_null(path) as VisualInstance3D
		if node and not _active_exclusion_nodes.has(node):
			_active_exclusion_nodes.append(node)
			
	# 2. Add nodes from the specified group
	if use_exclusion_group and not exclusion_group.is_empty() and is_inside_tree():
		var group_nodes := get_tree().get_nodes_in_group(exclusion_group)
		for node in group_nodes:
			if node is VisualInstance3D and not _active_exclusion_nodes.has(node):
				_active_exclusion_nodes.append(node)


func _generate_collision() -> void: # Creates a trimesh collision shape from the generated mesh
	if not mesh:
		return
		
	var static_body := StaticBody3D.new()
	var collision_shape := CollisionShape3D.new()
	
	collision_shape.shape = mesh.create_trimesh_shape()
	static_body.add_child(collision_shape)
	
	add_child(static_body)
	
	# If running in the editor, we set the owner so the collision nodes show up in the scene tree
	if Engine.is_editor_hint() and get_tree().edited_scene_root:
		static_body.owner = get_tree().edited_scene_root
		collision_shape.owner = get_tree().edited_scene_root
