extends Control

@onready var Counter = $HBoxContainer/Counter
@onready var AnimPlayer = $AnimationPlayer

var mistakes := 0


func _ready():
	mistakes = 0


func add_mistake() -> void:
	mistakes += 1
	update_label()


func set_mistakes(value : int) -> void:
	mistakes = value
	update_label()


func update_label() -> void:
	Counter.text = str(mistakes)
	AnimPlayer.play("update_counter")
