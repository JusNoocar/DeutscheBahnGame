extends Node2D

@onready var tile_map = $TileMapLayer

@onready var ticker = $CanvasLayer/VBoxContainer/BottomBar/RichTextLabel

@onready var score_label = $CanvasLayer/VBoxContainer/TopBar/PanelC/HBoxC/Score
@onready var time_label = $CanvasLayer/VBoxContainer/TopBar/PanelC/HBoxC/Time
@onready var needle = $CanvasLayer/VBoxContainer/TopBar/TextureProgressBar/Needle

var total_score: int = 0
var game_time: float = 0.0
@export var tick_time: float = 1.0 # Trains move 1 tile every 1 second
var time_since_last_tick: float = 0.0

func _process(delta):
	# 1. Update Time (simple timer)
	game_time += delta
	var minutes = int(game_time) / 60
	var seconds = int(game_time) % 60
	
	time_label.text = "%02d:%02d" % [minutes, seconds]
	
	print(time_label.text)
	step(delta)
	update_total_score()

func update_total_score():
	var sum = 0
	for train in train_list.get_children():
		if "delay_value" in train:
			sum += train.delay_value 

	total_score = sum
	score_label.text = "Score: " + str(total_score) + " min Verspätung"

	# 3. Move the Needle (Heuristic from 1 to 100)
	# Map the score to the bar width. 
	# Example: 0 score = 0%, 200 total delay = 100%
	var bar_width = needle.get_parent().size.x
	var heuristic = clamp(float(total_score) / 200.0, 0.0, 1.0) # Returns 0 to 1

	needle.position.x = heuristic * bar_width - (needle.size.x / 2)
	
func _ready():
	ticker.text = "++ AKTUELL: RB33 hat 15 Minuten Verspätung ++ Baustelle in Aachen Hbf sorgt für Verzögerungen ++"
	# Start text at the far right of the bar
	ticker.position.x = ticker.get_parent_control().size.x
	# 1. Restore obstacles from Editor
	game_time = GlobalGameManager.game_time
	
	for track in GlobalGameManager.procedural_tracks:
		$TileMapLayerTrack.set_cell(track.pos, 0, track.atlas)
	for city in GlobalGameManager.generated_cities:
		tile_map.set_cell(city.pos, 0, city.atlas)
	for stone in GlobalGameManager.stone_paths:
		tile_map.set_cell(stone.pos, 0, stone.atlas)
	for data in GlobalGameManager.saved_tile_data:
		tile_map.set_cell(data.map_pos, 0, data.id)

	Train_Navigation.getNextPos()
	#add_train_status("RB33", "Aachen Hbf - West", "11:30", "11:55", 15)
	#add_train_status("RE4", "West - Düsseldorf", "12:20", "13:05", 40)
	#add_train_status("S11", "Köln - Düsseldorf", "13:10", "14:20", 0)
	
	var back_btn = $CanvasLayer/VBoxContainer/TopBar/Back
	back_btn.pressed.connect(_on_back_button_pressed)
	
	var pause_btn = $CanvasLayer/VBoxContainer/TopBar/Pause
	pause_btn.pressed.connect(_on_pause_pressed)
	spawn_visual_test_train(10)
	
func _on_back_button_pressed():
	GlobalGameManager.reset_to_initial()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

@onready var train_list = $CanvasLayer/VBoxContainer/Center/ScrollContainer/TrainList

func add_train_status(name: String, route: String,  dep: String, arr: String, delay: int):
	var item = preload("res://assets/menu items/train_status_item.tscn").instantiate()
	item.delay_value = delay
	train_list.add_child(item)

	item.get_node("HBoxContainer/VBoxContainer/Name").text = name
	item.get_node("HBoxContainer/VBoxContainer/Route").text = route
	
	
	var schedule_node = item.get_node("HBoxContainer/VBoxContainer/Schedule")
	var delay_color = "red" if delay > 0 else "green"

	schedule_node.bbcode_enabled = true
	schedule_node.text = "%s | %s [color=%s](+%d)[/color]" % [dep, arr, delay_color, delay]
	return item
	
