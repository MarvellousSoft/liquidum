extends Control

const ALPHA_SPEED = 4.0
const HIDE_ALPHA = 0.5
const NORMAL_COLOR = Color("#d9ffe2ff")
const SATISFIED_COLOR = Color("#61fc89ff")
const ERROR_COLOR = Color("#ff6a6aff")
const NUMBER_HEADER = """[font_size={12}]
[/font_size]"""

@onready var Hints = {
	E.Walls.Top: $Hints/Top,
	E.Walls.Right: $Hints/Right,
	E.Walls.Bottom: $Hints/Bottom,
	E.Walls.Left:$Hints/Left,
}
@onready var EditorButtons = $VBoxContainer/EditorButtons
@onready var ToggleHintType = $VBoxContainer/EditorButtons/ToggleHintType
@onready var ToggleVisibility = $VBoxContainer/EditorButtons/ToggleVisibility
@onready var HintsContainer = $VBoxContainer/HintsContainer
@onready var Number = %Number
@onready var Boat = %Boat

var editor_mode := false
var hint_type : E.HintType = E.HintType.Any
var is_boat := false
var hint_value := 0.0
var hint_type_active := true
var hint_visibility_active := true
var hint_alpha := 1.0

func _ready():
	disable_editor()
	set_boat(false)
	set_status(E.HintStatus.Normal)
	for side in Hints.keys():
		set_hint_visibility(side, true)


func _process(dt):
	if hint_type_active:
		if hint_alpha < 1.0:
			hint_alpha = min(hint_alpha + ALPHA_SPEED*dt, 1.0)
			update_label()
	else:
		if hint_alpha > 0.0:
			hint_alpha = max(hint_alpha - ALPHA_SPEED*dt, 0.0)
			update_label()
	if hint_visibility_active:
		HintsContainer.modulate.a = min(HintsContainer.modulate.a + ALPHA_SPEED*dt, 1.0)
	else:
		HintsContainer.modulate.a = max(HintsContainer.modulate.a - ALPHA_SPEED*dt, HIDE_ALPHA)
	
func set_boat(value):
	is_boat = value
	Boat.visible = value


func set_value(new_value : float) -> void:
	hint_value = new_value
	update_label()


func set_hint_type(new_type : E.HintType) -> void:
	hint_type = new_type
	if hint_type == E.HintType.Any:
		ToggleHintType.hide()
	else:
		ToggleHintType.show()
	
	update_label()


func alpha_t(text : String, alpha : float) -> String:
	var color = Color(1.0, 1.0, 1.0, alpha)
	return "[color=%s]%s[/color]" % ["#"+color.to_html(true),text]


func update_label() -> void:
	Number.text = NUMBER_HEADER
	match hint_type:
		E.HintType.Any:
			Number.text += str(hint_value)
		E.HintType.Together:
			Number.text += alpha_t("{", hint_alpha) + str(hint_value) + alpha_t("}", hint_alpha)
		E.HintType.Separated:
			Number.text += alpha_t("-", hint_alpha) + str(hint_value) + alpha_t("-", hint_alpha)


func no_hint() -> void:
	Number.text = ""
	hide()


func set_hint_visibility(which : E.Walls, value : bool) -> void:
	Hints[which].visible = value


func set_status(status: E.HintStatus) -> void:
	match status:
		E.HintStatus.Normal:
			Number.add_theme_color_override("default_color", NORMAL_COLOR)
		E.HintStatus.Satisfied:
			Number.add_theme_color_override("default_color", SATISFIED_COLOR)
		E.HintStatus.Wrong:
			Number.add_theme_color_override("default_color", ERROR_COLOR)


func enable_editor() -> void:
	editor_mode = true
	EditorButtons.show()


func disable_editor() -> void:
	editor_mode = false
	EditorButtons.hide()


func _on_visibility_toggled(button_pressed):
	hint_visibility_active = button_pressed


func _on_hint_type_toggled(button_pressed):
	hint_type_active = button_pressed
