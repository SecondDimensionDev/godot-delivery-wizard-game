extends SceneTree

## Dev tool — generates labeled_zoo.tscn: every item in the shared dungeon MeshLibrary
## laid out on a grid with a floating name label and a fly camera. F6 it to browse the
## set and read the real item names.
## Run:  godot --headless --path . -s res://Levels/test_levels/creation_levels/dungeon_1/labeled_zoo_gen.gd

const LIB_PATH := "res://environment/3d_mesh_libraries/dungeon_mesh_library.res"
const OUT_PATH := "res://levels/_debug_levels/labeled_zoo.tscn"
const COLS := 12
const SPACING := 6.0


func _init() -> void:
	var lib: MeshLibrary = load(LIB_PATH)
	var root := Node3D.new()
	root.name = "LabeledZoo"

	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.13, 0.13, 0.15)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 1.4
	env.environment = e
	root.add_child(env)

	var ids := lib.get_item_list()
	for i in ids.size():
		var id := ids[i]
		var holder := Node3D.new()
		holder.name = "Item%03d" % id
		holder.position = Vector3(
			(i % COLS) * SPACING, 0.0, float(i / COLS) * SPACING)
		root.add_child(holder)

		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = lib.get_item_mesh(id)
		mi.transform = lib.get_item_mesh_transform(id)
		holder.add_child(mi)

		var label := Label3D.new()
		label.name = "Label"
		label.text = "%d\n%s" % [id, lib.get_item_name(id)]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 48
		label.outline_size = 12
		label.position = Vector3(0, 4.2, 0)
		label.pixel_size = 0.01
		holder.add_child(label)

	var cam := Camera3D.new()
	cam.name = "FlyCamera"
	cam.set_script(load("res://levels/_debug_levels/fly_camera.gd"))
	cam.position = Vector3(COLS * SPACING * 0.5, 10.0, -14.0)
	cam.rotation_degrees = Vector3(-25, 180, 0)
	root.add_child(cam)

	for child in root.get_children():
		child.owner = root
		for sub in child.get_children():
			sub.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, OUT_PATH)
	print("saved ", OUT_PATH, " err=", err)
	quit(0 if err == OK else 1)
