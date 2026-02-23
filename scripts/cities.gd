extends Node2D
class_name Cities
@onready var game = get_tree().root.get_node("Game")
# --- CONFIGURATION ---
var tile_map_track: TileMapLayer
var tile_map: TileMapLayer
const TILE_OFFSET = Vector2i(61, 49)
const SKETCH_OFFSET = Vector2i(1, 3)

var map_width = 40
var map_height = 30
var tile_size = 16 # Pixel size for visualization
var min_city_distance = 6
var num_cities = 40
var path_to_draw: Array[Vector2i] = []
var current_graph
# --- DATA STRUCTURES ---
# Key: Vector2i, Value: CityData (or TrackPiece later)
static var grid_data: Dictionary = {}

var track_tiles = {
	TrackPiece.TYPE_HORIZONTAL: Vector2i(0, 0),
	TrackPiece.TYPE_VERTICAL:   Vector2i(1, 1),
	TrackPiece.TYPE_NE:         Vector2i(0, 1),
	TrackPiece.TYPE_SE:         Vector2i(2, 0),
	TrackPiece.TYPE_SW:         Vector2i(1, 0),
	TrackPiece.TYPE_NW:         Vector2i(2, 1)
}

class CityData:
	var name: String
	var position: Vector2i
	var population: int
	var track: TrackPiece = TrackPiece.new()
# --- MAIN LOOP ---
func _ready():
	if not tile_map_track:
		print("Warning: Cities was added to tree without a tile_map!")
		return 
	randomize()
	generate_cities()
	var connections = generate_connections()
	build_tracks(connections)
	
	auto_connect_cities() # <--- ADD THIS
	
	queue_redraw()
	check_city_track_interfaces()
	
	GlobalVars.current_graph = ShortestPath.graph_from_map(get_all_track_connections())
	
	var current_graph = GlobalVars.current_graph
	var nodes = current_graph.nodes
	path_to_draw = ShortestPath.get_shortest_path(current_graph, nodes[15], nodes[39])
	print(ShortestPath.get_shortest_path(current_graph, nodes[15], nodes[39]))

# --- 1. Variable to store the path ---

# --- 2. Call this function to update the visual ---
func set_debug_path(path: Array[Vector2i]):
	path_to_draw = path
	queue_redraw() # Tells Godot to run _draw() again next frame

func init_trains():
	var cities = get_indexed_city_positions()
	var n = len(cities)
	for i in range(10):
		var start = cities[randi() % n]
		var goal = cities[randi() % n]	
		var trainObj = Train_Navigation.TrainObject.new()
		trainObj.start = start
		trainObj.goal = goal
		Train_Navigation._initTrain(trainObj)
		Train_Navigation.trains.append(trainObj)

# --- 3. Add this code INSIDE your existing _draw() function ---
# (Paste this at the bottom of your _draw function)
func _draw_debug_path_overlay():
	if path_to_draw.is_empty():
		return

	var color = Color(1, 0, 0, 0.5) # Red, 50% transparent
	
	for pos in path_to_draw:
		var px = Vector2(pos + SKETCH_OFFSET) * tile_size
		var rect = Rect2(px, Vector2(tile_size, tile_size))
		
		# Draw a filled square on the tile
		draw_rect(rect, color, true)
		
		# Optional: Draw a border
		draw_rect(rect, Color.RED, false, 2.0)
# If you see [false, false...] or missing 'true' for a neighbor that exists, 
# then the City Logic is definitely blocking the pathfinder.

# --- LOGIC ---
func generate_cities():
	var cities_placed = 0
	var attempts = 0
	
	print("Attempting to place ", num_cities, " cities...")
	
	while cities_placed < num_cities and attempts < 2000:
		attempts += 1
		
		# 1. Pick random spot (padding of 2 so they aren't on edge)
		var x = randi_range(2, map_width - 3)
		var y = randi_range(2, map_height - 3)
		var candidate_pos = Vector2i(x, y)
		
		# 2. Check validity
		if is_valid_city_pos(candidate_pos):
			create_city(candidate_pos)
			cities_placed += 1
			
	print("Finished. Placed ", cities_placed, " cities after ", attempts, " attempts.")

