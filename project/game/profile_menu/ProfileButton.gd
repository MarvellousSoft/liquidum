extends Control

@export var profile_name: String
@onready var button: Button = $SelectButton

signal select(profile: String)

func _ready() -> void:
	assert(not profile_name.is_empty())
	$ProfileInfo.text = "%s: %d %s" % [profile_name, 0, tr("LEVELS_COMPLETED")]
	if FileManager.current_profile == profile_name:
		button.disabled = true
		button.text = "SELECTED"
	else:
		button.disabled = false
		button.text = "SELECT"


func _on_select_button_pressed():
	select.emit(profile_name)
