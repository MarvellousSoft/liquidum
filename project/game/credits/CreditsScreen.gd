extends Control

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"return"):
		TransitionManager.pop_scene()


func _on_game_pressed(app_id: int) -> void:
	if SteamManager.enabled:
		SteamManager.steam.activateGameOverlayToStore(app_id)


func _on_back_pressed() -> void:
	TransitionManager.pop_scene()
