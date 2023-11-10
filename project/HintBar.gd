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
	for child in bar.get_children():
		bar.remove_child(child)
	for idx in hints.size():
		var hint = hints[idx]
		var new_hint = HINT.instantiate()
		bar.add_child(new_hint)
		#Set value
		if hint == -1:
			new_hint.no_hint()
		else:
			new_hint.set_value(hint)
		#Set graphical hints
		if is_horizontal:
			new_hint.set_hint_visibility(E.Top, false)
			new_hint.set_hint_visibility(E.Bottom, false)
			new_hint.set_hint_visibility(E.Left, idx == 0)
		else:
			new_hint.set_hint_visibility(E.Left, false)
			new_hint.set_hint_visibility(E.Right, false)
			new_hint.set_hint_visibility(E.Top,  idx == 0)

func get_hint(idx : int) -> Node:
	var bar = Horizontal if is_horizontal else Vertical
	assert(idx < bar.get_child_count(), "Not a valid index to get hint:" + str(idx))
	return bar.get_child(idx)