class_name HintBar
extends Control

const HINT = preload("res://game/level/hints/Hint.tscn")

@export var is_horizontal := false

@onready var Horizontal = $Horizontal
@onready var Vertical = $Vertical
@onready var AnimPlayer = $AnimationPlayer

func _ready():
	Vertical.visible = not is_horizontal
	Horizontal.visible = is_horizontal
	for child in Vertical.get_children():
		Vertical.remove_child(child)
	for child in Horizontal.get_children():
		Horizontal.remove_child(child)


func setup(hints : Array, editor_mode : bool) -> void:
	var bar = Horizontal if is_horizontal else Vertical
	for child in bar.get_children():
		bar.remove_child(child)
	for i in hints.size():
		var container := (VBoxContainer.new() as BoxContainer) if is_horizontal else (HBoxContainer.new() as BoxContainer)
		container.alignment = BoxContainer.ALIGNMENT_END
		container.add_theme_constant_override("separation", 0)
		bar.add_child(container)
		var water_hint = create_hint(container, editor_mode, true, hints[i].boat_count, hints[i].boat_count_type, i == 0)
		create_hint(container, editor_mode, false, hints[i].water_count, hints[i].water_count_type, i == 0)
		if hints[i].boat_count == -1 and hints[i].water_count == -1:
			water_hint.dummy_hint()


	await get_tree().process_frame
	custom_minimum_size = bar.size


func startup(editor_mode : bool, delay : float) -> void:
	if not editor_mode:
		await get_tree().create_timer(delay).timeout
		AnimPlayer.play("startup")
	else:
		modulate.a = 1.0


func create_hint(container : Container, editor_mode : bool, is_boat: float, hint_value : float, type: E.HintType, first : bool) -> Node:
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
	
	if editor_mode:
		new_hint.enable_editor()
	else:
		new_hint.disable_editor()
	
	return new_hint

const WATER_COUNT_VISIBLE := 1
const WATER_TYPE_VISIBLE := 2
const BOAT_COUNT_VISIBLE := 4
const BOAT_TYPE_VISIBLE := 8

func should_be_visible() -> Array[int]:
	var bar = Horizontal if is_horizontal else Vertical
	var ans: Array[int] = []
	for container in bar.get_children():
		var val := 0
		for child in container.get_children():
			if child.should_be_visible():
				val |= BOAT_COUNT_VISIBLE if child.is_boat else WATER_COUNT_VISIBLE
			if child.should_have_type():
				val |= BOAT_TYPE_VISIBLE if child.is_boat else WATER_TYPE_VISIBLE 
		ans.append(val)
	return ans

func set_visibility(arr: Array[int]) -> void:
	var bar = Horizontal if is_horizontal else Vertical
	assert(arr.size() == bar.get_child_count())
	for i in arr.size():
		for child in bar.get_child(i).get_children():
			if child.is_boat:
				child.set_visibility(bool(arr[i] & BOAT_COUNT_VISIBLE), bool(arr[i] & BOAT_TYPE_VISIBLE))
			else:
				child.set_visibility(bool(arr[i] & WATER_COUNT_VISIBLE), bool(arr[i] & WATER_TYPE_VISIBLE))


func get_hint(idx : int, is_boat : bool) -> Node:
	var bar = Horizontal if is_horizontal else Vertical
	assert(idx < bar.get_child_count(), "Not a valid index to get hint:" + str(idx))
	for child in bar.get_child(idx).get_children():
		if child.is_boat == is_boat:
			return child
	#"Couldn't find hint of this type
	return null
