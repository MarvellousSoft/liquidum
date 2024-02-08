extends Control

@onready var Buttons: BoxContainer = %ButtonsContainer


func _ready():
	Profile.dark_mode_toggled.connect(_on_dark_mode_changed)
	_on_dark_mode_changed(Profile.get_option("dark_mode"))
	SteamManager.steam.item_downloaded.connect(_item_downloaded)
	SteamManager.steam.item_installed.connect(_item_installed)


func _enter_tree() -> void:
	if not SteamManager.enabled:
		return
	call_deferred("reload_all_levels")

func reload_all_levels() -> void:
	var ids: Array = SteamManager.steam.getSubscribedItems()
	while Buttons.get_child_count() > 0:
		Buttons.remove_child(Buttons.get_child(Buttons.get_child_count() - 1))
	var button_class := preload("res://game/workshop_menu/WorkshopLevelButton.tscn")
	for id in ids:
		var button := button_class.instantiate()
		button.id = id
		Buttons.add_child(button)
	for idx in Buttons.get_child_count():
		await Buttons.get_child(idx).get_vote()


func _item_installed(app_id: int, _id: int) -> void:
	if app_id == SteamManager.APP_ID:
		reload_all_levels()

func _item_downloaded(app_id: int, _id: int, _res: int) -> void:
	if app_id == SteamManager.APP_ID:
		reload_all_levels()

func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_WM_GO_BACK_REQUEST:
		_back_logic()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"return"):
		_back_logic()

func _back_logic() -> void:
	_on_back_pressed()

func _on_back_pressed():
	AudioManager.play_sfx("button_back")
	TransitionManager.pop_scene()


func _on_open_workshop_pressed() -> void:
	AudioManager.play_sfx("button_pressed")
	if SteamManager.enabled:
		SteamManager.steam.activateGameOverlayToWebPage("https://steamcommunity.com/app/2716690/workshop/")


func _on_dark_mode_changed(is_dark : bool):
	theme = Global.get_theme(is_dark)


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")
