extends TabContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
 # Set padding for the tab content
	add_theme_constant_override("content_margin_left", 20)
	add_theme_constant_override("content_margin_right", 20)
	add_theme_constant_override("content_margin_top", 10)
	add_theme_constant_override("content_margin_bottom", 10)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
