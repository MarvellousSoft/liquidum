extends Control

@export var counter_name := "MISTAKES_COUNTER"

@onready var Counter = $HBoxContainer/Counter
@onready var MainLabel = $HBoxContainer/Label
@onready var AnimPlayer = $AnimationPlayer

var count := 0


func _ready():
	MainLabel.text = tr(counter_name)


func startup(delay : float) -> void:
	await get_tree().create_timer(delay).timeout
	AnimPlayer.play("startup")


func add_count() -> void:
	count += 1
	update_label()


func set_count(value : int) -> void:
	if count != value:
		count = value
		update_label()


func set_unknown():
	Counter.text = "?"


func update_label() -> void:
	Counter.text = str(count)
	AnimPlayer.play("update_counter")
