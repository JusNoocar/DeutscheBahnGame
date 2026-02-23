extends RefCounted
class_name ShortestPath
# Godot 4.x GDScript
# A* on an unweighted, undirected graph.
# Nodes are Vector2i positions so they can be Dictionary keys.
# Neighborhood is a Dictionary[Vector2i, Array[Vector2i]].

class Graph:
	var edge_set: Array                    	# Array[[Vector2i, Vector2i], ...]
	var nodes: Array = []                  	# Array[Vector2i]
	var neighborhood: Dictionary = {}      	# Dictionary[Vector2i, Array[Vector2i]]
	var disabled: Dictionary = {}			# Set[Vector2i]

	func _init(p_edge_set: Array = []) -> void:
		edge_set = p_edge_set
		nodes = _get_nodes()
		neighborhood = _get_neighborhood()

	func _get_nodes() -> Array:
		var s := {} # "set" via Dictionary keys
		for e in edge_set:
			if e.size() < 2:
				continue
			var a: Vector2i = e[0]
			var b: Vector2i = e[1]
			s[a] = true
			s[b] = true
		return s.keys()

	func _get_neighborhood() -> Dictionary:
		var neigh := {}
		#for n in nodes:
		#	neigh[n] = []

		for e in edge_set:
			if e.size() < 2:
				continue
			var a: Vector2i = e[0]
			var b: Vector2i = e[1]
			if disabled.has(a) or disabled.has(b): continue
			# Ensure keys exist even if nodes was built strangely
			if not neigh.has(a):
				neigh[a] = []
			if not neigh.has(b):
				neigh[b] = []

			# Undirected edges; avoid duplicates
			if not neigh[a].has(b):
				neigh[a].append(b)
			if not neigh[b].has(a):
				neigh[b].append(a)

		return neigh

	static func manhattan(a: Vector2i, b: Vector2i) -> int:
		return abs(a.x - b.x) + abs(a.y - b.y)
		
	# tracks: Dictionary where keys are Vector2i(x,y)
# values are Array[8] in order: [N, NE, E, SE, S, SW, W, NW]
# returns: Graph built from edges [[a,b], [a,b], ...]

static func graph_from_map(tracks: Dictionary) -> Graph:
	var edges: Array = []

	for pos: Vector2i in tracks: # iterates keys
		var dirs: Array = tracks[pos] # [N, NE, E, SE, S, SW, W, NW]

		var N: bool  = bool(dirs[0])
		var NE: bool = bool(dirs[1])
		var E: bool  = bool(dirs[2])
		var SE: bool = bool(dirs[3])
		var S: bool  = bool(dirs[4])
		var SW: bool = bool(dirs[5])
		var W: bool  = bool(dirs[6])
		var NW: bool = bool(dirs[7])

		if N:
			edges.append([pos, pos + Vector2i(0, -1)]) # Corrected: Up is -Y
		if NE:
			edges.append([pos, pos + Vector2i(1, -1)]) # Corrected
		if E:
			edges.append([pos, pos + Vector2i(1, 0)])
		if SE:
			edges.append([pos, pos + Vector2i(1, 1)])  # Corrected
		if S:
			edges.append([pos, pos + Vector2i(0, 1)])  # Corrected: Down is +Y
		if SW:
			edges.append([pos, pos + Vector2i(-1, 1)]) # Corrected
		if W:
			edges.append([pos, pos + Vector2i(-1, 0)])
		if NW:
			edges.append([pos, pos + Vector2i(-1, -1)]) # Corrected

	var g = Graph.new(edges)
	g.disabled = {} # Ensure this is ready for obstacle.gd to fill [file:810]
	return g


static func get_shortest_path_with_costs(graph: Graph, start: Vector2i, goal: Vector2i)-> Array:
	# Returns an Array of nodes: [start, node1, ..., node n, goal] from start to goal.
	# If no path exists, returns [].

	if start == goal:
		return [[], 0]

	if not graph.neighborhood.has(start) or not graph.neighborhood.has(goal):
		return [[],-1]

	var g_cost := {}  # Dictionary[Vector2i, float]
	var h_cost := {}  # Dictionary[Vector2i, float]
	var f_cost := {}  # Dictionary[Vector2i, float]
	const EDGE_COST := 1.0

	for n in graph.nodes:
		g_cost[n] = INF
		h_cost[n] = float(Graph.manhattan(n, goal))

	var came_from := {} # Dictionary[Vector2i, Vector2i]

	g_cost[start] = 0.0
	f_cost[start] = g_cost[start] + h_cost[start]
	came_from[start] = start

	var open := Heap.MinHeap.new()
	open.push(f_cost[start], start)

	# We skip stale entries when we pop them.
	while not open.is_empty():
		var item := open.pop()
		var current: Vector2i = item["n"]
		#var popped_f: float = float(item["p"])

		if current == goal:
			break

		var neighbors: Array = graph.neighborhood.get(current, [])
		for nb in neighbors:
			if graph.disabled.has(nb):
				continue
			var tentative := float(g_cost.get(current, INF)) + EDGE_COST
			if tentative < float(g_cost.get(nb, INF)):
				came_from[nb] = current
				g_cost[nb] = tentative
				f_cost[nb] = tentative + float(h_cost.get(nb, Graph.manhattan(nb, goal)))
				open.push(f_cost[nb], nb)
	var path = _reconstruct_edge_path(start, goal, came_from)
	var cost = g_cost[goal]
	return [path, cost]

static func get_shortest_path(graph: Graph, start: Vector2i, goal: Vector2i) -> Array:
	var path_cost_array = get_shortest_path_with_costs(graph, start,goal)
	print(path_cost_array[1])
	return path_cost_array[0]

static func set_alternative_path(train, graph, start, goal):
	var old_path = train.current_path
	if not old_path or old_path.size() == 0:
		return

	# 1. Attempt to find a NEW detour around the obstacle
	var new_path = get_shortest_path(graph, start, goal)
	
	# 2. Get the penalty duration (how long the obstacle stays) [file:812]
	var obstacle_time_left = Tracks_Manager.getObsticalRemainingDuration(old_path[0])
	
	# 3. Decision Logic: Is waiting better than the detour? [file:810]
	# If the detour is much longer than the wait, we "slow down" (wait it out)
	if new_path.is_empty() or (old_path.size() + obstacle_time_left < new_path.size()):
		var prefix = []
		for i in range(obstacle_time_left):
			prefix.append(old_path[0]) # Repeat current position to "wait"
			train.delay_count += 1      # Increment the delay dynamically
		train.current_path = prefix + old_path
	else:
		# Otherwise, take the detour
		train.current_path = new_path

static func _reconstruct_edge_path(start: Vector2i, goal: Vector2i, came_from: Dictionary) -> Array:
	if not came_from.has(goal):
		return []

	# Build node path goal->start, then reverse
	var node_path: Array[Vector2i] = []
	var cur: Vector2i = goal
	node_path.append(cur)

	while cur != start:
		if not came_from.has(cur):
			return [] # broken predecessor chain
		cur = came_from[cur]
		node_path.append(cur)

	node_path.reverse()

	return node_path


# Example usage:
# var g = Graph.new([
# 	[Vector2i(0,0), Vector2i(1,0)],
# 	[Vector2i(1,0), Vector2i(1,1)],
# 	[Vector2i(0,0), Vector2i(0,1)],
# 	[Vector2i(0,1), Vector2i(1,1)],
# ])
# var path_edges = get_shortest_path(g, Vector2i(0,0), Vector2i(1,1))
# print(path_edges)
