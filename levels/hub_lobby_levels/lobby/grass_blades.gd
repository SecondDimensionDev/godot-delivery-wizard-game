extends MultiMeshInstance3D

## Client-local grass blade dressing for the nature-area ground plane. Scatters a
## simple tapered blade mesh via MultiMesh across Scenery/Grass, which never scrolls
## (only the Movers dressing scrolls to fake cart motion) -- purely cosmetic and unsynced.

# CONSTANTS
const BLADE_COUNT := 1500
const AREA_HALF_X := 38.0
const AREA_HALF_Z := 38.0
const ROAD_HALF_WIDTH := 2.3 # keep blades off the dirt road strip
const BLADE_HEIGHT_MIN := 0.15
const BLADE_HEIGHT_MAX := 0.35
const BLADE_WIDTH := 0.06
const BASE_COLOR := Color(0.09, 0.16, 0.06)
const TIP_COLOR := Color(0.32, 0.42, 0.16)


# BUILT-IN VIRTUAL METHODS
func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1 # deterministic layout so every client sees the same field
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _build_blade_mesh()
	multimesh.instance_count = BLADE_COUNT
	for i in BLADE_COUNT:
		multimesh.set_instance_transform(i, _random_blade_transform(rng))
	material_override = _build_blade_material()


# PRIVATE FUNCTIONS
func _random_blade_transform(rng: RandomNumberGenerator) -> Transform3D:
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var x := side * rng.randf_range(ROAD_HALF_WIDTH, AREA_HALF_X)
	var z := rng.randf_range(-AREA_HALF_Z, AREA_HALF_Z)
	var height_scale := rng.randf_range(BLADE_HEIGHT_MIN, BLADE_HEIGHT_MAX) / BLADE_HEIGHT_MAX
	var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
	basis = basis.scaled(Vector3(1.0, height_scale, 1.0))
	return Transform3D(basis, Vector3(x, 0.05, z))


func _build_blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_w := BLADE_WIDTH * 0.5
	var verts := [
		Vector3(-half_w, 0.0, 0.0),
		Vector3(half_w, 0.0, 0.0),
		Vector3(0.0, BLADE_HEIGHT_MAX, 0.0),
	]
	var colors := [BASE_COLOR, BASE_COLOR, TIP_COLOR]
	for idx in range(3):
		st.set_color(colors[idx])
		st.add_vertex(verts[idx])
	st.generate_normals()
	return st.commit()


func _build_blade_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.9
	return mat
