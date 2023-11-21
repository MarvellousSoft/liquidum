extends Control

@export var counter_name := "MISTAKES_COUNTER"
@export var check_for_satisfied := true

@onready var Counter = $HBoxContainer/Counter
@onready var MainLabel = $HBoxContainer/Label
@onready var AnimPlayer = $AnimationPlayer

var count: float = 0.0

func _ready():
	MainLabel.text = tr(counter_name)


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