func is_valid_city_pos(pos: Vector2i) -> bool:
	# Check distance to all existing cities
	for existing_pos in grid_data:
		if grid_data[existing_pos] is CityData:
			# Euclidean distance check
			if pos.distance_to(existing_pos) < min_city_distance:
				return false
	return true

func create_city(pos: Vector2i):
	if not tile_map:
		print("problem city")
	# 1. Create Data
	var city = CityData.new()
	city.position = pos
	city.name = "City_" + str(randi() % 99)
	city.population = randi_range(100, 5000)
	grid_data[pos] = city
	
	# 2. Create Visuals (So you can see it!)
	var visual = ColorRect.new()
	visual.color = Color(0.0, 1.0, 1.0, 0.0)
	visual.size = Vector2(tile_size, tile_size)
	visual.position = Vector2((pos.x + SKETCH_OFFSET[0]) * tile_size, (pos.y + SKETCH_OFFSET[1]) * tile_size)
	add_child(visual)
	
	var atlas_coords = Vector2i(2, 6) # Your city tile ID
	# 1. Place it on the current (editor) map
	tile_map.set_cell(pos + TILE_OFFSET, 0, atlas_coords)
	
	# 2. SAVE IT GLOBALLY for the Main Game
	var city_info = {
		"pos": pos + TILE_OFFSET,
		"atlas": atlas_coords
	}
	GlobalGameManager.generated_cities.append(city_info)
	
	# Add a label for the name
	var label = Label.new()
	label.text = city.name
	label.position = Vector2(0, -20) # Float above the square
	visual.add_child(label)

func get_indexed_city_positions() -> Dictionary:
	var city_indices = {}
	var index_counter = 0
	for pos in grid_data:
		if grid_data[pos] is CityData:
			city_indices[index_counter] = pos
			index_counter += 1
	return city_indices

# --- OPTIONAL: DEBUG DRAWING ---
# Draws the map border so you know how big the world is

func render_to_tilemap():
	if not tile_map_track: 
		print("Error: No TileMap assigned to Cities script!")
		return
	
	print("Starting TileMap Render. Total grid items: ", grid_data.size())
	for pos in grid_data:
		var item = grid_data[pos]
		var track_ref = null
		if item is CityData: 
			tile_map.set_cell(pos + TILE_OFFSET, 0, Vector2i(2, 6))
			
		elif item is TrackPiece:
			track_ref = item

			var mask = track_ref.orientation_mask
			if track_tiles.has(mask):
				var atlas_pos = track_tiles[mask]
				print("Placing tile at ", pos + TILE_OFFSET, " with atlas ", atlas_pos)
				tile_map_track.set_cell(pos + TILE_OFFSET, 0, atlas_pos)
				
				
			else:
				print("No atlas mapping for mask: ", mask)
			var atlas_path_coords = Vector2i(1, 0) # Your city tile ID
			# 1. Place it on the current (editor) map
			tile_map.set_cell(pos + TILE_OFFSET, 0, atlas_path_coords)

			var stone_info = {
				"pos": pos + TILE_OFFSET,
				"atlas": atlas_path_coords
			}
			GlobalGameManager.stone_paths.append(stone_info)

