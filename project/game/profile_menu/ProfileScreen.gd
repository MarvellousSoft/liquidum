extends Control

func _input(event):
	if event.is_action_pressed("return"):
		_on_back_button_pressed()

func _on_back_button_pressed():
	AudioManager.play_sfx("button_back")
	TransitionManager.pop_scene()

func select_profile(profile: String) -> void:
	FileManager.change_current_profile(profile)
	get_tree().reload_current_scene()


func delete_profile(profile: String) -> void:
	FileManager.clear_whole_profile(profile)
	get_tree().reload_current_scene()


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")
