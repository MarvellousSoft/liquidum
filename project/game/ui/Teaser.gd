extends Control

func _ready() -> void:
	Background.get_node("GPUParticles2D").queue_free()

func _input(event: InputEvent) -> void:
	if event.is_pressed() and (event is InputEventKey) and (event as InputEventKey).keycode == KEY_SPACE:
		$SpaceToPlay.hide()
		$GPUParticles2D.restart()
		$AnimationPlayer.play(&"teaser")
