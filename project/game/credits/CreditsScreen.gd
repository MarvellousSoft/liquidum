extends Control

const GAMES_LINK := "https://store.steampowered.com/search/?publisher=Marvellous%20Soft"


func _ready():
	Profile.dark_mode_toggled.connect(_on_dark_mode_changed)
	_on_dark_mode_changed(Profile.get_option("dark_mode"))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"return"):
		TransitionManager.pop_scene()


func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()


func _on_game_pressed(app_id: int) -> void:
	if SteamManager.enabled:
		SteamManager.steam.activateGameOverlayToStore(app_id)


func _on_back_pressed() -> void:
	TransitionManager.pop_scene()


func _on_other_games_pressed():
	if SteamManager.enabled:
		SteamManager.steam.activateGameOverlayToWebPage(GAMES_LINK)
	else:
		OS.shell_open(GAMES_LINK)


func _on_dark_mode_changed(is_dark : bool):
	theme = Global.get_theme(is_dark)
