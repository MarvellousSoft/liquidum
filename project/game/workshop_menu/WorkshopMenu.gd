extends Control

@onready var ButtonsContainer: BoxContainer = $ScrollContainer/VBoxContainer

func _ready() -> void:
	if not SteamManager.enabled:
		return
	var ids: Array = SteamManager.steam.getSubscribedItems()
	var button_class := preload("res://game/workshop_menu/WorkshopLevelButton.tscn")
	for id in ids:
		var button := button_class.instantiate()
		button.id = id
		ButtonsContainer.add_child(button)
	SteamManager.steam.item_downloaded.connect(_item_downloaded)
	SteamManager.steam.item_installed.connect(_item_installed)

func _item_installed(app_id: int, _id: int) -> void:
	if app_id == SteamManager.APP_ID:
		reload_all_levels()

func _item_downloaded(app_id: int, _id: int, _res: int) -> void:
	if app_id == SteamManager.APP_ID:
		reload_all_levels()

func reload_all_levels() -> void:
	get_tree().reload_current_scene()

func _on_back_pressed():
	TransitionManager.pop_scene()
