extends Control

@onready var Buttons: BoxContainer = %ButtonsContainer

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
	SteamManager.steam.item_downloaded.connect(_item_downloaded)
	SteamManager.steam.item_installed.connect(_item_installed)

func _item_installed(app_id: int, _id: int) -> void:
	if app_id == SteamManager.APP_ID:
		reload_all_levels()

func _item_downloaded(app_id: int, _id: int, _res: int) -> void:
	if app_id == SteamManager.APP_ID:
		reload_all_levels()

func _on_back_pressed():
	TransitionManager.pop_scene()


func _on_open_workshop_pressed() -> void:
	if SteamManager.enabled:
		SteamManager.steam.activateGameOverlayToWebPage("https://steamcommunity.com/app/2716690/workshop/")
