extends Control

const RANDOM := "random"

@onready var Continue: Button = $Center/VBox/Continue

func _ready() -> void:
	Continue.visible = FileManager.load_level(RANDOM) != null

func _on_back_pressed() -> void:
	AudioManager.play_sfx("button_pressed")
	TransitionManager.pop_scene()

func gen_level() -> void:
	var g := Generator.new(randi(), false).generate(5, 5)
	FileManager.save_random_level(LevelData.new("", g.export_data(), ""))
	load_existing()

func load_existing() -> void:
	var data := FileManager.load_random_level()
	if data == null:
		return
	var level := Global.create_level(GridImpl.import_data(data.grid_data, GridModel.LoadMode.Solution), RANDOM, data.full_name)
	TransitionManager.push_scene(level)

func _on_easy_pressed() -> void:
	AudioManager.play_sfx("button_pressed")
	if Continue.visible and ConfirmationScreen.start_confirmation(&"CONFIRM_NEW_RANDOM"):
		if not await ConfirmationScreen.pressed:
			return
	gen_level()

func _on_continue_pressed() -> void:
	AudioManager.play_sfx("button_pressed")
	load_existing()
