extends Node

signal login_response(code: int, response: Dictionary)
signal login_status_response(response: Dictionary)
signal show_dialog_response(code: int, response: Dictionary)
signal graph_call_response(code: int, response: Dictionary)
signal deferred_app_link_response(target_uri: String)
signal reauthorize_response(code: int, response: Dictionary)

const LOGIN_RESPONSE : StringName = "login_response"
const LOGIN_STATUS_RESPONSE : StringName = "login_status_response"
const SHOW_DIALOG_RESPONSE : StringName = "show_dialog_response"
const GRAPH_CALL_RESPONSE : StringName = "graph_call_response"
const DEFERRED_APP_LINK_RESPONSE : StringName = "deferred_app_link_response"
const REAUTHORIZE_RESPONSE : StringName = "reauthorize_response"

const FACEBOOK_PLUGIN_NAME := 'GodotFacebook'
const APP_ID_PATH := "facebook/app_id"
const APP_NAME_PATH := "facebook/app_name"
const CLIENT_TOKEN_PATH := "facebook/client_token"

var _fb = null

func _ready():
	var os_name = OS.get_name()
	if os_name != "Android":
		return
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	
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
	
	if not Engine.has_singleton(FACEBOOK_PLUGIN_NAME):
		printerr("Facebook plugin is not activated yet")
		return
		
	_fb = Engine.get_singleton(FACEBOOK_PLUGIN_NAME)
	
	_fb.connect(LOGIN_RESPONSE, _on_login_response)
	_fb.connect(LOGIN_STATUS_RESPONSE, _on_login_status_response)
	_fb.connect(SHOW_DIALOG_RESPONSE, _on_show_dialog_response)
	_fb.connect(GRAPH_CALL_RESPONSE, _on_graph_call_response)
	_fb.connect(DEFERRED_APP_LINK_RESPONSE, _on_deferred_app_link_response)
	_fb.connect(REAUTHORIZE_RESPONSE, _on_reauthorize_response)
	
	_fb.initApplication(_app_id, _app_name, _client_token)

func _is_fb():
	return _fb != null
	
func get_client_token() -> String:
	if _is_fb():
		return _fb.getClientToken()
	return ""

func get_application_id() -> String:
	if _is_fb():
		return _fb.getApplicationId()
	return ""
	
func get_application_name() -> String:
	if _is_fb():
		return _fb.getApplicationName()
	return ""
	
func login(permissions: Array = []):
	if _is_fb():
		_fb.login(permissions)

func is_data_access_expried() -> bool:
	if _is_fb():
		return _fb.isDataAccessExpired()
	return false
	
func logout():
	if _is_fb():
		_fb.logout()

func get_deferred_app_link():
	if _is_fb():
		_fb.getDeferredApplink()

func show_dialog(data : Dictionary):
	if _is_fb():
		_fb.showDialog(data)

func get_current_profile() -> Dictionary:
	if _is_fb():
		return _fb.getCurrentProfile()
	return {}

func graph_api(data : Dictionary):
	if _is_fb():
		_fb.graphApi(data)
		
func set_auto_log_app_events_enabled(enabled : bool):
	if _is_fb():
		_fb.setAutoLogAppEventsEnabled(enabled)

func set_advertiser_id_collection_enabled(enabled : bool):
	if _is_fb():
		_fb.setAdvertiserIDCollectionEnabled(enabled)

func set_data_processing_options(options : Array = []):
	if _is_fb():
		_fb.setDataProcessingOptions(options)
		

func set_user_data(data : Dictionary):
	if _is_fb():
		_fb.setUserData(data)
		

func clear_user_data():
	if _is_fb():
		_fb.clearUserData()
		
func log_event(data: Dictionary):
	if _is_fb():
		_fb.logEvent()
		

func log_purchase(data: Dictionary):
	if _is_fb():
		_fb.logPurchase()
		

func check_has_correct_permissions(permissions: Array = []) -> bool:
	if _is_fb():
		return _fb.checkHasCorrectPermissions(permissions)
	return false

func reauthorize_data_access():
	if _is_fb():
		_fb.reauthorizeDataAccess()

func get_login_status(force: bool):
	if _is_fb():
		_fb.getLoginStatus(force)

func getAccessToken() -> String:
	if _is_fb():
		return _fb.getAccessToken()
	return ""


#Signals
func _on_login_response(code: int, response: Dictionary):
	emit_signal("login_response", code, response)

func _on_login_status_response(response: Dictionary):
	emit_signal("login_status_response", response)
	
func _on_show_dialog_response(code: int, response: Dictionary):
	emit_signal("show_dialog_response", code, response)
	
func _on_graph_call_response(code: int, response: Dictionary):
	emit_signal("graph_call_response", code, response)
	
func _on_deferred_app_link_response(target_uri: String):
	emit_signal("deferred_app_link_response", target_uri)
	
func _on_reauthorize_response(code: int, response: Dictionary):
	emit_signal("reauthorize_response", code, response)
