class_name AquariumHintContainer
extends Control

const HINT_DELAY = .3
const COLORS = {
	"normal": {
		"font_color": Color(0.016, 0.106, 0.22),
	},
	"dark": {
		"font_color": Color(0.671, 1, 0.82),
	}
}

const PANELS = {
	"dark": preload("res://assets/ui/AquariumHintContainerMobileDarkPanel.tres"),
	"normal": preload("res://assets/ui/AquariumHintContainerMobilePanel.tres"),
}

@onready var AnimPlayer: AnimationPlayer = $AnimationPlayer
@onready var HintContainer = $PanelContainer/MarginContainer/VBox/ScrollContainer/HintContainer
@onready var Title = %Title

func _ready():
	Profile.dark_mode_toggled.connect(update_dark_mode)
	for child in HintContainer.get_children():
		child.queue_free()
	update_dark_mode(Profile.get_option("dark_mode"))


func startup(delay: float, expected: Dictionary, current: Dictionary, editor_mode: bool, fast_mode: bool) -> void:
	if not editor_mode and expected.is_empty():
		hide()
		return
	show()
	
	delay = HINT_DELAY
	for child in HintContainer.get_children():
		child.modulate.a = 0.0
	update_values(expected, current, editor_mode, true)
	if not fast_mode:
		await get_tree().create_timer(delay).timeout
	AnimPlayer.play("startup")
	if fast_mode:
		AnimPlayer.advance(AnimPlayer.current_animation_length)
	for child in HintContainer.get_children():
		child.startup(delay, fast_mode)
		delay += HINT_DELAY
	
	if not fast_mode:
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
		%Amount.text = tr("AQ_AMOUNT_EDITOR")
		%Header.add_theme_constant_override("separation", 150)
	else:
		Title.text = tr("AQUARIUMS_COUNTER")
		%Amount.text = tr("AQ_AMOUNT")
		if not Global.is_mobile:
			%Header.add_theme_constant_override("separation", 100)
			


func visible_sizes() -> Array[float]:
	var ans: Array[float] = []
	for child in HintContainer.get_children():
		if child.should_be_visible():
			ans.append(child.aquarium_size)
	return ans


func set_should_be_visible(sizes: Dictionary) -> void:
	for child in HintContainer.get_children():
		child.set_should_be_visible(sizes.has(child.aquarium_size))


func update_dark_mode(is_dark : bool) -> void:
	var colors = COLORS.dark if is_dark else COLORS.normal
	for label in [%Title, %Size, %Amount]:
		label.add_theme_color_override("font_color", colors.font_color)
	if Global.is_mobile:
		for label in [%Size2, %Amount2]:
			label.add_theme_color_override("font_color", colors.font_color)
		if is_dark:
			%PanelContainer.add_theme_stylebox_override("panel", PANELS.dark)
		else:
			%PanelContainer.add_theme_stylebox_override("panel", PANELS.normal)
		


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
		var c
		if not Global.is_mobile:
			c = preload("res://game/level/hints/AquariumHint.tscn").instantiate()
		else:
			c = preload("res://game/level/hints/AquariumHintMobile.tscn").instantiate()
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
	if Global.is_mobile:
		for node in [%VSeparator, %Size2, %Amount2]:
			node.visible = HintContainer.get_child_count() > 1
