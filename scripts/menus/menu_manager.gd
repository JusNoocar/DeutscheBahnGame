extends Node2D

@onready var item_list = $CanvasLayer/ScrollContainer/ItemList
@onready var tile_map = $TileMapLayer

var item_scene = preload("res://assets/obstacles/obstacle_item.tscn")
var used_items = []

var initial_data = [
	{"id": Vector2i(5, 0), "name": "Baustelle"},
	{"id": Vector2i(4, 1), "name": "Gras"},
	{"id": Vector2i(2, 6), "name": "Aachener Höhlen"}
]

func _ready():
	used_items = GlobalGameManager.saved_tile_data.duplicate(true)
	
	for track in GlobalGameManager.procedural_tracks:
		$TileMapLayerTrack.set_cell(track.pos, 0, track.atlas)
	for city in GlobalGameManager.generated_cities:
		tile_map.set_cell(city.pos, 0, city.atlas)
	for stone in GlobalGameManager.stone_paths:
		tile_map.set_cell(stone.pos, 0, stone.atlas)
	for item in used_items:
		tile_map.set_cell(item.map_pos, 0, item.id)
	if not GlobalGameManager.is_game_running:
		
		start_generation()
		trains_generation()
		
	setup_menu()
	
	var back_btn = $CanvasLayer/Back
	back_btn.pressed.connect(_on_back_button_pressed)

func trains_generation():
	#TODO
	pass
func start_generation():
	var generator = Cities.new() 
	generator.tile_map_track = $TileMapLayerTrack
	generator.tile_map = $TileMapLayer
	add_child(generator)
	
	generator.generate_cities()
	generator.generate_connections()
	
	# Generate connections returns an array, pass it to build_tracks
	#var connections = generator.generate_connections()
	#generator.build_tracks(connections)
	#
	# 5. Paint the final result to TileMapLayer2
	generator.render_to_tilemap()
	
	# 6. Request a redraw for the debug lines
	#generator.queue_redraw()
	GlobalGameManager.procedural_tracks.clear()
	var tracks = $TileMapLayerTrack.get_used_cells() # Gets all track positions [web:644]

	for pos in tracks:
		var atlas = $TileMapLayerTrack.get_cell_atlas_coords(pos)
		GlobalGameManager.procedural_tracks.append({"pos": pos, "atlas": atlas})
	
	#GlobalGameManager.saved_tile_data = 
	

func setup_menu():

	for child in item_list.get_children(): child.queue_free()
	
	var stock = [
		{"id": Vector2i(5, 0), "name": "Baustelle", "desc": "Warten Sie 2 Monate", "total": 10},
		{"id": Vector2i(4, 7), "name": "Person", "desc": "Unidentified person on the tracks", "total": 2},
		{"id": Vector2i(5, 2), "name": "Schnee", "desc": "Snow on tracks", "total": 1},
		{"id": Vector2i(5, 8), "name": "Karnival", "desc": "Total kölsch", "total": 1},
		{"id": Vector2i(5, 6), "name": "Accident on a train", "desc": "Something happened", "total": 2},
		{"id": Vector2i(1, 2), "name": "A basic delay", "desc": "5 mins delay is not a delay", "total": 5},
	]

	for cfg in stock:
		var placed = 0
		for item in used_items:
			if item.id == cfg.id: placed += 1
		add_menu_item(cfg.id, cfg.name, cfg.desc, get_tile_texture(cfg.id), cfg.total - placed)
		
	#add_menu_item(Vector2i(5, 0), "Baustelle", "Warten Sie 2 Monate", get_tile_texture(Vector2i(5, 0)), 2)
	#add_menu_item(Vector2i(5, 0), "Baustelle", "Warten Sie 2 Monate", get_tile_texture(Vector2i(5, 0)), 2)
	#add_menu_item(Vector2i(5, 0), "Baustelle", "Warten Sie 2 Monate", get_tile_texture(Vector2i(5, 0)), 2)
	#add_menu_item(Vector2i(5, 0), "Baustelle", "Warten Sie 2 Monate", get_tile_texture(Vector2i(5, 0)), 2)
	#add_menu_item(Vector2i(4, 1), "Gras", "Geduld, wir genießen die Natur!", get_tile_texture(Vector2i(4, 1)), 3)
	#add_menu_item(Vector2i(2, 6), "Aachener Höhlen", "Für immer verloren", get_tile_texture(Vector2i(2, 6)), 1)
	
	var button_row = HBoxContainer.new()
	item_list.add_child(button_row)

	var reset_btn = Button.new()
	reset_btn.text = "RESET MAP"
	reset_btn.pressed.connect(_on_reset_pressed)
	button_row.add_child(reset_btn)

	var start_btn = Button.new()
	start_btn.text = "START"
	start_btn.pressed.connect(_on_start_pressed)
	button_row.add_child(start_btn)
	
	# Connect it to the reset function
	reset_btn.pressed.connect(_on_reset_pressed)
	
func _on_back_button_pressed():
	GlobalGameManager.reset_to_initial()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
func _on_start_pressed():
	# Save the current state of used_items to the global script
	
	for item in used_items:
		item["pinned"] = true
	GlobalGameManager.saved_tile_data = used_items.duplicate(true)
	for tile in GlobalGameManager.saved_tile_data:
		print(tile)
		Tracks_Manager.register_obstacle(tile["map_pos"], 1, 1000) # TEST
	GlobalGameManager.is_game_running = true
	get_tree().change_scene_to_file("res://scenes//maingame.tscn")

func _on_reset_pressed():
	for i in range(used_items.size() - 1, -1, -1):
		var item = used_items[i]
		# Only reset UNPINNED items (placed during this edit session)
		if not item.get("pinned", false):
			if item.has("old_tile_atlas"):
				tile_map.set_cell(item.map_pos, item.old_tile_source, item.old_tile_atlas)
			else:
				tile_map.erase_cell(item.map_pos)
			used_items.remove_at(i)
			
	GlobalGameManager.saved_tile_data = used_items.duplicate(true)

	setup_menu()

func add_menu_item(id, nme, desc, tex, count):
	var new_item = item_scene.instantiate()
	item_list.add_child(new_item)
	
	new_item.item_id = id
	new_item.item_name = nme
	new_item.amount = count
	
	new_item.get_node("HBoxContainer/VBoxContainer/Title").text = nme
	new_item.get_node("HBoxContainer/VBoxContainer/Description").text = desc
	new_item.get_node("HBoxContainer/Icon").texture = tex
	new_item.update_visuals()

func _on_reset_button_pressed():
	for i in range(used_items.size() - 1, -1, -1):
		var item = used_items[i]
		
		# ONLY reset items that are NOT pinned [file:517]
		if not item.get("pinned", false):
			# Restore original tile
			if item.has("old_tile_atlas"):
				tile_map.set_cell(item.map_pos, item.old_tile_source, item.old_tile_atlas)
			else:
				tile_map.erase_cell(item.map_pos)
			
			# Remove from tracking
			used_items.remove_at(i)

	# 2. SYNC GLOBAL FIRST
	GlobalGameManager.saved_tile_data = used_items.duplicate(true)
	
	# 3. REFRESH THE MENU (This recalculates the remaining amount)
	setup_menu()

func get_tile_texture(atlas_coords: Vector2i) -> AtlasTexture:
	var source: TileSetAtlasSource = tile_map.tile_set.get_source(0)
	var atlas_tex = AtlasTexture.new()
	atlas_tex.atlas = source.texture
	atlas_tex.region = source.get_tile_texture_region(atlas_coords)
	return atlas_tex
