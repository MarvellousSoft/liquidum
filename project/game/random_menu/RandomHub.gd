class_name RandomHub
extends Control

const RANDOM := "random"

@onready var Continue: Button = $Center/VBox/Continue
@onready var Completed: Label = $CompletedCount

var completed_count: int

func _enter_tree() -> void:
	call_deferred(&"_update")

func _update() -> void:
	Continue.visible = FileManager.load_level(RANDOM) != null
	completed_count = FileManager.load_user_data().random_levels_completed
	Completed.text = "%s: %d" % [tr(&"RANDOM_COMPLETED"), completed_count]

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
	level.won.connect(_level_completed)
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

func _level_completed() -> void:
	# Save was already deleted
	completed_count += 1
	FileManager.save_user_data(UserData.new(completed_count))
