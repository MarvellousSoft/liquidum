extends Control


func _ready():
	Profile.dark_mode_toggled.connect(_on_dark_mode_changed)
	_on_dark_mode_changed(Profile.get_option("dark_mode"))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"return"):
		_back_logic()

func _back_logic() -> void:
	_on_back_button_pressed()

func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_WM_GO_BACK_REQUEST:
		_back_logic()


func select_profile(profile: String) -> void:
	FileManager.change_current_profile(profile)
	get_tree().reload_current_scene()
	_on_back_button_pressed()


func delete_profile(profile: String) -> void:
	FileManager.clear_whole_profile(profile)
	get_tree().reload_current_scene()


func _on_back_button_pressed():
	AudioManager.play_sfx("button_back")
	TransitionManager.pop_scene()


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")


func _on_dark_mode_changed(is_dark : bool):
	theme = Global.get_theme(is_dark)
