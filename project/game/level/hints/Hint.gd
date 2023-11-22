extends Control

const ALPHA_SPEED = 4.0
const HIDE_ALPHA = 0.5
const NUMBER_HEADER = """[font_size={50}]
[/font_size]"""

@onready var Hints = {
	E.Walls.Top: $Hints/Top,
	E.Walls.Right: $Hints/Right,
	E.Walls.Bottom: $Hints/Bottom,
	E.Walls.Left:$Hints/Left,
}
@onready var ContentContainer = $VBoxContainer
@onready var EditorButtons = $VBoxContainer/EditorButtons
@onready var ToggleHintType = $VBoxContainer/EditorButtons/ToggleHintType
@onready var ToggleVisibility = $VBoxContainer/EditorButtons/ToggleVisibility
@onready var HintsContainer = $VBoxContainer/HintsContainer
@onready var Number = %Number
@onready var Boat = %Boat
@onready var DummyLabel = %DummyLabel

var editor_mode := false
var hint_type : E.HintType = E.HintType.Any
var is_boat := false
var hint_value := 0.0
var hint_type_active := true
var hint_visibility_active := true
var hint_alpha := 1.0
var is_dummy := false

func _ready():
	disable_editor()
	DummyLabel.hide()
	set_boat(false)
	set_status(E.HintStatus.Normal)
	for side in Hints.keys():
		set_hint_visibility(side, true)


func _process(dt):
	if is_dummy:
		return
	
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

func should_be_visible() -> bool:
	return hint_visibility_active

func should_have_type() -> bool:
	return hint_type_active


func alpha_t(text : String, alpha : float) -> String:
	var color = Global.COLORS.normal
	color.a = alpha
	return "[color=%s]%s[/color]" % ["#"+color.to_html(true),text]


func update_label() -> void:
	Number.text = NUMBER_HEADER
	match hint_type:
		E.HintType.Any:
			Number.text += str(hint_value)
		E.HintType.Together:
			if editor_mode:
				Number.text += alpha_t("{", hint_alpha) + str(hint_value) + alpha_t("}", hint_alpha)
			else:
				Number.text += "{" + str(hint_value) + "}"
		E.HintType.Separated:
			if editor_mode:
				Number.text += alpha_t("-", hint_alpha) + str(hint_value) + alpha_t("-", hint_alpha)
			else:
				Number.text += "-" + str(hint_value) + "-"


func no_hint() -> void:
	Number.text = ""
	hide()


func dummy_hint() -> void:
	is_dummy = true
	show()
	DummyLabel.show()
	ContentContainer.hide()


func set_hint_visibility(which : E.Walls, value : bool) -> void:
	Hints[which].visible = value


func set_status(status: E.HintStatus) -> void:
	match status:
		E.HintStatus.Normal:
			Number.add_theme_color_override("default_color", Global.COLORS.normal)
		E.HintStatus.Satisfied:
			Number.add_theme_color_override("default_color", Global.COLORS.satisfied)
		E.HintStatus.Wrong:
			Number.add_theme_color_override("default_color", Global.COLORS.error)


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
