extends Control

@onready var Cont: MarginContainer = $MarginContainer

func _ready() -> void:
	if Global.is_mobile:
		Cont.begin_bulk_theme_override()
		theme = Global.get_theme(Profile.get_option("dark_mode"))
		Cont.add_theme_constant_override("margin_left", 50)
		Cont.add_theme_constant_override("margin_right", 50)
		Cont.add_theme_constant_override("margin_top", 200)
		Cont.add_theme_constant_override("margin_bottom", 50)
		Cont.end_bulk_theme_override()
		$Back.reset_size()

func _on_back_pressed() -> void:
	TransitionManager.pop_scene()

func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")
