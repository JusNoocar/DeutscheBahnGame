extends Control

func _on_play_pressed():
	# Link to your editing/map creation scene
	get_tree().change_scene_to_file("res://scenes/editor.tscn")

func _on_help_pressed():
	print("Show tutorial or instructions")
	get_tree().change_scene_to_file("res://scenes/instructions.tscn")

func _ready():
	# Connect the 'pressed' signal of the child node "Play" to the function below [web:396]
	$VBoxContainer/Play.pressed.connect(_on_play_pressed)
	$Button2.pressed.connect(_on_help_pressed)
	
func _process(delta):
	pass
