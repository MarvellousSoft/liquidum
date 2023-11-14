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


func setup(normal_hints : Array, boat_hints : Array) -> void:
	assert(normal_hints.size() == boat_hints.size(), "Normal and boat hints don't have same size")
	var bar = Horizontal if is_horizontal else Vertical
	for child in bar.get_children():
		bar.remove_child(child)
	for i in normal_hints.size():
		var container = VBoxContainer.new() if is_horizontal else HBoxContainer.new()
		container.alignment = BoxContainer.ALIGNMENT_END
		bar.add_child(container)
		create_hint(container, normal_hints[i], is_horizontal, i == 0)
		create_hint(container, boat_hints[i], is_horizontal, i == 0)


func create_hint(container : Container, hint_value : float, is_horizontal : bool, first : bool) -> void:
	var new_hint = HINT.instantiate()
	container.add_child(new_hint)
	#Set value
	if hint_value == -1:
		new_hint.no_hint()
	else:
		new_hint.set_value(hint_value)
	#Set graphical hints
	if is_horizontal:
		new_hint.set_hint_visibility(E.Top, false)
		new_hint.set_hint_visibility(E.Bottom, false)
		new_hint.set_hint_visibility(E.Left, first)
	else:
		new_hint.set_hint_visibility(E.Left, false)
		new_hint.set_hint_visibility(E.Right, false)
		new_hint.set_hint_visibility(E.Top,  first)


func get_hint(idx : int, is_boat : bool) -> Node:
	var bar = Horizontal if is_horizontal else Vertical
	assert(idx < bar.get_child_count(), "Not a valid index to get hint:" + str(idx))
	for child in bar.get_child(idx).get_children():
		if child.is_boat == is_boat:
			return child
	push_error("Couldn't find hint at pos %d and type of boat equal to %b" % [idx, is_boat])
	return null
