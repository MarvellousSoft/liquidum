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
var editor_mode := false

func _ready():
	Profile.dark_mode_toggled.connect(_on_dark_mode_changed)
	_on_dark_mode_changed(Profile.get_option("dark_mode"))
	disable_editor()
	MainLabel.text = counter_name


func _process(dt):
	if should_be_visible():
		MainLabel.modulate.a = min(MainLabel.modulate.a + ALPHA_SPEED*dt, 1.0)
		Counter.modulate.a = min(Counter.modulate.a + ALPHA_SPEED*dt, 1.0)
	else:
		MainLabel.modulate.a = max(MainLabel.modulate.a - ALPHA_SPEED*dt, HIDE_ALPHA)
		Counter.modulate.a = max(Counter.modulate.a - ALPHA_SPEED*dt, HIDE_ALPHA)


func enable_editor():
	MainLabel.text += "_EDITOR"
	editor_mode = true
	VisibilityButton.show()


func disable_editor():
	editor_mode = false
	VisibilityButton.hide()

func should_be_visible() -> bool:
	return VisibilityButton.is_pressed()

func set_should_be_visible(b: bool) -> void:
	VisibilityButton.set_pressed_no_signal(b)


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
	if is_mistake_counter() and not Global.is_mobile:
		AnimPlayer.play("update_counter_big")
	elif Global.is_mobile:
		AnimPlayer.play("update_counter_mobile")
	else:
		AnimPlayer.play("update_counter")
	if not editor_mode:
		if check_for_satisfied:
			if count == 0:
				Counter.add_theme_color_override("font_color", Global.COLORS.satisfied)
			elif count > 0:
				Counter.add_theme_color_override("font_color", Global.COLORS.normal)
			else:
				Counter.add_theme_color_override("font_color", Global.COLORS.error)
	else:
		Counter.add_theme_color_override("font_color", Global.COLORS.normal)


func is_mistake_counter():
	return counter_name == "MISTAKES_COUNTER"


func _on_dark_mode_changed(is_dark : bool):
	var color = Global.get_color(is_dark)
	if not is_mistake_counter():
		%Label.add_theme_color_override("font_color", color.dark)
