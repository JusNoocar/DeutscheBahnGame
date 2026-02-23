extends Node

var procedural_tracks = []
var generated_cities = []
var stone_paths = []
var saved_tile_data = []  # List of {map_pos, id, source, pinned}
var game_time = 0.0
var is_game_running = false # true if START has been pressed once
var total_delay = 400 # we could also use it as the score
const DELAY_MINIMUM_WIN = 100
const DELAY_MAXIMUM_WIN = 300
var is_dragging_obstacle: bool = false
var current_obstacle: Node = null

func reset_to_initial():
	procedural_tracks.clear()
	generated_cities.clear()
	stone_paths.clear()
	saved_tile_data.clear()
	game_time = 0.0
	is_dragging_obstacle = false
	current_obstacle = null
	is_game_running = false
	
static func incrementDelay():
	GlobalGameManager.total_delay += 1
