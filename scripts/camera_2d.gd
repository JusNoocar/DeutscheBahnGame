extends Camera2D

# Config
var zoom_min = Vector2(0.5, 0.5)
var zoom_max = Vector2(2.0, 2.0)
var zoom_speed = Vector2(0.1, 0.1)
var pan_speed = 500.0 # Pixels per second

# State
var dragging = false
var last_mouse_pos = Vector2.ZERO

func _input(event):
	# 1. ZOOMING (Mouse Wheel)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom += zoom_speed
			# Clamp to max zoom
			if zoom > zoom_max: zoom = zoom_max
			
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom -= zoom_speed
			# Clamp to min zoom
			if zoom < zoom_min: zoom = zoom_min

		# 2. DRAGGING (Middle Mouse or Right Click)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				dragging = true
				last_mouse_pos = event.position
			else:
				dragging = false

	# 3. DRAG MOTION
	elif event is InputEventMouseMotion and dragging:
		# We need to move the camera OPPOSITE to the mouse movement
		# We also divide by zoom so dragging feels consistent at all zoom levels
		var delta = (last_mouse_pos - event.position) / zoom
		position += delta
		last_mouse_pos = event.position

func _process(delta):
	# 4. KEYBOARD PANNING (WASD)
	var move_vec = Vector2.ZERO
	if Input.is_action_pressed("ui_up"):    move_vec.y -= 1
	if Input.is_action_pressed("ui_down"):  move_vec.y += 1
	if Input.is_action_pressed("ui_left"):  move_vec.x -= 1
	if Input.is_action_pressed("ui_right"): move_vec.x += 1
	
	if move_vec != Vector2.ZERO:
		# Normalize so diagonal isn't faster
		# Divide by zoom so moving while zoomed in is slower/more precise
		position += move_vec.normalized() * pan_speed * delta * (1.0 / zoom.x)
