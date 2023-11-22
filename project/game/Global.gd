extends Node

const LEVEL_SCENE = preload("res://game/level/Level.tscn")
const COLORS = {
	"normal": Color("#d9ffe2ff"),
	"satisfied": Color("#61fc89ff"),
	"error": Color("#ff6a6aff"),
}

var previous_windowed_pos = false

func _input(event):
	if event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()


func create_level(grid_: GridModel, level_name_: String) -> Node:
	var level : Level = LEVEL_SCENE.instantiate()
	level.grid = grid_
	level.level_name = level_name_
	return level


func is_fullscreen():
	return get_window().mode == Window.MODE_FULLSCREEN

func toggle_fullscreen():
	var window = get_window()
	var cur_screen = window.get_current_screen()
	if window.mode == Window.MODE_WINDOWED:
		previous_windowed_pos = window.position
	window.mode = Window.MODE_FULLSCREEN if window.mode == Window.MODE_WINDOWED else Window.MODE_WINDOWED
	Profile.set_option("fullscreen", window.mode != Window.MODE_WINDOWED, true)
	window.borderless =  window.mode != Window.MODE_WINDOWED
	if window.mode == Window.MODE_WINDOWED:
		var size = DisplayServer.screen_get_size()*.8
		window.size = size
		if previous_windowed_pos:
			window.position = previous_windowed_pos
		else:
			window.position = Vector2(50, 50)
		window.set_current_screen(cur_screen)
