@tool
class_name ProceduralGrassGenerator
extends MultiMeshInstance3D
## Generates a highly performant MultiMesh of grass billboards based on a target terrain.
##
## This component reads the grid size, cell size, and noise from a ProceduralTerrainGenerator.
## It uses jitter to break up the grid, culls grass on steep slopes, and allows optional 
## integration with the terrain's exclusion zones.

# EXPORT VARIABLES
@export_tool_button("Generate Grass") var generate_button = _on_generate_button_pressed
@export_tool_button("Clear Grass") var clear_button = _clear_existing_data

@export_group("Dependencies")
@export var target_terrain: ProceduralTerrainGenerator ## The terrain component to sample from.
@export var grass_mesh: Mesh ## The simple quad or crossed-quad mesh to use for the grass.
@export var grass_material: Material ## The shader material to apply to the grass chunks.

@export_group("Spawning Rules")
@export var chunk_size: int = 16 ## How many terrain cells wide/deep a single grass chunk is.
@export var density: int = 2 ## How many grass blades to attempt to spawn per terrain cell.
@export var position_jitter: float = 1.5 ## How far a blade can wander from its grid center.
@export var min_scale: float = 0.8 ## The minimum random scale for a grass blade.
@export var max_scale: float = 1.2 ## The maximum random scale for a grass blade.
@export_range(0.0, 1.0) var max_slope_threshold: float = 0.8 ## 1.0 is flat. Lower numbers allow grass on steeper hills.

@export_group("Shader: Colors")
@export var shader_grass_texture: Texture2D ## Optional: Overrides the shader's base texture
@export var shader_alpha_scissor: float = 0.5
@export var shader_base_color: Color = Color(0.35, 0.5, 0.2)
@export var shader_variance_color: Color = Color(0.45, 0.6, 0.25)
@export var shader_use_upwards_normals: bool = true

@export_group("Shader: Wind")
@export var shader_wind_direction: Vector2 = Vector2(1.0, 0.5)
@export var shader_wind_speed: float = 2.0
@export var shader_wind_strength: float = 0.15

@export_group("Shader: Culling")
@export var shader_cull_distance: float = 60.0
@export var shader_fade_distance: float = 10.0

@export_group("Exclusion Zones")
@export var respect_terrain_exclusions: bool = false ## If true, grass will not spawn on roads/flat zones.

# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	if not Engine.is_editor_hint():
		# In a real build, you might want to call this deferred if it's not saved in the scene
		pass

# PRIVATE FUNCTIONS
func _on_generate_button_pressed() -> void:
	_generate_grass()

func _get_or_create_grass_mesh() -> Mesh:
	# If the user assigned a mesh in the inspector, use it!
	if grass_mesh:
		return grass_mesh
		
	# Otherwise, generate a procedural crossed-quad with the pivot at the bottom
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var w := 0.25 # Half-width
	var h := 1.0  # Height
	
	# Quad 1 (Facing Z)
	st.set_uv(Vector2(0, 1)); st.add_vertex(Vector3(-w, 0, 0)) # Bottom Left
	st.set_uv(Vector2(1, 1)); st.add_vertex(Vector3(w, 0, 0))  # Bottom Right
	st.set_uv(Vector2(1, 0)); st.add_vertex(Vector3(w, h, 0))  # Top Right
	
	st.set_uv(Vector2(1, 0)); st.add_vertex(Vector3(w, h, 0))  # Top Right
	st.set_uv(Vector2(0, 0)); st.add_vertex(Vector3(-w, h, 0)) # Top Left
	st.set_uv(Vector2(0, 1)); st.add_vertex(Vector3(-w, 0, 0)) # Bottom Left
	
	# Quad 2 (Facing X)
	st.set_uv(Vector2(0, 1)); st.add_vertex(Vector3(0, 0, -w)) # Bottom Left
	st.set_uv(Vector2(1, 1)); st.add_vertex(Vector3(0, 0, w))  # Bottom Right
	st.set_uv(Vector2(1, 0)); st.add_vertex(Vector3(0, h, w))  # Top Right
	
	st.set_uv(Vector2(1, 0)); st.add_vertex(Vector3(0, h, w))  # Top Right
	st.set_uv(Vector2(0, 0)); st.add_vertex(Vector3(0, h, -w)) # Top Left
	st.set_uv(Vector2(0, 1)); st.add_vertex(Vector3(0, 0, -w)) # Bottom Left
	
	st.generate_normals()
	return st.commit()


