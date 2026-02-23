class_name Train_Navigation
extends RefCounted

class TrainObject:
	var start: Vector2i
	var goal: Vector2i
	var occupied_tiles: Array = []
	var current_path = null
	var delay_count: int = 0      # Actual delay in "minutes"
	var expected_ticks: int = 0   # How many ticks the path should take
	var ticks_taken: int = 0      # How many ticks have passed
	var lastIntersection
	var _tempGoalVar
	var color
	
# Array of trains of length n
# trains[i] = Train object

# test function for Jori


func get_next_position_for(train: Train) -> Variant:
	return train.current_grid_pos + Vector2i(1,1)
	print("asked for new pos")
	
static var trains: Array = [] 

func createTrain(startp: Vector2i, goalp: Vector2i):
	var obj = TrainObject.new()
	obj.start = startp
	obj.goal = goalp
	_initTrain(obj)
	trains.append(obj)
	
# Real next position
static func getNextPos():
	 ## maybe try to do this in parallel
	var graph = GlobalVars.current_graph
	var tmp_occupied = []
	for i in range(len(trains)):
		var train = trains[i]
	
		if typeof(train) == TYPE_STRING:
			continue
			
		train.ticks_taken += 1
		# Calculate delay: If we have taken more steps than the original path length
		if train.ticks_taken > train.expected_ticks:
			train.delay_count = train.ticks_taken - train.expected_ticks
		var start = train.start
		var goal = train.goal
		if not train.current_path:
			_initTrain(train)
			# if there is no path to destination, the _init funtction makes train = null
			if not train.current_path:
				trains[i] = "DESPAWNED"
				continue
		var path = train.current_path
		if len(path) == 1:
			# if the current goal is temporary
			if train._tempGoalVar:
				train.goal = train._tempGoalVar
				train.path = ShortestPath.get_shortest_path(graph, train.start, train.goal)
				train.occupied_tiles.reverse()
				train._tempGoalVar = null
			else: 
				train = "DESPAWNED"
				tmp_occupied.append([])
				continue
		tmp_occupied.append(_adjustOccupiedTiles(train.occupied_tiles, path[1]))
	resolveConflicts(tmp_occupied)
	updateIntersections()
	#if trains:
		#print(trains[0].current_path)
	return 


static func _initTrain(train):
	var start = train.start
	var goal = train.goal
	var path = ShortestPath.get_shortest_path(GlobalVars.current_graph, start, goal)
	train.current_path = path
	if len(path) == 0:
		train.current_path = null
		return
	if len(path) > 1:
		train.occupied_tiles.append(path[1])
		train.occupied_tiles.append(path[0])
		train.start = train.occupied_tiles[0]
		return 
	train.occupied_tiles[0] = start
	train.occupied_tiles[1] = start
	train.lastIntersection = train.start 
	
	if path.size() > 0:
		train.expected_ticks = path.size()
		train.ticks_taken = 0
		train.delay_count = 0
	
		 
static func updateIntersections():
	for i in range(len(trains)):
		if typeof(trains[i]) == TYPE_STRING:
			return # Append empty list so indices stay synced
			
	# if the neighborhood of the node is > 2, then it qualifies as an intersection
		if len(GlobalVars.current_graph.neighborhood[trains[i].start] )> 2:
			trains[i].lastIntersection = trains[i].start

static func getConflict(tmp_occupied): # returns the first conflict
	var graph = GlobalVars.current_graph
	
	
	
	for i in range(len(tmp_occupied)):
		# if the train is not occupying any tiles (despawned or arrived)
		if tmp_occupied[i] == null or len(tmp_occupied[i]) == 0:
			continue 
		 # if the first wagon would drive into an obstical
		var head_pos = tmp_occupied[i][0]
		if graph.disabled.has(head_pos):
			# Return the train index and the obstacle position as the "conflict"
			return [i, head_pos]
	
	#for i in range(len(tmp_occupied)):
	#	for j in range(i+1, len(tmp_occupied)):
	#		# check if soome cell is occupied by both train i and train j
	#		for pos in tmp_occupied[i]:
	#			if pos in tmp_occupied[j]:
	#				return [i,j]
	return []
	
	
static func resolveConflicts(tmp_occupied):
	var graph = GlobalVars.current_graph
	var conflicts = getConflict(tmp_occupied)
	
	var iterations = 0
	var MAX_ITERATIONS = 50 # Safety breaker to prevent freezing [file:787]

	while conflicts and iterations < MAX_ITERATIONS:
		iterations += 1
		var i = conflicts[0]
		var j = conflicts[1]
		
		if iterations >= MAX_ITERATIONS:
			tmp_occupied[j] = trains[j].occupied_tiles # Stay still
			break
		
		
		if j is Vector2i: # If the conflict is a tile position (an obstacle)
			# 1. FORCE STOP: The train stays on its current tiles [file:829]
			tmp_occupied[i] = trains[i].occupied_tiles
			#conflictedInd[i] = true
			
			# 2. TICK DOWN: Reduce the obstacle timer in the manager
			if Tracks_Manager.active_obstacles.has(j):
				Tracks_Manager.active_obstacles[j]["ticks_left"] -= 1
				# If time is up, clear it [file:833]
				if Tracks_Manager.active_obstacles[j]["ticks_left"] <= 0:
					Tracks_Manager.active_obstacles.erase(j)
					GlobalVars.current_graph.disabled.erase(j)
			
			conflicts = getConflict(tmp_occupied)
			continue
		#if j is Vector2i:
			#var new_path = ShortestPath.set_alternative_path(	trains[i], graph, 
																#trains[i].occupied_tiles[0], trains[i].goal)
			#tmp_occupied[i] = trains[i].occupied_tiles
			#conflicts = getConflict(tmp_occupied)
			#continue
	
	for i in range(len(trains)):
		if typeof(trains[i]) == TYPE_STRING:
			continue
		trains[i].occupied_tiles = tmp_occupied[i]
		trains[i].current_path.pop_front()
			
			
static func setTemporaryGoal(train_ind, temp_goal):
	if temp_goal == null:
		temp_goal = trains[train_ind].start
	
	trains[train_ind]._tempGoalVar = trains[train_ind].goal
	trains[train_ind].goal = temp_goal
	
	var path = ShortestPath.get_shortest_path(GlobalVars.current_graph, trains[train_ind].start, trains[train_ind].goal)

	if path.size() == 0:
		return trains[train_ind].occupied_tiles

	trains[train_ind].current_path = path
	trains[train_ind].occupied_tiles.reverse()
	#return _adjustOccupiedTiles(trains[train_ind].occupied_tiles, trains[train_ind].current_path[0])
	
static func _adjustOccupiedTiles(occupied, head):
	occupied.pop_back()
	occupied.push_front(head)
	return occupied
