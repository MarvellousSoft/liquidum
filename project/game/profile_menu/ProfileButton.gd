extends Control

const IMAGES = {
	"dark": {
		"selected": preload("res://assets/images/ui/brush/brush_picker_pressed_dark.png"),
	},
	"normal": {
		"selected": preload("res://assets/images/ui/brush/brush_picker_pressed.png"),
	}
}

@export var profile_name: String
@onready var Selected = %Selected

signal select(profile: String)
signal delete(profile: String)

func _ready() -> void:
	Profile.dark_mode_toggled.connect(_on_dark_mode_changed)
	_on_dark_mode_changed(Profile.get_option("dark_mode"))
	assert(not profile_name.is_empty())
	$ProfileInfo.text = "%d %s\n%d %s" % [CampaignLevelLister.count_completed_levels(profile_name), \
		tr(&"LEVELS_COMPLETED"), ExtraLevelLister.count_completed_levels(profile_name), tr(&"EXTRA_LEVELS_COMPLETED")]
	if FileManager.current_profile == profile_name:
		Selected.show()
	else:
		Selected.hide()


func set_button_icon(icon):
	%SelectButton.icon = icon


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


func _on_dark_mode_changed(is_dark : bool):
	var images = IMAGES.dark if is_dark else IMAGES.normal
	%Selected.texture = images.selected
