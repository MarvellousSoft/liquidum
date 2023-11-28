extends Control

const CAM_POS = {
	"menu": Vector2(1930, 1080),
	"level_hub": Vector2(1930, -1280),
}

@onready var Version: Label = $Version
@onready var ProfileButton: Button = $ProfileButton
@onready var Camera = $Camera2D

func _ready():
	FileManager.load_game()
	
	Camera.position = CAM_POS.menu
	AudioManager.play_bgm("main")
	
	await get_tree().process_frame
	
	Version.text = Profile.VERSION
	Version.visible = Profile.SHOW_VERSION


func _enter_tree() -> void:
	#call_deferred("update_open_levels")
	call_deferred("update_profile_button")


func update_profile_button() -> void:
	ProfileButton.text = "%s: %s" % [tr("PROFILE"), FileManager.current_profile]


#func update_open_levels() -> void:
#	while LevelButtons.get_child_count() > 1:
#		var c := LevelButtons.get_child(LevelButtons.get_child_count() - 1)
#		LevelButtons.remove_child(c)
#		c.queue_free()
#	for section in range(1, 100):
#		var mx := LevelLister.get_max_unlocked_level(section)
#		if mx == 0:
#			break
#		for i in range(1, mx + 1):
#			var button := Button.new()
#			button.text = "%d - %d" % [section, i]
#			button.pressed.connect(_on_level_button_pressed.bind(section, i))
#			button.mouse_entered.connect(_on_button_mouse_entered)
#			button.focus_mode = Control.FOCUS_NONE
#			LevelButtons.add_child(button)

func _on_level_button_pressed(section: int, level: int) -> void:
	AudioManager.play_sfx("button_pressed")
	var level_data := FileManager.load_level_data(section, level)
	var level_name := LevelLister.level_name(section, level)
	var grid := GridImpl.import_data(level_data.grid_data, GridModel.LoadMode.Solution)
	# TODO: Display level_data.full_name somewhere
	var level_node := Global.create_level(grid, level_name)
	TransitionManager.push_scene(level_node)

func _on_editor_button_pressed():
	AudioManager.play_sfx("button_pressed")
	var editor_hub = preload("res://game/editor_menu/EditorHub.tscn").instantiate()
	TransitionManager.push_scene(editor_hub)


func _on_profile_button_pressed():
	AudioManager.play_sfx("button_pressed")
	var profile := preload("res://game/profile_menu/ProfileScreen.tscn").instantiate()
	TransitionManager.push_scene(profile)


func _on_exit_button_pressed():
	AudioManager.play_sfx("button_pressed")
	if ConfirmationScreen.start_confirmation("EXIT_CONFIRMATION"):
		if await ConfirmationScreen.pressed:
			get_tree().quit()


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")


func _on_play_pressed():
	AudioManager.play_sfx("button_pressed")
	Camera.position = CAM_POS.level_hub


func _on_back_button_pressed():
	AudioManager.play_sfx("button_back")
	Camera.position = CAM_POS.menu
