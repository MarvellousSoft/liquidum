extends Control

var done := false

func _ready() -> void:
	FileManager.load_game()

func _play_audio() -> void:
	if not done:
		AudioManager.play_sfx("its_marvellous")

func _transition_out() -> void:
	if not done:
		done = true
		TransitionManager.push_scene(Global.load_mobile_compat("res://game/main_menu/MainMenu").instantiate())

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"skip_splash"):
		$AnimationPlayer.pause()
		_transition_out()
