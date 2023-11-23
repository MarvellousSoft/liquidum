class_name HintBar
extends Control

# Add or remove row/column depending on the HintBar orientation
signal add_line()
signal rem_line()

const HINT = preload("res://game/level/hints/Hint.tscn")

@export var is_horizontal := false

@onready var Horizontal = $Horizontal
@onready var Vertical = $Vertical
@onready var AnimPlayer = $AnimationPlayer

const VALUE_VISIBLE := 1
const TYPE_VISIBLE := 2

func _ready():
	Vertical.visible = not is_horizontal
	Horizontal.visible = is_horizontal
	for child in Vertical.get_children():
		Vertical.remove_child(child)
	for child in Horizontal.get_children():
		Horizontal.remove_child(child)
	_setup_resize_buttons()

func _setup_resize_buttons() -> void:
	var bar = Horizontal if is_horizontal else Vertical
	var box: BoxContainer = VBoxContainer.new() if is_horizontal else HBoxContainer.new()
	var add_button := Global.create_button("+")
	var rem_button := Global.create_button("-")
	add_button.pressed.connect(_add_line)
	rem_button.pressed.connect(_rem_line)
	box.add_child(add_button)
	box.add_child(rem_button)
	box.name = "ResizeButtons"
	# Internal so we don't remove it by accident
	bar.add_child(box, false, Node.INTERNAL_MODE_BACK)

func _add_line() -> void:
	add_line.emit()

func _rem_line() -> void:
	rem_line.emit()

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

	bar.get_node("ResizeButtons").visible = editor_mode

	await get_tree().process_frame
	custom_minimum_size = bar.size


func startup(delay : float) -> void:
	await get_tree().create_timer(delay).timeout
	AnimPlayer.play("startup")


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

func should_be_visible(is_boat: bool) -> Array[int]:
	var bar = Horizontal if is_horizontal else Vertical
	var ans: Array[int] = []
	for container in bar.get_children():
		for child in container.get_children():
			if child.is_boat == is_boat:
				var val := 0
				if child.should_be_visible():
					val |= VALUE_VISIBLE
				if child.should_have_type():
					val |= TYPE_VISIBLE
				ans.append(val)
	return ans

const WATER_COUNT_VISIBLE := 1
const WATER_TYPE_VISIBLE := 2
const BOAT_COUNT_VISIBLE := 4
const BOAT_TYPE_VISIBLE := 8

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
