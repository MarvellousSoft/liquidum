extends Control


func _ready():
	Profile.dark_mode_toggled.connect(_on_dark_mode_changed)
	_on_dark_mode_changed(Profile.get_option("dark_mode"))
	
	await get_tree().create_timer(.8).timeout
	
	AudioManager.play_sfx("all_levels_completed")


func _on_continue_pressed():
	AudioManager.play_sfx("button_pressed")
	TransitionManager.change_scene(Global.load_mobile_compat("res://game/credits/CreditsScreen").instantiate())


func _on_dark_mode_changed(is_dark : bool):
	theme = Global.get_theme(is_dark)
	%MarginContainer.theme = Global.get_font_theme(is_dark)


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")
