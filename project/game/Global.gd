extends Node

const THEME = {
	"desktop": {
		"normal": preload("res://assets/ui/GeneralTheme.tres"),
		"dark": preload("res://assets/ui/GeneralDarkTheme.tres"),
	},
	"mobile": {
		"normal": preload("res://assets/ui/MobileTheme.tres"),
		"dark": preload("res://assets/ui/MobileDarkTheme.tres"),
	},
	"font": {
		"normal": preload("res://assets/ui/DarkFont.tres"),
		"dark": preload("res://assets/ui/LightFont.tres"),
	},
}
const SETTINGS_THEME = {
	"desktop": {
		"normal": preload("res://assets/ui/SettingsTheme.tres"),
		"dark": preload("res://assets/ui/SettingsDarkTheme.tres"),
	},
	"mobile": {
		"normal": preload("res://assets/ui/SettingsMobileTheme.tres"),
		"dark": preload("res://assets/ui/SettingsMobileDarkTheme.tres"),
	},
}
const COLORS = {
	"normal": Color("#d9ffe2ff"),
	"satisfied": Color("#61fc89ff"),
	"error": Color("#ff6a6aff"),
}
const WATER_COLORS = {
	"normal": {
		"dark": Color(0, 0.035, 0.141),
		"bg": Color(0.851, 1, 0.886),
		"water_color": Color(0.671, 1, 0.82),
		"depth_color": Color(0.078, 0.365, 0.529),
		"ray_value": 0.3,
	},
	"dark": {
		"dark": Color(0.671, 1, 0.82),
		"bg": Color(0.035, 0.212, 0.349),
		"water_color": Color(0.671, 1, 0.82),
		"depth_color": Color(0.275, 0.812, 0.702),
		"ray_value": 1.0,
	}
}
const TUTORIALS = {
	"mouse1": {
		"desktop": preload("res://database/tutorials/Mouse1.tscn"),
		"mobile": preload("res://database/tutorials/Mouse1Mobile.tscn"),
	},
	"mouse2": {
		"desktop": preload("res://database/tutorials/Mouse2.tscn"),
	},
	"preview": {
		"desktop": preload("res://database/tutorials/HoverPreview.tscn"),
		"mobile": preload("res://database/tutorials/HoldPreview.tscn"),
	},
	"together_separate": preload("res://database/tutorials/TogetherSeparate.tscn"),
	"unknown_hints": preload("res://database/tutorials/UnknownHints.tscn"),
	"boats": preload("res://database/tutorials/Boats.tscn"),
}

signal dev_mode_toggled(status : bool)

@onready var level_scene = load_mobile_compat("res://game/level/Level")

var _dev_mode := false
var dev_mode_label: Label
var is_mobile: bool = ProjectSettings.get_setting("liquidum/is_mobile")
var play_new_dif_again = -1

func _ready() -> void:
	dev_mode_label = Label.new()
	dev_mode_label.text = "dev mode"
	dev_mode_label.position.x = get_viewport().get_visible_rect().size.x - 400
	dev_mode_label.position.y = get_viewport().get_visible_rect().size.y - 100
	dev_mode_label.visible = false
	add_child(dev_mode_label)
	if ProjectSettings.get_setting("liquidum/dev_mode"):
		toggle_dev_mode()


func _input(event):
	if event.is_action_pressed(&"toggle_fullscreen"):
		toggle_fullscreen()
	if event.is_action_pressed(&"toggle_dev_mode") and OS.is_debug_build():
		toggle_dev_mode()


func toggle_dev_mode():
	_dev_mode = not _dev_mode
	dev_mode_toggled.emit(_dev_mode)
	if not is_mobile:
		dev_mode_label.visible = _dev_mode


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Global.exit_game()

func load_mobile_compat(scene: String) -> PackedScene:
	if is_mobile:
		return load(scene + "Mobile.tscn")
	else:
		return load(scene + ".tscn")

func exit_game() -> void:
	if get_window().mode == Window.MODE_WINDOWED:
		_store_window()
	FileManager.save_game()
	call_deferred(&"_do_exit")

func _do_exit() -> void:
	var node := Global.load_mobile_compat("res://game/ui/Quitting").instantiate()
	get_tree().current_scene.hide()
	get_tree().root.add_child(node)
	await get_tree().process_frame
	get_tree().quit()


func is_dev_mode() -> bool:
	return OS.is_debug_build() and _dev_mode


func create_level(grid_: GridModel, level_name_: String, full_name_: String, description_: String, tracking_stats: Array[String], level_number := -1, section_number := -1) -> Level:
	var level : Level = level_scene.instantiate()
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

func is_fullscreen():
	return get_window().mode == Window.MODE_FULLSCREEN

func _store_window() -> void:
	var window := get_window()
	Profile.set_option("window_position", window.position)
	Profile.set_option("window_size", window.size)
	Profile.set_option("window_screen", window.current_screen)

func toggle_fullscreen():
	if is_mobile:
		return
	var window = get_window()
	if window.mode == Window.MODE_WINDOWED:
		_store_window()
	window.mode = Window.MODE_FULLSCREEN if window.mode == Window.MODE_WINDOWED else Window.MODE_WINDOWED
	Profile.set_option("fullscreen", window.mode != Window.MODE_WINDOWED, true)
	window.borderless =  window.mode != Window.MODE_WINDOWED
	if window.mode == Window.MODE_WINDOWED:
		var wpos := Profile.get_vec2i("window_position")
		var wsize := Profile.get_vec2i("window_size")
		if wpos != Vector2i(-1, -1) and wsize != Vector2i(-1, -1):
			window.position = wpos
			window.size = wsize
		else:
			var s_size = DisplayServer.screen_get_size()
			var size = s_size*.8
			window.size = size
			window.position = Vector2(s_size.x/2 - size.x/2, size.y/2)


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

#Checks if a certain tutorial exists in the current mode
func has_tutorial(tutorial_name):
	assert(TUTORIALS.has(tutorial_name), "Not a valid tutorial name: " + str(tutorial_name))
	var tut = TUTORIALS[tutorial_name]
	if tut is Dictionary:
		if is_mobile:
			return tut.has("mobile")
		else:
			return tut.has("desktop")
	return true


func get_tutorial(tutorial_name):
	assert(TUTORIALS.has(tutorial_name), "Not a valid tutorial name: " + str(tutorial_name))
	var tut = TUTORIALS[tutorial_name]
	if tut is Dictionary:
		if is_mobile:
			if tut.has("mobile"):
				return tut.mobile.instantiate()
			return false
		else:
			if tut.has("desktop"):
				return tut.desktop.instantiate()
			return false
	return tut.instantiate()


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


func get_theme(is_dark : bool):
	if is_mobile:
		if is_dark:
			return THEME.mobile.dark
		else:
			return THEME.mobile.normal
	else:
		if is_dark:
			return THEME.desktop.dark
		else:
			return THEME.desktop.normal


func get_font_theme(is_dark : bool):
	if is_dark:
		return THEME.font.dark
	else:
		return THEME.font.normal


func get_settings_theme(is_dark : bool):
	if is_mobile:
		if is_dark:
			return SETTINGS_THEME.mobile.dark
		else:
			return SETTINGS_THEME.mobile.normal
	else:
		if is_dark:
			return SETTINGS_THEME.desktop.dark
		else:
			return SETTINGS_THEME.desktop.normal


func get_color(is_dark : bool):
	if is_dark:
		return WATER_COLORS.dark
	else:
		return WATER_COLORS.normal
