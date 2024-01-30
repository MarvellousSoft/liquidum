extends Control


func _ready():
	Profile.dark_mode_toggled.connect(_on_dark_mode_changed)
	_on_dark_mode_changed(Profile.get_option("dark_mode"))


func _on_continue_pressed():
	TransitionManager.change_scene(Global.load_mobile_compat("res://game/credits/CreditsScreen").instantiate())


func _on_dark_mode_changed(is_dark : bool):
	theme = Global.get_theme(is_dark)
	%MarginContainer.theme = Global.get_font_theme(is_dark)