func _draw():
	return
	# Draw Border
	draw_rect(Rect2(SKETCH_OFFSET[0] * tile_size, SKETCH_OFFSET[1] * tile_size, map_width * tile_size, map_height * tile_size), Color.GRAY, false, 2.0)
	
	for pos in grid_data:
		var item = grid_data[pos]
		var track_to_draw = null
		var rail_color = Color.LIGHT_GRAY
		
		# --- CHECK 1: Is it a City? ---
		if item is CityData:
			track_to_draw = item.track # <--- CRITICAL: Get the track FROM the city
			rail_color = Color.BLACK   # Draw city rails in Black so you can see them!
			
		# --- CHECK 2: Is it a normal Track? ---
		elif item is TrackPiece:
			track_to_draw = item
		
		# --- DRAWING ---
		if track_to_draw:
			var px = (pos + SKETCH_OFFSET) * tile_size
			var center = Vector2(px) + Vector2(tile_size/2.0, tile_size/2.0)
			var width = 4.0
			var half = tile_size / 2.0
			
			# Straights
			
			#if (TrackPiece.TYPE_HORIZONTAL):
				#tile_map.set_cell(px, 0, Vector2(1,1))

			if track_to_draw.orientation_mask & TrackPiece.TYPE_HORIZONTAL:
				draw_line(center + Vector2(-half, 0), center + Vector2(half, 0), rail_color, width)
			if track_to_draw.orientation_mask & TrackPiece.TYPE_VERTICAL:
				draw_line(center + Vector2(0, -half), center + Vector2(0, half), rail_color, width)
				
			# Diagonals
			if track_to_draw.orientation_mask & TrackPiece.TYPE_NE:
				draw_line(center + Vector2(0, -half), center + Vector2(half, 0), rail_color, width)
			if track_to_draw.orientation_mask & TrackPiece.TYPE_SE:
				draw_line(center + Vector2(0, half), center + Vector2(half, 0), rail_color, width)
			if track_to_draw.orientation_mask & TrackPiece.TYPE_SW:
				draw_line(center + Vector2(0, half), center + Vector2(-half, 0), rail_color, width)
			if track_to_draw.orientation_mask & TrackPiece.TYPE_NW:
				draw_line(center + Vector2(0, -half), center + Vector2(-half, 0), rail_color, width)
	if not path_to_draw.is_empty():
		for pos in path_to_draw:
			var px = Vector2(pos + SKETCH_OFFSET) * tile_size
			var rect = Rect2(px, Vector2(tile_size, tile_size))
			draw_rect(rect, Color(1, 0, 0, 0.5), true) # Red Highlight

class Connection:
	var start: Vector2i
	var end: Vector2i
	var distance: float


	

func generate_connections():
	var cities = get_indexed_city_positions() # {0: pos, 1: pos...}
	var connections = [] # Array of Connection objects
	
	# 1. Gather all possible edges (City A -> City B)
	var all_edges = []
	var city_ids = cities.keys()
	
	for i in range(city_ids.size()):
		for j in range(i + 1, city_ids.size()):
			var u = city_ids[i]
			var v = city_ids[j]
			var dist = cities[u].distance_to(cities[v])
			all_edges.append({ "u": u, "v": v, "dist": dist })
	
	# Sort by distance (shortest first) for Kruskal's Algorithm
	all_edges.sort_custom(func(a, b): return a["dist"] < b["dist"])
	
	# 2. KRUSKAL'S ALGORITHM (Minimum Spanning Tree)
	# Connects everything with minimum track
	var parent = {}
	for id in city_ids: parent[id] = id
	
	# Helper for Union-Find
	var find = func(i, parent_dict, find_ref):
		if parent_dict[i] != i:
			parent_dict[i] = find_ref.call(parent_dict[i], parent_dict, find_ref)
		return parent_dict[i]
		
	var union = func(i, j, parent_dict, find_ref):
		var root_i = find_ref.call(i, parent_dict, find_ref)
		var root_j = find_ref.call(j, parent_dict, find_ref)
		if root_i != root_j:
			parent_dict[root_i] = root_j
			return true # Connected successfully
		return false # Already connected
	
	# Build MST
	for edge in all_edges:
		if union.call(edge["u"], edge["v"], parent, find):
			_add_connection(connections, cities[edge["u"]], cities[edge["v"]])
	
	# 3. ADD REDUNDANCY (The "Hub" Logic)
	# Connect close cities that aren't directly connected,
	# especially if they are large (simulate "Major Lines")
	var redundancy_count = 0
	
	var max_redundancy = num_cities / 2 # Tweak this for more/less loops
	
	for edge in all_edges:
		if redundancy_count >= max_redundancy: break
		
		# If this edge wasn't used in MST...
		# (We can check if it's already in 'connections' but for simplicity
		# just checking if it's short enough to justify a direct line)
		
		# Skip really long bridges
		if edge["dist"] > min_city_distance * 2.5: continue
		
		# Add it if we haven't already (simple check)
		if not _connection_exists(connections, cities[edge["u"]], cities[edge["v"]]):
			_add_connection(connections, cities[edge["u"]], cities[edge["v"]])
			redundancy_count += 1
			print("Added redundancy track between ", edge["u"], " and ", edge["v"])

	print("Total Connections to build: ", connections.size())
	return connections

