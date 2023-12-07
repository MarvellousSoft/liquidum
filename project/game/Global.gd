extends Node

const LEVEL_SCENE = preload("res://game/level/Level.tscn")
const COLORS = {
	"normal": Color("#d9ffe2ff"),
	"satisfied": Color("#61fc89ff"),
	"error": Color("#ff6a6aff"),
}

var previous_windowed_pos = false
var _dev_mode := false
var dev_mode_label: Label


func _ready() -> void:
	dev_mode_label = Label.new()
	dev_mode_label.text = "dev mode"
	dev_mode_label.scale = Vector2(5, 5)
	dev_mode_label.position.y = get_viewport().get_visible_rect().size.y - 100
	dev_mode_label.visible = false
	add_child(dev_mode_label)


func _input(event):
	if event.is_action_pressed(&"toggle_fullscreen"):
		toggle_fullscreen()
	if event.is_action_pressed(&"toggle_dev_mode"):
		_dev_mode = not _dev_mode and OS.is_debug_build()
		dev_mode_label.visible = _dev_mode


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


func create_level(grid_: GridModel, level_name_: String, full_name_: String, description_: String) -> Node:
	var level : Level = LEVEL_SCENE.instantiate()
	level.grid = grid_
	level.level_name = level_name_
	level.full_name = full_name_
	level.description = description_
	return level


func create_button(text: String) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.text = text
	return button

func is_fullscreen():
	return get_window().mode == Window.MODE_FULLSCREEN

func toggle_fullscreen():
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
