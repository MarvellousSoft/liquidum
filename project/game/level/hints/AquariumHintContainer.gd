class_name AquariumHintContainer
extends Control

const HINT_DELAY = .3

@onready var AnimPlayer = $AnimationPlayer
@onready var HintContainer = $PanelContainer/MarginContainer/VBox/HintContainer

func startup(delay: float, expected: Dictionary, current: Dictionary, editor_mode: bool) -> void:
	await get_tree().create_timer(delay).timeout
	AnimPlayer.play("startup")
	
	delay = HINT_DELAY
	update_values(expected, current, editor_mode)
	for child in HintContainer.get_children():
		child.startup(delay)
		delay += HINT_DELAY 

func update_values(expected: Dictionary, current: Dictionary, editor_mode: bool) -> void:
	while HintContainer.get_child_count() > expected.size():
		HintContainer.remove_child(HintContainer.get_child(HintContainer.get_child_count() - 1))
	while HintContainer.get_child_count() < expected.size():
		HintContainer.add_child(preload("res://game/level/hints/AquariumHint.tscn").instantiate())
	var sizes = expected.keys()
	sizes.sort()
	for i in sizes.size():
		HintContainer.get_child(i).set_values(sizes[i], expected[sizes[i]], current.get(sizes[i], 0), editor_mode)
