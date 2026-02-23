extends RichTextLabel

@export var scroll_speed: float = 100.0

func _process(delta):
	position.x -= scroll_speed * delta
	# Loop back to the right once it moves off-screen
	if position.x < -get_content_width():
		position.x = get_viewport_rect().size.x