func _update_item_schedule(item: Node, dep: String, arr: String, delay: int):
	item.delay_value = delay
	var schedule_node = item.get_node("HBoxContainer/VBoxContainer/Schedule")
	var delay_color = "red" if delay > 0 else "green"
	schedule_node.bbcode_enabled = true
	schedule_node.text = "%s | %s [color=%s](+%d)[/color]" % [dep, arr, delay_color, delay]

func _on_pause_pressed():
	# 1. Save data to the Global Singleton
	GlobalGameManager.game_time = game_time
	GlobalGameManager.is_game_running = true
	
	# 2. Switch to Editor
	get_tree().change_scene_to_file("res://scenes/editor.tscn")
func get_indexed_city_positions() -> Dictionary:
	var city_indices = {}
	var index_counter = 0
	for pos in Cities.grid_data:
		if Cities.grid_data[pos] is Cities.CityData:
			city_indices[index_counter] = pos
			index_counter += 1
	return city_indices
var train_nav = Train_Navigation.new()
var trainsprite: Array = []
var trainnr = 10

func spawn_singletrain(i: int):
	# 1. Load the Train Scene
	var train_scene = load("res://scenes/Train.tscn")
	if not train_scene:
		printerr("Error: Could not find Train.tscn")
		return

	# 2. Pick a valid start position
	# (Just grabbing the first city as a safe spawn point)
	var start_pos = Vector2i(0, 0)
	var goal_pos = Vector2i(0, 0)
	var cities = get_indexed_city_positions()
	if cities.size() > i:
		var rand = randi_range(0, cities.size()-1)
		start_pos = cities[rand]
		goal_pos = cities[rand+1]
		
	# 3. Instantiate and Add to Scene
	trainsprite[i]= train_scene.instantiate()
	trainsprite[i].index = i
	add_child(trainsprite[i])
	train_nav.createTrain(start_pos,goal_pos)
		
	
	# 4. Initialize
	# We pass 'train_navigation' so the train knows who to ask "Where next?"
	# The train script will immediately move to 'start_pos' and ask for the next step.
	trainsprite[i].setup(start_pos, train_nav)
	
	print("Test Train spawned at: ", start_pos)

func spawn_visual_test_train(trainnum: int):
	# 1. Load the Train Scene
	var train_scene = load("res://scenes/Train.tscn")
	if not train_scene:
		printerr("Error: Could not find Train.tscn")
		return
	for i in range (trainnum):
	# 2. Pick a valid start position
	# (Just grabbing the first city as a safe spawn point)
		var start_pos = Vector2i(0, 0)
		var goal_pos = Vector2i(0, 0)
		var cities = get_indexed_city_positions()
		if cities.size() > i:
			start_pos = cities[i]
			goal_pos = cities[i+1]
		
	# 3. Instantiate and Add to Scene
		var train_node = train_scene.instantiate()
		add_child(train_node) # Add the actual NEW node

		# 1. Create the UI box and link it
		var ui_item = add_train_status("RB" + str(i + 33), "Aachen - West", "11:30", "11:55", 0)
		train_node.status_ui_item = ui_item

		# 2. Setup indices correctly
		train_node.index = i
		train_node.setup(start_pos, train_nav)

		# 3. Register in logic and list
		train_nav.createTrain(start_pos, goal_pos)
		trainsprite.append(train_node)
		
		print("Test Train spawned at: ", start_pos)

	train_nav.getNextPos()

func step(delta):
	# Accumulate time
	time_since_last_tick += delta
	
	if time_since_last_tick >= tick_time:
		time_since_last_tick -= tick_time
		_advance_game_tick()

func _advance_game_tick():
	print("--- Game Tick ---")
	
	# 1. Update the Navigation / "Brain" (if needed)
	# This is where your colleague's "get_next_pos" logic might run for everyone
	# train_navigation.update_all_paths() 
	train_nav.getNextPos()

		
	# 2. Tell every train to move to its next step
	for traino in trainsprite: # Ensure you have an array 'active_trains'
		if is_instance_valid(traino):
			if train_nav.trains[traino.index]:
				traino.do_game_tick(tick_time)
			else: 
				traino.kill()
				spawn_singletrain(traino.index)
			print(train_nav.trains[0].start)
