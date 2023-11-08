extends Control

const NORMAL_COLOR = Color(1.0, 1.0, 1.0)
const SATISFIED_COLOR = Color(0.0, 1.0, 0.4)
const ERROR_COLOR = Color(.96, .19, .19)

@onready var Number = $Number


func _ready():
	set_normal()


func set_value(value : float) -> void:
	Number.text = str(value)


func no_hint() -> void:
	Number.text = ""


func set_normal() -> void:
	Number.add_theme_color_override("font_color", NORMAL_COLOR)


func set_satisfied() -> void:
	Number.add_theme_color_override("font_color", SATISFIED_COLOR)


func set_error() -> void:
	Number.add_theme_color_override("font_color", ERROR_COLOR)
