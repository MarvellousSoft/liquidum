class_name EditorHub
extends Control

@onready var LevelNode: VBoxContainer = %LevelNode

func _ready():
	Profile.dark_mode_toggled.connect(_on_dark_mode_changed)
	_on_dark_mode_changed(Profile.get_option("dark_mode"))


func _enter_tree() -> void:
	call_deferred(&"load_all_levels")


func load_all_levels() -> void:
	var levels := FileManager.load_editor_levels()
	for child in LevelNode.get_children():
		LevelNode.remove_child(child)
		child.queue_free()
	var level_names = {}
	var ids := levels.keys()
	for id in ids:
		level_names[id] = FileManager.load_editor_level(id).full_name
	ids.sort_custom(func(a, b): return level_names[a] < level_names[b])
	for id in ids:
		var button := preload("res://game/editor_menu/EditorLevelButton.tscn").instantiate()
		button.setup(id, level_names[id])
		button.edit.connect(load_level)
		button.play.connect(play_level)
		button.delete.connect(delete_level)
		LevelNode.add_child(button)


func load_level(id: String) -> void:
	AudioManager.play_sfx("button_pressed")
	# Will be loaded
	var level := Global.create_level(GridImpl.empty_editor(1, 1), id, "", "", ["editor"])
	TransitionManager.push_scene(level)


func play_level(id: String) -> void:
	AudioManager.play_sfx("button_pressed")
	var data := FileManager.load_editor_level(id)
	var level := Global.create_level(GridImpl.import_data(data.grid_data, GridModel.LoadMode.Solution), "", data.full_name, data.description, ["playtest"])
	TransitionManager.push_scene(level)


func delete_level(id: String) -> void:
	FileManager.clear_editor_level(id)
	load_all_levels()


static func save_to_editor(level_name: String, grid: GridModel) -> void:
	var new_id := str(int(Time.get_unix_time_from_system() * 1000))
	var metadata := EditorLevelMetadata.new()
	var data := LevelData.new(level_name, "", grid.export_data(), "")
	FileManager.save_editor_level(new_id, metadata, data)


func _on_create_new_level_pressed() -> void:
	AudioManager.play_sfx("button_pressed")
	var level_name := "Level %d" % (LevelNode.get_child_count() + 1)
	var grid := GridImpl.new(5, 5)
	grid.grid_hints().total_boats = -1
	for i in grid.rows():
		grid.row_hints()[i].water_count = 0
	for j in grid.cols():
		grid.col_hints()[j].water_count = 0
	EditorHub.save_to_editor(level_name, grid)
	load_all_levels()


func _on_back_pressed():
	AudioManager.play_sfx("button_back")
	TransitionManager.pop_scene()


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")


func _on_dark_mode_changed(is_dark : bool):
	theme = Global.get_theme(is_dark)