func _clear_existing_data() -> void:
	# Clear the root mesh just in case
	multimesh = null 
	# Destroy all previously generated chunk children
	for child in get_children():
		child.queue_free()


func _setup_grass_material() -> Material:
	if not grass_material:
		return null
	
	# Duplicate so this generator doesn't overwrite grass in completely different levels
	var mat = grass_material.duplicate() as ShaderMaterial
	if not mat:
		return grass_material # Fallback just in case a non-shader material was assigned
	
	# Push all our exported variables directly into the shader uniforms
	if shader_grass_texture:
		mat.set_shader_parameter("grass_texture", shader_grass_texture)
		
	mat.set_shader_parameter("alpha_scissor", shader_alpha_scissor)
	mat.set_shader_parameter("base_color", shader_base_color)
	mat.set_shader_parameter("variance_color", shader_variance_color)
	mat.set_shader_parameter("use_upward_normals", shader_use_upwards_normals)
	
	mat.set_shader_parameter("wind_direction", shader_wind_direction)
	mat.set_shader_parameter("wind_speed", shader_wind_speed)
	mat.set_shader_parameter("wind_strength", shader_wind_strength)
	
	mat.set_shader_parameter("cull_distance", shader_cull_distance)
	mat.set_shader_parameter("fade_distance", shader_fade_distance)
	
	return mat


func _generate_grass() -> void:
	if not target_terrain or not target_terrain.noise:
		push_warning("ProceduralGrassGenerator: Missing target terrain or noise!")
		return
	
	var hm: Array = target_terrain.get("_height_map")
	if not hm or hm.is_empty():
		print("Grass Generator: Terrain heightmap is empty. Forcing terrain rebuild...")
		target_terrain.generate_terrain()
	
	_clear_existing_data()
	
	var active_mat: Material = _setup_grass_material()
	
	var grid := target_terrain.grid_size
	var cell := target_terrain.cell_size
	var half_width := grid.x / 2.0
	var half_depth := grid.y / 2.0
	
	# Calculate how many chunks we need to cover the entire grid
	var chunks_x: int = ceil(grid.x / float(chunk_size))
	var chunks_z: int = ceil(grid.y / float(chunk_size))
	
	# Loop through the chunk grid
	for cx in range(chunks_x):
		for cz in range(chunks_z):
			_generate_chunk(cx, cz, grid, cell, half_width, half_depth, active_mat)


func _generate_chunk(cx: int, cz: int, grid: Vector2i, cell: float, half_width: float, half_depth: float, active_mat: Material) -> void:
	print("tried to generate chunk")
	# 1. Determine the start and end cells for this specific chunk
	var start_x := cx * chunk_size
	var start_z := cz * chunk_size
	var end_x :int = min(start_x + chunk_size, grid.x)
	var end_z :int = min(start_z + chunk_size, grid.y)

	# 2. Collect all valid grass positions for this chunk
	var chunk_data: Array = []
	
	for z in range(start_z, end_z):
		for x in range(start_x, end_x):
			for i in range(density):
				var data = _calculate_grass_transform(x, z, cell, half_width, half_depth)
				if data != null:
					chunk_data.append(data)
	
	# 3. If this chunk is completely empty (e.g., all roads or steep cliffs), abort to save memory!
	if chunk_data.is_empty():
		print("No Data")
		return
	
	# 4. Build the MultiMesh for this specific chunk
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _get_or_create_grass_mesh()
	mm.instance_count = chunk_data.size()
	
	for i in range(chunk_data.size()):
		mm.set_instance_transform(i, chunk_data[i].transform)
		mm.set_instance_custom_data(i, chunk_data[i].color)
	
	# 5. Create the Node, apply the mesh, and disable shadows
	var mm_instance := MultiMeshInstance3D.new()
	mm_instance.multimesh = mm
	mm_instance.name = "GrassChunk_%d_%d" % [cx, cz]
	mm_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	if active_mat:
		mm_instance.material_override = active_mat
		
	add_child(mm_instance)
	
	# Optional: Set the owner so you can actually see the chunks in the Editor Scene Tree
	if Engine.is_editor_hint() and get_tree().edited_scene_root:
		mm_instance.owner = get_tree().edited_scene_root


