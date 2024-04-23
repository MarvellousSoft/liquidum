extends Node

const APP_ID_PATH := "facebook/app_id"
const APP_NAME_PATH := "facebook/app_name"
const CLIENT_TOKEN_PATH := "facebook/client_token"

var _fb = null

var enabled: bool:
	get: return _fb != null

# Called when the node enters the scene tree for the first time.
func _ready():
	var _app_id = ProjectSettings.get_setting(APP_ID_PATH)
	var _app_name = ProjectSettings.get_setting(APP_NAME_PATH)
	var _client_token = ProjectSettings.get_setting(CLIENT_TOKEN_PATH)
	
	if _app_id.is_empty():
		printerr("[Facebook] - App id not found! Please set it in Project Setting/Facebook/App ID")
		return
	if _app_name.is_empty():
		printerr("[Facebook] - App name not found! Please set it in Project Setting/Facebook/App Name")
		return
	if _client_token.is_empty():
		printerr("[Facebook] - Client token not found! Please set it in Project Setting/Facebook/Client token")
		return
		
	if Engine.has_singleton(&"Facebook"):
		_fb = Engine.get_singleton(&"Facebook")
		_fb.init(_app_id, _client_token, _app_name)
		await get_tree().create_timer(5.0).timeout
		_fb.log_event("custom_ios_event")
		print("Initialised Facebook iOS SDK")
