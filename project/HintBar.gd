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


func setup(hints : Array) -> void:
	var bar = Horizontal if is_horizontal else Vertical
	for child in bar.get_children():
		bar.remove_child(child)
	for i in hints.size():
		@warning_ignore("incompatible_ternary")
		var container = VBoxContainer.new() if is_horizontal else HBoxContainer.new()
		container.alignment = BoxContainer.ALIGNMENT_END
		container.add_theme_constant_override("separation", 0)
		bar.add_child(container)
		create_hint(container, false, hints[i].water_count, hints[i].water_count_type, i == 0)
		create_hint(container, true, hints[i].boat_count, hints[i].boat_count_type, i == 0)
	
	await get_tree().process_frame
	custom_minimum_size = bar.size

func create_hint(container : Container, is_boat: float, hint_value : float, type: E.HintType, first : bool) -> void:
	var new_hint = HINT.instantiate()
	container.add_child(new_hint)
	new_hint.set_boat(is_boat)
	#Set value
	if hint_value == -1:
		new_hint.no_hint()
	else:
		new_hint.set_value(hint_value)
		new_hint.set_hint_type(type)
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
	#"Couldn't find hint of this type
	return null
