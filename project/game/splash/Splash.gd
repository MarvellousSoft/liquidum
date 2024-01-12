extends Control


func _ready():
	randomize()
	FileManager.load_game()
	
	if Global.is_mobile():
		TransitionManager.push_scene(load("res://game/main_menu/MainMenuMobile.tscn").instantiate())
	else:
		TransitionManager.push_scene(load("res://game/main_menu/MainMenu.tscn").instantiate())
