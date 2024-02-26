@tool
extends EditorPlugin

const APP_ID_PATH = "facebook/app_id"
const APP_NAME_PATH = "facebook/app_name"
const CLIENT_TOKEN_PATH = "facebook/client_token"

func _enter_tree():
	add_custom_project_setting(APP_ID_PATH, "", TYPE_STRING)
	add_custom_project_setting(APP_NAME_PATH, "", TYPE_STRING)
	add_custom_project_setting(CLIENT_TOKEN_PATH, "", TYPE_STRING)
	ProjectSettings.save()
	
	add_autoload_singleton("GodotFacebook", "res://addons/facebook_plugin/godot_facebook.gd")

func _exit_tree():
	remove_autoload_singleton("GodotFacebook")
	
func _get_plugin_icon():
	return get_editor_interface().get_base_control().get_theme_icon("Node", "EditorIcons")

func add_custom_project_setting(name: String, default_value, type: int, hint: int = PROPERTY_HINT_NONE, hint_string: String = ""):

	if ProjectSettings.has_setting(name): return

	var setting_info: Dictionary = {
		"name": name,
		"type": type,
		"hint": hint,
		"hint_string": hint_string
	}

	ProjectSettings.set_setting(name, default_value)
	ProjectSettings.add_property_info(setting_info)
	ProjectSettings.set_initial_value(name, default_value)
