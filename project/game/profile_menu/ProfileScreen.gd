extends Control

func _on_back_button_pressed():
	TransitionManager.pop_scene()

func select_profile(profile: String) -> void:
	FileManager.current_profile = profile
	FileManager.save_current_profile()
	get_tree().reload_current_scene()
