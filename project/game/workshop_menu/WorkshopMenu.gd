extends Control

@onready var ButtonsContainer: BoxContainer = $ScrollContainer/MarginContainer/VBoxContainer

func _ready() -> void:
	if not SteamManager.enabled:
		return
	var ids := Steam.getSubscribedItems()
	var button_class := preload("res://game/workshop_menu/WorkshopLevelButton.tscn")
	for id in ids:
		var button := button_class.instantiate()
		button.id = id
		ButtonsContainer.add_child(button)
	Steam.item_downloaded.connect(reload_all_levels)

func reload_all_levels() -> void:
	get_tree().reload_current_scene()

func _on_back_pressed():
	TransitionManager.pop_scene()
