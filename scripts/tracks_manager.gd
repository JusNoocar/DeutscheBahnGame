extends RefCounted
class_name Tracks_Manager

class Obstical:
	var pos
	var duration
	var placement_time


static var disabledNodes = {}

static var active_obstacles: Dictionary = {}

static func register_obstacle(pos: Vector2i, type: int, duration: int):
	active_obstacles[pos] = {"type": type, "ticks_left": duration}
	print("Obstacle", type, ", ", duration, "registered")
	# Also disable it in the graph so pathfinders avoid it
	if GlobalVars.current_graph:
		print(GlobalVars.current_graph)
		GlobalVars.current_graph.disabled[pos] = true

static func get_obstacle_type(pos: Vector2i) -> int:
	if active_obstacles.has(pos):
		return active_obstacles[pos]["type"]
	return -1

static func monitorDisabledNodes():
	#var graph = GlobalVars.current_graph
	#for node in disabledNodes:
		#var duration = disabledNodes[0]
		#var placement_time = disabledNodes[1]
		#if GlobalGameManager.game_time > placement_time + duration:
			#disabledNodes.erase(node)
			#graph.disabled.erase(node)
	var graph = GlobalVars.current_graph
	if not graph: return
	
	var current_time = GlobalGameManager.game_time
	var keys_to_remove = []
	
	for node in disabledNodes:
		var data = disabledNodes[node] # [duration, placement_time]
		if current_time > data[1] + data[0]:
			keys_to_remove.append(node)
	
	# Clean up expired obstacles [file:786]
	for node in keys_to_remove:
		disabledNodes.erase(node)
		if graph.disabled.has(node):
			graph.disabled.erase(node)

static func updateGraph(obsticals):
	var graph = GlobalVars.current_graph
	if not graph: return
	
	# Clear old disabled nodes if necessary, or just merge
	for obs in obsticals:
		# Store in our internal tracker [file:786]
		disabledNodes[obs.pos] = [obs.duration, obs.placement_time]
		
		# CRITICAL: Disable the node in the actual pathfinding graph
		graph.disabled[obs.pos] = true
		

static func getObsticalRemainingDuration(node):
	return GlobalGameManager.game_time - (disabledNodes[node].placement_time + disabledNodes[node].duration)