func _add_connection(list, pos_a, pos_b):
	var c = Connection.new()
	c.start = pos_a
	c.end = pos_b
	list.append(c)

func _connection_exists(list, pos_a, pos_b) -> bool:
	for c in list:
		if (c.start == pos_a and c.end == pos_b) or (c.start == pos_b and c.end == pos_a):
			return true
	return false
func build_tracks(connections: Array):
	# ... (Keep your existing AStar setup code here) ...
	var astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, map_width, map_height)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	
	for conn in connections:
		var path = astar.get_id_path(conn.start, conn.end)
		
		# We iterate through the path to determine the shape of every tile
		for i in range(path.size()):
			var current = path[i]
			var prev = path[i-1] if i > 0 else null
			var next = path[i+1] if i < path.size() - 1 else null
			
			solve_track_shape(current, prev, next)

func solve_track_shape(pos: Vector2i, prev, next):
	# 1. Determine which neighbors we are connecting to
	var neighbor_dirs = []
	
	if prev != null: neighbor_dirs.append(prev - pos)
	if next != null: neighbor_dirs.append(next - pos)
	
	# If we are a dead end (start or end of line), we just point to the only neighbor
	# (For now, let's treat dead ends as simple straights pointing that way)
	if neighbor_dirs.size() == 1:
		var d = neighbor_dirs[0]
		if d.x != 0: _add_track_mask(pos, TrackPiece.TYPE_HORIZONTAL)
		else:        _add_track_mask(pos, TrackPiece.TYPE_VERTICAL)
		return

	# 2. Logic for 2 neighbors (The Middle of the track)
	var has_north = Vector2i.UP in neighbor_dirs
	var has_south = Vector2i.DOWN in neighbor_dirs
	var has_east  = Vector2i.RIGHT in neighbor_dirs
	var has_west  = Vector2i.LEFT in neighbor_dirs
	
	if has_north and has_south: _add_track_mask(pos, TrackPiece.TYPE_VERTICAL)
	elif has_east and has_west: _add_track_mask(pos, TrackPiece.TYPE_HORIZONTAL)
	elif has_north and has_east: _add_track_mask(pos, TrackPiece.TYPE_NE)
	elif has_south and has_east: _add_track_mask(pos, TrackPiece.TYPE_SE)
	elif has_south and has_west: _add_track_mask(pos, TrackPiece.TYPE_SW)
	elif has_north and has_west: _add_track_mask(pos, TrackPiece.TYPE_NW)

func _add_track_mask(pos: Vector2i, type: int):
	# 1. Create track if nothing exists
	if not grid_data.has(pos):
		grid_data[pos] = TrackPiece.new()
	
	# 2. Get the target (Logic handles both Cities and Standalone Tracks)
	var target = null
	if grid_data[pos] is TrackPiece:
		target = grid_data[pos]
	elif grid_data[pos] is CityData:
		target = grid_data[pos].track
	
	# 3. Apply orientation
	if target:
		target.add_orientation(type)


func place_rail_between(pos_a: Vector2i, pos_b: Vector2i):
	# Calculate direction
	var diff = pos_b - pos_a
	
	# Update or Create TrackPiece at pos_a
	_add_track_data(pos_a, diff)
	
	# Update or Create TrackPiece at pos_b (the incoming connection)
	_add_track_data(pos_b, -diff)

func _add_track_data(pos: Vector2i, direction: Vector2i):
	# Get or Create
	if not grid_data.has(pos):
		grid_data[pos] = TrackPiece.new()
	
	# If it's a city, we might need a special "StationPiece" logic,
	# but for now let's just assume rails can exist "under" cities or we ignore it.
	if grid_data[pos] is TrackPiece:
		var track = grid_data[pos]
		
		# Map direction to Orientation bit
		if direction.x != 0: track.add_orientation(TrackPiece.TYPE_HORIZONTAL)
		elif direction.y != 0: track.add_orientation(TrackPiece.TYPE_VERTICAL)
		
		# (Note: We are using Manhattan/L-shape pathing so no diagonals yet)
