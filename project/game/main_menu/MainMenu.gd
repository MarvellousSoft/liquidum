extends Control

@onready var Version: Label = $Version
@onready var LevelButtons: VBoxContainer = $LevelButtons


func _ready():
	FileManager.load_game()
	
	AudioManager.play_bgm("main")
	
	await get_tree().process_frame
	
	Version.text = Profile.VERSION
	Version.visible = Profile.SHOW_VERSION

func _enter_tree() -> void:
	call_deferred("update_open_levels")

func update_open_levels() -> void:
	while LevelButtons.get_child_count() > 1:
		var c := LevelButtons.get_child(LevelButtons.get_child_count() - 1)
		LevelButtons.remove_child(c)
		c.queue_free()
	for section in range(1, 100):
		var mx := LevelLister.get_max_unlocked_level(section)
		if mx == 0:
			break
		for i in range(1, mx + 1):
			var button := Button.new()
			button.text = "%d - %d" % [section, i]
			button.pressed.connect(_on_level_button_pressed.bind(section, i))
			button.focus_mode = Control.FOCUS_NONE
			LevelButtons.add_child(button)

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
