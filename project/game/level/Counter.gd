extends Control

const ALPHA_SPEED = 4.0
const HIDE_ALPHA = 0.5

@export var counter_name := "MISTAKES_COUNTER"
@export var check_for_satisfied := true

@onready var VisibilityButton = %VisibilityButton
@onready var Counter = $HBoxContainer/Counter
@onready var MainLabel = $HBoxContainer/Label
@onready var AnimPlayer = $AnimationPlayer

var count: float = 0.0
var visibility_active := true


func _ready():
	disable_editor()
	MainLabel.text = tr(counter_name)


func _process(dt):
	if visibility_active:
		MainLabel.modulate.a = min(MainLabel.modulate.a + ALPHA_SPEED*dt, 1.0)
		Counter.modulate.a = min(Counter.modulate.a + ALPHA_SPEED*dt, 1.0)
	else:
		MainLabel.modulate.a = max(MainLabel.modulate.a - ALPHA_SPEED*dt, HIDE_ALPHA)
		Counter.modulate.a = max(Counter.modulate.a - ALPHA_SPEED*dt, HIDE_ALPHA)


func enable_editor():
	VisibilityButton.show()


func disable_editor():
	VisibilityButton.hide()


func startup(delay : float) -> void:
	await get_tree().create_timer(delay).timeout
	AnimPlayer.play("startup")


func add_count() -> void:
	count += 1
	update_label()


func set_count(value: float) -> void:
	if count != value:
		count = value
		update_label()


func set_unknown():
	Counter.text = "?"


func update_label() -> void:
	Counter.text = str(count)
	AnimPlayer.play("update_counter")
	if check_for_satisfied:
		if count == 0:
			Counter.add_theme_color_override("font_color", Global.COLORS.satisfied)
		elif count > 0:
			Counter.add_theme_color_override("font_color", Global.COLORS.normal)
		else:
			Counter.add_theme_color_override("font_color", Global.COLORS.error)


func _on_visibility_button_toggled(button_pressed):
	visibility_active = button_pressed
