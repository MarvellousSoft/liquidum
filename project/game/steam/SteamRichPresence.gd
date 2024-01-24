extends Node

@export var display: String
@export var group: String
@export var extra_data: Dictionary

func _enter_tree() -> void:
	if not SteamManager.enabled:
		return
	SteamManager.steam.setRichPresence("steam_display", display)
	SteamManager.steam.setRichPresence("steam_player_group", group)
	for key in extra_data:
		SteamManager.steam.setRichPresence(key, extra_data[key])

func set_display(value: String) -> void:
	set_key_value("steam_display", value)

func set_group(value: String) -> void:
	set_key_value("steam_player_group", value)

func set_key_value(key: String, value: String) -> void:
	if SteamManager.enabled:
		SteamManager.steam.setRichPresence(key, value)

func _exit_tree() -> void:
	if SteamManager.enabled:
		SteamManager.steam.clearRichPresence()

