extends Control

func _ready() -> void:
	if ConfirmationScreen.AnimPlayer.is_playing():
		await ConfirmationScreen.AnimPlayer.animation_finished
	get_tree().quit()
