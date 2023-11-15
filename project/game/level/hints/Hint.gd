extends Control

const NORMAL_COLOR = Color("#d9ffe2ff")
const SATISFIED_COLOR = Color("#61fc89ff")
const ERROR_COLOR = Color("#ff6a6aff")

@onready var Hints = {
	E.Walls.Top: $Hints/Top,
	E.Walls.Right: $Hints/Right,
	E.Walls.Bottom: $Hints/Bottom,
	E.Walls.Left:$Hints/Left,
}
@onready var Number = $HBoxContainer/Number
@onready var Boat = $HBoxContainer/Boat

var hint_type : E.HintType = E.HintType.Any
var is_boat := false
var hint_value := 0.0

func _ready():
	set_boat(false)
	set_normal()
	for side in Hints.keys():
		set_hint_visibility(side, true)


func set_boat(value):
	is_boat = value
	Boat.visible = value


func set_value(new_value : float) -> void:
	hint_value = new_value
	update_label()


func set_hint_type(new_type : E.HintType) -> void:
	hint_type = new_type
	update_label()


func update_label() -> void:
	match hint_type:
		E.HintType.Any:
			Number.text = str(hint_value)
		E.HintType.Together:
			Number.text = "{" + str(hint_value) + "}"
		E.HintType.Separated:
			Number.text = "-" + str(hint_value) + "-"


func no_hint() -> void:
	Number.text = ""
	hide()


func set_hint_visibility(which : E.Walls, value : bool) -> void:
	Hints[which].visible = value


func set_normal() -> void:
	Number.add_theme_color_override("font_color", NORMAL_COLOR)


func set_satisfied() -> void:
	Number.add_theme_color_override("font_color", SATISFIED_COLOR)


func set_error() -> void:
	Number.add_theme_color_override("font_color", ERROR_COLOR)
