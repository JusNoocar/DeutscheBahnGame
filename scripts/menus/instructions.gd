extends Control

func _on_back_pressed():
	# Link to your editing/map creation scene
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	print("Go back to main menu")

func _ready():
	# Connect the 'pressed' signal of the child node "Play" to the function below [web:396]
	$Back.pressed.connect(_on_back_pressed)
