extends Node
## A simple debug tool to print network authority and active processing nodes.

func _unhandled_input(event: InputEvent) -> void:
	# Check if the '[' key was just pressed
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_BRACKETLEFT:
		_print_multiplayer_debug_info()


func _print_multiplayer_debug_info() -> void:
	print("\n========== MULTIPLAYER DEBUG INFO ==========")
	
	# NOTE: You MUST ensure your player scene root node is in a group called "player"
	var players = get_tree().get_nodes_in_group("player")
	
	if players.is_empty():
		print("ERROR: No players found. Add your player scene to the 'player' group!")
		print("============================================\n")
		return
		
	for player in players:
		var auth_id = player.get_multiplayer_authority()
		var is_local_auth = player.is_multiplayer_authority()
		
		print("\n> PLAYER NODE: ", player.name)
		print("  Authority ID: ", auth_id)
		print("  Is Local Authority?: ", is_local_auth)
		print("  --- Processing Nodes ---")
		
		# Kick off the recursive check
		_check_processing_recursively(player, "    ")
		
	print("\n============================================\n")


func _check_processing_recursively(node: Node, indent: String) -> void:
	var active_processes: Array[String] = []
	
	# Check all the common processing flags
	if node.is_processing(): 
		active_processes.append("Process")
	if node.is_physics_processing(): 
		active_processes.append("Physics")
	if node.is_processing_input(): 
		active_processes.append("Input")
	if node.is_processing_unhandled_input(): 
		active_processes.append("Unhandled Input")
	if node.is_processing_unhandled_key_input(): 
		active_processes.append("Key Input")
	
	# If this node has any processing active, print it out
	if not active_processes.is_empty():
		print(indent + "- " + node.name + " [" + ", ".join(active_processes) + "]")
		
	# Recursively check all children of this node
	for child in node.get_children():
		_check_processing_recursively(child, indent + "  ")
