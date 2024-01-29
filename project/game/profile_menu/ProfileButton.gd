extends Control

@export var profile_name: String
@onready var Selected = %Selected

signal select(profile: String)
signal delete(profile: String)

func _ready() -> void:
	assert(not profile_name.is_empty())
	$ProfileInfo.text = "%d %s" % [LevelLister.count_completed_levels(profile_name), tr(&"LEVELS_COMPLETED")]
	if FileManager.current_profile == profile_name:
		Selected.show()
	else:
		Selected.hide()


func _on_select_button_pressed():
	AudioManager.play_sfx("button_pressed")
	select.emit(profile_name)


func _on_delete_button_pressed() -> void:
	AudioManager.play_sfx("button_back")
	if ConfirmationScreen.start_confirmation(&"CONFIRM_DELETE_PROFILE"):
		if await ConfirmationScreen.pressed:
			delete.emit(profile_name)


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")
