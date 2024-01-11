extends Node

const LEVEL_SCENE = preload("res://game/level/Level.tscn")
const COLORS = {
	"normal": Color("#d9ffe2ff"),
	"satisfied": Color("#61fc89ff"),
	"error": Color("#ff6a6aff"),
}
const TUTORIALS = {
	"mouse": preload("res://database/tutorials/Mouse.tscn"),
	"mouse2": preload("res://database/tutorials/Mouse2.tscn"),
	"together_separate": preload("res://database/tutorials/TogetherSeparate.tscn"),
	"unknown_hints": preload("res://database/tutorials/UnknownHints.tscn"),
	"boats": preload("res://database/tutorials/Boats.tscn"),
}

signal dev_mode_toggled(status : bool)

var previous_windowed_pos = false
var _dev_mode := false
var dev_mode_label: Label



func _ready() -> void:
	dev_mode_label = Label.new()
	dev_mode_label.text = "dev mode"
	dev_mode_label.scale = Vector2(5, 5)
	dev_mode_label.position.x = get_viewport().get_visible_rect().size.x - 400
	dev_mode_label.position.y = get_viewport().get_visible_rect().size.y - 100
	dev_mode_label.visible = false
	add_child(dev_mode_label)


func _input(event):
	if event.is_action_pressed(&"toggle_fullscreen"):
		toggle_fullscreen()
	if event.is_action_pressed(&"toggle_dev_mode") and OS.is_debug_build():
		toggle_dev_mode()


func toggle_dev_mode():
	_dev_mode = not _dev_mode
	dev_mode_label.visible = _dev_mode
	dev_mode_toggled.emit(_dev_mode)


func _notification(what : int):
	if what == NOTIFICATION_EXIT_TREE:
		exit_game()


func exit_game():
	var window = get_window()
	if window.mode == Window.MODE_WINDOWED:
		Profile.set_option("previous_windowed_pos", window.position, true)
	get_tree().quit()


func is_dev_mode() -> bool:
	return OS.is_debug_build() and _dev_mode


func create_level(grid_: GridModel, level_name_: String, full_name_: String, description_: String, tracking_stats: Array[String], level_number := -1, section_number := -1) -> Level:
	var level : Level = LEVEL_SCENE.instantiate()
	level.grid = grid_
	level.level_name = level_name_
	level.full_name = full_name_
	level.level_number = level_number
	level.section_number = section_number
	level.description = description_
	level.add_playtime_tracking(tracking_stats)
	return level


func create_button(text: String) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.text = text
	return button


func is_mobile():
	return ProjectSettings.get_setting("liquidum/is_mobile")


func is_fullscreen():
	return get_window().mode == Window.MODE_FULLSCREEN


func toggle_fullscreen():
	if is_mobile():
		return
	var window = get_window()
	var cur_screen = window.get_current_screen()
	if window.mode == Window.MODE_WINDOWED:
		Profile.set_option("previous_windowed_pos", window.position)
	window.mode = Window.MODE_FULLSCREEN if window.mode == Window.MODE_WINDOWED else Window.MODE_WINDOWED
	Profile.set_option("fullscreen", window.mode != Window.MODE_WINDOWED, true)
	window.borderless =  window.mode != Window.MODE_WINDOWED
	if window.mode == Window.MODE_WINDOWED:
		var s_size = DisplayServer.screen_get_size()
		var size = s_size*.8
		window.size = size
		var prev = Profile.get_option("previous_windowed_pos")
		if prev:
			if prev is String:
				window.position = str_to_var("Vector2" + prev)
			else:
				window.position = prev
		else:
			window.position = Vector2(s_size.x/2 - size.x/2, size.y/2)
		window.set_current_screen(cur_screen)


func shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in a.size():
		var j := rng.randi_range(i, a.size() - 1)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp


func wait_for_thread(t: Thread) -> Variant:
	while t.is_started() and t.is_alive():
		await get_tree().create_timer(0.5).timeout
	return t.wait_to_finish()


func get_tutorial(tutorial_name):
	assert(TUTORIALS.has(tutorial_name), "Not a valid tutorial name: " + str(tutorial_name))
	return TUTORIALS[tutorial_name].instantiate()


func alpha_fade_node(dt: float, node: Node, show: bool, alpha_speed := 1.0, toggle_visibility := false, max_alpha := 1.0, min_alpha := 0.0) -> void:
	if show:
		node.modulate.a = min(node.modulate.a + alpha_speed*dt, max_alpha)
	else:
		node.modulate.a = max(node.modulate.a - alpha_speed*dt, min_alpha)
	if toggle_visibility:
		if node.modulate.a > 0.0:
			node.show()
		else:
			node.hide()
