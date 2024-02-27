extends Control

@export var link: String

const NORMAL_COLOR := Color(0.671, 1, 0.82)
const HOVER_COLOR := Color(0.847, 0.996, 0.882)

func _on_mouse_entered() -> void:
	AudioManager.play_sfx("button_hover")
	modulate = HOVER_COLOR

func _on_mouse_exited() -> void:
	modulate = NORMAL_COLOR

func _on_button_pressed() -> void:
	OS.shell_open(link)
