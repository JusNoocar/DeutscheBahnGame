extends ColorRect

@onready var game = get_tree().root.get_node("Game")

# 1. Start a drag from the map
func _get_drag_data(at_position: Vector2) -> Variant:
	#var tile_map = game.tile_map
	#var map_pos = tile_map.local_to_map(tile_map.to_local(get_global_mouse_position()))
	#
	
	#for item in game.used_items:
		#if item.get("map_pos") == map_pos and item.get("pinned", false):
			#return null
			#
	#var atlas_coords = tile_map.get_cell_atlas_coords(map_pos)
	#var is_obstacle = false
	#for item in game.initial_data: # Wir nutzen die Liste aus dem MenuManager
		#if item.id == atlas_coords:
			#is_obstacle = true
			#break
	#
	#if not is_obstacle:
		#return null
	#
	#if atlas_coords != Vector2i(-1, -1):
		## Create the data package for the drag
		#var data = {"id": atlas_coords, "map_pos": map_pos, "from_map": true}
		#
		## Find this placement in the used_items list to get the 'old_tile' data
		#for item in game.used_items:
			#if item.has("map_pos") and item.map_pos == map_pos:
				#if item.has("old_tile_atlas"):
					#data["old_tile_atlas"] = item.old_tile_atlas
					#data["old_tile_source"] = item.old_tile_source
#
				#break
		#
		## Visual preview and return
		#var preview = TextureRect.new()
		#preview.texture = game.get_tile_texture(atlas_coords)
		#preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		#preview.custom_minimum_size = Vector2(14, 14)
		#set_drag_preview(preview)
		#
		#return data
	#return null
	
	var tile_map = game.tile_map
	var map_pos = tile_map.local_to_map(tile_map.to_local(get_global_mouse_position()))
	
	# 1. Find the item at this position in our tracking list [file:516]
	var current_item = null
	for item in game.used_items:
		if item.map_pos == map_pos:
			current_item = item
			break
	
	# 2. If no item exists OR it is PINNED, block the drag
	if current_item == null or current_item.get("pinned", false) == true:
		return null # This prevents dragging back "old" obstacles [file:519]

	# 3. If it's a new obstacle (not pinned), allow the drag [file:515]
	var data = {
		"id": current_item.id, 
		"map_pos": map_pos, 
		"from_map": true
	}
	
	# Pack the old tile data so we can restore the tracks underneath [file:518]
	if current_item.has("old_tile_atlas"):
		data["old_tile_atlas"] = current_item.old_tile_atlas
		data["old_tile_source"] = current_item.old_tile_source

	# Visual preview
	var preview = TextureRect.new()
	preview.texture = game.get_tile_texture(current_item.id)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(14, 14)
	set_drag_preview(preview)
	
	return data

var valid_frame = Rect2i(Vector2i(61, 49), Vector2i(40, 30)) 

func _can_drop_data(_at_position, data):
	var tile_map = game.tile_map
	var map_pos = tile_map.local_to_map(tile_map.to_local(get_global_mouse_position()))


	if not valid_frame.has_point(map_pos):
		return false
	var current_atlas = tile_map.get_cell_atlas_coords(map_pos)

	for item in game.used_items:
		if item.map_pos == map_pos:
			return false
			
	#for item in game.initial_data:
		#if item.id == current_atlas:
			#return false

	if data.has("from_map"):
		return false
		
	return data is Dictionary and data.has("id")

func _drop_data(_at_position, data):
	var tile_map = game.tile_map
	var map_pos = tile_map.local_to_map(tile_map.to_local(get_global_mouse_position()))

	var next_atlas = tile_map.get_cell_atlas_coords(map_pos)
	var next_source = tile_map.get_cell_source_id(map_pos)
	
	tile_map.set_cell(map_pos, 0, data.id)

	var new_record = {
		"id": data.id, 
		"map_pos": map_pos,
		"creation_time":GlobalGameManager.game_time,
		"pinned": false # Pinned if added during pause
	}
	
	if data.has("source") and data.source != null:
		data.source.amount -= 1
		data.source.update_visuals()
		
	if next_source != -1:
		new_record["old_tile_atlas"] = next_atlas
		new_record["old_tile_source"] = next_source

	game.used_items.append(new_record)
	# Sync to global immediately
	GlobalGameManager.saved_tile_data = game.used_items.duplicate(true)
