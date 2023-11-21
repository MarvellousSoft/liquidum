extends Node2D

@onready var Version: Label = $Version

func _ready():
	FileManager.load_game()
	await get_tree().process_frame
	
	Version.text = Profile.VERSION
	Version.visible = Profile.SHOW_VERSION

func _on_level_button_pressed(level_name: String) -> void:
	# TODO: In the future, don't use from_str, but instead import_data
	var grid_str := FileAccess.get_file_as_string("res://game/levels/%s.txt" % level_name)
	var grid := GridImpl.from_str(grid_str)
	var level := Level.with_grid(grid, level_name)
	TransitionManager.push_scene(level)


func _on_editor_button_pressed():
	var grid := GridImpl.empty_editor(5, 5)
	var level := Level.with_grid(grid, "")
	TransitionManager.push_scene(level)