func _calculate_grass_transform(x: int, z: int, cell: float, half_width: float, half_depth: float) -> Variant:
	# 1. The terrain mesh stops 1 cell before the grid edge. We should too.
	if x >= target_terrain.grid_size.x - 1 or z >= target_terrain.grid_size.y - 1:
		return null
		
	# 2. Fetch the terrain's pre-calculated height map (Massive performance boost!)
	var hm: Array = target_terrain.get("_height_map")
	if not hm or hm.is_empty():
		return null
		
	# 3. Jitter STRICTLY within the bounds of this cell to perfectly fill the space without gaps
	var jitter_x := randf_range(0.0, cell)
	var jitter_z := randf_range(0.0, cell)

	var local_x := ((x - half_width) * cell) + jitter_x
	var local_z := ((z - half_depth) * cell) + jitter_z

	# 4. Get the exact heights of the 4 corners of this specific terrain cell
	var h_tl: float = hm[z][x]
	var h_tr: float = hm[z][x + 1]
	var h_bl: float = hm[z + 1][x]
	var h_br: float = hm[z + 1][x + 1]

	var final_height := 0.0
	var surface_normal := Vector3.UP

	# 5. Replicate the Terrain's exact meshing logic so we never float or clip
	if target_terrain.use_marching_squares:
		# Marching squares always creates a flat floor at the lowest corner point
		final_height = min(min(h_tl, h_tr), min(h_bl, h_br))
		surface_normal = Vector3.UP
	else:
		# Reconstruct the exact Triangles the terrain uses to find the true height and normal
		var p_tl := Vector3(0.0, h_tl, 0.0)
		var p_tr := Vector3(cell, h_tr, 0.0)
		var p_bl := Vector3(0.0, h_bl, cell)
		var p_br := Vector3(cell, h_br, cell)
		
		var plane: Plane
		
		# Match the terrain's diagonal splitting logic
		if abs(h_tl - h_br) < abs(h_tr - h_bl):
			if jitter_x > jitter_z:
				plane = Plane(p_tl, p_tr, p_br) # Top-Right Triangle
			else:
				plane = Plane(p_tl, p_br, p_bl) # Bottom-Left Triangle
		else:
			if (jitter_x + jitter_z) < cell:
				plane = Plane(p_tr, p_bl, p_tl) # Top-Left Triangle
			else:
				plane = Plane(p_tr, p_br, p_bl) # Bottom-Right Triangle
		
		surface_normal = plane.normal
		# Plane Equation: (D - Ax - Cz) / B = Y (This calculates the exact height on the slope!)
		final_height = (plane.d - (plane.normal.x * jitter_x) - (plane.normal.z * jitter_z)) / plane.normal.y

	# 6. Apply Slope Culling safely
	if surface_normal.y < max_slope_threshold:
		return null

	var local_pos := Vector3(local_x, final_height, local_z)
	var world_pos := target_terrain.to_global(local_pos)

	# 7. Check Exclusion Zones last, so we only run the expensive math on valid grass placements
	if respect_terrain_exclusions:
		var exclusion_mult: float = target_terrain._get_exclusion_multiplier(world_pos, local_pos)
		if exclusion_mult < 0.9:
			return null

	var final_pos := to_local(world_pos)
	var random_scale := randf_range(min_scale, max_scale)
	var random_rotation := randf_range(0.0, TAU)

	# Build the final transform safely
	var grass_basis := Basis().rotated(Vector3.UP, random_rotation).scaled(Vector3.ONE * random_scale)

	return {
		"transform": Transform3D(grass_basis, final_pos),
		"color": Color(randf(), 0.0, 0.0, 0.0)
	}
