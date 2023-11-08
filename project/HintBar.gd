extends Control

const HINT = preload("res://game/level/hints/Hint.tscn")

@export var is_horizontal := false

@onready var Horizontal = $Horizontal
@onready var Vertical = $Vertical

func _ready():
	Vertical.visible = not is_horizontal
	Horizontal.visible = is_horizontal
	for child in Vertical.get_children():
		Vertical.remove_child(child)
	for child in Horizontal.get_children():
		Horizontal.remove_child(child)

func setup(hints : Array):
	var bar = Horizontal if is_horizontal else Vertical
	for hint in hints:
		var new_hint = HINT.instantiate()
		bar.add_child(new_hint)
		if hint == -1:
			new_hint.no_hint()
		else:
			new_hint.set_value(hint)
