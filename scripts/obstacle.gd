extends PanelContainer

var item_id: Vector2i 
var item_name: String
var amount: int = 3

enum Type { CONSTRUCTION, PERSON, SNOW, CARNEVAL, ACCIDENT, BASIC_DELAY }
@export var type: Type = Type.CONSTRUCTION
static var OBSTACLE_DURATIONS = {
	Vector2i(5, 0): 60.0, # Baustelle
	Vector2i(4, 7): 30.0, # Person
	Vector2i(5, 2): 45.0, # Schnee
	Vector2i(5, 8): 90.0, # Karnival
	Vector2i(5, 6): 50.0, # Accident
	Vector2i(1, 2): 15.0  # Delay
}

func _on_place(grid_pos: Vector2i):
	var duration = 0
	match type:
		Type.PERSON: duration = 15 # Minutes/Ticks
		Type.ACCIDENT: duration = 10
		Type.BASIC_DELAY: duration = 2
		Type.CONSTRUCTION, Type.SNOW: duration = 999 # Permanent
	
	# Register with the tracks manager to store the duration [file:832]
	Tracks_Manager.register_obstacle(grid_pos, type, duration)
	print("checkie")
	# Update Graph [file:827]
	if GlobalVars.current_graph:
		GlobalVars.current_graph.disabled[grid_pos] = true

func _get_drag_data(_at_position: Vector2) -> Variant:
	if amount <= 0: return null
	
	var preview = TextureRect.new()
	preview.texture = $HBoxContainer/Icon.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(14, 14)
	set_drag_preview(preview)
	
	# 2. Return the data to be "dropped"
	return {"id": item_id, "name": item_name, "source": self}
	
func _can_drop_data(_pos, data):
	return data is Dictionary and data.has("id") and data.id == item_id

func _drop_data(_pos, data):
	var game = get_tree().root.get_node("Game")
	#var tile_map = game.tile_map
	
	if data.has("map_pos"):
		for item in game.used_items:
			if item.map_pos == data.map_pos and item.get("pinned", false):
				return # Block returning pinned items to the menu
				
	if data.has("from_map") and data.from_map == true:
		amount += 1
		update_visuals()
	
	if data.has("map_pos"):
		if data.has("old_tile_atlas"):
			game.tile_map.set_cell(data.map_pos, data.old_tile_source, data.old_tile_atlas)
		else:
			game.tile_map.erase_cell(data.map_pos)
		
		# Remove from the tracking list
		for i in range(game.used_items.size()):
			if game.used_items[i].map_pos == data.map_pos:
				game.used_items.remove_at(i)
				break
				
	GlobalGameManager.saved_tile_data = game.used_items.duplicate(true)

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Check if the mouse is clicking THIS obstacle [file:806]
			# (Assuming you have an Area2D setup)
			pass # Logic usually handled by _on_input_event
			
		else: # MOUSE RELEASE
			if GlobalGameManager.is_dragging_obstacle and GlobalGameManager.current_obstacle == self:
				GlobalGameManager.is_dragging_obstacle = false
				var grid_pos = Vector2i((global_position / 16).floor()) - Vector2i(1, 3)
				
				# Determine duration based on your list [file:833]
				var duration = 999 # Default for permanent (Construction/Snow)
				if type == Type.PERSON: duration = 15
				elif type == Type.ACCIDENT: duration = 10
				elif type == Type.BASIC_DELAY: duration = 2
				
				# Call the new function we just added [file:832]
				Tracks_Manager.register_obstacle(grid_pos, type, duration)

func update_visuals():
	var title_node = $HBoxContainer/VBoxContainer/Title
	var icon_node = $HBoxContainer/Icon
	
	title_node.text = item_name + " (" + str(amount) + ")"
	
	if amount <= 0:
		modulate.a = 0.3 
		title_node.text = item_name + " (0)"
	else:
		modulate.a = 1.0

static var current_obsticals = []

static func monitorObsticals():
	var obstical_objects = []
	for data in GlobalGameManager.saved_tile_data:
		# 1. Create a new logic object
		var obs = Tracks_Manager.Obstical.new()
		obs.pos = data.map_pos
		obs.placement_time = data.get("creation_time", 0.0)
		
		# 2. Look up duration based on the Atlas ID
		var atlas_id = data.id
		obs.duration = OBSTACLE_DURATIONS.get(atlas_id, 10.0) # Default 10s
		
		obstical_objects.append(obs)
		print(obstical_objects)
	
	# 3. Pass the actual objects to update the graph [file:786]
	Tracks_Manager.updateGraph(obstical_objects)
