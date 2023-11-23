extends Control

@onready var Version: Label = $Version

func _ready():
	FileManager.load_game()
	await get_tree().process_frame
	
	Version.text = Profile.VERSION
	Version.visible = Profile.SHOW_VERSION


func _on_level_button_pressed(section: int, level: int) -> void:
	var level_data := FileManager.load_level_data(section, level)
	var level_name := LevelLister.level_name(section, level)
	var grid := GridImpl.import_data(level_data.grid_data, GridModel.LoadMode.Solution)
	# TODO: Display level_data.full_name somewhere
	var level_node := Global.create_level(grid, level_name)
	TransitionManager.push_scene(level_node)



func _on_editor_button_pressed():
	var editor_hub = preload("res://game/main_menu/EditorHub.tscn").instantiate()
	TransitionManager.push_scene(editor_hub)
