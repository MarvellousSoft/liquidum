extends Control


func _ready():
	randomize()
	FileManager.load_game()

	TransitionManager.push_scene(Global.load_mobile_compat("res://game/main_menu/MainMenu").instantiate())
