extends Control

var done := false

func _ready() -> void:
	# The override is not working, I'm not sure why
	if Global.is_mobile and not name.ends_with("Mobile"):
		call_deferred(&"_open_mobile_version")
		return
	FileManager.load_game()

func _open_mobile_version() -> void:
	get_tree().change_scene_to_file("res://game/splash/SplashMobile.tscn")

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
