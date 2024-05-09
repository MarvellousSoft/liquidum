class_name ModulateTextureButton
extends Control

const NORMAL_COLOR := {
	"dark": Color(0.671, 1, 0.82),
	"normal": Color(0, 0.035, 0.141),
}
const HOVER_COLOR := {
	"dark": Color(0.847, 0.996, 0.882),
	"normal": Color(0.035, 0.212, 0.349),
}

func _ready():
	Profile.dark_mode_toggled.connect(_on_dark_mode_changed)
	_on_dark_mode_changed(Profile.get_option("dark_mode"))


func get_color(color):
	return color.dark if Profile.get_option("dark_mode") else color.normal


func _on_mouse_entered() -> void:
	AudioManager.play_sfx("button_hover")
	modulate = get_color(HOVER_COLOR)

func _on_mouse_exited() -> void:
	modulate = get_color(NORMAL_COLOR)


func _on_dark_mode_changed(_is_dark):
	modulate = get_color(NORMAL_COLOR)
