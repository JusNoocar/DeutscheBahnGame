extends Node2D
class_name Train

# --- VISUALS ---
@export var head_sprite: Sprite2D
@export var wagon_sprite: Sprite2D

# --- STATE ---
var head_current: Vector2i
var head_target: Vector2i
var wagon_current: Vector2i
var wagon_target: Vector2i

# Interpolation State
var tween: Tween
var navigation_system: Train_Navigation
var index: int = 0

const TILE_SIZE = 16
const HALF_TILE = Vector2(TILE_SIZE/2.0, TILE_SIZE/2.0)

var status_ui_item: Node # Reference to the instantiated train_status_item.tscn

func update_ui_status(name: String, route: String, dep: String, arr: String, delay: int):
	if is_instance_valid(status_ui_item):
		status_ui_item.get_node("HBoxContainer/VBoxContainer/Name").text = name
		status_ui_item.get_node("HBoxContainer/VBoxContainer/Route").text = route
		
		var schedule_node = status_ui_item.get_node("HBoxContainer/VBoxContainer/Schedule")
		var delay_color = "red" if delay > 0 else "green"
		schedule_node.bbcode_enabled = true
		schedule_node.text = "%s | %s [color=%s](+%d)[/color]" % [dep, arr, delay_color, delay]
func setup(start_pos: Vector2i, nav_ref: Train_Navigation):
	head_current = start_pos
	head_target = start_pos
	wagon_current = start_pos
	wagon_target = start_pos
	
	navigation_system = nav_ref
	
	_snap_visuals()
	

# CALL THIS ONCE PER TURN from MapManager
func do_game_tick(duration: float):
	# 1. Fetch New Data (Instant Logic Step)
	var occupied = Train_Navigation.trains[index].occupied_tiles
	
	# Update "Current" to be what "Target" was (we arrived)
	head_current = head_target
	wagon_current = wagon_target
	
	# Set new "Targets"
	if occupied:
		head_target = occupied[0]
		wagon_target = occupied[1] if occupied.size() > 1 else occupied[0]
	
	# 2. Start Visual Movement (Interpolation)
	
	if is_instance_valid(status_ui_item):
		var nav_train = Train_Navigation.trains[index]
		if typeof(nav_train) != TYPE_STRING:
			# Format: Name, Route, Dep, Arr, Delay
			var main = get_tree().current_scene
			if main.has_method("_update_item_schedule"):
				main._update_item_schedule(status_ui_item, "12:00", "13:00", nav_train.delay_count)
	_animate_move(duration)
	
func _animate_move(duration: float):
	# Kill previous animation if it's somehow still running
	if tween: tween.kill()
	tween = create_tween()
	
	# Orient Sprites
	_orient_sprite(head_sprite, head_current, head_target)
	_orient_sprite(wagon_sprite, wagon_current, wagon_target)
	
	# Calculate Pixel Positions
	var h_start = _grid_to_world(head_current)
	var h_end = _grid_to_world(head_target)
	var w_start = _grid_to_world(wagon_current)
	var w_end = _grid_to_world(wagon_target)
	
	# Reset sprites to start position (in case of drift)
	head_sprite.position = h_start
	wagon_sprite.position = w_start
	
	# Tween to end position over 'duration' seconds
	tween.set_parallel(true) # Animate both at same time
	tween.tween_property(head_sprite, "position", h_end, duration)
	tween.tween_property(wagon_sprite, "position", w_end, duration)

func _snap_visuals():
	head_sprite.position = _grid_to_world(head_current)
	wagon_sprite.position = _grid_to_world(wagon_current)

func _orient_sprite(sprite: Sprite2D, from: Vector2i, to: Vector2i):
	# Calculate direction vector
	var dir = to - from
	
	# Reset rotation (since we rely on pre-drawn frames now)
	sprite.rotation = 0
	
	# Select Frame based on Direction
	# (Adjust these numbers to match your specific spritesheet layout)
	match dir:
		# --- STRAIGHT MOVEMENT ---
		Vector2i(0, -1): # North (Up)
			sprite.frame = 0 
		Vector2i(0, 1):  # South (Down)
			sprite.frame = 1 
		Vector2i(1, 0):  # East (Right)
			sprite.frame = 2 
		Vector2i(-1, 0): # West (Left)
			sprite.frame = 2 # Assuming frame 2 can be flipped for West
			sprite.flip_h = true
			return # Exit so we don't undo the flip below
			
		# --- DIAGONAL / CURVE MOVEMENT ---
		# (If your trains move diagonally between tiles)
		Vector2i(1, 1):   # South-East
			sprite.frame = 4
		Vector2i(-1, 1):  # South-West
			sprite.frame = 5
		Vector2i(1, -1):  # North-East
			sprite.frame = 6
		Vector2i(-1, -1): # North-West
			sprite.frame = 7
			
	# Reset flip if not West
	sprite.flip_h = false

func _grid_to_world(pos: Vector2i) -> Vector2:
	return (Vector2(pos) * TILE_SIZE) + HALF_TILE + Vector2(13, 49)
func kill():
	# 1. Stop any active movement/animation
	if tween and tween.is_running():
		tween.kill()
	
	# 2. (Optional) Play a death animation or particle effect
	# spawn_explosion(position) 
	
	# 3. Remove from the "Active Trains" list in the Manager
	# You can signal the manager, or the manager handles this when checking is_instance_valid()
	
	# 4. Delete the node from the scene tree
	queue_free()
