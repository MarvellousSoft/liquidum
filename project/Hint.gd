extends Control

const NORMAL_COLOR = Color(1.0, 1.0, 1.0)
const SATISFIED_COLOR = Color(0.0, 1.0, 0.4)
const ERROR_COLOR = Color(.96, .19, .19)

@onready var Hints = {
	E.Walls.Top: $Hints/Top,
	E.Walls.Right: $Hints/Right,
	E.Walls.Bottom: $Hints/Bottom,
	E.Walls.Left:$Hints/Left,
}
@onready var Number = $HBoxContainer/Number
@onready var Boat = $HBoxContainer/Boat

var hint_type : E.HintType = E.HintType.Normal
var is_boat := false
var value := 0

func _ready():
	set_boat(false)
	set_normal()
	for side in Hints.keys():
		set_hint_visibility(side, true)


func set_boat(value):
	is_boat = value
	Boat.visible = value


func set_value(new_value : float) -> void:
	value = new_value
	update_label()


func set_hint_type(new_type : E.HintType) -> void:
	hint_type = new_type


func update_label() -> void:
	match hint_type:
		E.HintType.Normal:
			Number.text = str(value)
		E.HintType.Together:
			Number.text = "{" + str(value) + "}"
		E.HintType.Separated:
			Number.text = "-" + str(value) + "-"


func no_hint() -> void:
	Number.text = ""


func set_hint_visibility(which : E.Walls, value : bool) -> void:
	Hints[which].visible = value


func set_normal() -> void:
	Number.add_theme_color_override("font_color", NORMAL_COLOR)


func set_satisfied() -> void:
	Number.add_theme_color_override("font_color", SATISFIED_COLOR)


func set_error() -> void:
	Number.add_theme_color_override("font_color", ERROR_COLOR)
