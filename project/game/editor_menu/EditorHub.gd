extends Control

@onready var LevelNode: VBoxContainer = %LevelNode

func _ready() -> void:
	load_all_levels()


func load_all_levels() -> void:
	var levels := FileManager.load_editor_levels()
	for child in LevelNode.get_children():
		LevelNode.remove_child(child)
		child.queue_free()
	var ids := levels.keys()
	ids.sort_custom(func(a, b): return levels[a].full_name < levels[b].full_name)
	for id in ids:
		var button := preload("res://game/editor_menu/EditorLevelButton.tscn").instantiate()
		button.setup(id, levels[id].full_name)
		button.edit.connect(load_level)
		button.play.connect(play_level)
		button.delete.connect(delete_level)
		LevelNode.add_child(button)


func load_level(id: String) -> void:
	AudioManager.play_sfx("button_pressed")
	# Will be loaded
	var level := Global.create_level(GridImpl.empty_editor(1, 1), id, "")
	TransitionManager.push_scene(level)

func play_level(id: String) -> void:
	AudioManager.play_sfx("button_pressed")
	var data := FileManager.load_editor_level(id)
	var level := Global.create_level(GridImpl.import_data(data.grid_data, GridModel.LoadMode.Solution), "", data.full_name)
	TransitionManager.push_scene(level)


func delete_level(id: String) -> void:
	FileManager.clear_editor_level(id)
	load_all_levels()


func _on_create_new_level_pressed() -> void:
	AudioManager.play_sfx("button_pressed")
	var new_id := str(int(Time.get_unix_time_from_system() * 1000))
	var level_name := "Level %d" % (LevelNode.get_child_count() + 1)
	var metadata := EditorLevelMetadata.new(level_name)
	var grid := GridImpl.new(5, 5)
	grid.grid_hints().total_boats = -1
	for i in grid.rows():
		grid.row_hints()[i].water_count = 0
	for j in grid.cols():
		grid.col_hints()[j].water_count = 0
	var data := LevelData.new(level_name, grid.export_data(), "")
	FileManager.save_editor_level(new_id, metadata, data)
	load_all_levels()


func _on_back_pressed():
	AudioManager.play_sfx("button_back")
	TransitionManager.pop_scene()


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")