func auto_connect_cities():
	for pos in grid_data:
		if grid_data[pos] is CityData:
			var t = grid_data[pos].track
			var n = _has_track(pos + Vector2i.UP)
			var s = _has_track(pos + Vector2i.DOWN)
			var e = _has_track(pos + Vector2i.RIGHT)
			var w = _has_track(pos + Vector2i.LEFT)
			
			# Straights
			if n and s: t.add_orientation(TrackPiece.TYPE_VERTICAL)
			if e and w: t.add_orientation(TrackPiece.TYPE_HORIZONTAL)
			
			# Curves (The Omni-Junction)
			if n and e: t.add_orientation(TrackPiece.TYPE_NE)
			if s and e: t.add_orientation(TrackPiece.TYPE_SE)
			if s and w: t.add_orientation(TrackPiece.TYPE_SW)
			if n and w: t.add_orientation(TrackPiece.TYPE_NW)

# Helper for auto_connect
func _has_track(pos: Vector2i) -> bool:
	if not grid_data.has(pos): return false
	return (grid_data[pos] is TrackPiece) or (grid_data[pos] is CityData)
	# Returns { Vector2i : Array[bool] }
# Example: { (10,5): [true, false, true, ...] }
func get_all_track_connections() -> Dictionary:
	var result = {}
	
	for pos in grid_data:
		var item = grid_data[pos]
		var track_ref: TrackPiece = null
		
		# Extract the track object regardless of container
		if item is TrackPiece:
			track_ref = item
		elif item is CityData:
			track_ref = item.track
		
		# If we found a track, save its connections
		if track_ref:
			# We duplicate() the array to ensure the receiver 
			# gets a clean copy of data, not a reference to the internal array
			result[pos] = track_ref.connections.duplicate()
		
	return result
func check_city_track_interfaces():
	print("\n=== VALIDATING CITY <-> TRACK INTERFACES ===")
	
	var directions = [
		{ "vec": Vector2i.UP,    "name": "NORTH", "out_idx": 0, "in_idx": 4 },
		{ "vec": Vector2i.RIGHT, "name": "EAST",  "out_idx": 2, "in_idx": 6 },
		{ "vec": Vector2i.DOWN,  "name": "SOUTH", "out_idx": 4, "in_idx": 0 },
		{ "vec": Vector2i.LEFT,  "name": "WEST",  "out_idx": 6, "in_idx": 2 }
	]
	
	for pos in grid_data:
		# We only care about Cities
		if not (grid_data[pos] is CityData): continue
		
		var city = grid_data[pos]
		var city_track = city.track
		
		# Check all 4 sides
		for d in directions:
			var neighbor_pos = pos + d.vec
			
			if grid_data.has(neighbor_pos):
				# Get the neighbor track (whether it's a piece or another city)
				var neighbor_item = grid_data[neighbor_pos]
				var neighbor_track = null
				
				if neighbor_item is TrackPiece: neighbor_track = neighbor_item
				elif neighbor_item is CityData: neighbor_track = neighbor_item.track
				
				# If there is a track here, we MUST check the handshake
				if neighbor_track:
					var city_points_out = city_track.connections[d.out_idx]
					var neighbor_points_in = neighbor_track.connections[d.in_idx]
					
					# 1. PERFECT CONNECTION
					if city_points_out and neighbor_points_in:
						# print("City ", pos, " <-> ", d.name, ": OK") # Uncomment for verbose
						pass
						
					# 2. ERROR: City blocks the path
					elif not city_points_out and neighbor_points_in:
						print("FAIL at ", pos, ": Neighbor to ", d.name, " points to City, but City DOES NOT connect back!")
						
					# 3. ERROR: Neighbor blocks the path
					elif city_points_out and not neighbor_points_in:
						print("FAIL at ", pos, ": City connects ", d.name, ", but that Track Piece DOES NOT connect back!")

	print("Interface check complete.")
