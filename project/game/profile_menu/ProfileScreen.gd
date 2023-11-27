extends Control

func _on_back_button_pressed():
	TransitionManager.pop_scene()

func select_profile(profile: String) -> void:
	FileManager.change_current_profile(profile)
	get_tree().reload_current_scene()


func delete_profile(profile: String) -> void:
	FileManager.clear_whole_profile(profile)
	get_tree().reload_current_scene()
