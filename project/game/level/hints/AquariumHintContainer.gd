class_name AquariumHintContainer
extends Control

const HINT_DELAY = .3

@onready var AnimPlayer = $AnimationPlayer
@onready var HintContainer = $PanelContainer/MarginContainer/VBox/HintContainer

func startup(delay: float, expected: Dictionary, current: Dictionary, editor_mode: bool) -> void:
	await get_tree().create_timer(delay).timeout
	AnimPlayer.play("startup")
	
	delay = HINT_DELAY
	update_values(expected, current, editor_mode, false)
	for child in HintContainer.get_children():
		child.startup(delay)
		delay += HINT_DELAY

func visible_sizes() -> Array[float]:
	var ans: Array[float] = []
	for child in HintContainer.get_children():
		if child.should_be_visible():
			ans.append(child.aquarium_size)
	return ans

func update_values(expected: Dictionary, current: Dictionary, editor_mode: bool, auto_start := true) -> void:
	while HintContainer.get_child_count() < expected.size():
		var c := preload("res://game/level/hints/AquariumHint.tscn").instantiate()
		HintContainer.add_child(c)
		if auto_start:
			c.startup(0)
	while HintContainer.get_child_count() > expected.size():
		var child := HintContainer.get_child(HintContainer.get_child_count() - 1)
		HintContainer.remove_child(child)
		child.queue_free()
	var sizes := expected.keys()
	sizes.sort()
	for i in sizes.size():
		HintContainer.get_child(i).set_values(sizes[i], expected[sizes[i]], current.get(sizes[i], 0), editor_mode)
