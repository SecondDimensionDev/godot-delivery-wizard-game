@tool
extends EditorScript

# --- SETTINGS ---
# Set to 'true' to show every single node inside instantiated child scenes.
# Set to 'false' to just show the root node of the scene and hide its internals.
const EXPAND_INSTANCED_SCENES: bool = false
# ----------------

func _run():
	# Get the root node of the currently open scene
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		print("No scene currently open in the editor.")
		return
		
	# Build the string
	var tree_string = _build_tree_string(root, 0)
	
	tree_string = "Godot Scene Tree. Each node shows the base node type, associated script and instantiated child scene if applicable.  Any nodes inheriting from StateMachine will also show the associated registered state scripts." + "\n"  + "\n" + tree_string
	
	# Create a clean file name based on the Root Node's name
	var safe_name = str(root.name).to_lower().replace(" ", "_")
	var save_path = "res://" + safe_name + "_scene_tree.txt"
	
	# FileAccess.WRITE automatically overwrites existing files
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	
	if file:
		file.store_string(tree_string)
		print("Scene tree exported successfully to: ", save_path)
		
		# Force Godot to refresh the FileSystem dock so the updated file is visible instantly
		EditorInterface.get_resource_filesystem().scan()
	else:
		print("Failed to save file.")

func _build_tree_string(node: Node, indent_level: int) -> String:
	var indent = "  ".repeat(indent_level)
	var line = indent + "- " + node.name + " (" + node.get_class() + ")"
	var script = node.get_script()
	
	if script:
		line += " [Script: " + script.resource_path.get_file() + "]"
		
	# Determine if this specific node is an instantiated child scene
	var is_instanced_scene = node != EditorInterface.get_edited_scene_root() and node.scene_file_path != ""
	
	if is_instanced_scene:
		line += " [Scene: " + node.scene_file_path.get_file() + "]"
		
	var result = line + "\n"
	
	# --- CUSTOM STATE MACHINE CHECK ---
	if node.get_class() == "StateMachine" or (script and "state_machine" in script.resource_path.get_file().to_lower()):
		var state_scripts = node.get("set_state_scripts")
		
		if state_scripts and typeof(state_scripts) == TYPE_DICTIONARY:
			var state_indent = "  ".repeat(indent_level + 1)
			result += state_indent + "Registered States:\n"
			
			for state_name in state_scripts:
				var state_script = state_scripts[state_name]
				if state_script:
					result += state_indent + "  -> " + str(state_name) + " [" + state_script.resource_path.get_file() + "]\n"
				else:
					result += state_indent + "  -> " + str(state_name) + " [Empty Script Assign]\n"
	# ----------------------------------
	
	# --- RECURSION CONTROL ---
	if not is_instanced_scene or EXPAND_INSTANCED_SCENES:
		for child in node.get_children():
			result += _build_tree_string(child, indent_level + 1)
			
	return result
