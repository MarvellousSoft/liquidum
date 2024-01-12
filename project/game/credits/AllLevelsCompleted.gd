extends Control


func _on_continue_pressed():
	TransitionManager.change_scene(Global.load_no_mobile("res://game/credits/CreditsScreen").instantiate())
