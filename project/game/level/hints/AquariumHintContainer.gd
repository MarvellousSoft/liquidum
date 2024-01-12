class_name AquariumHintContainer
extends Control

const HINT_DELAY = .3

@onready var AnimPlayer = $AnimationPlayer
@onready var HintContainer = $PanelContainer/MarginContainer/VBox/ScrollContainer/HintContainer
@onready var Title = %Title

func _ready():
	for child in HintContainer.get_children():
		child.queue_free()

func startup(delay: float, expected: Dictionary, current: Dictionary, editor_mode: bool) -> void:
	if not editor_mode and expected.is_empty():
		hide()
		return
	show()
	
	await get_tree().create_timer(delay).timeout
	AnimPlayer.play("startup")
	
	delay = HINT_DELAY
	for child in HintContainer.get_children():
		child.modulate.a = 0.0
	update_values(expected, current, editor_mode, true)
	for child in HintContainer.get_children():
		child.startup(delay)
		delay += HINT_DELAY
	
	# Start with some scroll so it's clear to users a scrollbar is there
	var bar: ScrollBar = %ScrollContainer.get_v_scroll_bar()
	var scroll_max: float = bar.max_value - %ScrollContainer.size.y
	if not editor_mode and scroll_max > 0:
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_property(bar, ^'value', scroll_max, 3)
		tween.tween_property(bar, ^'value', 0, 3)
		tween.tween_property(bar, ^'value', scroll_max / 3, 1)
		var stop_tween := func(): tween.kill()
		%ScrollContainer.scroll_started.connect(stop_tween, CONNECT_ONE_SHOT)
		%ScrollContainer.get_v_scroll_bar().scrolling.connect(stop_tween, CONNECT_ONE_SHOT)

	if editor_mode:
		Title.text = tr("AQUARIUMS_COUNTER_EDITOR")
	else:
		Title.text = tr("AQUARIUMS_COUNTER")

func visible_sizes() -> Array[float]:
	var ans: Array[float] = []
	for child in HintContainer.get_children():
		if child.should_be_visible():
			ans.append(child.aquarium_size)
	return ans

func set_should_be_visible(sizes: Dictionary) -> void:
	for child in HintContainer.get_children():
		child.set_should_be_visible(sizes.has(child.aquarium_size))

func _visible() -> Dictionary:
	var ans := {}
	for sz in visible_sizes():
		ans[sz] = true
	return ans

func update_values(expected: Dictionary, current: Dictionary, editor_mode: bool, disable_instant_startup := false) -> void:
	var visible_ := _visible()
	for sz in visible_:
		if not expected.has(sz):
			expected[sz] = 0
	while HintContainer.get_child_count() < expected.size():
		var c := preload("res://game/level/hints/AquariumHint.tscn").instantiate()
		HintContainer.add_child(c)
		if editor_mode and not disable_instant_startup:
			c.instant_startup()
	while HintContainer.get_child_count() > expected.size():
		var child := HintContainer.get_child(HintContainer.get_child_count() - 1)
		HintContainer.remove_child(child)
		child.queue_free()
	var sizes := expected.keys()
	sizes.sort()
	for i in sizes.size():
		var c := HintContainer.get_child(i)
		c.set_values(sizes[i], expected[sizes[i]], current.get(sizes[i], 0), editor_mode)
		c.set_should_be_visible(visible_.has(sizes[i]))
