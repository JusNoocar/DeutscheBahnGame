extends Control

func _on_back_button_pressed():
	GlobalGameManager.reset_to_initial()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Back.pressed.connect(_on_back_button_pressed)
	if(GlobalGameManager.total_delay > GlobalGameManager.DELAY_MAXIMUM_WIN):
		$Title.text = "Du wurdest gefeueret!"
		$Message.text = "Die Bahn kann dir nicht mehr vertrauen, zu viele Verstörungen wurden verursacht! Sei nächstes Mal vorsichtiger!"
	elif(GlobalGameManager.total_delay >= GlobalGameManager.DELAY_MINIMUM_WIN):
		$Title.text = "Du hast gewonnen!!"
		$Message.text = "Glückwunsch! Thank you for traveling with Die Bahn!"
	else:
		$Title.text = "Du hast verloren!"
		$Message.text = "Leider kann Die Bahn nicht so pünktlich sein. Probier's nochmal!" 
	$Score.text = str(GlobalGameManager.total_delay) + " Minutes"
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
